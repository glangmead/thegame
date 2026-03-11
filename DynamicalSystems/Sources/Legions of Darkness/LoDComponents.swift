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

    /// Printed values at each track position (index 0 = starting/best).
    var trackValues: [Int] {
      switch self {
      case .menAtArms: return [3, 2, 2, 2, 1, 0]
      case .archers: return [2, 2, 1, 1, 0]
      case .priests: return [2, 2, 1, 0]
      }
    }

    var trackLength: Int { trackValues.count }
    var startingPosition: Int { 0 }
    var lastPosition: Int { trackLength - 1 }

    /// Starting capability value (equivalent to old maxValue).
    var maxValue: Int { trackValues[0] }
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

}
