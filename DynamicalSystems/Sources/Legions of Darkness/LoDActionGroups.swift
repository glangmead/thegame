//
//  LoDActionGroups.swift
//  DynamicalSystems
//
//  Legions of Darkness — Action sub-enums for grouped UI rendering.
//

import Foundation

extension LoD {

  // MARK: - Combat

  enum CombatAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Combat"

    case meleeAttack(ArmySlot, bloodyBattleDefender: DefenderType?, useMagicSword: ItemTiming?)
    case rangedAttack(ArmySlot, bloodyBattleDefender: DefenderType?, useMagicBow: ItemTiming?)

    var description: String {
      switch self {
      case .meleeAttack(let slot, _, _):
        return "Melee: \(slot.rawValue.capitalized)"
      case .rangedAttack(let slot, _, _):
        return "Ranged: \(slot.rawValue.capitalized)"
      }
    }
  }

  // MARK: - Build

  enum BuildAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Fortification"

    case buildUpgrade(UpgradeType, Track)
    case buildBarricade(Track)

    var description: String {
      switch self {
      case .buildUpgrade(let upgrade, let track):
        return "Build \(upgrade) on \(track.rawValue.capitalized)"
      case .buildBarricade(let track):
        return "Barricade \(track.rawValue.capitalized)"
      }
    }
  }

  // MARK: - Magic

  enum MagicAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Magic"

    case chant
    case memorize
    case pray

    var description: String {
      switch self {
      case .chant:
        return "Chant"
      case .memorize:
        return "Memorize"
      case .pray:
        return "Pray"
      }
    }
  }

  // MARK: - Heroic

  enum HeroicAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Heroic"

    case moveHero(HeroType, HeroLocation)
    case heroicAttack(HeroType, ArmySlot)
    case rally

    var description: String {
      switch self {
      case .moveHero(let hero, let loc):
        return "Move \(hero.rawValue.capitalized) → \(loc)"
      case .heroicAttack(let hero, let slot):
        return "\(hero.rawValue.capitalized) Attack \(slot.rawValue.capitalized)"
      case .rally:
        return "Rally"
      }
    }
  }

  // MARK: - Quest

  enum QuestAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Quest"

    case quest(isHeroic: Bool, pointsSpent: Int = 1)

    var description: String {
      switch self {
      case .quest(let isHeroic, let pts):
        let label = isHeroic ? "Heroic Quest" : "Quest"
        let spendLabel = pts > 1 ? " (spend \(pts))" : ""
        return "\(label)\(spendLabel)"
      }
    }
  }
}
