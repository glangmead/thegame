//
//  LoDState.swift
//  DynamicalSystems
//
//  Legions of Darkness — Game state.
//

import Foundation

extension LoD {

  struct State: Equatable, Sendable {

    // MARK: - Turn structure

    var phase: Phase = .setup
    var scenario: Scenario = .greenskinHorde

    // MARK: - Armies

    /// What type of army occupies each slot (set during setup, fixed for the game).
    var armyType: [ArmySlot: ArmyType] = [:]

    /// Current space number for each army. Absent = not yet placed / removed.
    var armyPosition: [ArmySlot: Int] = [:]

    // MARK: - Heroes

    /// Location of each hero in play. Heroes not in play are absent from this dict.
    var heroLocation: [HeroType: HeroLocation] = [:]

    /// Which heroes are wounded.
    var heroWounded: Set<HeroType> = []

    /// Which heroes are dead.
    var heroDead: Set<HeroType> = []

    // MARK: - Defenders

    var defenders: [DefenderType: Int] = [
      .menAtArms: DefenderType.menAtArms.maxValue,
      .archers: DefenderType.archers.maxValue,
      .priests: DefenderType.priests.maxValue,
    ]

    // MARK: - Morale

    var morale: Morale = .normal

    // MARK: - Magic energy

    var arcaneEnergy: Int = 0
    var divineEnergy: Int = 0

    // MARK: - Spells

    var spellStatus: [SpellType: SpellStatus] = {
      var d: [SpellType: SpellStatus] = [:]
      for spell in SpellType.allCases {
        d[spell] = .faceDown
      }
      return d
    }()

    // MARK: - Upgrades (placed on wall track castle circles)

    var upgrades: [Track: UpgradeType] = [:]

    // MARK: - Breaches and barricades (wall tracks only)

    var breaches: Set<Track> = []
    var barricades: Set<Track> = []

    // MARK: - Time

    var timePosition: Int = 0

    // MARK: - Bloody battle

    /// Which army slot has the bloody battle marker, if any.
    var bloodyBattleArmy: ArmySlot? = nil

    /// Whether the bloody battle defender cost has already been paid this turn.
    var bloodyBattlePaidThisTurn: Bool = false

    // MARK: - Per-turn tracking

    /// Whether the Paladin has used their re-roll this turn.
    var paladinRerollUsed: Bool = false

    // MARK: - Victory / defeat

    var ended: Bool = false
    var victory: Bool = false

    // MARK: - Queries

    /// Whether all defenders are at zero (defeat condition per rule 4.4 / 11.1).
    var allDefendersAtZero: Bool {
      defenders.values.allSatisfy { $0 == 0 }
    }

    /// Current time space type.
    var currentTimeSpace: TimeSpaceType {
      LoDComponents.timeTrack[timePosition]
    }

    /// Whether the current time space draws from the day deck.
    var drawsFromDayDeck: Bool {
      LoDComponents.drawsFromDayDeck(at: timePosition)
    }

    /// Heroes currently alive and in play.
    var livingHeroes: [HeroType] {
      heroLocation.keys.filter { !heroDead.contains($0) }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Whether a given track has an army at space 1 (relevant for breach/build rules).
    func armyAtSpace1(on track: Track) -> Bool {
      for slot in ArmySlot.allCases where slot.track == track {
        if armyPosition[slot] == 1 { return true }
      }
      return false
    }

    // MARK: - Army Advancement (rule 4.1)

    /// Result of attempting to advance an army one space toward the castle.
    enum AdvanceResult: Equatable {
      case advanced(ArmySlot, from: Int, to: Int)
      case breachCreated(Track)
      case armyEnteredCastle(Track)
      case barricadeHeld(Track)
      case armyBrokeBarricade(Track)
      case defenderLoss
      case notOnBoard
    }

    /// Advance a single army slot one space toward the castle (space number decreases).
    /// For barricade tests, provide `dieRoll`.
    mutating func advanceArmy(_ slot: ArmySlot, dieRoll: Int? = nil) -> AdvanceResult {
      guard let currentSpace = armyPosition[slot] else {
        return .notOnBoard
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
          let roll = dieRoll!
          let strength = armyType[slot]!.strength
          if roll <= strength {
            barricades.remove(track)
            armyPosition[slot] = 0
            ended = true
            return .armyBrokeBarricade(track)
          } else {
            barricades.remove(track)
            breaches.insert(track)
            return .barricadeHeld(track)
          }
        } else if !breaches.contains(track) {
          // First time: create breach, remove any upgrade (4.1.2)
          upgrades.removeValue(forKey: track)
          breaches.insert(track)
          return .breachCreated(track)
        } else {
          // Breach exists: army enters → defeat
          armyPosition[slot] = 0
          ended = true
          return .armyEnteredCastle(track)
        }
      }

      // Normal advance
      armyPosition[slot] = newSpace
      return .advanced(slot, from: currentSpace, to: newSpace)
    }

