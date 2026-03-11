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

    case meleeAttack(ArmySlot, dieRoll: Int, bloodyBattleDefender: DefenderType?, useMagicSword: ItemTiming?)
    case rangedAttack(ArmySlot, dieRoll: Int, bloodyBattleDefender: DefenderType?, useMagicBow: ItemTiming?)

    var description: String {
      switch self {
      case .meleeAttack(let slot, let roll, _, _):
        return roll > 0
          ? "Melee: \(slot.rawValue.capitalized) (roll \(roll))"
          : "Melee: \(slot.rawValue.capitalized)"
      case .rangedAttack(let slot, let roll, _, _):
        return roll > 0
          ? "Ranged: \(slot.rawValue.capitalized) (roll \(roll))"
          : "Ranged: \(slot.rawValue.capitalized)"
      }
    }
  }

  // MARK: - Build

  enum BuildAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Fortification"

    case buildUpgrade(UpgradeType, Track, dieRoll: Int)
    case buildBarricade(Track, dieRoll: Int)

    var description: String {
      switch self {
      case .buildUpgrade(let upgrade, let track, let roll):
        return roll > 0
          ? "Build \(upgrade) on \(track.rawValue.capitalized) (roll \(roll))"
          : "Build \(upgrade) on \(track.rawValue.capitalized)"
      case .buildBarricade(let track, let roll):
        return roll > 0
          ? "Barricade \(track.rawValue.capitalized) (roll \(roll))"
          : "Barricade \(track.rawValue.capitalized)"
      }
    }
  }

  // MARK: - Magic

  enum MagicAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Magic"

    case chant(dieRoll: Int)
    case memorize(randomSpell: SpellType?)
    case pray(randomSpell: SpellType?)
    case castSpell(SpellType, heroic: Bool, SpellCastParams)

    var description: String {
      switch self {
      case .chant(let roll):
        return roll > 0 ? "Chant (roll \(roll))" : "Chant"
      case .memorize(let spell):
        if let spell { return "Memorize \(spell)" }
        return "Memorize"
      case .pray(let spell):
        if let spell { return "Pray \(spell)" }
        return "Pray"
      case .castSpell(let spell, let heroic, _):
        return heroic ? "Heroic Cast \(spell)" : "Cast \(spell)"
      }
    }
  }

  // MARK: - Heroic

  enum HeroicAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Heroic"

    case moveHero(HeroType, HeroLocation)
    case heroicAttack(HeroType, ArmySlot, dieRoll: Int)
    case rally(dieRoll: Int)

    var description: String {
      switch self {
      case .moveHero(let hero, let loc):
        return "Move \(hero.rawValue.capitalized) → \(loc)"
      case .heroicAttack(let hero, let slot, let roll):
        return roll > 0
          ? "\(hero.rawValue.capitalized) Attack \(slot.rawValue.capitalized) (roll \(roll))"
          : "\(hero.rawValue.capitalized) Attack \(slot.rawValue.capitalized)"
      case .rally(let roll):
        return roll > 0 ? "Rally (roll \(roll))" : "Rally"
      }
    }
  }

  // MARK: - Quest

  enum QuestAction: ActionGroup, CustomStringConvertible {
    static let groupName = "Quest"

    case quest(isHeroic: Bool, dieRoll: Int, reward: QuestRewardParams)

    var description: String {
      switch self {
      case .quest(let isHeroic, let roll, _):
        let label = isHeroic ? "Heroic Quest" : "Quest"
        return roll > 0 ? "\(label) (roll \(roll))" : label
      }
    }
  }
}
