//
//  LoDSlowPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Slow spell page.
//

import Foundation

extension LoD {

  static var slowPage: RulePage<State, Action> {
    RulePage(
      name: "Slow",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.slow)
              && state.arcaneEnergy >= SpellType.slow.energyCost
          },
          actions: { state in
            var actions: [Action] = []
            let slots = state.targetableSlotsForArcaneSpell(.slow)
            for slot in slots {
              actions.append(.slow(slot: slot, heroic: false))
            }
            if state.canHeroicCast(.slow) {
              for slot in slots {
                actions.append(.slow(slot: slot, heroic: true))
              }
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .slow(let slot, let heroic) = action else { return nil }
        let castResult = state.castSpell(.slow, heroic: heroic)
        guard case .success = castResult else { return nil }
        state.applySlow(on: slot, heroic: heroic)
        return ([Log(msg: "Slow on \(slot)\(heroic ? " (heroic)" : "")")], [])
      }
    )
  }
}
