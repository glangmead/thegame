//
//  ComposedGame.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Foundation

/// A game assembled by composing RulePages via `oapply`.
///
/// The composed game manages the action history and cached phase automatically.
/// Each page contributes rules and handles its own slice of the action space.
/// Priority pages (e.g., victory/defeat) are checked first and override
/// normal pages when they fire.
struct ComposedGame<State: HistoryTracking>: PlayableGame where State.Action: Hashable {
  let gameName: String
  let pages: [RulePage<State, State.Action>]
  let priorities: [RulePage<State, State.Action>]
  let makeInitialState: () -> State
  let terminalCheck: (State) -> Bool
  let rolloutTerminalCheck: ((State) -> Bool)?
  let phaseForAction: (State.Action) -> State.Phase?
  var stateEvaluator: ((State) -> Float)?
  var rolloutPolicy: (([State.Action]) -> State.Action)?
  let autoRules: [AutoRule<State>]

  func isTerminal(state: State) -> Bool { terminalCheck(state) }
  func isRolloutTerminal(state: State) -> Bool {
    rolloutTerminalCheck?(state) ?? terminalCheck(state)
  }

  func allowedActions(state: State) -> [State.Action] {
    guard !isTerminal(state: state) else { return [] }

    // Priority pages override everything
    var urgent: [State.Action] = []
    for page in priorities {
      for rule in page.rules where rule.condition(state) {
        urgent.append(contentsOf: rule.actions(state))
      }
    }
    if !urgent.isEmpty { return urgent }

    // Normal pages contribute rules
    var actions: [State.Action] = []
    for page in pages {
      for rule in page.rules where rule.condition(state) {
        actions.append(contentsOf: rule.actions(state))
      }
    }
    return actions
  }

  func reduce(into state: inout State, action: State.Action) -> [Log] {
    // Framework: append to history (source of truth)
    state.history.append(action)

    // Framework: update cached phase
    if let newPhase = phaseForAction(action) {
      state.phase = newPhase
    }

    // Dispatch to the first page that handles this action
    var result: [Log] = []
    var dispatched = false
    for page in priorities where !dispatched {
      if let (logs, followUps) = page.reduce(&state, action) {
        result = logs
        for followUp in followUps {
          result.append(contentsOf: reduce(into: &state, action: followUp))
        }
        dispatched = true
      }
    }
    if !dispatched {
      for page in pages where !dispatched {
        if let (logs, followUps) = page.reduce(&state, action) {
          result = logs
          for followUp in followUps {
            result.append(contentsOf: reduce(into: &state, action: followUp))
          }
          dispatched = true
        }
      }
    }

    // Scan auto-rules after this action (and its follow-ups) resolve.
    // Note: auto-rules scan at every stack frame. If a follow-up doesn't
    // change history.last, a predicate matching history.last may fire at
    // multiple levels. Concrete auto-rules should use state guards to
    // prevent double-firing (e.g., checking bloodyBattleArmy == nil).
    for rule in autoRules where rule.when(state) {
      result.append(contentsOf: rule.apply(&state))
    }

    return result
  }

  func newState() -> State {
    makeInitialState()
  }
}

/// Compose RulePages into a complete game.
///
/// This is the game-engine analog of `oapply` from AlgebraicDynamics.jl.
/// Each page is a composable machine; `oapply` wires them together:
///
/// - **Phase sequencing**: each page's transition action feeds the next phase
/// - **Shared board state**: all pages read/write the same State struct
/// - **History**: managed by the framework, available to all ForEach pages
/// - **Priorities**: victory/defeat checked before phase-specific rules
func oapply<State: HistoryTracking>(
  gameName: String,
  pages: [RulePage<State, State.Action>],
  priorities: [RulePage<State, State.Action>] = [],
  autoRules: [AutoRule<State>] = [],
  initialState: @escaping () -> State,
  isTerminal: @escaping (State) -> Bool,
  isRolloutTerminal: ((State) -> Bool)? = nil,
  phaseForAction: @escaping (State.Action) -> State.Phase?,
  stateEvaluator: ((State) -> Float)? = nil,
  rolloutPolicy: (([State.Action]) -> State.Action)? = nil
) -> ComposedGame<State> where State.Action: Hashable {
  ComposedGame(
    gameName: gameName,
    pages: pages,
    priorities: priorities,
    makeInitialState: initialState,
    terminalCheck: isTerminal,
    rolloutTerminalCheck: isRolloutTerminal,
    phaseForAction: phaseForAction,
    stateEvaluator: stateEvaluator,
    rolloutPolicy: rolloutPolicy,
    autoRules: autoRules
  )
}
