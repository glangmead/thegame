//
//  LoDComponents.swift
//  DynamicalSystems
//
//  Legions of Darkness — Component definitions derived from rules PDF.
//

import Foundation

typealias LoD = LoDComponents

struct LoDComponents: GameComponents {

  enum Player: Equatable, Hashable {
    case solo
  }

  // MARK: - Tracks (rule 4.0)

  /// The five army tracks leading to the castle.
  /// East, West, Gate are "wall" tracks (rule 4.1.2) — can breach and have upgrades.
  /// Terror and Sky cannot breach or have upgrades (rule 4.4).
  enum Track: String, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case east, west, gate, terror, sky

    var isWall: Bool {
      switch self {
      case .east, .west, .gate: return true
      case .terror, .sky: return false
      }
    }

    /// Highest numbered space on this track (farthest from castle).
    var maxSpace: Int {
      switch self {
      case .east, .west, .sky: return 6
      case .gate: return 4
      case .terror: return 3
      }
    }

    /// Whether a given space is in melee range (red-tinted on board).
    /// Melee attacks can only target armies on melee-range spaces.
    /// Ranged attacks can target any space.
    func isMeleeRange(space: Int) -> Bool {
      switch self {
      case .east, .west: return space >= 1 && space <= 3
      case .gate: return space >= 1 && space <= 3
      case .terror: return true // all spaces (rule 4.2)
      case .sky: return space == 1 // only space 1 (rule 4.3)
      }
    }

