//
//  LoDAction.swift
//  DynamicalSystems
//
//  Legions of Darkness — Action enum for the composed game.
//

import Foundation

extension LoD {

  /// All parameters needed to resolve an event, packed into one struct
  /// so that a single `.resolveEvent(EventResolution)` action captures
  /// every die roll and player choice deterministically.
  struct EventResolution: Hashable {
    var dieRoll: Int = 0
    var chosenHero: HeroType?
    var woundHeroes: Bool = false
    var deserterDefenders: (DefenderType, DefenderType)?
    var sacrificedHeroes: [HeroType] = []
    var sacrificedDefenders: [DefenderType] = []
    var chosenSlot: ArmySlot?
    var advanceSky: Bool = false
    var otherAdvances: [ArmySlot] = []
    var randomSpell: SpellType?
    var barricadeDieRoll: Int?

    // Hashable conformance for the tuple
    static func == (lhs: EventResolution, rhs: EventResolution) -> Bool {
      lhs.dieRoll == rhs.dieRoll
        && lhs.chosenHero == rhs.chosenHero
        && lhs.woundHeroes == rhs.woundHeroes
        && lhs.deserterDefenders?.0 == rhs.deserterDefenders?.0
        && lhs.deserterDefenders?.1 == rhs.deserterDefenders?.1
        && lhs.sacrificedHeroes == rhs.sacrificedHeroes
        && lhs.sacrificedDefenders == rhs.sacrificedDefenders
        && lhs.chosenSlot == rhs.chosenSlot
        && lhs.advanceSky == rhs.advanceSky
        && lhs.otherAdvances == rhs.otherAdvances
        && lhs.randomSpell == rhs.randomSpell
        && lhs.barricadeDieRoll == rhs.barricadeDieRoll
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(dieRoll)
      hasher.combine(chosenHero)
      hasher.combine(woundHeroes)
      hasher.combine(deserterDefenders?.0)
      hasher.combine(deserterDefenders?.1)
      hasher.combine(sacrificedHeroes)
      hasher.combine(sacrificedDefenders)
      hasher.combine(chosenSlot)
      hasher.combine(advanceSky)
      hasher.combine(otherAdvances)
      hasher.combine(randomSpell)
      hasher.combine(barricadeDieRoll)
    }
  }

  /// Parameters for quest reward application (only used on success).
  struct QuestRewardParams: Hashable {
    var chosenSpell: SpellType?              // Scrolls of the Dead
    var chosenDefender: DefenderType?        // Put Forth the Call
    var chosenHero: HeroType?                // Last Ditch Efforts
    var chosenSlot: ArmySlot?                // Pillars of the Earth
    var discardIndex: Int?                   // Prophecy Revealed
  }

  /// Parameters for spell effect application.
  struct SpellCastParams: Hashable {
    // Targeting (Fireball, Slow, Chain Lightning, Divine Wrath)
    var targetSlot: ArmySlot?
    var targetSlots: [ArmySlot] = []
    var dieRolls: [Int] = []
    // Cure Wounds
    var heroes: [HeroType] = []
    // Mass Heal / Raise Dead
    var defenders: [DefenderType] = []
    var returnHero: HeroType?
    // Fortune
    var newOrder: [Int] = []
    var discardIndex: Int?
  }

