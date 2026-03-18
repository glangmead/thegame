//
//  LoDPillarsOfTheEarthPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Pillars of the Earth quest reward page (card #22).
//

import Foundation

extension LoD {

  static var pillarsOfTheEarthPage: RulePage<State, Action> {
    RulePage(
      name: "Pillars of the Earth",
      rules: [
        GameRule(
          condition: {
            $0.phase == .action && $0.questRewardPending && $0.currentCard?.number == 22
          },
          actions: { state in
            ArmySlot.allCases.filter { state.armyPosition[$0] != nil }
              .map { .pillarsOfTheEarth($0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .pillarsOfTheEarth(let slot) = action else { return nil }
        state.questPillarsOfEarth(slot: slot)
        state.questRewardPending = false
        return ([Log(msg: "Quest reward: Pillars of the Earth — retreated \(slot)")], [])
      }
    )
  }
}
