//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

import ComposableArchitecture
import Overture
import SwiftUI

protocol LookaheadReducer<State, Action>: Reducer {
  associatedtype Rule
  static func rules() -> [Rule]
  static func allowedActions(state: State) -> [Action]
}

@Reducer
struct CantStop: LookaheadReducer {
  
  // the sigma type of the type family: pairs of (component, value)
  // The state will supply some context, such as who is performing the action
  enum Action: Hashable, Equatable, Sendable {
    case movePieceTo(PiecePosition)
    case advancePlayer
    case pass
    case bust
    case rollDice
    case setPhase(Phase)
    case assignDicePair(Pair<Die>)
    case progressColumn(Column)
    // recursive: ordered list of actions
    case sequence([Action])
    
    var name: String {
      switch self {
      case .movePieceTo(let ppos):
        return "\(ppos.name)"
      case .assignDicePair(let pair):
        return "\(pair.fst.name)/\(pair.snd.name)"
      case .sequence(let actions):
        let name = actions.map { $0.name }
          .joined(separator: " + ")
        return "(\(name))"
      case .progressColumn(let col):
        return "move \(col)"
      default:
        return String(describing: self)
      }
    }
  }
  
  struct ConditionalAction {
    let condition: StatePredicate
    let actions: (State) -> [Action]
  }
  
  static func append(_ first: ConditionalAction, _ second: ConditionalAction) -> ConditionalAction {
    return ConditionalAction(
      condition: first.condition, // to enter into this sequence, you just need the first condition to be met
      actions: pipe(
        { state in
          first.actions(state).flatMap { a1 in
            // advance the state by a1 to see if we can append any a2 to it
            var stateAfterA1 = state
            let _ = reduce(state: &stateAfterA1, action: a1)

            if second.condition(stateAfterA1) {
              let secondActions = second.actions(stateAfterA1)
              if secondActions.isEmpty {
                return [a1]
              } else {
                return secondActions.map { a2 in
                  if a2 != a1 {
                    return Action.sequence([a1, a2])
                  } else {
                    return a1
                  }
                }
              }
            } else {
              return [a1]
            }
          }
        },
        Set.init, Array.init
      )
    )
  }
  
  // the rules are captured by a set of ConditionalActions: if the game looks like this, you can do that
  typealias Rule = ConditionalAction
  
  // Rule: State -> (Bool, [Action])
  // not a good name. the reducer is also rules
  // (State, Action) -> State
  static func rules() -> [Rule] {
    let passRule = Rule(
      condition: { $0.phase == .notRolled },
      actions: { _ in [.rollDice, .pass] }
    )

    let moveRule = Rule(
      condition: { state in
        state.phase == .rolled
      },
      actions: { state in
        // all pairs of rolled dice. dice with value .none have been assigned already
        let dicePairings: [Pair<Die>] = pairs(of: Die.allCases.filter { die in state.dice[die] != DSix.none})
        return dicePairings.compactMap { pairing in
          let col = twod6_total(pairing.map {state.dice[$0]!})
          let whiteCols = Piece.whitePieces.map { state.position[$0]!.col }
          if whiteCols.contains(col) || whiteCols.contains(Column.none) {
            return Action.sequence([.assignDicePair(pairing), .progressColumn(col)])
          }
          return nil
        }
      }
    )
    
    let bustRule = Rule(
      condition: { state in
        let didRoll = state.phase == .rolled
        let moveActions = moveRule.actions(state)
        let actionsEmpty = moveActions.isEmpty
        return didRoll && actionsEmpty
      },
      actions: { state in
        let numAssignedDice = Die.allCases.filter({state.dice[$0]! != DSix.none}).count
        if (numAssignedDice == 4) {
          return [Action.bust]
        } else {
          return [Action.setPhase(Phase.notRolled)]
        }
      }
    )
    
    let winRule = Rule(
      condition: { $0.win() },
      actions: { _ in [] }
    )
    
    return [passRule, bustRule, append(moveRule, moveRule), winRule]
  }
    
  static func allowedActions(state: State) -> [Action] {
    CantStop.rules().flatMap { rule in
      if rule.condition(state) {
        return removeSameState(state: state, actions: rule.actions(state))
      } else {
        return [Action]()
      }
    }
  }
  
  static func yieldsSameState(state: State, lhs: Action, rhs: Action) -> Bool {
    var stateAfterLHS = state
    reduce(state: &stateAfterLHS, action: lhs)
    var stateAfterRHS = state
    reduce(state: &stateAfterRHS, action: rhs)
    return stateAfterLHS == stateAfterRHS
  }

  static func removeSameState(state: State, actions: [Action]) -> [Action] {
    var result = [Action]()
    for action in actions {
      if result.contains(where: { yieldsSameState(state: state, lhs: $0, rhs: action) }) {
        continue
      } else {
        result.append(action)
      }
    }
    return result
  }
  
  static func reduce(state: inout State, action: Action) {
    switch action {
    case let .movePieceTo(ppos):
      state.position[ppos.piece] = ppos.position
    case .setPhase(let phase):
      state.phase = phase
    case .advancePlayer:
      state.advancePlayer()
    case .pass:
      state.savePlace()
      state.advancePlayer()
    case .bust:
      state.clearWhite()
      state.advancePlayer()
    case .rollDice:
      state.dice[.die1] = DSix.random()
      state.dice[.die2] = DSix.random()
      state.dice[.die3] = DSix.random()
      state.dice[.die4] = DSix.random()
      state.phase = .rolled
    case let .assignDicePair(pairing):
      // copy the resulting column to the assignedDicePair component
      state.assignedDicePair = CantStop.twod6_total(pairing.map { state.dice[$0]! })
      // erase/consume the values of these two dice
      for die in [pairing.fst, pairing.snd] {
        state.dice[die] = DSix.none
      }
    case let .progressColumn(col):
      let newPos = Position(
        col: col,
        row: state.farthestAlong(for: state.player, in: col) + 1
      )
      if let white = Piece.whitePieces.first(where: {state.position[$0]?.col == col}) {
        state.position[white] = newPos
      } else if let spareWhite = Piece.whitePieces.first(where: {state.position[$0]?.col == Column.none}) {
        state.position[spareWhite] = newPos
      }
      state.assignedDicePair = Column.none
    case let .sequence(actions):
      for action in actions {
        reduce(state: &state, action: action)
      }
    }
  }
  
  /// for TCA
  var body: some Reducer<State, Action> {
    Reduce { st, act in
      CantStop.reduce(state: &st, action: act)
      return .none
    }
  }
  
  static func twod6_total(_ dice: Pair<DSix>) -> Column {
    let col = Column(rawValue: dice.fst.rawValue + dice.snd.rawValue) ?? .none
    return col
  }
}

