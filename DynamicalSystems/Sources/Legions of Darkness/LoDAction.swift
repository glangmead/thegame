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
    var chosenHero: HeroType? = nil
    var woundHeroes: Bool = false
    var deserterDefenders: (DefenderType, DefenderType)? = nil
    var sacrificedHeroes: [HeroType] = []
    var sacrificedDefenders: [DefenderType] = []
    var chosenSlot: ArmySlot? = nil
    var advanceSky: Bool = false
    var otherAdvances: [ArmySlot] = []
    var randomSpell: SpellType? = nil
    var barricadeDieRoll: Int? = nil

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

  /// All possible actions in the composed game.
  /// Die rolls and random selections are included as parameters so that
  /// the history log is fully deterministic and replayable.
  enum Action: Hashable {

    // -- Card phase --
    case drawCard

    // -- Army phase (automatic, driven by card advance icons) --
    case advanceArmies

    // -- Event phase --
    case skipEvent                          // card has no event
    case resolveEvent(EventResolution)      // card has event

    // -- Action phase --
    case meleeAttack(ArmySlot, dieRoll: Int)
    case rangedAttack(ArmySlot, dieRoll: Int)
    case buildUpgrade(UpgradeType, Track, dieRoll: Int)
    case chant(dieRoll: Int)
    case memorize(SpellType)
    case pray(SpellType)
    case questAction(dieRoll: Int)
    case passActions

    // -- Heroic phase --
    case moveHero(HeroType, HeroLocation)
    case heroicAttack(HeroType, ArmySlot, dieRoll: Int)
    case rally(dieRoll: Int)
    case questHeroic(dieRoll: Int)
    case passHeroics

    // -- Housekeeping --
    case performHousekeeping
  }
}
