//
//  MCTS.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 11/17/25.
//

/// Nodes get created
/// Nodes get updated
/// Selecting a node is read-only
/// Expanding a node adds a node
/// Rolling creates temporary nodes then mutates the new node, then propagates that info upwards

import ComposableArchitecture
import Foundation

// https://github.com/pkamppur/swift-othello-monte-carlo-tree-search/blob/main/Classes/Monte%20Carlo%20Tree%20Search/MonteCarloTreeSearch.swift

class Node<State: GameState & CustomStringConvertible, Action: Hashable & Equatable & CustomStringConvertible>: CustomStringConvertible {
  var state: State
  var actions: [Action]
  var children: [Action:Node]
  var parent: Node?
  var parentAction: Action? // the action that created us when applies to our parent
  
  // stats for this here node
  var valueSum: Float = 0
  var visitCount: Int = 0
  
  // stats for the actions/children
  var childrenValues = [Action: Float]()
  var childrenVisitCounts = [Action: Int]()
  
  var description: String {
    "\(state) VAL:\(valueSum), #:\(visitCount), PA:\(parentAction?.description ?? "∅")"
  }
  
  func printTree(level: Int = 0) {
    let indent = String(repeating: " ", count: level)
    print("\(indent)\(self)")
    for (_, child) in children {
      child.printTree(level: level + 1)
    }
  }
  
  var isLeaf: Bool {
    children.isEmpty
  }
  
  var isTerminal: Bool {
    state.ended
  }
  
  init(state: State, actions: [Action], parent: Node?, parentAction: Action?) {
    self.state = state
    self.actions = actions
    self.children = [Action:Node]()
    self.parent = parent
    self.parentAction = parentAction
  }
  
  func copy() -> Node<State, Action> {
    return Node(
      state: self.state,
      actions: self.actions,
      parent: self.parent,
      parentAction: self.parentAction
    )
  }
  
  // updates the stats and propagates them upward
  func recordRolloutSample(value: Float, via: Action?) {
    self.visitCount += 1
    self.valueSum += value
    if let childbearingAction = via {
      self.childrenValues[childbearingAction] = self.childrenValues[childbearingAction] ?? 0 + value
      self.childrenVisitCounts[childbearingAction] = self.childrenVisitCounts[childbearingAction] ?? 0 + 1
    }
    self.parent?.recordRolloutSample(value: value, via: self.parentAction)
  }
  
  func visitlessActions() -> [Action] {
    actions.filter { (childrenVisitCounts[$0] ?? 0) == 0 }
  }
  
  // a calculation based on visit count unless visit count is 0 in which case uniform over unvisited sibs
  func exploitValue(action: Action) -> Float {
    guard let count = childrenVisitCounts[action], count > 0  else {
      return 0
    }
    return Float(childrenValues[action] ?? 0) / Float(childrenVisitCounts[action]!)
  }
  
  // 0 if we have no data yet
  func exploreValue(action: Action) -> Float {
    guard let count = childrenVisitCounts[action],  count > 0  else {
      return 1.0 / Float(visitlessActions().count)
    }
    return sqrt(log(Float(visitCount > 0 ? visitCount : 1)) / Float(childrenVisitCounts[action]!))
  }
  
  // upper confidence for trees (Kocsis & Szepesvári, Bandit-based monte-carlo planning, 2006)
  func exploreExploitValue(action: Action, exploreCoeff: Float = 1.0) -> Float {
    let exploit = exploitValue(action: action)
    let explore = exploreValue(action: action)
    return exploit + exploreCoeff * explore
  }
}

// A study of the game tree under the start state, iteratively refined,
// each iteration consisting of a fixed sequence of actions
class TreeSearch<State: GameState & CustomStringConvertible, Action: Hashable & Equatable & CustomStringConvertible> {
  var rootState: State
  var reducer: any LookaheadReducer<State, Action>
  var cursorNode: Node<State, Action>
  var rootNode: Node<State, Action>
  
  init(state: State, reducer: any LookaheadReducer<State, Action>) {
    self.rootState = state
    self.reducer = reducer
    rootNode = Node<State, Action>(
      state: state,
      actions: reducer.allowedActions(state: state),
      parent: nil,
      parentAction: nil
    )
    cursorNode = rootNode
  }
  
  func createChild(of parent: Node<State, Action>, with action: Action) -> Node<State, Action> {
    var beforeAfterState = parent.state
    let _ = reducer.reduce(into: &beforeAfterState, action: action)
    
    let newNode = Node(
      state: beforeAfterState,
      actions: reducer.allowedActions(state: beforeAfterState),
      parent: parent,
      parentAction: action
    )
    parent.children[action] = newNode
    return newNode
  }
  
  // use our best heuristic selectionOfChild to recursively find an unexpanded node
  // (creates up to one node)
  func selectionAnyLevel(from: Node<State, Action>) -> Node<State, Action> {
    var selectedNode = from
    var selectedAction = selectionOfChild(of: selectedNode)
    if let node = from.children[selectedAction] {
      selectedNode = node
    }
    while(!selectedNode.isLeaf) {
      selectedAction = selectionOfChild(of: selectedNode)
      if let node = selectedNode.children[selectedAction] {
        selectedNode = node
      } else {
        selectedNode = createChild(of: selectedNode, with: selectedAction)
      }
    }
    return selectedNode
  }
  
  // creates no nodes
  func selectionOfChild(of node: Node<State, Action>) -> Action {
    return node.actions.max {
      node.exploreExploitValue(action: $0) < node.exploreExploitValue(action: $1)
    }!
  }
  
  // creates up to one node
  func expansion(from parent: Node<State, Action>) -> Node<State, Action> {
    if parent.visitlessActions().isEmpty {
      return parent
    }
    let randoAction = parent.visitlessActions().randomElement()!
    return createChild(of: parent, with: randoAction)
  }
  
  func rollout(from: Node<State, Action>) -> Float {
    var cursor = from
    while !cursor.isTerminal {
      let randoAction = cursor.actions.randomElement()!
      cursor = createChild(of: cursor, with: randoAction)
    }
    // TODO: generalize to > 1 player
    return cursor.state.endedInVictory ? 1.0 : -1.0
  }
  
  func recommendation(iters: Int) -> Action? {
    guard !cursorNode.isTerminal else {
      return nil
    }
    var bestGuessAction = cursorNode.actions.randomElement()!
    for iter in 0..<iters {
      //print("iteration \(iter)")
      // do the iter
      let selected = selectionAnyLevel(from: cursorNode)
      let expanded = expansion(from: selected)
      let    value = rollout(from: expanded.copy()) // copy() so that created children are temporary
      // backprop
      expanded.recordRolloutSample(value: value, via: nil)
      
      let newBestGuessAction = selectionOfChild(of: cursorNode)
      if newBestGuessAction != bestGuessAction {
        // log something about the new best
      }
      bestGuessAction = newBestGuessAction
    }
    return bestGuessAction
  }
  
}
