//
//  HeartsEvaluator.swift
//  DynamicalSystems
//
//  Hearts — MCTS state evaluator. Score-based relative standing heuristic.
//

import Foundation

extension Hearts {
  /// Evaluates from `state.player`'s perspective.
  /// Each AI seat creates its own MCTS with itself as rootState.player.
  static func heartsEvaluator(_ state: State) -> Float {
    let seat = state.player
    let myPenalties = (state.cumulativeScores[seat] ?? 0)
      + (state.handPenalties[seat] ?? 0)

    let allPenalties = Seat.allCases.map { seat in
      (state.cumulativeScores[seat] ?? 0) + (state.handPenalties[seat] ?? 0)
    }
    let maxPenalties = allPenalties.max() ?? 0
    let minPenalties = allPenalties.min() ?? 0

    if myPenalties == minPenalties { return 1.0 }
    if maxPenalties == minPenalties { return 0.5 }
    return 1.0 - Float(myPenalties - minPenalties) / Float(maxPenalties - minPenalties)
  }
}
