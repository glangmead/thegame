//
//  OpenLoopMCTS.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 12/30/25.
//

import ComposableArchitecture
import Foundation

// A node that records only the action that was taken; the state is maintained by the client
// e.g., the client may create a root state, then create nodes for all the legal actions.
// The client then selects one of those actions and applies its reducer to create a new state
// with new child actions.
class ActionNode<Action: Hashable & Equatable & CustomStringConvertible>: CustomStringConvertible {
  let inboundAction: Action?
  var children = [Action:ActionNode]()
  var parent: ActionNode?

  var visitableCount: Int = 0 // how often we were legal to be visited by our parent
  var visitCount: Int = 0
  var valueSum: Float = 0
  
  var description: String {
    ((inboundAction == nil) ? "none" : "\(inboundAction!)")
  }
  
  init(action: Action?, parent: ActionNode?) {
    self.inboundAction = action
    self.parent = parent
  }
  
  func copy() -> ActionNode<Action> {
    return ActionNode(action: self.inboundAction, parent: self.parent)
  }
  
  func printTree<Target>(level: Int = 0, to: inout Target) where Target: TextOutputStream {
    let indent = String(repeating: " ", count: level)
    print("\(indent)\(self)", to: &to)
    for (_, child) in children {
      child.printTree(level: level + 1, to: &to)
    }
  }

  // updates the stats and propagates them upward
  func recordRolloutValue(value: Float) {
    valueSum += value
    visitCount += 1
    var next = parent
    while parent != nil {
      next?.valueSum += value
      next?.visitCount += 1
      next = next?.parent
    }
  }

  // a calculation based on visit count unless visit count is 0 in which case 0, to force explore
  var exploitValue: Float {
    visitCount > 0 ? valueSum / Float(visitCount) : 0
  }
  
  // 0 if we have no data yet
  var exploreValue: Float {
    // sqrt( N(a) / n(a) ) in the notation of "Dice, Cards, Action!" Goodman, J., 2025
    // see equation 3.2.1
    // modified by discussion of using N instead of log(N) in 3.2.3, p. 32
    // modified further by discussion of N(a) in 4.2, p. 47
    visitCount > 0
      ? sqrt(Float(visitableCount) / Float(visitCount))
      : Float.greatestFiniteMagnitude
  }
  
  // upper confidence for trees (Kocsis & Szepesvári, Bandit-based monte-carlo planning, 2006)
  var exploreExploitValue: Float {
    return exploitValue + exploreValue
  }
}

class OpenLoopMCTS<
  State: GameState & CustomStringConvertible,
  Action: Hashable & Equatable & CustomStringConvertible
>: AnytimePlayer {
  
  var rootState: State
  var rootNode: ActionNode<Action>
  var reducer: any LookaheadReducer<State, Action>
  
  init(state: State, reducer: any LookaheadReducer<State, Action>) {
    self.rootState = state
    self.reducer = reducer
    self.rootNode = ActionNode(action: nil, parent: nil)
    let firstActions = reducer.allowedActions(state: state)
    for action in firstActions {
      rootNode.children[action] = ActionNode<Action>(action: action, parent: rootNode)
    }
  }
  
  // recursively apply the explore-exploit tradeoff to select a node, stopping when we get to an unexpanded node (infinite explore-exploit score)
  func selectDeep(from parent: ActionNode<Action>, in state: inout State) -> ActionNode<Action> {
    var selectedNode = parent
    var stop = false
    while !stop {
      let nextAction = selectAction(for: selectedNode, in: state)
      if nextAction != nil && selectedNode.children[nextAction!] != nil {
        selectedNode = selectedNode.children[nextAction!]!
        let _ = reducer.reduce(into: &state, action: nextAction!)
        stop = state.ended
      } else {
        stop = true
      }
    }
    return selectedNode
  }
  
  // use the explore-exploit tradeoff to select one next action
  func selectAction(for node: ActionNode<Action>, in state: State) -> Action? {
    let legalActions = reducer.allowedActions(state: state)
    // update the node with each action: make sure it has a child, and a visitable-count stat
    for legalAction in legalActions {
      var child = node.children[legalAction]
      if child == nil {
        child = ActionNode(action: legalAction, parent: node)
        node.children[legalAction] = child
      }
      child?.visitableCount += 1
    }
    let bestScore = legalActions.map { action in
      node.children[action]!.exploreExploitValue
    }.max() ?? 0
    let bestActions = legalActions.filter { action in
      node.children[action]!.exploreExploitValue.near(bestScore)
    }
    return bestActions.randomElement()
  }
  
  // pick an unexpanded action and expand it, updating the state alongside
  func expandNode(from parent: ActionNode<Action>, in state: inout State) -> ActionNode<Action> {
    let legalActions = reducer.allowedActions(state: state)
    // by assumption one of these actions has no visit count
    if let randoAction = legalActions.filter({
      parent.children[$0]!.visitCount == 0
    }).randomElement() {
      let _ = reducer.reduce(into: &state, action: randoAction)
      return parent.children[randoAction]!
    } else {
      return parent
    }
  }
  
  func rolloutNode(from: ActionNode<Action>, in state: State) -> Float {
    var depth = 0
    var stateCopy = state
    while !stateCopy.ended && depth < 100 {
      let randoAction = reducer.allowedActions(state: stateCopy).randomElement()!
      let _ = reducer.reduce(into: &stateCopy, action: randoAction)
      depth += 1
    }
    // TODO: generalize to > 1 player
    if stateCopy.endedInVictory {
      return 1.0
    } else if stateCopy.endedInDefeat {
      return 0
    } else {
      fatalError()
    }
  }
  
  func recommendation(iters: Int, numRollouts: Int = 1) -> [Action:(Float, Float)] {
    var result = [Action:(Float, Float)]()
    guard !rootState.ended else {
      return result
    }
    
    for _ in 0..<iters {
      var state = rootState
      let selected = selectDeep(from: rootNode, in: &state)
      let expanded = expandNode(from: selected, in: &state)
      for _ in 0..<numRollouts {
        let value = rolloutNode(from: expanded.copy(), in: state) // copy() so that created children are temporary
        // backprop the win/loss value
        expanded.recordRolloutValue(value: value)
      }
      for action in rootNode.children.keys {
        result[action] = (
          rootNode.children[action]?.valueSum ?? 0,
          Float(rootNode.children[action]?.visitCount ?? 0)
        )
      }
    }
    
    return result
  }
  
  func printTree<Target>(to: inout Target) where Target: TextOutputStream {
    rootNode.printTree(level: 0, to: &to)
  }
}
