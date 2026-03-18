//
//  AutoRule.swift
//  DynamicalSystems
//

import Foundation

/// A reactive rule that fires silently after an action resolves.
///
/// Auto-rules react to state (typically checking `state.history.last`)
/// and mutate it. They never emit follow-up actions or return choices.
/// An auto-rule may set up state that a subsequent GameRule reads
/// to offer a player choice.
struct AutoRule<State>: @unchecked Sendable {
  let name: String
  let when: (State) -> Bool
  let apply: (inout State) -> [Log]
}
