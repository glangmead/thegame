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
  enum Action: Hashable {

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
  }
}
