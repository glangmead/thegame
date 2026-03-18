//
//  LoDProphecyRevealedPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Prophecy Revealed quest reward page (card #28).
//

import Foundation

extension LoD {

  static var prophecyRevealedPage: RulePage<State, Action> {
    RulePage(
      name: "Prophecy Revealed",
      rules: [
        GameRule(
          condition: {
            $0.phase == .action && $0.questRewardPending && $0.currentCard?.number == 28
          },
          actions: { state in
            let count = min(3, state.dayDrawPile.count)
            return (0..<count).map { .prophecyRevealed(discardIndex: $0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .prophecyRevealed(let discardIndex) = action else { return nil }
        state.questProphecyRevealed(discardIndex: discardIndex)
        state.questRewardPending = false
        return ([Log(msg: "Quest reward: Prophecy Revealed")], [])
      }
    )
  }
}
