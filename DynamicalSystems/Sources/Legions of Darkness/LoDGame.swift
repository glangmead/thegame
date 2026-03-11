//
//  LoDGame.swift
//  DynamicalSystems
//
//  Legions of Darkness — composedGame factory and victory/defeat priority pages.
//

import Foundation

extension LoD {

  // MARK: - Composed Game

  /// Map an action to the phase it transitions into, or nil to stay in current phase.
  private static func nextPhase(for action: Action) -> Phase? {
    switch action {
    case .drawCard: return .army
    case .advanceArmies: return .event
    case .skipEvent, .resolveEvent: return .action
    case .passActions: return .heroic
    case .passHeroics: return .housekeeping
    case .performHousekeeping: return .card
    default: return nil  // stay in current phase
    }
  }

  /// Create a composed game for the Greenskin Horde scenario.
  /// All RulePages are wired together via oapply.
  static func composedGame(
    windsOfMagicArcane: Int,
    heroes: [HeroType] = [.warrior, .wizard, .cleric],
    shuffledDayCards: [Card]? = nil,
    shuffledNightCards: [Card]? = nil
  ) -> ComposedGame<State> {
    oapply(
      pages: [cardPage, armyPage, eventPage,
              chainLightningPage, fortunePage, deathAndDespairPage,
              combatPage, buildPage, magicPage, questPage,
              heroicPage, generalPage,
              paladinReactPage, housekeepingPage],
      priorities: [victoryPage, defeatPage],
      initialState: {
        var state = greenskinSetup(
          windsOfMagicArcane: windsOfMagicArcane,
          heroes: heroes
        )
        state.setupDecks(
          shuffledDayCards: shuffledDayCards,
          shuffledNightCards: shuffledNightCards
        )
        return state
      },
      isTerminal: { $0.gameAcknowledged },
      phaseForAction: { nextPhase(for: $0) },
      stateEvaluator: lodStateEvaluator
    )
  }

  // MARK: - MCTS State Evaluator

  /// Graduated evaluation for MCTS backpropagation.
  /// Victory = 1.0, defeat = 0.0–0.5 scaled by time survived.
  private static func lodStateEvaluator(_ state: State) -> Float {
    if state.endedInVictoryFor.contains(.solo) { return 1.0 }
    if state.endedInDefeatFor.contains(.solo) {
      return 0.5 * Float(state.timePosition) / 15.0
    }
    // Rollout hit max depth without ending (rare)
    return 0.5 * Float(state.timePosition) / 15.0 + 0.25
  }

  // MARK: - Paladin Re-roll (rule 10.2)

  static var paladinReactPage: RulePage<State, Action> {
    RulePage(
      name: "Paladin React",
      rules: [
        GameRule(
          condition: { $0.phase == .paladinReact && $0.pendingDieRollAction != nil },
          actions: { _ in
            [.paladinReroll(newDieRoll: 0), .declineReroll]
          }
        )
      ],
      reduce: { state, action in
        var logs: [Log] = []

        switch action {
        case .declineReroll:
          guard let pending = state.pendingDieRollAction else { return nil }
          let returnPhase = state.phaseBeforePaladinReact ?? .action

          // Resolve the deferred action
          if returnPhase == .action {
            logs += state.resolveActionDieRoll(pending)
          } else {
            logs += state.resolveHeroicDieRoll(pending)
          }

          state.pendingDieRollAction = nil
          state.phaseBeforePaladinReact = nil
          state.phase = returnPhase
          return (logs, [])

        case .paladinReroll(let newDieRoll):
          guard let pending = state.pendingDieRollAction else { return nil }
          let returnPhase = state.phaseBeforePaladinReact ?? .action

          // Modify the pending action with the new die roll
          let modifiedAction = State.withNewDieRoll(pending, newDieRoll: newDieRoll)
          logs.append(Log(msg: "Paladin re-roll: new die = \(newDieRoll)"))

          // Resolve with the new die roll
          if returnPhase == .action {
            logs += state.resolveActionDieRoll(modifiedAction)
          } else {
            logs += state.resolveHeroicDieRoll(modifiedAction)
          }

          state.usePaladinReroll()
          state.pendingDieRollAction = nil
          state.phaseBeforePaladinReact = nil
          state.phase = returnPhase
          return (logs, [])

        default:
          return nil
        }
      }
    )
  }

  // MARK: - Housekeeping

  static var housekeepingPage: RulePage<State, Action> {
    RulePage(
      name: "Housekeeping",
      rules: [],  // automatic — no player choices
      reduce: { state, action in
        guard case .performHousekeeping = action else { return nil }
        state.performHousekeeping()
        return ([Log(msg: "Housekeeping complete. Time: \(state.timePosition)")],
                [])  // stop — next allowedActions will offer drawCard
      }
    )
  }

  // MARK: - Victory / Defeat Priority Pages

  static var victoryPage: RulePage<State, Action> {
    RulePage(
      name: "Victory",
      rules: [
        GameRule(
          condition: { $0.ended && $0.victory },
          actions: { _ in [.claimVictory] }
        )
      ],
      reduce: { state, action in
        guard case .claimVictory = action else { return nil }
        state.gameAcknowledged = true
        return ([Log(msg: "Victory! The castle stands!")], [])
      }
    )
  }

  static var defeatPage: RulePage<State, Action> {
    RulePage(
      name: "Defeat",
      rules: [
        GameRule(
          condition: { $0.ended && !$0.victory },
          actions: { _ in [.declareLoss] }
        )
      ],
      reduce: { state, action in
        guard case .declareLoss = action else { return nil }
        state.gameAcknowledged = true
        return ([Log(msg: "Defeat! The castle has fallen.")], [])
      }
    )
  }
}
