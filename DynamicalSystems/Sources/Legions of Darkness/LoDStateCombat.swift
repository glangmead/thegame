//
//  LoDStateCombat.swift
//  DynamicalSystems
//
//  Legions of Darkness — Combat, army advancement, and heroic acts.
//

import Foundation

extension LoD.State {

  // MARK: - Army Advancement (rule 4.1)

  /// Result of attempting to advance an army one space toward the castle.
  enum AdvanceResult: Equatable, CustomStringConvertible {
    case advanced(LoD.ArmySlot, from: Int, destination: Int)
    case breachCreated(LoD.Track)
    case armyEnteredCastle(LoD.Track)
    case barricadeHeld(LoD.Track)
    case armyBrokeBarricade(LoD.Track)
    case defenderLoss
    case notOnBoard
    case slowMarkerRemoved(LoD.ArmySlot)
    case greaseHeld(LoD.Track)

    var description: String {
      switch self {
      case .advanced(_, let from, let dest):
        return "moved from space \(from) to \(dest)"
      case .breachCreated(let track):
        return "breach created on \(track.rawValue)"
      case .armyEnteredCastle(let track):
        return "army entered castle via \(track.rawValue)"
      case .barricadeHeld(let track):
        return "barricade held on \(track.rawValue)"
      case .armyBrokeBarricade(let track):
        return "barricade broken on \(track.rawValue)"
      case .defenderLoss:
        return "defender lost"
      case .notOnBoard:
        return "army not on board"
      case .slowMarkerRemoved(let slot):
        return "slow removed from \(slot.rawValue)"
      case .greaseHeld(let track):
        return "grease held on \(track.rawValue)"
      }
    }
  }

  /// Advance a single army slot one space toward the castle (space number decreases).
  mutating func advanceArmy(_ slot: LoD.ArmySlot) -> AdvanceResult {
    guard let currentSpace = armyPosition[slot] else {
      return .notOnBoard
    }

    // Slow spell: remove marker instead of advancing
    if slowedArmy == slot {
      slowedArmy = nil
      return .slowMarkerRemoved(slot)
    }

    let track = slot.track
    let newSpace = currentSpace - 1

    // Terror and Sky special rule (4.4): cannot enter castle
    if !track.isWall && newSpace < 1 {
      return .defenderLoss
    }

    // Wall track advancing to space 0 (4.1.2, 4.1.3)
    if track.isWall && newSpace == 0 {
      if barricades.contains(track) {
        // Barricade test (4.1.3)
        let roll = LoD.rollDie()
        let strength = armyType[slot]!.strength
        if roll <= strength {
          barricades.remove(track)
          armyPosition[slot] = 0
          endInDefeat()
          return .armyBrokeBarricade(track)
        } else {
          barricades.remove(track)
          breaches.insert(track)
          return .barricadeHeld(track)
        }
      } else if !breaches.contains(track) {
        // Grease check (rule 6.3): army rolls die, if > 2 stays on space 1
        if upgrades[track] == .grease {
          upgrades.removeValue(forKey: track)  // Grease is consumed
          let roll = LoD.rollDie()
          if roll > 2 {
            // Grease held — army stays on space 1
            return .greaseHeld(track)
          }
          // Grease failed — fall through to create breach
        }
        // First time: create breach, remove any upgrade (4.1.2)
        upgrades.removeValue(forKey: track)
        breaches.insert(track)
        return .breachCreated(track)
      } else {
        // Breach exists: army enters → defeat
        armyPosition[slot] = 0
        endInDefeat()
        return .armyEnteredCastle(track)
      }
    }

    // Normal advance
    armyPosition[slot] = newSpace
    return .advanced(slot, from: currentSpace, destination: newSpace)
  }

  /// Process one advance icon for a given track.
  /// For the Gate track, applies rule 4.1.1 (farthest advances first; tied = both).
  mutating func advanceArmyOnTrack(_ track: LoD.Track) -> [AdvanceResult] {
    if track == .gate {
      return advanceGateArmies()
    }
    guard let slot = LoD.ArmySlot.allCases.first(where: { $0.track == track }) else {
      return []
    }
    return [advanceArmy(slot)]
  }

