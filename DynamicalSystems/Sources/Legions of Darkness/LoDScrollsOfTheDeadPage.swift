//
//  LoDScrollsOfTheDeadPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Scrolls of the Dead quest reward page (card #2).
//

import Foundation

extension LoD {

  static var scrollsOfTheDeadPage: RulePage<State, Action> {
    RulePage(
      name: "Scrolls of the Dead",
      rules: [
        GameRule(
          condition: { $0.phase == .action && $0.questRewardPending && $0.currentCard?.number == 2 },
          actions: { state in
            (state.faceDownArcaneSpells + state.faceDownDivineSpells)
              .map { .scrollsOfTheDead($0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .scrollsOfTheDead(let spell) = action else { return nil }
        state.questScrollsOfDead(chosenSpell: spell)
        state.questRewardPending = false
        return ([Log(msg: "Quest reward: Scrolls of the Dead — learned \(spell)")], [])
      }
    )
  }
}
