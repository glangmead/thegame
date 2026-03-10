//
//  LoDState.swift
//  DynamicalSystems
//
//  Legions of Darkness — Game state.
//

import Foundation

extension LoD {

  struct State: Equatable, Sendable, HistoryTracking {

    // MARK: - Turn structure

    var phase: Phase = .setup
    var scenario: Scenario = .greenskinHorde

    // MARK: - History (HistoryTracking conformance)

    var history: [LoD.Action] = []

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
      .priests: DefenderType.priests.maxValue
    ]

    // MARK: - Morale

    var morale: Morale = .normal

    // MARK: - Magic energy

    var arcaneEnergy: Int = 0
    var divineEnergy: Int = 0

    // MARK: - Spells

    var spellStatus: [SpellType: SpellStatus] = {
      var statuses: [SpellType: SpellStatus] = [:]
      for spell in SpellType.allCases {
        statuses[spell] = .faceDown
      }
      return statuses
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
    var bloodyBattleArmy: ArmySlot?

    /// Whether the bloody battle defender cost has already been paid this turn.
    var bloodyBattlePaidThisTurn: Bool = false

    // MARK: - Slow marker

    /// Which army slot has the Slow marker, if any.
    var slowedArmy: ArmySlot?

    // MARK: - Card decks (rule 3.0)

    var dayDrawPile: [LoD.Card] = []
    var nightDrawPile: [LoD.Card] = []
    var dayDiscardPile: [LoD.Card] = []
    var nightDiscardPile: [LoD.Card] = []
    var currentCard: LoD.Card?

    // MARK: - Per-turn tracking

    /// Whether the Paladin has used their re-roll this turn.
    var paladinRerollUsed: Bool = false

    /// Action deferred for Paladin re-roll decision (rule 10.2).
    var pendingDieRollAction: LoD.Action?

    /// Phase to return to after Paladin re-roll decision.
    var phaseBeforePaladinReact: LoD.Phase?

    /// Whether Inspire's +1 DRM to all rolls is active this turn.
    var inspireDRMActive: Bool = false

    /// Per-turn +1 attack DRM from events (Acts of Valor, Assassin's Creedo).
    var eventAttackDRMBonus: Int = 0

    /// Whether melee attacks are forbidden this turn (Lamentation of the Women).
    var noMeleeThisTurn: Bool = false

    /// Whether wounded heroes cannot act this turn (Council of Heroes).
    var woundedHeroesCannotAct: Bool = false

    // MARK: - Items (quest rewards)

    /// Whether the player holds the Magic Sword (from The Vorpal Blade quest).
    var hasMagicSword: Bool = false

    /// Whether the player holds the Magic Bow (from Arrows of the Dead quest).
    var hasMagicBow: Bool = false

    // MARK: - Victory / defeat (rule 11.0)

    var ended: Bool = false
    var victory: Bool = false

    enum GameOutcome: Equatable {
      case ongoing
      case victory
      case defeatBreached
      case defeatAllDefendersLost
    }

    /// Current game outcome.
    var outcome: GameOutcome {
      if !ended { return .ongoing }
      if victory { return .victory }
      if allDefendersAtZero { return .defeatAllDefendersLost }
      return .defeatBreached
    }

    /// Check for victory at the end of the Final Twilight turn (rule 11.0).
    /// Call this during housekeeping of the last turn.
    mutating func checkVictory() {
      guard !ended else { return }
      if isOnFinalTwilight {
        ended = true
        victory = true
      }
    }

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

    // MARK: - Budget Tracking (action/heroic phases)

    /// How many action points this turn's card grants (card.actions + morale modifier).
    var actionBudget: Int {
      guard let card = currentCard else { return 0 }
      return max(card.actions + morale.actionModifier, 0)
    }

    /// How many heroic points this turn's card grants.
    var heroicBudget: Int {
      currentCard?.heroics ?? 0
    }

    /// Count action-phase actions taken this turn (since last .advanceArmies or .resolveEvent or .skipEvent).
    var actionPointsSpent: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .skipEvent, .resolveEvent:
          return count
        case .meleeAttack, .rangedAttack, .buildUpgrade, .chant, .memorize, .pray, .questAction, .castSpell:
          count += 1
        default:
          break
        }
      }
      return count
    }

    /// Count heroic-phase actions taken this turn (since last .passActions).
    var heroicPointsSpent: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .passActions:
          return count
        case .moveHero, .heroicAttack, .rally, .questHeroic:
          count += 1
        default:
          break
        }
      }
      return count
    }

    /// Remaining action points this turn.
    var actionBudgetRemaining: Int {
      max(actionBudget - actionPointsSpent, 0)
    }

    /// Remaining heroic points this turn.
    var heroicBudgetRemaining: Int {
      max(heroicBudget - heroicPointsSpent, 0)
    }

  }
}
