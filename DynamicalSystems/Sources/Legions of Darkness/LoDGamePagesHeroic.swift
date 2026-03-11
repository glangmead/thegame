//
//  LoDGamePagesHeroic.swift
//  DynamicalSystems
//
//  Legions of Darkness — Heroic phase rule page (move, heroic attack, rally).
//

import Foundation

extension LoD {

  static var heroicPage: RulePage<State, Action> {
    RulePage(
      name: "Heroic Phase",
      rules: [
        GameRule(
          condition: { $0.phase == .heroic && $0.heroicBudgetRemaining > 0 },
          actions: { state in
            var actions: [Action] = []
            let heroes = state.livingHeroes.filter { hero in
              if state.woundedHeroesCannotAct && state.heroWounded.contains(hero) {
                return false
              }
              return true
            }

            // Move hero (to any track or reserves)
            for hero in heroes {
              for track in Track.allCases {
                actions.append(.heroic(.moveHero(hero, .onTrack(track))))
              }
              actions.append(.heroic(.moveHero(hero, .reserves)))
            }

            // Heroic attack (hero must be on a track with an army)
            for hero in heroes {
              guard case .onTrack(let heroTrack) = state.heroLocation[hero] else { continue }
              for slot in ArmySlot.allCases where slot.track == heroTrack {
                guard state.armyPosition[slot] != nil else { continue }
                actions.append(.heroic(.heroicAttack(hero, slot, dieRoll: 0)))
              }
            }

            // Rally
            actions.append(.heroic(.rally(dieRoll: 0)))

            return actions
          }
        )
      ],
      reduce: { state, action in
        var logs: [Log] = []

        switch action {
        case .heroic(.moveHero(let hero, let location)):
          state.moveHero(hero, to: location)
          logs.append(Log(msg: "Hero \(hero) moved to \(location)"))
          return (logs, [])

        case .heroic(.heroicAttack), .heroic(.rally):
          let heroicLogs = state.resolveDieRollWithPaladinCheck(action, phase: .heroic)
          return (heroicLogs, [])

        default:
          return nil
        }
      }
    )
  }
}
