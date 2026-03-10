//
//  GameRule.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Foundation

/// A condition-action pair: when condition is true, actions are offered to the player.
/// This is the framework's version of the per-game Rule structs.
struct GameRule<State, Action> {
  let condition: (State) -> Bool
  let actions: (State) -> [Action]
}