  /// Gate track advancement per rule 4.1.1.
  private mutating func advanceGateArmies() -> [AdvanceResult] {
    let pos1 = armyPosition[.gate1]
    let pos2 = armyPosition[.gate2]

    switch (pos1, pos2) {
    case (nil, nil):
      return [.notOnBoard]
    case (_?, nil):
      return [advanceArmy(.gate1)]
    case (nil, _?):
      return [advanceArmy(.gate2)]
    case (let pos1?, let pos2?):
      if pos1 > pos2 {
        return [advanceArmy(.gate1)]
      } else if pos2 > pos1 {
        return [advanceArmy(.gate2)]
      } else {
        let result1 = advanceArmy(.gate1)
        let result2 = advanceArmy(.gate2)
        return [result1, result2]
      }
    }
  }

  /// Lose one defender of the specified type (rule 8.2.1).
  mutating func loseDefender(_ type: LoD.DefenderType) {
    if let current = defenderPosition[type], current < type.lastPosition {
      defenderPosition[type] = current + 1
    }
    if allDefendersAtZero {
      endInDefeat()
    }
  }

  // MARK: - Time LoD.Track Advancement (rule 3.1)

  /// Advance the time marker by the given number of spaces.
  /// Triggers twilight (3.1.1) and dawn (3.1.2) effects for each such space
  /// entered or passed through. Clamped at position 15 (Final Twilight).
  mutating func advanceTime(by spaces: Int) {
    guard spaces > 0 else { return }

    let finalPosition = 15
    for _ in 0..<spaces {
      guard timePosition < finalPosition else { return }
      timePosition += 1
      let spaceType = LoDComponents.timeTrack[timePosition]

      switch spaceType {
      case .twilight:
        // Rule 3.1.1: +1 arcane energy, place Terror army at space 3
        arcaneEnergy = min(arcaneEnergy + 1, 6)
        armyPosition[.terror] = 3
      case .dawn:
        // Rule 3.1.2: -1 morale, +1 arcane energy, remove Terror army
        morale = morale.lowered()
        arcaneEnergy = min(arcaneEnergy + 1, 6)
        armyPosition.removeValue(forKey: .terror)
      case .day, .night:
        break
      }
    }
  }

  /// Whether the time marker is on the Final Twilight (victory check).
  var isOnFinalTwilight: Bool {
    timePosition == 15
  }

  // MARK: - Battle Resolution (rule 8.0)

  enum AttackType: Equatable {
    case melee
    case ranged
  }

  enum AttackResult: Equatable, CustomStringConvertible {
    case hit(LoD.ArmySlot, pushedFrom: Int, pushedTo: Int)
    case miss(LoD.ArmySlot)
    case naturalOneFail(LoD.ArmySlot)
    case targetNotOnBoard
    case targetNotInMeleeRange
    case targetNotInRange

    var description: String {
      switch self {
      case .hit(let slot, let from, let dest):
        return "hit \(slot.rawValue), pushed from \(from) to \(dest)"
      case .miss(let slot):
        return "missed \(slot.rawValue)"
      case .naturalOneFail(let slot):
        return "natural 1 vs \(slot.rawValue)"
      case .targetNotOnBoard:
        return "target not on board"
      case .targetNotInMeleeRange:
        return "target not in melee range"
      case .targetNotInRange:
        return "target not in range"
      }
    }
  }

