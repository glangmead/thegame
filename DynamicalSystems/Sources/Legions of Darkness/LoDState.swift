//
//  LoDState.swift
//  DynamicalSystems
//
//  Legions of Darkness — Game state.
//

import Foundation

extension LoD {

  /// State for a consumable magic item (Sword or Bow).
  /// Non-nil means the item is held. Consumed on use.
  struct MagicItemState: Equatable, Hashable, Sendable {}

  struct State: Equatable, Sendable, HistoryTracking, GameState, CustomStringConvertible {

    // MARK: - GameComponents typealiases

    // swiftlint:disable:next nesting
    typealias Player        = LoDComponents.Player
    // swiftlint:disable:next nesting
    typealias Phase         = LoDComponents.Phase
    // swiftlint:disable:next nesting
    typealias Piece         = LoDComponents.Piece
    // swiftlint:disable:next nesting
    typealias Position      = LoDComponents.Position
    // swiftlint:disable:next nesting
    typealias PiecePosition = LoDComponents.PiecePosition

    // MARK: - GameState conformance

    var player: Player = .solo
    var players: [Player] = [.solo]
    var endedInVictoryFor: [Player] = []
    var endedInDefeatFor: [Player] = []
    var position: [Piece: Position] = [:]

    var description: String { "LoD Turn \(timePosition) (\(phase.rawValue))" }

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

    var defenderPosition: [DefenderType: Int] = [
      .menAtArms: DefenderType.menAtArms.startingPosition,
      .archers: DefenderType.archers.startingPosition,
      .priests: DefenderType.priests.startingPosition
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

    /// Whether the acid upgrade's free attack has been used this turn.
    var acidUsedThisTurn: Bool = false

    /// Army slots eligible for acid free melee attack this turn (arrived at space 1).
    var acidEligibleSlots: Set<ArmySlot> = []

    /// Whether the Last Ditch Efforts quest penalty has been applied this turn.
    /// Guards against double-firing when auto-rules scan at multiple stack frames.
    var questPenaltyAppliedThisTurn: Bool = false

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

    /// Die value from the first roll, stashed for paladin decline path.
    var firstDieRoll: Int?

    /// Whether Inspire's +1 DRM to all rolls is active this turn.
    var inspireDRMActive: Bool = false

    /// Per-turn +1 attack DRM from events (Acts of Valor, Assassin's Creedo).
    var eventAttackDRMBonus: Int = 0

    /// Whether melee attacks are forbidden this turn (Lamentation of the Women).
    var noMeleeThisTurn: Bool = false

    /// Whether wounded heroes cannot act this turn (Council of Heroes).
    var woundedHeroesCannotAct: Bool = false

    /// Snapshot of action budget at start of player turn (rule 6.1.1).
    /// Mid-turn morale changes don't affect budget until next turn.
    var snapshotActionBudget: Int?

    // MARK: - Items (quest rewards)

    /// State for the Magic Sword item (non-nil = held). Consumed on use.
    var magicSwordState: MagicItemState?

    /// State for the Magic Bow item (non-nil = held). Consumed on use.
    var magicBowState: MagicItemState?

    // MARK: - Sub-resolution state (multi-step pages)

    var chainLightningState: ChainLightningState?
    var fortuneState: FortuneState?
    var deathAndDespairState: DeathAndDespairState?

    /// Pending player choice for bloody battle marker when Gate armies are tied.
    var pendingBloodyBattleChoices: [ArmySlot]?

    var questRewardPending: Bool = false

    /// Whether a multi-step sub-resolution is in progress, blocking normal action pages.
    var isInSubResolution: Bool {
      chainLightningState != nil || fortuneState != nil || deathAndDespairState != nil
        || pendingBloodyBattleChoices != nil || questRewardPending
    }

    // MARK: - Victory / defeat (rule 11.0)

    var ended: Bool = false
    var victory: Bool = false
    var gameAcknowledged: Bool = false

    /// Set ended + victory/defeat arrays atomically to prevent inconsistency.
    mutating func endInDefeat() {
      ended = true
      endedInDefeatFor = players
      endedInVictoryFor = []
    }

    mutating func endInVictory() {
      ended = true
      victory = true
      endedInVictoryFor = players
      endedInDefeatFor = []
    }

    // swiftlint:disable:next nesting
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
        endInVictory()
      }
    }

    // MARK: - Queries

    /// Whether all defenders are at zero (defeat condition per rule 4.4 / 11.1).
    var allDefendersAtZero: Bool {
      DefenderType.allCases.allSatisfy { defenderPosition[$0] == $0.lastPosition }
    }

    /// Look up the capability value (max attacks or chant DRM) at the current track position.
    func defenderValue(for type: DefenderType) -> Int {
      let position = defenderPosition[type] ?? type.lastPosition
      return type.trackValues[position]
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

    /// Heroes never selected during setup (no location, not dead).
    var unselectedHeroes: [HeroType] {
      HeroType.allCases.filter { heroLocation[$0] == nil && !heroDead.contains($0) }
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

    /// Count action-phase actions taken this turn (since last .advanceArmies or .skipEvent).
    var actionPointsSpent: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .advanceArmies, .skipEvent:
          return count
        case .combat, .build, .magic,
             .fireball, .slow, .cureWounds, .massHeal, .divineWrath,
             .raiseDead, .inspire, .castChainLightning, .castFortune:
          count += 1
        case .quest(.quest(isHeroic: false, let pointsSpent)):
          count += pointsSpent
        default:
          break
        }
      }
      return count
    }

    /// Count heroic actions taken this turn (since last event resolution).
    var heroicPointsSpent: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .advanceArmies, .skipEvent:
          return count
        case .heroic:
          count += 1
        case .quest(.quest(isHeroic: true, let pointsSpent)):
          count += pointsSpent
        default:
          break
        }
      }
      return count
    }

    /// Remaining action points this turn.
    /// Uses snapshot if available (rule 6.1.1: mid-turn morale changes don't affect budget).
    var actionBudgetRemaining: Int {
      let budget = snapshotActionBudget ?? actionBudget
      return max(budget - actionPointsSpent, 0)
    }

    /// Remaining heroic points this turn.
    var heroicBudgetRemaining: Int {
      max(heroicBudget - heroicPointsSpent, 0)
    }

    /// Count melee attacks made this turn (since last event phase action).
    var meleeAttacksThisTurn: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .advanceArmies, .skipEvent:
          return count
        case .combat(.meleeAttack):
          count += 1
        default:
          break
        }
      }
      return count
    }

    /// Count ranged attacks made this turn (since last event phase action).
    var rangedAttacksThisTurn: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .advanceArmies, .skipEvent:
          return count
        case .combat(.rangedAttack):
          count += 1
        default:
          break
        }
      }
      return count
    }

    // MARK: - Redeterminize (information-set MCTS)

    func redeterminize() -> Self {
      var copy = self
      GameRNG.shuffle(&copy.dayDrawPile)
      GameRNG.shuffle(&copy.nightDrawPile)
      return copy
    }

    func redeterminize(using generator: inout some RandomNumberGenerator) -> Self {
      var copy = self
      copy.dayDrawPile.shuffle(using: &generator)
      copy.nightDrawPile.shuffle(using: &generator)
      return copy
    }

  }
}
