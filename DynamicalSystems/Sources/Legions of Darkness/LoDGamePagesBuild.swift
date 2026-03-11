//
//  LoDGamePagesBuild.swift
//  DynamicalSystems
//
//  Legions of Darkness — Build phase rule page (upgrades and barricades).
//

import Foundation

extension LoD {

  static var buildPage: RulePage<State, Action> {
    RulePage(
      name: "Fortification",
      rules: [
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining > 0 },
          actions: { state in
            var actions: [Action] = []

            // Build upgrades (on unbreached walls without existing upgrades and no army on space 1)
            for track in Track.walls {
              if !state.breaches.contains(track) && state.upgrades[track] == nil
                && !state.armyAtSpace1(on: track) {
                for upgrade in UpgradeType.allCases {
                  actions.append(.build(.buildUpgrade(upgrade, track, dieRoll: 0)))
                }
              }
            }

            // Build barricade (on breached walls, rule 6.3)
            for track in Track.walls where state.breaches.contains(track) {
              actions.append(.build(.buildBarricade(track, dieRoll: 0)))
            }

            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .build = action else { return nil }
        let logs = state.resolveDieRollWithPaladinCheck(action, phase: .action)
        return (logs, [])
      }
    )
  }
}
