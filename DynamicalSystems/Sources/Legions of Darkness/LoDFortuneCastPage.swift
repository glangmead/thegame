//
//  LoDFortuneCastPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Fortune cast initiation page.
//

import Foundation

extension LoD {

  static var fortuneCastPage: RulePage<State, Action> {
    RulePage(
      name: "Cast Fortune",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.fortune)
              && state.arcaneEnergy >= SpellType.fortune.energyCost
          },
          actions: { state in
            var actions: [Action] = [.castFortune(heroic: false)]
            if state.canHeroicCast(.fortune) {
              actions.append(.castFortune(heroic: true))
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .castFortune(let heroic) = action else { return nil }
        let castResult = state.castSpell(.fortune, heroic: heroic)
        guard case .success = castResult else { return nil }
        let cards = state.fortunePeek()
        state.fortuneState = FortuneState(heroic: heroic, drawnCards: cards)
        return ([Log(msg: "Fortune: viewing \(cards.count) cards")], [])
      }
    )
  }
}
