//
//  LoDFireballPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Fireball spell page.
//

import Foundation

extension LoD {

  static var fireballPage: RulePage<State, Action> {
    RulePage(
      name: "Fireball",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.fireball)
              && state.arcaneEnergy >= SpellType.fireball.energyCost
          },
          actions: { state in
            state.targetableSlotsForArcaneSpell(.fireball).map { .fireball(slot: $0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .fireball(let slot) = action else { return nil }
        let castResult = state.castSpell(.fireball, heroic: false)
        guard case .success = castResult else { return nil }
        let dieRoll = LoD.rollDie()
        let result = state.applyFireball(on: slot, dieRoll: dieRoll)
        return ([Log(msg: "Fireball on \(slot): \(result)")], [])
      }
    )
  }
}
