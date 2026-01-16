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
class ActionNode<Action: Hashable & Equatable & CustomStringConvertible, Player: Equatable>: CustomStringConvertible {
  let inboundAction: Action?
  let player: Player
  var children = [Action:ActionNode]() // successor nodes after applying some action
  var parent: ActionNode?

  var visitableCount: Int = 0 // how often we were legal to be visited by our parent
  var visitCount: Int = 0
  var valueSum: Float = 0
  
  var description: String {
    ((inboundAction == nil) ? "none" : "\(inboundAction!)")
  }
  
  init(action: Action?, parent: ActionNode?, player: Player) {
    self.inboundAction = action
    self.parent = parent
    self.player = player
  }
  
  func copy() -> ActionNode<Action, Player> {
    return ActionNode(action: self.inboundAction, parent: self.parent, player: self.player)
  }
  
  func getOrCreateChild(action: Action, player: Player) -> ActionNode<Action, Player> {
    var child = children[action]
    if child == nil {
      child = ActionNode(action: action, parent: self, player: player)
      children[action] = child
    }
    return child!
  }
  
  func printTree<Target>(level: Int = 0, to: inout Target) where Target: TextOutputStream {
    let indent = String(repeating: " ", count: level)
    print("\(indent)\(self)", to: &to)
    for (_, child) in children {
      child.printTree(level: level + 1, to: &to)
    }
  }

  // updates the stats and propagates them upward
  func recordRolloutValue(winners: [Player], losers: [Player]) {
    if winners.contains(player) {
      valueSum += 1
    }
    visitCount += 1
    var next = parent
    while next != nil {
      if winners.contains(next!.player) {
        next!.valueSum += 1
      }
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
  var rootNodes = [State.Player:ActionNode<Action,State.Player>]()
  var reducer: any LookaheadReducer<State, Action>
  
  init(state: State, reducer: any LookaheadReducer<State, Action>) {
    self.rootState = state
    self.reducer = reducer
    for player in state.players {
      self.rootNodes[player] = ActionNode(action: nil, parent: nil, player: player)
    }
  }
  
  // use the explore-exploit tradeoff to select one next action
  func selectAction(for node: ActionNode<Action,State.Player>, in state: State) -> Action {
    let legalActions = reducer.allowedActions(state: state)
    // update the node with each action: make sure it has a child, and a visitable-count stat
    for legalAction in legalActions {
      var child = node.children[legalAction]
      if child == nil {
        child = ActionNode(action: legalAction, parent: node, player: state.player)
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
    return bestActions.randomElement()!
  }
  

  // pick an unexpanded action
  func expandAction(from parent: ActionNode<Action,State.Player>, in state: State) -> Action {
    let legalActions = reducer.allowedActions(state: state)
    // by assumption one of these actions has no visit count
    return legalActions.filter({
      (parent.children[$0]?.visitCount ?? 0) == 0
    }).randomElement()!
  }
  
  func rolloutAction(from: ActionNode<Action,State.Player>, in state: State) -> Action {
    reducer.allowedActions(state: state).randomElement()!
  }

  enum SearchPhase {
    case select
    case expand
    case rollout
  }
  
  func recommendation(iters: Int, numRollouts: Int = 1) -> [Action:(Float, Float)] {
    var result = [Action:(Float, Float)]()
    guard !rootState.ended else {
      return result
    }
    
    let maxRolloutDepth = 1000

    for _ in 0..<iters {
      // init the search for each player similarly
      var currentNodes = [State.Player:ActionNode<Action,State.Player>]()  // where the iteration currently stands
      var selectedNodes = [State.Player:ActionNode<Action,State.Player>]() // the node created by selection
      var expandedNodes = [State.Player:ActionNode<Action,State.Player>]() // the node created by expansion
      var currentSearchPhase = [State.Player:SearchPhase]()
      for player in rootState.players {
        currentNodes[player] = rootNodes[player]
        currentSearchPhase[player] = .select
      }
      
      var state = rootState
      var rolloutDepth = 0
      
      // Explore a tree for each player, even though the player of rootState is "the player".
      //
      while rolloutDepth < maxRolloutDepth && !state.ended {
        let player = state.player
        
        // Pick one next action for the current player.
        // Since we jump from player to player, we need to somehow know whether to do selection, expansion, or rollout at this moment.
        let currentNode = currentNodes[player]!
        var nextAction: Action
        switch currentSearchPhase[player]! {
        case .select:
          nextAction = selectAction(for: currentNode, in: state) // as a side effect this will create all children and update visitableCount for them
        case .expand:
          //let _ = selectAction(for: currentNode, in: state) // as a side effect this will create all
          nextAction = expandAction(from: currentNode, in: state)
        case .rollout:
          nextAction = rolloutAction(from: currentNode, in: state)
          rolloutDepth += 1
        }
        
        // apply action
        let _ = reducer.reduce(into: &state, action: nextAction)
        
        // successor node
        let child = currentNode.getOrCreateChild(action: nextAction, player: state.player)
        currentNodes[state.player] = child
        switch currentSearchPhase[state.player]! {
        case .select:
          selectedNodes[state.player] = child
        case .expand:
          expandedNodes[state.player] = child
        default:
          ()
        }
        
        // update the phase for the player who started this iteration of the while loop
        switch currentSearchPhase[player]! {
          case .select:
            // if this new node has visitable but unvisited children, move to .expand
            var someUnvisitedGrandchild = false
            for action in reducer.allowedActions(state: state) {
              let grandchild = child.children[action]
              if grandchild == nil || grandchild!.visitCount == 0 {
                someUnvisitedGrandchild = true
              }
            }
            if someUnvisitedGrandchild {
              currentSearchPhase[player] = .expand
            } else {
              currentSearchPhase[player] = .select
            }
          case .expand:
            currentSearchPhase[player] = .rollout
          case .rollout:
            currentSearchPhase[player] = .rollout
        }
        
      } // while
      
      // backprop the win/loss value
      for player in rootState.players {
        let expandedNode = (expandedNodes[player]) ?? (selectedNodes[player]!)
        expandedNode.recordRolloutValue(winners: state.endedInVictoryFor, losers: state.endedInDefeatFor)
      }
      // update our return data
      for action in rootNodes[rootState.player]!.children.keys {
        result[action] = (
          rootNodes[rootState.player]!.children[action]?.valueSum ?? 0,
          Float(rootNodes[rootState.player]!.children[action]?.visitCount ?? 0)
        )
      }
    }
    
    return result
  }
  
  func printTree<Target>(to: inout Target) where Target: TextOutputStream {
    rootNodes[rootState.player]!.printTree(level: 0, to: &to)
  }
}
