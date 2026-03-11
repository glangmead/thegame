//
//  CantStopPages.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

enum CantStopPages {
  static func rollPage() -> RulePage<CantStop.State, CantStop.Action> {
    RulePage(
      name: "Roll",
      rules: [
        GameRule(
          condition: { state in state.phase == .notRolled },
          actions: { _ in [.rollDice] }
        )
      ],
      reduce: { state, action in
        guard case .rollDice = action else { return nil }
        for die in CantStop.Die.allCases {
          state.dice[die] = DSix.allFaces().randomElement()
        }
        state.rolledThisTurn = true
        return ([Log(msg: "Rolled dice")], [.setPhase(.rolled)])
      }
    )
  }

  static func bustPage() -> RulePage<CantStop.State, CantStop.Action> {
    RulePage(
      name: "Bust",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .rolled &&
            state.rolledDice().count == 4 &&
            movePage().allowedActions(state: state).isEmpty
          },
          actions: { _ in [.bust] }
        )
      ],
      reduce: { state, action in
        guard case .bust = action else { return nil }
        state.clearWhite()
        state.advancePlayer()
        state.clearDice()
        return ([Log(msg: "Busted!")], [.setPhase(.notRolled)])
      }
    )
  }

  static func victoryPage() -> RulePage<CantStop.State, CantStop.Action> {
    RulePage(
      name: "Victory",
      rules: [
        GameRule(
          condition: { state in
            !state.ended &&
            state.winAchieved() &&
            state.rolledDice().count < 4 &&
            movePage().allowedActions(state: state).isEmpty
          },
          actions: { _ in [.claimVictory] }
        )
      ],
      reduce: { state, action in
        guard case .claimVictory = action else { return nil }
        state.ended = true
        state.endedInVictoryFor = [state.player]
        state.endedInDefeatFor = state.players.filter { $0 != state.player }
        return ([], [])
      }
    )
  }

  static func passPage() -> RulePage<CantStop.State, CantStop.Action> {
    RulePage(
      name: "Pass",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .rolled &&
            !state.winAchieved() &&
            state.rolledDice().count < 4 &&
            state.rolledThisTurn &&
            movePage().allowedActions(state: state).isEmpty
          },
          actions: { _ in [.rollDice, .pass] }
        )
      ],
      reduce: { state, action in
        guard case .pass = action else { return nil }
        state.savePlace()
        state.advancePlayer()
        state.clearDice()
        return ([], [.setPhase(.notRolled)])
      }
    )
  }

  // swiftlint:disable:next function_body_length
  static func movePage() -> RulePage<CantStop.State, CantStop.Action> {
    RulePage(
      name: "Move",
      rules: [
        GameRule(
          condition: { state in state.phase == .rolled },
          actions: { state in
            guard state.rolledDice().count == 4 else { return [] }
            let dualPairs: [([CantStop.Die], [CantStop.Die])] = [
              ([.die1, .die2], [.die3, .die4]),
              ([.die1, .die3], [.die2, .die4]),
              ([.die1, .die4], [.die2, .die3])
            ]
            let candidates: [CantStop.Action] = dualPairs.flatMap { (pair1, pair2) in
              let col1 = twod6_total(pair1.map { state.dice[$0]! })
              let col2 = twod6_total(pair2.map { state.dice[$0]! })
              let legalSingleCols = [col1, col2].filter { col in
                !state.colIsWon(col) &&
                (state.whiteIn(col: col) != nil || state.whiteIn(col: .none) != nil)
              }
              // see if it's legal to do both, in which case return the action that does both
              if legalSingleCols.count == 2 {
                var testState = state
                if progressColumnsOrFail(state: &testState, action: .progressColumns(legalSingleCols)) {
                  return [CantStop.Action.progressColumns(legalSingleCols)]
                } else {
                  return [
                    CantStop.Action.progressColumns([legalSingleCols[0]]),
                    CantStop.Action.progressColumns([legalSingleCols[1]])
                  ]
                }
              } else if legalSingleCols.count == 1 {
                return [CantStop.Action.progressColumns(legalSingleCols)]
              } else {
                return []
              }
            }
            var seen = Set<CantStop.State>()
            return candidates.filter { action in
              var testState = state
              _ = progressColumnsOrFail(state: &testState, action: action)
              return seen.insert(testState).inserted
            }
          }
        )
      ],
      reduce: { state, action in
        guard case .progressColumns = action else { return nil }
        if progressColumnsOrFail(state: &state, action: action) {
          state.clearDice()
          state.rolledThisTurn = true
          return ([], [])
        }
        return nil
      }
    )
  }

  // return true if it's legal to progress all these columns (e.g., there are enough spare white pieces)
  static func progressColumnsOrFail(state: inout CantStop.State, action: CantStop.Action) -> Bool {
    guard case .progressColumns(let cols) = action else { return false }
    for col in cols {
      let newRow = min(CantStop.colHeights()[col]!, state.farthestAlong(in: col) + 1)
      if let white = state.whiteIn(col: col) {
        state.position[white]!.row = newRow
      } else if let spareWhite = state.whiteIn(col: .none) {
        state.position[spareWhite]! = CantStop.Position(col: col, row: newRow)
      } else {
        return false
      }
    }
    return true
  }

  static func twod6_total(_ dice: [DSix]) -> CantStop.Column {
    let col = CantStop.Column(rawValue: dice.map({$0.rawValue}).reduce(0, +)) ?? .none
    return col
  }

  // MARK: - MCTS State Evaluator

  /// Graduated evaluation: average fraction climbed of the top 3 columns
  /// (by committed placeholder position, ranked by progress).
  /// Evaluates from player1's perspective.
  private static func cantStopStateEvaluator(_ state: CantStop.State) -> Float {
    let player = CantStop.Player.player1
    if state.endedInVictoryFor.contains(player) { return 1.0 }
    if state.endedInDefeatFor.contains(player) { return 0.0 }
    let heights = CantStop.colHeights()
    var fractions = [Float]()
    for col in CantStop.Column.allCases where col != .none {
      let row = state.position[CantStop.Piece.placeholder(player, col)]?.row ?? 0
      fractions.append(Float(row) / Float(heights[col]!))
    }
    fractions.sort(by: >)
    return fractions.prefix(3).reduce(0, +) / 3.0
  }

  static func game() -> ComposedGame<CantStop.State> {
    oapply(
      pages: [
        rollPage(), movePage()
      ],
      priorities: [
        victoryPage(),
        bustPage(),
        passPage()
      ],
      initialState: {
        var state = CantStop.State()
        state.history = [.setPhase(.notRolled)]
        return state
      },
      isTerminal: { $0.ended },
      phaseForAction: { action in
        if case .setPhase(let phase) = action { return phase }
        return nil
      },
      stateEvaluator: cantStopStateEvaluator
    )
  }
}
