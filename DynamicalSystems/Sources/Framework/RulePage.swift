//
//  RulePage.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Foundation

/// A composable unit of game logic — one "page" of the rulebook.
///
/// Each page contributes rules (condition-action pairs) and a reduce function
/// that handles its own actions. Pages are composed via `oapply` into a
/// complete game.
struct RulePage<State, Action: Hashable> {
    let name: String
    let rules: [GameRule<State, Action>]

    /// Applies this page's action to state. Returns nil if the action
    /// doesn't belong to this page (dispatch continues to the next page).
    let reduce: (inout State, Action) -> [Log]?
}

extension RulePage {
  func allowedActions(state: State) -> [Action] {
    rules.flatMap { $0.condition(state) ? $0.actions(state) : [] }
  }
}
