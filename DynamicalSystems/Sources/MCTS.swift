//
//  MCTS.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 11/17/25.
//

import ComposableArchitecture

// https://github.com/pkamppur/swift-othello-monte-carlo-tree-search/blob/main/Classes/Monte%20Carlo%20Tree%20Search/MonteCarloTreeSearch.swift

class Node<State: GameState, Action> {
  var state: State
  var children: [State]
  var parent: State?
  var valueSum: Float = 0
  var visitCount: Int = 0
  
  var isTerminal: Bool {
    state.ended
  }
  
  init(state: State, children: [State], parent: State?) {
    self.state = state
    self.children = children
    self.parent = parent
  }
}

class TreeSearch<State: GameState, Action> {
  enum Policy {
    case Exhaustive
    case Random
  }
  
  var rootState: State
  var reducer: any LookaheadReducer<State, Action>
  var cursorNode: Node<State, Action>
  
  init(state: State, reducer: any LookaheadReducer<State, Action>) {
    self.rootState = state
    self.reducer = reducer
    cursorNode = Node<State, Action>(state: state, children: [], parent: nil)
    expand()
  }
  
  func pickAction(state: State, policy: Policy) -> Action {
    switch policy {
    case .Exhaustive:
      // TODO: implement
      type(of: reducer).allowedActions(state: state).randomElement()!
    case .Random:
      type(of: reducer).allowedActions(state: state).randomElement()!
    }
  }
  
  private func expand() {
    if let action = type(of: reducer).allowedActions(state: cursorNode.state).randomElement() {
      var stateCopy = cursorNode.state
      let effect = reducer.reduce(into: &stateCopy, action: action)
    }
  }
}