    static var walls: [Track] { [.east, .west, .gate] }
  }

  // MARK: - Armies (rules 4.0, scenarios)

  enum ArmyType: String, CaseIterable, Equatable, Hashable {
    case goblin, orc, dragon, troll
    case zombie, skeletalRider, wraith, nightmare

    var strength: Int {
      switch self {
      case .goblin: return 2
      case .orc: return 3
      case .dragon: return 4
      case .troll: return 4
      case .zombie: return 3
      case .skeletalRider: return 3
      case .wraith: return 5
      case .nightmare: return 5
      }
    }

    /// Whether this army type is undead (relevant for Divine Wrath bonus).
    var isUndead: Bool {
      switch self {
      case .zombie, .skeletalRider, .wraith, .nightmare: return true
      default: return false
      }
    }
  }

  /// Each army counter is identified by its track slot.
  /// Gate uniquely holds two armies (rule 4.1.1).
  enum ArmySlot: String, CaseIterable, Equatable, Hashable {
    case east, west, gate1, gate2, sky, terror

    var track: Track {
      switch self {
      case .east: return .east
      case .west: return .west
      case .gate1, .gate2: return .gate
      case .sky: return .sky
      case .terror: return .terror
      }
    }
  }

  // MARK: - Heroes (rule 10.0)

  enum HeroType: String, CaseIterable, Equatable, Hashable {
    case warrior, wizard, ranger, rogue, paladin, cleric

    /// DRM applied during heroic attacks.
    var combatDRM: Int {
      switch self {
      case .warrior: return 2
      default: return 1
      }
    }

    /// Whether this hero makes ranged (vs melee) heroic attacks.
    var isRangedCombatant: Bool {
      switch self {
      case .wizard, .ranger, .cleric: return true
      case .warrior, .rogue, .paladin: return false
      }
    }

    /// Whether this hero is immune to wounding during combat.
    /// Warrior (armored) and Ranger (agile) per Player Aid.
    var isWoundImmuneInCombat: Bool {
      switch self {
      case .warrior, .ranger: return true
      default: return false
      }
    }
  }

  enum HeroLocation: Equatable, Hashable {
    case reserves
    case onTrack(Track)
  }

  // MARK: - Defenders (rule 8.2)

  enum DefenderType: String, CaseIterable, Equatable, Hashable {
    case menAtArms, archers, priests

    /// Starting and maximum value for this defender.
    var maxValue: Int {
      switch self {
      case .menAtArms: return 3
      case .archers: return 2
      case .priests: return 2
      }
    }
  }

  // MARK: - Morale (rule 6.1.1)

  enum Morale: String, CaseIterable, Equatable, Hashable, Comparable {
    case low, normal, high

    /// Modifier to action points at start of action phase.
    var actionModifier: Int {
      switch self {
      case .low: return -1
      case .normal: return 0
      case .high: return 1
      }
    }

    func raised() -> Morale {
      switch self {
      case .low: return .normal
      case .normal: return .high
      case .high: return .high
      }
    }

    func lowered() -> Morale {
      switch self {
      case .low: return .low
      case .normal: return .low
      case .high: return .normal
      }
    }

    static func < (lhs: Morale, rhs: Morale) -> Bool {
      let order: [Morale] = [.low, .normal, .high]
      return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
  }

  // MARK: - Magic Item Timing

  /// When to use a magic item relative to a die roll (rule 9.2).
  /// Before rolling: +2 DRM. After seeing the roll: +1 DRM.
  enum ItemTiming: Hashable {
    case before  // +2 DRM
    case after   // +1 DRM
  }

  // MARK: - Upgrades (rule 6.3)

  enum UpgradeType: String, CaseIterable, Equatable, Hashable {
    case grease, oil, acid, lava

    /// Die result must exceed this number to build.
    var buildNumber: Int {
      switch self {
      case .grease: return 3
      case .oil: return 3
      case .acid: return 5
      case .lava: return 5
      }
    }
  }

  // MARK: - Spells (rules 9.2, 9.3)

  enum SpellType: String, CaseIterable, Equatable, Hashable {
    // Arcane (9.2)
    case fireball, slow, chainLightning, fortune
    // Divine (9.3)
    case cureWounds, massHeal, divineWrath, inspire, raiseDead

    var isArcane: Bool {
      switch self {
      case .fireball, .slow, .chainLightning, .fortune: return true
      default: return false
      }
    }

    var isDivine: Bool { !isArcane }

    var energyCost: Int {
      switch self {
      case .fireball: return 1
      case .slow: return 2
      case .chainLightning: return 3
      case .fortune: return 4
      case .cureWounds: return 1
      case .massHeal: return 2
      case .divineWrath: return 3
      case .inspire: return 3
      case .raiseDead: return 4
      }
    }

    static var arcaneSpells: [SpellType] {
      allCases.filter { $0.isArcane }
    }

    static var divineSpells: [SpellType] {
      allCases.filter { $0.isDivine }
    }
  }

  enum SpellStatus: Equatable, Hashable {
    case faceDown
    case known
    case cast
  }

  // MARK: - Time Track (16 spaces)

  /// Type of each space on the time track.
  /// Dawn/day → draw from day deck. Twilight/night → draw from night deck.
  /// Dawn: entering triggers -1 morale, +1 arcane energy, remove Terror army.
  /// Twilight: entering triggers +1 arcane energy, place Terror army at space 3.
  enum TimeSpaceType: String, Equatable, Hashable {
    case dawn
    case day
    case twilight
    case night
  }

  /// The 16-space time track:
  /// First Dawn, day, day, Twilight, night, night, Dawn, day, day, Twilight, night, night, Dawn, day, day, Final Twilight
  static let timeTrack: [TimeSpaceType] = [
    .dawn,      // 0: First Dawn
    .day,       // 1
    .day,       // 2
    .twilight,  // 3
    .night,     // 4
    .night,     // 5
    .dawn,      // 6
    .day,       // 7
    .day,       // 8
    .twilight,  // 9
    .night,     // 10
    .night,     // 11
    .dawn,      // 12
    .day,       // 13
    .day,       // 14
    .twilight   // 15: Final Twilight
  ]

  /// Whether a time space draws from the day deck.
  static func drawsFromDayDeck(at position: Int) -> Bool {
    let spaceType = timeTrack[position]
    return spaceType == .dawn || spaceType == .day
  }

  // MARK: - Turn Phases (rule 3.0)

  enum Phase: String, Equatable, Hashable {
    case setup
    case card
    case army
    case event
    case action
    case heroic
    case housekeeping
    case paladinReact
  }

  // MARK: - Cards (rule 3.0)

  enum DeckType: String, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case day, night
  }

  struct CardDRM: Equatable, Hashable, Codable, Sendable {
    enum ActionType: String, Equatable, Hashable, Codable, Sendable {
      case attack    // all attacks (melee + ranged)
      case melee     // melee attacks only
      case ranged    // ranged attacks only
      case build     // build actions
      case chant     // chant actions
      case rally     // rally heroic acts
    }

    let action: ActionType
    let track: Track?
    let value: Int
  }

  struct CardEvent: Equatable, Hashable, Codable, Sendable {
    let title: String
    let text: String
  }

  struct CardQuest: Equatable, Hashable, Codable, Sendable {
    let title: String
    let text: String
    let target: Int
    let reward: String
    let penalty: String?
  }

  struct Card: Equatable, Hashable, Codable, Sendable {
    let number: Int
    let file: String
    let title: String
    let deck: DeckType
    let advances: [Track]
    let actions: Int
    let heroics: Int
    let actionDRMs: [CardDRM]
    let heroicDRMs: [CardDRM]
    let event: CardEvent?
    let quest: CardQuest?
    let time: Int
    let bloodyBattle: Track?
  }

  // MARK: - Scenarios

  enum Scenario: String, Equatable, Hashable {
    case greenskinHorde
    case undeadScourge
  }

  // MARK: - GameComponents conformance

  enum Piece: Equatable, Hashable {
    case army(ArmySlot)
    case hero(HeroType)
  }

  enum Position: Equatable, Hashable {
    case offBoard
    case onTrack(Track, Int)
    case reserves
  }

  struct PiecePosition: Equatable, Hashable {
    var piece: Piece
    var position: Position
  }
}
