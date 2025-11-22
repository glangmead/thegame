//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

import ComposableArchitecture
import Overture
import SwiftUI

@Reducer
struct CantStop: LookaheadReducer {
  
  // the sigma type of the type family: pairs of (component, value)
  // The state will supply some context, such as who is performing the action
  enum Action: Hashable, Equatable, Sendable {
    case pass
    case bust
    case claimVictory
    case rollDice
    case forceRoll([DSix])
    case assignDicePair(Pair<Die>)
    case progressColumn(Column)
    case playAgain
    // recursive: ordered list of actions
    case sequence([Action])
    
    var name: String {
      switch self {
      case .assignDicePair(_):
        return ""
      case .sequence(let actions):
        let name = actions.compactMap { $0.name.isEmpty ? nil : $0.name }
          .joined(separator: " and ")
        return "\(name)"
      case .progressColumn(let col):
        return "\(col.rawValue)"
      case .rollDice:
        return "Roll dice"
      case .claimVictory:
        return "Claim victory!"
      case .pass:
        return "Pass"
      case .bust:
        return "Busted: Pass"
      case .playAgain:
        return "New game"
      default:
        return String(describing: self)
      }
    }
  }
  
  /// A Rule is a conditional action
  struct Rule {
    let condition: StatePredicate
    let actions: (State) -> [Action]
    
    // Form a conjunction of a rule with another predicate, for when you want to say "oh but it also needs to be the case that..."
    func also(_ cond: @escaping StatePredicate) -> Rule {
      return Rule(
        condition: { self.condition($0) && cond($0) },
        actions: self.actions
      )
    }
  }

  // here we are appending the actions of `first` with all the actions of `second` such that
  // - the conditions of `second` are true
  // - there are actions coming from `second`
  // edge cases:
  // - `second` no longer applies after an action of `first`
  // - `second` emits no rules after an action of `first`
  // - we want to use .sequence only for two or more actions
  static func append(_ first: Rule, _ second: Rule) -> Rule {
    return Rule(
      condition: first.condition, // to enter into this sequence, you just need the first condition to be met
      actions: { state in
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
      }
    )
  }
  
  /// The idea is to have all the logic of the game inside these Rule objects.
  /// The actions, reducer, and state are meant to be brainless.
  /// Granted, there is nonzero logic emergent from the subtypes of the pieces and their fibers.
  ///
  /// (State) -> Bool -> [Action] is secretly [State] -> [Action] hence State -> [Action]?
  /// Some of this typing is just so as to group and organize State -> [Action] semantically.
  /// State semantic helpers:
  ///   - equiv
  ///   - whitePositions
  ///   - whiteIn
  ///   - farthestAlong
  ///   - rolledDice
  ///   - colIsWon
  ///   - wonCols
  ///   - winAchieved
  ///   - piecesAt (though this is quite generic)
  ///
  /// The rules are using these.
  ///
  static func rules() -> [Rule] {
    // in words: you can turn two rolled dice into a column advance (.assignDicePair)
    // you can advance an existing white piece in that column (.progressColumn)
    // you can place and advance an unused white piece in that column (.progressColumn)
    // you can't advance in a column if it's claimed <- &&= a condition?
    // implicit: you can't advance in a column if you don't satisfy the white piece conditions
    //
    // Are the semantics of the rules to take the union? Must be, right? That's what is being generated.
    // Then I could repeat the condition and have more actions.
    // I can just keep going with conditions and actions, and take the union.
    // I want to support being able to say "but you can't do X if Y". That requires cutting down on actions.
    //   - or enlarging the conditions later?
    //   - doing rule1 && condition2 which adds a condition to rule1?
    let moveRule = Rule(
      condition: { state in
        state.rolledDice().isNonEmpty
      },
      actions: { state in
        let dicePairings: [Pair<Die>] = pairs(of: state.rolledDice())
        
        return dicePairings.compactMap { pairing in
          let col = twod6_total(pairing.map {state.dice[$0]!})
          // possible factorization: whiteThatCanMoveIn(col:)
          if !state.colIsWon(col) &&
              (state.whiteIn(col: col) != nil || state.whiteIn(col: .none) != nil) {
            return Action.sequence([.assignDicePair(pairing), .progressColumn(col)])
          }
          return nil
        }
      }
    )
    
    let passRule = Rule(
      condition: { state in
        !state.winAchieved() &&
        state.rolledDice().count < 4 &&
        moveRule.actions(state).isEmpty
      },
      actions: { _ in [.rollDice, .pass] }
    )
    
    let victoryRule = Rule(
      condition: { state in
        !state.ended &&
        state.winAchieved() &&
        state.rolledDice().count < 4 &&
        moveRule.actions(state).isEmpty
      },
      actions: { _ in [.claimVictory] }
    )
    
    let newGameRule = Rule(condition: { state in state.ended }, actions: {_ in [.playAgain]})

    let bustRule = Rule(
      condition: { state in
        state.rolledDice().count == 4 &&
        moveRule.actions(state).isEmpty
      },
      actions: { _ in [.bust] }
    )

    return [victoryRule, passRule, bustRule, append(moveRule, moveRule), newGameRule]
  }
    
  static func allowedActions(state: State) -> [Action] {
    let actions = rules().flatMap { rule in
      if rule.condition(state) {
        return rule.actions(state)
      } else {
        return [Action]()
      }
    }
    return removeSameState(state: state, actions: actions)
  }
  
  static func yieldsEquivState(state: State, lhs: Action, rhs: Action) -> Bool {
    var stateAfterLHS = state
    reduce(state: &stateAfterLHS, action: lhs)
    var stateAfterRHS = state
    reduce(state: &stateAfterRHS, action: rhs)
    return State.equiv(lhs: stateAfterLHS, rhs: stateAfterRHS)
  }

  static func removeSameState(state: State, actions: [Action]) -> [Action] {
    var result = [Action]()
    for action in actions {
      if result.contains(where: { yieldsEquivState(state: state, lhs: $0, rhs: action) }) {
        continue
      } else {
        result.append(action)
      }
    }
    return result
  }
  
  static func reduce(state: inout State, action: Action) {
    switch action {
    case .playAgain:
      state = State()
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
        state.dice[die] = DSix.allFaces().randomElement()
      }
    case .forceRoll(let ds):
      state.dice[Die.die1] = ds[0]
      state.dice[Die.die2] = ds[1]
      state.dice[Die.die3] = ds[2]
      state.dice[Die.die4] = ds[3]
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