  /// All possible actions in the composed game.
  /// Die rolls and random selections are included as parameters so that
  /// the history log is fully deterministic and replayable.
  indirect enum Action: Hashable, CustomStringConvertible {

    // -- Card phase --
    case drawCard

    // -- Army phase (automatic, driven by card advance icons) --
    case advanceArmies(acidAttackDieRolls: [ArmySlot: Int])

    // -- Event phase --
    case skipEvent                          // card has no event
    case resolveEvent(EventResolution)      // card has event

    // -- Action phase --
    case meleeAttack(ArmySlot, dieRoll: Int, bloodyBattleDefender: DefenderType?, useMagicSword: ItemTiming?)
    case rangedAttack(ArmySlot, dieRoll: Int, bloodyBattleDefender: DefenderType?, useMagicBow: ItemTiming?)
    case buildUpgrade(UpgradeType, Track, dieRoll: Int)
    case chant(dieRoll: Int)
    case memorize(SpellType)
    case pray(SpellType)
    case questAction(dieRoll: Int, reward: QuestRewardParams)
    case castSpell(SpellType, heroic: Bool, SpellCastParams)
    case buildBarricade(Track, dieRoll: Int) // build barricade on breached wall (rule 6.3)
    case rogueMove(HeroLocation)           // free move, no action cost (rule 10.4)
    case passActions

    // -- Heroic phase --
    case moveHero(HeroType, HeroLocation)
    case heroicAttack(HeroType, ArmySlot, dieRoll: Int)
    case rally(dieRoll: Int)
    case questHeroic(dieRoll: Int, reward: QuestRewardParams)
    case passHeroics

    // -- Paladin re-roll (rule 10.2) --
    case paladinReroll(newDieRoll: Int)
    case declineReroll

    // -- Housekeeping --
    case performHousekeeping

    // -- Victory / Defeat --
    case claimVictory
    case declareLoss

    var description: String {
      switch self {
      case .drawCard: return "Draw Card"
      case .advanceArmies: return "Advance Armies"
      case .skipEvent: return "Skip Event"
      case .resolveEvent(let event):
        return event.dieRoll > 0 ? "Resolve Event (roll \(event.dieRoll))" : "Resolve Event"
      case .meleeAttack(let slot, let roll, _, _):
        return "Melee: \(slot.rawValue.capitalized) (roll \(roll))"
      case .rangedAttack(let slot, let roll, _, _):
        return "Ranged: \(slot.rawValue.capitalized) (roll \(roll))"
      case .buildUpgrade(let upgrade, let track, let roll):
        return "Build \(upgrade) on \(track.rawValue.capitalized) (roll \(roll))"
      case .buildBarricade(let track, let roll):
        return "Barricade \(track.rawValue.capitalized) (roll \(roll))"
      case .chant(let roll): return "Chant (roll \(roll))"
      case .memorize(let spell): return "Memorize \(spell)"
      case .pray(let spell): return "Pray \(spell)"
      case .questAction(let roll, _): return "Quest (roll \(roll))"
      case .castSpell(let spell, let heroic, _):
        return heroic ? "Heroic Cast \(spell)" : "Cast \(spell)"
      case .rogueMove(let loc): return "Rogue Move → \(loc)"
      case .passActions: return "Pass Actions"
      case .moveHero(let hero, let loc): return "Move \(hero.rawValue.capitalized) → \(loc)"
      case .heroicAttack(let hero, let slot, let roll):
        return "\(hero.rawValue.capitalized) Attack \(slot.rawValue.capitalized) (roll \(roll))"
      case .rally(let roll): return "Rally (roll \(roll))"
      case .questHeroic(let roll, _): return "Heroic Quest (roll \(roll))"
      case .passHeroics: return "Pass Heroics"
      case .paladinReroll(let roll): return "Paladin Re-roll (\(roll))"
      case .declineReroll: return "Decline Re-roll"
      case .performHousekeeping: return "End Turn"
      case .claimVictory: return "Victory!"
      case .declareLoss: return "Defeat"
      }
    }

    // Lightweight hash: discriminator + primary identifying field only.
    // Full equality is still checked on collision, so correctness is preserved.
    // MCTS action spaces are small (5-20), making collisions cheap.
    // swiftlint:disable:next cyclomatic_complexity
    func hash(into hasher: inout Hasher) {
      switch self {
      case .drawCard: hasher.combine(0)
      case .advanceArmies: hasher.combine(1)
      case .skipEvent: hasher.combine(2)
      case .resolveEvent: hasher.combine(3)
      case .meleeAttack(let slot, _, _, _):
        hasher.combine(4); hasher.combine(slot)
      case .rangedAttack(let slot, _, _, _):
        hasher.combine(5); hasher.combine(slot)
      case .buildUpgrade(let upgrade, let track, _):
        hasher.combine(6); hasher.combine(upgrade); hasher.combine(track)
      case .chant: hasher.combine(7)
      case .memorize(let spell):
        hasher.combine(8); hasher.combine(spell)
      case .pray(let spell):
        hasher.combine(9); hasher.combine(spell)
      case .questAction: hasher.combine(10)
      case .castSpell(let spell, let heroic, _):
        hasher.combine(11); hasher.combine(spell); hasher.combine(heroic)
      case .buildBarricade(let track, _):
        hasher.combine(12); hasher.combine(track)
      case .rogueMove(let loc):
        hasher.combine(13); hasher.combine(loc)
      case .passActions: hasher.combine(14)
      case .moveHero(let hero, let loc):
        hasher.combine(15); hasher.combine(hero); hasher.combine(loc)
      case .heroicAttack(let hero, let slot, _):
        hasher.combine(16); hasher.combine(hero); hasher.combine(slot)
      case .rally: hasher.combine(17)
      case .questHeroic: hasher.combine(18)
      case .passHeroics: hasher.combine(19)
      case .paladinReroll: hasher.combine(20)
      case .declineReroll: hasher.combine(21)
      case .performHousekeeping: hasher.combine(22)
      case .claimVictory: hasher.combine(23)
      case .declareLoss: hasher.combine(24)
      }
    }
  }
}
