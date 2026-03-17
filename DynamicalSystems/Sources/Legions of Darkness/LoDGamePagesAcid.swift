//
//  LoDGamePagesAcid.swift
//  DynamicalSystems
//
//  Legions of Darkness — Acid upgrade free melee attack (rule 6.3).
//

import Foundation

extension LoD {

  /// Acid free melee attack — offered when an army arrives at space 1
  /// on a track with the acid upgrade. Free action (no budget cost).
  static var acidPage: RulePage<State, Action> {
    RulePage(
      name: "Acid Attack",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action
              && !state.acidUsedThisTurn
              && !state.acidEligibleSlots.isEmpty
              && !state.isInSubResolution
          },
          actions: { state in
            state.acidEligibleSlots.map { .acidMeleeAttack($0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .acidMeleeAttack(let slot) = action else { return nil }
        let dieRoll = LoD.rollDie()
        let attackResult = state.resolveAttack(
          on: slot, attackType: .melee, dieRoll: dieRoll)
        state.acidUsedThisTurn = true
        return ([Log(msg: "Acid free melee attack on \(slot): rolled \(dieRoll), \(attackResult)")], [])
      }
    )
  }
}
