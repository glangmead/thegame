//
//  CantStopAI.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 11/21/25.
//

class CantStopRandomPlayer: ComputerPlayer {
  typealias State = CantStop.State
  typealias Action = CantStop.Action
  var search: TreeSearch<State, Action>
  var chosenActions: [State: Action] = [:]
  
  init(state: State, game: CantStop) {
    self.search = TreeSearch(state: state, reducer: game)
  }
  
  func chooseAction(state: State, game: any LookaheadReducer<State, Action>) -> Action {
    if let action = chosenActions[state] {
      return action
    }
    chosenActions[state] = search.recommendation(iters: 1).keys.randomElement()!
    return chosenActions[state]!
  }
}
