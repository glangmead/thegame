//
//  LoDMassHealPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Mass Heal spell page.
//

import Foundation

extension LoD {

  static var massHealPage: RulePage<State, Action> {
    RulePage(
      name: "Mass Heal",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.massHeal)
              && state.divineEnergy >= SpellType.massHeal.energyCost
          },
          actions: { state in
            var actions: [Action] = []
            let types = DefenderType.allCases
            // Normal: +1 to one defender
            for dtype in types {
              actions.append(.massHeal(defenders: [dtype], heroic: false))
            }
            // Heroic: +1 to one or two defenders
            if state.canHeroicCast(.massHeal) {
              for dtype in types {
                actions.append(.massHeal(defenders: [dtype], heroic: true))
              }
              for idx in 0..<types.count {
                for jdx in (idx + 1)..<types.count {
                  actions.append(.massHeal(defenders: [types[idx], types[jdx]], heroic: true))
                }
              }
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .massHeal(let defenders, let heroic) = action else { return nil }
        let castResult = state.castSpell(.massHeal, heroic: heroic)
        guard case .success = castResult else { return nil }
        state.applyMassHeal(defenders: defenders)
        return ([Log(msg: "Mass Heal: +1 \(defenders)\(heroic ? " (heroic)" : "")")], [])
      }
    )
  }
}
