//
//  LoDAction.swift
//  DynamicalSystems
//
//  Legions of Darkness — Action enum for the composed game.
//

import Foundation

extension LoD {

  /// All possible actions in the composed game.
  /// Actions represent pure player intent — die rolls happen during resolution.
  indirect enum Action: Hashable, CustomStringConvertible, GroupedAction {

    // -- Grouped actions --
    case combat(CombatAction)
    case build(BuildAction)
    case magic(MagicAction)
    case heroic(HeroicAction)
    case quest(QuestAction)
    case chainLightning(ChainLightningAction)
    case fortune(FortuneAction)
    case deathAndDespair(DeathAndDespairAction)

    // -- Card phase --
    case drawCard

    // -- Army phase (automatic, driven by card advance icons) --
    case advanceArmies

    // -- Event phase --
    case skipEvent                          // card has no event

    // -- Events (no choice) --
    case catapultShrapnel
    case rocksOfAges
    case actsOfValor
    case distractedDefenders
    case brokenWalls
    case lamentationOfWomen
    case reignOfArrows
    case trappedByFlames
    case bannersInDistance
    case campfires
    case councilOfHeroes
    case paleMoonlight
    case midnightMagic
    case deathAndDespairEvent
    case waningMoon
    case mysticForcesReborn

    // -- Events (player choice) --
    case bumpInTheNight(BumpInTheNightAction)
    case deserters(DesertersAction)
    case bloodyHandprints(BloodyHandprintsAction)
    case assassinsCreedo(AssassinsCreedoAction)
    case harbingers(HarbingersAction)

    // -- Spells --
    case fireball(slot: ArmySlot)
    case slow(slot: ArmySlot, heroic: Bool)
    case cureWounds(heroes: [HeroType], heroic: Bool)
    case massHeal(defenders: [DefenderType], heroic: Bool)
    case divineWrath(slots: [ArmySlot], heroic: Bool)
    case raiseDead(defenders: [DefenderType], returnHero: HeroType?, heroic: Bool)
    case inspire(heroic: Bool)
    case castChainLightning(heroic: Bool)
    case castFortune(heroic: Bool)

    // -- Quest rewards --
    case scrollsOfTheDead(SpellType)
    case putForthTheCall(DefenderType)
    case lastDitchEfforts(HeroType)
    case pillarsOfTheEarth(ArmySlot)
    case prophecyRevealed(discardIndex: Int)

    // -- Player turn (ungrouped) --
    case rogueMove(HeroLocation)           // free move, no action cost (rule 10.4)
    case acidMeleeAttack(ArmySlot)         // free acid attack, no action cost (rule 6.3)
    case endPlayerTurn

    // -- Bloody battle placement choice (Gate tie) --
    case chooseBloodyBattle(ArmySlot)

    // -- Paladin re-roll (rule 10.2) --
    case paladinReroll
    case declineReroll

    // -- Housekeeping --
    case performHousekeeping

    // -- Victory / Defeat --
    case claimVictory
    case declareLoss

    var description: String {
      switch self {
      case .combat(let sub): return sub.description
      case .build(let sub): return sub.description
      case .magic(let sub): return sub.description
      case .heroic(let sub): return sub.description
      case .quest(let sub): return sub.description
      case .chainLightning(let sub): return sub.description
      case .fortune(let sub): return sub.description
      case .deathAndDespair(let sub): return sub.description
      case .drawCard: return "Draw Card"
      case .advanceArmies: return "Advance Armies"
      case .skipEvent: return "Skip Event"
      case .catapultShrapnel: return "Catapult Shrapnel"
      case .rocksOfAges: return "Rocks of Ages"
      case .actsOfValor: return "Acts of Valor"
      case .distractedDefenders: return "Distracted Defenders"
      case .brokenWalls: return "Broken Walls"
      case .lamentationOfWomen: return "Lamentation of the Women"
      case .reignOfArrows: return "Reign of Arrows"
      case .trappedByFlames: return "Trapped by Flames"
      case .bannersInDistance: return "Banners in the Distance"
      case .campfires: return "Campfires in the Distance"
      case .councilOfHeroes: return "Council of Heroes"
      case .paleMoonlight: return "In the Pale Moonlight"
      case .midnightMagic: return "Midnight Magic"
      case .waningMoon: return "The Waning Moon"
      case .mysticForcesReborn: return "Mystic Forces Reborn"
      case .deathAndDespairEvent: return "Death and Despair"
      case .bumpInTheNight(let sub): return sub.description
      case .deserters(let sub): return sub.description
      case .bloodyHandprints(let sub): return sub.description
      case .assassinsCreedo(let sub): return sub.description
      case .harbingers(let sub): return sub.description
      case .fireball(let slot): return "Fireball on \(slot)"
      case .slow(let slot, let heroic): return "Slow on \(slot)\(heroic ? " (heroic)" : "")"
      case .cureWounds(let heroes, let heroic):
        return "Cure Wounds: \(heroes)\(heroic ? " (heroic)" : "")"
      case .massHeal(let defs, let heroic):
        return "Mass Heal: \(defs)\(heroic ? " (heroic)" : "")"
      case .divineWrath(let slots, let heroic):
        return "Divine Wrath: \(slots)\(heroic ? " (heroic)" : "")"
      case .raiseDead(let defs, let hero, let heroic):
        return "Raise Dead: \(defs)\(hero.map { ", \($0)" } ?? "")\(heroic ? " (heroic)" : "")"
      case .inspire(let heroic): return "Inspire\(heroic ? " (heroic)" : "")"
      case .castChainLightning(let heroic): return "Chain Lightning\(heroic ? " (heroic)" : "")"
      case .castFortune(let heroic): return "Fortune\(heroic ? " (heroic)" : "")"
      case .scrollsOfTheDead(let spell): return "Quest: learn \(spell)"
      case .putForthTheCall(let def): return "Quest: recruit \(def)"
      case .lastDitchEfforts(let hero): return "Quest: add \(hero)"
      case .pillarsOfTheEarth(let slot): return "Quest: retreat \(slot)"
      case .prophecyRevealed: return "Quest: Prophecy Revealed"
      case .chooseBloodyBattle(let slot): return "Place Bloody Battle on \(slot)"
      case .rogueMove(let loc): return "Rogue Move → \(loc)"
      case .acidMeleeAttack(let slot): return "Acid Attack on \(slot)"
      case .endPlayerTurn: return "End Turn"
      case .paladinReroll: return "Paladin Re-roll"
      case .declineReroll: return "Decline Re-roll"
      case .performHousekeeping: return "End Turn"
      case .claimVictory: return "Victory!"
      case .declareLoss: return "Defeat"
      }
    }

    var actionGroup: String {
      switch self {
      case .fireball, .slow, .cureWounds, .massHeal, .divineWrath,
           .raiseDead, .inspire, .castChainLightning, .castFortune:
        return "Magic"
      case .scrollsOfTheDead, .putForthTheCall, .lastDitchEfforts,
           .pillarsOfTheEarth, .prophecyRevealed:
        return "Quest"
      case .catapultShrapnel, .rocksOfAges, .actsOfValor, .distractedDefenders,
           .brokenWalls, .lamentationOfWomen, .reignOfArrows, .trappedByFlames,
           .bannersInDistance, .campfires, .councilOfHeroes, .paleMoonlight,
           .midnightMagic, .waningMoon, .mysticForcesReborn,
           .deathAndDespairEvent,
           .bumpInTheNight, .deserters, .bloodyHandprints, .assassinsCreedo,
           .harbingers, .skipEvent:
        return "Event"
      default:
        let mirror = Mirror(reflecting: self)
        guard let child = mirror.children.first,
              let group = child.value as? any ActionGroup else {
          return "General"
        }
        return type(of: group).groupName
      }
    }
  }
}
