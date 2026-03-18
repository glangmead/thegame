//
//  LoDLastDitchEffortsPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Last Ditch Efforts quest reward page (card #10).
//

import Foundation

extension LoD {

  static var lastDitchEffortsPage: RulePage<State, Action> {
    RulePage(
      name: "Last Ditch Efforts",
      rules: [
        GameRule(
          condition: {
            $0.phase == .action && $0.questRewardPending && $0.currentCard?.number == 10
          },
          actions: { state in
            Array(state.heroDead).sorted { $0.rawValue < $1.rawValue }
              .map { .lastDitchEfforts($0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .lastDitchEfforts(let hero) = action else { return nil }
        state.questLastDitchEfforts(hero: hero)
        state.questRewardPending = false
        return ([Log(msg: "Quest reward: Last Ditch Efforts — added \(hero)")], [])
      }
    )
  }
}
