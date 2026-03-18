//
//  LoDChainLightningCastPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Chain Lightning cast initiation page.
//

import Foundation

extension LoD {

  static var chainLightningCastPage: RulePage<State, Action> {
    RulePage(
      name: "Cast Chain Lightning",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.chainLightning)
              && state.arcaneEnergy >= SpellType.chainLightning.energyCost
          },
          actions: { state in
            var actions: [Action] = [.castChainLightning(heroic: false)]
            if state.canHeroicCast(.chainLightning) {
              actions.append(.castChainLightning(heroic: true))
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .castChainLightning(let heroic) = action else { return nil }
        let castResult = state.castSpell(.chainLightning, heroic: heroic)
        guard case .success = castResult else { return nil }
        state.chainLightningState = ChainLightningState(heroic: heroic)
        return ([Log(msg: "Chain Lightning: choose bolt targets one at a time")], [])
      }
    )
  }
}
