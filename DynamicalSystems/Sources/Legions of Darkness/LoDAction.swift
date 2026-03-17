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
  /// every player choice.
  struct EventResolution: Hashable {
    var chosenHero: HeroType?
    var woundHeroes: Bool = false
    var deserterDefenders: (DefenderType, DefenderType)?
    var sacrificedHeroes: [HeroType] = []
    var sacrificedDefenders: [DefenderType] = []
    var chosenSlot: ArmySlot?
    var advanceSky: Bool = false
    var otherAdvances: [ArmySlot] = []

    // Hashable conformance for the tuple
    static func == (lhs: EventResolution, rhs: EventResolution) -> Bool {
      lhs.chosenHero == rhs.chosenHero
        && lhs.woundHeroes == rhs.woundHeroes
        && lhs.deserterDefenders?.0 == rhs.deserterDefenders?.0
        && lhs.deserterDefenders?.1 == rhs.deserterDefenders?.1
        && lhs.sacrificedHeroes == rhs.sacrificedHeroes
        && lhs.sacrificedDefenders == rhs.sacrificedDefenders
        && lhs.chosenSlot == rhs.chosenSlot
        && lhs.advanceSky == rhs.advanceSky
        && lhs.otherAdvances == rhs.otherAdvances
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(chosenHero)
      hasher.combine(woundHeroes)
      hasher.combine(deserterDefenders?.0)
      hasher.combine(deserterDefenders?.1)
      hasher.combine(sacrificedHeroes)
      hasher.combine(sacrificedDefenders)
      hasher.combine(chosenSlot)
      hasher.combine(advanceSky)
      hasher.combine(otherAdvances)
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
    case resolveEvent(EventResolution)      // card has event

    // -- Player turn (ungrouped) --
    case rogueMove(HeroLocation)           // free move, no action cost (rule 10.4)
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
      case .resolveEvent: return "Resolve Event"
      case .chooseBloodyBattle(let slot): return "Place Bloody Battle on \(slot)"
      case .rogueMove(let loc): return "Rogue Move → \(loc)"
      case .endPlayerTurn: return "End Turn"
      case .paladinReroll: return "Paladin Re-roll"
      case .declineReroll: return "Decline Re-roll"
      case .performHousekeeping: return "End Turn"
      case .claimVictory: return "Victory!"
      case .declareLoss: return "Defeat"
      }
    }
  }
}