    /// Process one advance icon for a given track.
    /// For the Gate track, applies rule 4.1.1 (farthest advances first; tied = both).
    mutating func advanceArmyOnTrack(_ track: Track, dieRoll: Int? = nil) -> [AdvanceResult] {
      if track == .gate {
        return advanceGateArmies(dieRoll: dieRoll)
      }
      guard let slot = ArmySlot.allCases.first(where: { $0.track == track }) else {
        return []
      }
      return [advanceArmy(slot, dieRoll: dieRoll)]
    }

    /// Gate track advancement per rule 4.1.1.
    private mutating func advanceGateArmies(dieRoll: Int? = nil) -> [AdvanceResult] {
      let pos1 = armyPosition[.gate1]
      let pos2 = armyPosition[.gate2]

      switch (pos1, pos2) {
      case (nil, nil):
        return [.notOnBoard]
      case (_?, nil):
        return [advanceArmy(.gate1, dieRoll: dieRoll)]
      case (nil, _?):
        return [advanceArmy(.gate2, dieRoll: dieRoll)]
      case (let p1?, let p2?):
        if p1 > p2 {
          return [advanceArmy(.gate1, dieRoll: dieRoll)]
        } else if p2 > p1 {
          return [advanceArmy(.gate2, dieRoll: dieRoll)]
        } else {
          let r1 = advanceArmy(.gate1, dieRoll: dieRoll)
          let r2 = advanceArmy(.gate2, dieRoll: dieRoll)
          return [r1, r2]
        }
      }
    }

    /// Lose one defender of the specified type (rule 8.2.1).
    mutating func loseDefender(_ type: DefenderType) {
      if let current = defenders[type], current > 0 {
        defenders[type] = current - 1
      }
      if allDefendersAtZero {
        ended = true
      }
    }

    // MARK: - Time Track Advancement (rule 3.1)

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

    enum AttackResult: Equatable {
      case hit(ArmySlot, pushedFrom: Int, pushedTo: Int)
      case miss(ArmySlot)
      case naturalOneFail(ArmySlot)
      case targetNotOnBoard
      case targetNotInMeleeRange
      case targetNotInRange
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
      on slot: ArmySlot,
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

    // MARK: - Heroic Attack (rule 7.0)

    struct HeroicAttackResult: Equatable {
      let attackResult: AttackResult
      let heroWounded: Bool
      let heroKilled: Bool
    }

    enum HeroicAttackError: Error, Equatable {
      case heroNotOnTrack
      case heroOnWrongTrack
    }

    /// Resolve a heroic attack by a hero against an army (rule 7.3).
    /// The hero must be assigned to the same track as the target army.
    /// The hero's combat DRM and attack type are used automatically.
    /// On natural 1: attack fails AND hero is wounded (unless immune).
    mutating func resolveHeroicAttack(
      hero: HeroType,
      on slot: ArmySlot,
      dieRoll: Int,
      additionalDRM: Int = 0
    ) -> Result<HeroicAttackResult, HeroicAttackError> {
      // Rule 7.3: hero must be on the same track as the target army
      guard let location = heroLocation[hero] else {
        return .failure(.heroNotOnTrack)
      }
      guard case .onTrack(let heroTrack) = location, heroTrack == slot.track else {
        return .failure(.heroOnWrongTrack)
      }

      let attackType: AttackType = hero.isRangedCombatant ? .ranged : .melee
      let totalDRM = hero.combatDRM + additionalDRM

      let result = resolveAttack(
        on: slot,
        attackType: attackType,
        dieRoll: dieRoll,
        drm: totalDRM
      )

      // Natural 1: wound hero (unless immune)
      var wounded = false
      var killed = false
      if dieRoll == 1 && !hero.isWoundImmuneInCombat {
        if heroWounded.contains(hero) {
          // Already wounded → killed
          heroDead.insert(hero)
          heroWounded.remove(hero)
          heroLocation.removeValue(forKey: hero)
          killed = true
        } else {
          heroWounded.insert(hero)
          wounded = true
        }
      }

      return .success(HeroicAttackResult(
        attackResult: result,
        heroWounded: wounded,
        heroKilled: killed
      ))
    }