  /// Resolve an attack action against an army.
  ///
  /// - Parameters:
  ///   - slot: Which army to attack.
  ///   - attackType: `.melee` or `.ranged`.
  ///   - dieRoll: The natural d6 roll (1–6) before any modifiers.
  ///   - drm: Total die-roll modifier (hero bonuses, upgrade bonuses, etc.).
  ///   - isMagical: Whether this is a magical attack (ignores negative DRMs in melee range).
  /// - Returns: The result of the attack.
  mutating func resolveAttack(
    on slot: LoD.ArmySlot,
    attackType: AttackType,
    dieRoll: Int,
    drm: Int = 0,
    isMagical: Bool = false
  ) -> AttackResult {
    guard let space = armyPosition[slot] else {
      return .targetNotOnBoard
    }

    let track = slot.track

    // Natural 1 always fails (rules_notes: die rolls)
    if dieRoll == 1 {
      return .naturalOneFail(slot)
    }

    // Range validation
    switch attackType {
    case .melee:
      if !track.isMeleeRange(space: space) {
        return .targetNotInMeleeRange
      }
    case .ranged:
      // Ranged can target any space — but Terror is melee-only (rule 4.2)
      if track == .terror {
        return .targetNotInRange
      }
    }

    // Apply DRMs
    var effectiveDRM = drm
    // Magical attacks in melee range ignore negative DRMs
    if isMagical && track.isMeleeRange(space: space) {
      effectiveDRM = max(effectiveDRM, 0)
    }

    let modifiedRoll = dieRoll + effectiveDRM
    let strength = armyType[slot]!.strength

    if modifiedRoll > strength {
      // Hit — push army back one space (away from castle)
      let newSpace = min(space + 1, track.maxSpace)
      armyPosition[slot] = newSpace
      return .hit(slot, pushedFrom: space, pushedTo: newSpace)
    } else {
      return .miss(slot)
    }
  }

  // MARK: - Upgrade DRM (rule 6.3)

  /// DRM bonus from an upgrade on a track, for an army at a given space.
  /// Only applies to armies at space 1.
  func upgradeDRM(on track: LoD.Track, attackType: AttackType) -> Int {
    guard let upgrade = upgrades[track] else { return 0 }
    // Upgrades only affect armies at space 1 (per Player Aid)
    switch upgrade {
    case .grease:
      // Grease is a breach-prevention mechanic, not a DRM
      return 0
    case .oil:
      // +1 DRM to melee or ranged in space 1
      return 1
    case .lava:
      // +2 DRM to melee against army in space 1
      return attackType == .melee ? 2 : 0
    case .acid:
      // Acid gives a free attack, not a DRM bonus
      return 0
    }
  }

  // MARK: - Gate Targeting (rules 4.1.1, 8.1.2)

  /// Which army slot on the Gate track is eligible to be attacked.
  /// Rule: only the closest (lowest space number). If tied, either can be targeted (player choice, rule 8.1.2).
  func gateAttackTargets() -> [LoD.ArmySlot] {
    let pos1 = armyPosition[.gate1]
    let pos2 = armyPosition[.gate2]

    switch (pos1, pos2) {
    case (nil, nil): return []
    case (_?, nil): return [.gate1]
    case (nil, _?): return [.gate2]
    case (let pos1?, let pos2?):
      if pos1 < pos2 {
        return [.gate1]
      } else if pos2 < pos1 {
        return [.gate2]
      } else {
        return [.gate1, .gate2] // tied — player chooses
      }
    }
  }

  // MARK: - Bloody Battle (Player Aid: Markers)

  /// Check whether an attack against `slot` triggers the bloody battle
  /// defender cost. Returns true if a defender must be lost.
  /// Automatically marks the cost as paid for this turn.
  mutating func checkBloodyBattle(attacking slot: LoD.ArmySlot) -> Bool {
    guard bloodyBattleArmy == slot, !bloodyBattlePaidThisTurn else {
      return false
    }
    bloodyBattlePaidThisTurn = true
    return true
  }

  // MARK: - Paladin Re-roll (Player Aid: Paladin — holy)

  /// Whether the Paladin can use their once-per-turn re-roll.
  var canPaladinReroll: Bool {
    !paladinRerollUsed
      && heroLocation[.paladin] != nil
      && !heroDead.contains(.paladin)
  }

  /// Mark the Paladin re-roll as used for this turn.
  mutating func usePaladinReroll() {
    paladinRerollUsed = true
  }

}
