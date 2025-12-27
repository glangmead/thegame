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

extension BinaryFloatingPoint {
  func near(_ other: Self, epsilon: Self = 0.0001) -> Bool {
    return abs(self - other) < epsilon
  }
}
// https://github.com/pkamppur/swift-othello-monte-carlo-tree-search/blob/main/Classes/Monte%20Carlo%20Tree%20Search/MonteCarloTreeSearch.swift

class Node<State: GameState & CustomStringConvertible & CustomDebugStringConvertible, Action: Hashable & Equatable & CustomStringConvertible & CustomDebugStringConvertible>: CustomStringConvertible, CustomDebugStringConvertible {
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
  
  var recursiveSize: Int {
    1 + children.values.map({$0.recursiveSize}).reduce(0, +)
  }
  
  var debugDescription: String {
    description
  }
  
  func printTree<Target>(level: Int = 0, to: inout Target) where Target: TextOutputStream {
    let indent = String(repeating: " ", count: level)
    print("\(indent)\(self)", to: &to)
    for (_, child) in children {
      child.printTree(level: level + 1, to: &to)
    }
  }
  
  var isUnvisited: Bool {
    visitCount == 0
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
class TreeSearch<State: GameState & CustomStringConvertible & CustomDebugStringConvertible, Action: Hashable & Equatable & CustomStringConvertible & CustomDebugStringConvertible> {
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
  
  // use our best heuristic selectAction to recursively find a promising node with an unexplored action
  // (creates no nodes)
  func selectNode(from: Node<State, Action>) -> Node<State, Action> {
    var selectedNode = from
    // look for an unvisited action
    while(!selectedNode.isTerminal && selectedNode.visitlessActions().isEmpty) {
      let selectedAction = selectAction(of: selectedNode)!
      if let node = selectedNode.children[selectedAction] {
        selectedNode = node
      }
    }
    return selectedNode
  }
  
  // creates no nodes
  func selectAction(of node: Node<State, Action>) -> Action? {
    if node.actions.isEmpty {
      return nil
    }
    if node.visitlessActions().isNonEmpty {
      return node.visitlessActions().randomElement()!
    }
    let maxExExValue = node.actions.map { node.exploreExploitValue(action: $0) }.max()!
    let maxAttainingActions = node.actions.filter { node.exploreExploitValue(action: $0).near(maxExExValue) }
    return maxAttainingActions.randomElement()!
  }
  
  func mostVisitedAction(of node: Node<State, Action>) -> Action? {
    node.actions.max(by: { node.childrenVisitCounts[$0] ?? 0 < node.childrenVisitCounts[$1] ?? 0})
  }
  
  func mostValuedAction(of node: Node<State, Action>) -> Action? {
    node.actions.max(by: { node.exploitValue(action: $0) < node.exploitValue(action: $1) })
  }
  
  // creates a node (and all trivial single-action descendents) for each untried action of the given node
  func expandNode(from parent: Node<State, Action>) -> [Node<State, Action>] {
    if parent.visitlessActions().isEmpty {
      return [parent]
    }
    return parent.visitlessActions().map { action in
      var child = createChild(of: parent, with: action)
      // now drill down through singleton actions as well
      while child.actions.count == 1 {
        child = createChild(of: child, with: child.actions[0])
      }
      return child
    }
  }
  
  func rolloutNode(from: Node<State, Action>) -> Float {
    var cursor = from
    while !cursor.isTerminal {
      let randoAction = cursor.actions.randomElement()!
      cursor = createChild(of: cursor, with: randoAction)
    }
    // TODO: generalize to > 1 player
    if cursor.state.endedInVictory {
      return 1.0
    } else if cursor.state.endedInDefeat {
      return -1.0
    } else {
      fatalError()
    }
  }
  
  /// When I run this, it has the property that even if there is only 1 action at the root,
  /// I get a very pessimistic value at the root, and a better value after taking that 1 action.
  func recommendation(iters: Int) -> Action? {
    guard !cursorNode.isTerminal else {
      return nil
    }
    var bestGuessAction = cursorNode.actions.randomElement()
    for _ in 0..<iters {
      //print("iter \(iter) size \(cursorNode.recursiveSize)")
      // do the iter
      let selected = selectNode(from: cursorNode)
      let expanded = expandNode(from: selected)
      for expandedNode in expanded {
        let value = rolloutNode(from: expandedNode.copy()) // copy() so that created children are temporary
        // backprop the win/loss value
        expandedNode.recordRolloutSample(value: value, via: nil)
      }
      
      let newBestGuessAction = mostValuedAction(of: cursorNode)
      if newBestGuessAction != bestGuessAction {
        // log something about the new best
      }
      bestGuessAction = newBestGuessAction
    }
    return bestGuessAction
  }
  
}
