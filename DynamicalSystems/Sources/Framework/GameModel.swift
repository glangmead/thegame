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
    let game: any PlayableGame<State, Action>
    let graph: SiteGraph

    init(game: some PlayableGame<State, Action>, graph: SiteGraph) {
        self.game = game
        self.graph = graph
        self.state = game.newState()
    }

    var allowedActions: [Action] {
        game.allowedActions(state: state)
    }

    @discardableResult
    func perform(_ action: Action) -> [Log] {
        game.reduce(into: &state, action: action)
    }
}
