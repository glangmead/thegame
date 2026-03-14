//
//  GameModel.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation
import Observation

@MainActor
@Observable
class GameModel<
  State: GameState & CustomStringConvertible,
  Action: Hashable & Equatable & CustomStringConvertible
> {
  var state: State
  var game: any PlayableGame<State, Action>
  let graph: SiteGraph
  var logs: [Log] = []

  init(game: some PlayableGame<State, Action>, graph: SiteGraph) {
    self.game = game
    self.graph = graph
    self.state = game.newState()
  }

  var allowedActions: [Action] {
    game.allowedActions(state: state)
  }

  var isTerminal: Bool {
    game.isTerminal(state: state)
  }

  @discardableResult
  func perform(_ action: Action) -> [Log] {
    let newLogs = game.reduce(into: &state, action: action)
    logs.insert(contentsOf: newLogs, at: 0)
    return newLogs
  }

  func reset(with game: some PlayableGame<State, Action>) {
    self.game = game
    self.state = game.newState()
    self.logs = []
  }
}
