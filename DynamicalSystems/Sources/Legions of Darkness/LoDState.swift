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
