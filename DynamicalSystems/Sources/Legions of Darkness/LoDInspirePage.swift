//
//  LoDInspirePage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Inspire spell page.
//

import Foundation

extension LoD {

  static var inspirePage: RulePage<State, Action> {
    RulePage(
      name: "Inspire",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.inspire)
              && state.divineEnergy >= SpellType.inspire.energyCost
          },
          actions: { state in
            var actions: [Action] = []
            if state.canCastInspireNormal() {
              actions.append(.inspire(heroic: false))
            }
            if state.canHeroicCast(.inspire) {
              actions.append(.inspire(heroic: true))
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .inspire(let heroic) = action else { return nil }
        let castResult = state.castSpell(.inspire, heroic: heroic)
        guard case .success = castResult else { return nil }
        state.applyInspire(heroic: heroic)
        return ([Log(msg: "Inspire\(heroic ? " (heroic)" : ""): morale=\(state.morale)")], [])
      }
    )
  }
}
