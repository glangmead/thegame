//
//  LoDGamePagesGeneral.swift
//  DynamicalSystems
//
//  Legions of Darkness — General rule page (rogue move, end player turn).
//

import Foundation

extension LoD {

  static var generalPage: RulePage<State, Action> {
    RulePage(
      name: "General",
      rules: [
        // Player turn: always offer rogue move + end turn
        GameRule(
          condition: { $0.phase == .action && !$0.isInSubResolution },
          actions: { state in
            var actions: [Action] = []

            // Rogue free move (rule 10.4) — doesn't cost an action
            if state.heroLocation[.rogue] != nil && !state.heroDead.contains(.rogue) {
              for track in Track.allCases {
                actions.append(.rogueMove(.onTrack(track)))
              }
              actions.append(.rogueMove(.reserves))
            }

            actions.append(.endPlayerTurn)
            return actions
          }
        )
      ],
      reduce: { state, action in
        switch action {
        case .rogueMove(let location):
          state.moveHero(.rogue, to: location)
          return ([Log(msg: "Rogue moved to \(location) (free)")], [])

        case .endPlayerTurn:
          return ([Log(msg: "Player turn ended")], [.performHousekeeping])

        default:
          return nil
        }
      }
    )
  }
}
