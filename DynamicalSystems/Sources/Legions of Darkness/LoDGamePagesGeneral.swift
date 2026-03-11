//
//  LoDGamePagesGeneral.swift
//  DynamicalSystems
//
//  Legions of Darkness — General rule page (rogue move, pass actions/heroics).
//

import Foundation

extension LoD {

  static var generalPage: RulePage<State, Action> {
    RulePage(
      name: "General",
      rules: [
        // Action phase: budget > 0 — offer rogue move + pass
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining > 0 },
          actions: { state in
            var actions: [Action] = []

            // Rogue free move (rule 10.4) — doesn't cost an action
            if state.heroLocation[.rogue] != nil && !state.heroDead.contains(.rogue) {
              for track in Track.allCases {
                actions.append(.rogueMove(.onTrack(track)))
              }
              actions.append(.rogueMove(.reserves))
            }

            actions.append(.passActions)
            return actions
          }
        ),
        // Action phase: budget exhausted — only rogue move + pass
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining == 0 },
          actions: { state in
            var actions: [Action] = []
            if state.heroLocation[.rogue] != nil && !state.heroDead.contains(.rogue) {
              for track in Track.allCases {
                actions.append(.rogueMove(.onTrack(track)))
              }
              actions.append(.rogueMove(.reserves))
            }
            actions.append(.passActions)
            return actions
          }
        ),
        // Heroic phase: budget exhausted — only pass
        GameRule(
          condition: { $0.phase == .heroic && $0.heroicBudgetRemaining == 0 },
          actions: { _ in [.passHeroics] }
        ),
        // Heroic phase: budget > 0 — offer pass
        GameRule(
          condition: { $0.phase == .heroic && $0.heroicBudgetRemaining > 0 },
          actions: { _ in [.passHeroics] }
        )
      ],
      reduce: { state, action in
        var logs: [Log] = []

        switch action {
        case .rogueMove(let location):
          state.moveHero(.rogue, to: location)
          logs.append(Log(msg: "Rogue moved to \(location) (free)"))
          return (logs, [])

        case .passActions:
          logs.append(Log(msg: "Actions passed"))
          return (logs, [])

        case .passHeroics:
          logs.append(Log(msg: "Heroics passed"))
          return (logs, [.performHousekeeping])

        default:
          return nil
        }
      }
    )
  }
}
