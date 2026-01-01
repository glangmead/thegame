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
  let inboundAction: Action
  let inboundPath: [Action] // list of actions leading here. appending inboundAction would continue it.
  var children = [Action:ActionNode]()
  var parent: ActionNode?

  var visitableCount: Int = 0 // how often we were legal to be visited by our parent
  var visitCount: Int = 0
  var valueSum: Float = 0
  
  var description: String {
    "\(inboundPath) + \(inboundAction)"
  }
  
  init(action: Action, parent: ActionNode?, inboundPath: [Action]) {
    self.inboundAction = action
    self.parent = parent
    self.inboundPath = inboundPath
  }
  
  func copy() -> ActionNode<Action> {
    return ActionNode(action: self.inboundAction, parent: self.parent, inboundPath: inboundPath)
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
    parent?.recordRolloutValue(value: value)
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
      : Float.infinity
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
  var reducer: any LookaheadReducer<State, Action>
  var rootNodes: [ActionNode<Action>]
  
  init(state: State, reducer: any LookaheadReducer<State, Action>) {
    self.rootState = state
    self.reducer = reducer
    let firstActions = reducer.allowedActions(state: state)
    rootNodes = firstActions.map {
      ActionNode<Action>(action: $0, parent: nil, inboundPath: [])
    }
  }
  
  // recursively apply the explore-exploit tradeoff to select a node, stopping when we get to an unexpanded node (infinite explore-exploit score)
  func selectDeep(from parent: ActionNode<Action>, in state: inout State) -> ActionNode<Action> {
    var selectedNode = parent
    var stop = false
    while !stop {
      let nextAction = selectAction(for: selectedNode, in: state)
      if nextAction != nil && parent.children[nextAction!] != nil {
        let _ = reducer.reduce(into: &state, action: selectedNode.inboundAction)
        selectedNode = parent.children[nextAction!]!
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
        child = ActionNode(action: legalAction, parent: node, inboundPath: node.inboundPath + [legalAction])
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
    var result = parent
    let legalActions = reducer.allowedActions(state: state)
    // by assumption one of these actions has no visit count
    if let randoAction = legalActions.filter({
      parent.children[$0]!.visitCount == 0
    }).randomElement() {
      let _ = reducer.reduce(into: &state, action: randoAction)
      return parent.children[randoAction]!
    }
    return result
  }
  
  func rolloutNode(from: ActionNode<Action>, in state: State) -> Float {
    var cursor = from
    var depth = 0
    var stateCopy = state
    while !state.ended && depth < 100 {
      let randoAction = reducer.allowedActions(state: state).randomElement()!
      cursor = ActionNode(action: randoAction, parent: cursor, inboundPath: cursor.inboundPath + [randoAction])
      let _ = reducer.reduce(into: &stateCopy, action: randoAction)
      depth += 1
    }
    // TODO: generalize to > 1 player
    if state.endedInVictory {
      return 1.0
    } else if state.endedInDefeat {
      return -1.0
    } else {
      return 0// fatalError()
    }
  }

  func bestRootNode(by: (ActionNode<Action>) -> Float) -> ActionNode<Action> {
    let topValue = rootNodes.map({ by($0) }).max() ?? 0
    return rootNodes.filter({ by($0).near(topValue) }).randomElement()!
  }

  func recommendation(iters: Int) -> Action? {
    guard !rootState.ended else {
      return nil
    }
    
    var state = rootState
    var bestGuessNode = bestRootNode(by: {$0.exploreExploitValue})
    var bestGuessAction = bestGuessNode.inboundAction
    let _ = reducer.reduce(into: &state, action: bestGuessAction)
    
    for _ in 0..<iters {
      let selected = selectDeep(from: bestGuessNode, in: &state)
      let expanded = expandNode(from: selected, in: &state)
      let value = rolloutNode(from: expanded.copy(), in: state) // copy() so that created children are temporary
      // backprop the win/loss value
      expanded.recordRolloutValue(value: value)
      
      bestGuessNode = bestRootNode(by: {$0.exploitValue})
      if bestGuessNode.inboundAction != bestGuessAction {
        // log something about the new best
      }
      bestGuessAction = bestGuessNode.inboundAction
    }
    
    return bestGuessAction
  }
}
