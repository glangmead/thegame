//
//  LoDRaiseDeadPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Raise Dead spell page.
//

import Foundation

extension LoD {

  static var raiseDeadPage: RulePage<State, Action> {
    RulePage(
      name: "Raise Dead",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.raiseDead)
              && state.divineEnergy >= SpellType.raiseDead.energyCost
          },
          actions: { state in
            var actions: [Action] = []
            let types = DefenderType.allCases
            let deadHeroes = Array(state.heroDead).sorted { $0.rawValue < $1.rawValue }
            // Normal: 2 different defenders OR 1 dead hero (exclusive)
            for idx in 0..<types.count {
              for jdx in (idx + 1)..<types.count {
                actions.append(.raiseDead(
                  defenders: [types[idx], types[jdx]], returnHero: nil, heroic: false))
              }
            }
            for hero in deadHeroes {
              actions.append(.raiseDead(defenders: [], returnHero: hero, heroic: false))
            }
            // Heroic: defenders, hero, or both
            if state.canHeroicCast(.raiseDead) {
              for idx in 0..<types.count {
                for jdx in (idx + 1)..<types.count {
                  actions.append(.raiseDead(
                    defenders: [types[idx], types[jdx]], returnHero: nil, heroic: true))
                }
              }
              for hero in deadHeroes {
                actions.append(.raiseDead(defenders: [], returnHero: hero, heroic: true))
              }
              for idx in 0..<types.count {
                for jdx in (idx + 1)..<types.count {
                  for hero in deadHeroes {
                    actions.append(.raiseDead(
                      defenders: [types[idx], types[jdx]], returnHero: hero, heroic: true))
                  }
                }
              }
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .raiseDead(let defenders, let returnHero, let heroic) = action else {
          return nil
        }
        let castResult = state.castSpell(.raiseDead, heroic: heroic)
        guard case .success = castResult else { return nil }
        state.applyRaiseDead(gainDefenders: defenders, returnHero: returnHero)
        let heroDesc = returnHero.map { ", hero \($0)" } ?? ""
        return ([Log(msg: "Raise Dead: \(defenders)\(heroDesc)\(heroic ? " (heroic)" : "")")], [])
      }
    )
  }
}
