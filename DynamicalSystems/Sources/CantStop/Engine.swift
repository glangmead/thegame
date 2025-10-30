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
    case pass
    case bust
    case claimVictory
    case rollDice
    case assignDicePair(Pair<Die>)
    case progressColumn(Column)
    // recursive: ordered list of actions
    case sequence([Action])
    
    var name: String {
      switch self {
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
      condition: { $0.usableDice().isEmpty },
      actions: { state in
        if state.winAchieved() {
          [.claimVictory]
        } else {
          [.rollDice, .pass]
        }
      }
    )
    
    let moveRule = Rule(
      condition: { $0.usableDice().isNonEmpty },
      actions: { state in
        let dicePairings: [Pair<Die>] = pairs(of: state.usableDice())
        
        return dicePairings.compactMap { pairing in
          let col = twod6_total(pairing.map {state.dice[$0]!})
          if !state.colIsWon(col) &&
              (state.whiteIn(col: col) != nil || state.whiteIn(col: .none) != nil) {
            return Action.sequence([.assignDicePair(pairing), .progressColumn(col)])
          }
          return nil
        }
      }
    )
    
    let onePairOnlyRule = Rule(
      condition: { state in
        moveRule.actions(state).isEmpty &&
        state.usableDice().count == 2
      },
      actions: { state in
        if state.winAchieved() {
          [.claimVictory]
        } else {
          [.rollDice, .pass]
        }
      }
    )
    
    let bustRule = Rule(
      condition: { state in
        moveRule.actions(state).isEmpty &&
        state.usableDice().count == 4
      },
      actions: { _ in [Action.bust] }
    )

    return [passRule, bustRule, onePairOnlyRule, append(moveRule, moveRule)]
  }
    
  static func allowedActions(state: State) -> [Action] {
    if state.ended {
      return []
    }
    let actions = rules().flatMap { rule in
      if rule.condition(state) {
        return rule.actions(state)
      } else {
        return [Action]()
      }
    }
    return removeSameState(state: state, actions: actions)
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
    case .claimVictory:
      state.ended = true
    case .pass:
      state.savePlace()
      state.advancePlayer()
      state.clearDice()
    case .bust:
      state.clearWhite()
      state.advancePlayer()
      state.clearDice()
    case .rollDice:
      for die in Die.allCases {
        state.dice[die] = DSix.random()
      }
    case let .assignDicePair(pairing):
      // copy the resulting column to the assignedDicePair component
      state.assignedDicePair = CantStop.twod6_total(pairing.map { state.dice[$0]! })
      // erase/consume the values of these two dice
      for die in [pairing.fst, pairing.snd] {
        state.dice[die] = DSix.none
      }
    case let .progressColumn(col):
      let newRow = min(colHeights()[col]!, state.farthestAlong(in: col) + 1)
      if let white = state.whiteIn(col: col) {
        state.position[white]!.row = newRow
      } else if let spareWhite = state.whiteIn(col: .none) {
        state.position[spareWhite]! = Position(col: col, row: newRow)
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