    // MARK: - Hero Wounding

    /// Wound a hero. If already wounded, the hero dies.
    mutating func woundHero(_ hero: HeroType) {
      if heroWounded.contains(hero) {
        heroDead.insert(hero)
        heroWounded.remove(hero)
        heroLocation.removeValue(forKey: hero)
      } else {
        heroWounded.insert(hero)
      }
    }

    // MARK: - Upgrade DRM (rule 6.3)

    /// DRM bonus from an upgrade on a track, for an army at a given space.
    /// Only applies to armies at space 1.
    func upgradeDRM(on track: Track, attackType: AttackType) -> Int {
      guard let upgrade = upgrades[track] else { return 0 }
      // Upgrades only affect armies at space 1 (per Player Aid)
      switch upgrade {
      case .grease, .oil:
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
    func gateAttackTargets() -> [ArmySlot] {
      let pos1 = armyPosition[.gate1]
      let pos2 = armyPosition[.gate2]

      switch (pos1, pos2) {
      case (nil, nil): return []
      case (_?, nil): return [.gate1]
      case (nil, _?): return [.gate2]
      case (let p1?, let p2?):
        if p1 < p2 { return [.gate1] }
        else if p2 < p1 { return [.gate2] }
        else { return [.gate1, .gate2] } // tied — player chooses
      }
    }

    // MARK: - Bloody Battle (Player Aid: Markers)

    /// Check whether an attack against `slot` triggers the bloody battle
    /// defender cost. Returns true if a defender must be lost.
    /// Automatically marks the cost as paid for this turn.
    mutating func checkBloodyBattle(attacking slot: ArmySlot) -> Bool {
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

    // MARK: - Turn Reset (rule 3.0 step 5 — housekeeping)

    /// Reset per-turn tracking at the start of a new turn.
    mutating func resetTurnTracking() {
      bloodyBattlePaidThisTurn = false
      paladinRerollUsed = false
    }
  }

  // MARK: - Greenskin Scenario Setup

  /// Create the initial state for the Greenskin Horde scenario.
  /// `windsOfMagicArcane` is the arcane energy after the Winds of Magic roll
  /// and player choice (before hero bonuses). Divine = 6 - arcane.
  /// Hero bonuses (+2 arcane for Wizard, +2 divine for Cleric) are applied automatically.
  static func greenskinSetup(
    windsOfMagicArcane: Int,
    heroes: [HeroType] = [.warrior, .wizard, .cleric]
  ) -> State {
    var state = State()
    state.scenario = .greenskinHorde

    // Armies (Scenario 1 card)
    state.armyType = [
      .east: .goblin,
      .west: .goblin,
      .gate1: .orc,
      .gate2: .orc,
      .sky: .dragon,
      .terror: .troll,
    ]
    state.armyPosition = [
      .east: 6,
      .west: 6,
      .gate1: 4,
      .gate2: 4,
      .sky: 6,
      // terror: Troll not placed until first twilight
    ]

    // Heroes — all start in Reserves
    for hero in heroes {
      state.heroLocation[hero] = .reserves
    }

    // Defenders at max
    state.defenders = [
      .menAtArms: DefenderType.menAtArms.maxValue,
      .archers: DefenderType.archers.maxValue,
      .priests: DefenderType.priests.maxValue,
    ]

    // Morale starts Normal (rule 6.1.1)
    state.morale = .normal

    // Winds of Magic (rule 2.1)
    let baseArcane = windsOfMagicArcane
    let baseDivine = 6 - windsOfMagicArcane
    let wizardBonus = heroes.contains(.wizard) ? 2 : 0
    let clericBonus = heroes.contains(.cleric) ? 2 : 0
    state.arcaneEnergy = min(baseArcane + wizardBonus, 6)
    state.divineEnergy = min(baseDivine + clericBonus, 6)

    // Time starts at First Dawn
    state.timePosition = 0

    // All spells face-down (default)
    // No breaches, barricades, upgrades (default)
    // Bloody battle in reserves (default nil)

    state.phase = .card

    return state
  }
}
