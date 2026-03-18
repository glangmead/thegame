//
//  LoDPutForthTheCallPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Put Forth the Call quest reward page (card #10).
//

import Foundation

extension LoD {

  static var putForthTheCallPage: RulePage<State, Action> {
    RulePage(
      name: "Put Forth the Call",
      rules: [
        GameRule(
          condition: { $0.phase == .action && $0.questRewardPending && $0.currentCard?.number == 10 },
          actions: { _ in
            DefenderType.allCases.map { .putForthTheCall($0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .putForthTheCall(let defender) = action else { return nil }
        state.questPutForthCall(defender: defender)
        state.questRewardPending = false
        return ([Log(msg: "Quest reward: Put Forth the Call — +1 \(defender)")], [])
      }
    )
  }
}
