//
//  LoDCureWoundsPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Cure Wounds spell page.
//

import Foundation

extension LoD {

  static var cureWoundsPage: RulePage<State, Action> {
    RulePage(
      name: "Cure Wounds",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.cureWounds)
              && state.divineEnergy >= SpellType.cureWounds.energyCost
              && !state.heroWounded.isEmpty
          },
          actions: { state in
            var actions: [Action] = []
            let wounded = Array(state.heroWounded).sorted { $0.rawValue < $1.rawValue }
            // Normal: heal 1
            for hero in wounded {
              actions.append(.cureWounds(heroes: [hero], heroic: false))
            }
            // Heroic: heal 1 or 2
            if state.canHeroicCast(.cureWounds) {
              for hero in wounded {
                actions.append(.cureWounds(heroes: [hero], heroic: true))
              }
              for idx in 0..<wounded.count {
                for jdx in (idx + 1)..<wounded.count {
                  actions.append(.cureWounds(heroes: [wounded[idx], wounded[jdx]], heroic: true))
                }
              }
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .cureWounds(let heroes, let heroic) = action else { return nil }
        let castResult = state.castSpell(.cureWounds, heroic: heroic)
        guard case .success = castResult else { return nil }
        state.applyCureWounds(heroes: heroes)
        return ([Log(msg: "Cure Wounds: healed \(heroes)\(heroic ? " (heroic)" : "")")], [])
      }
    )
  }
}
