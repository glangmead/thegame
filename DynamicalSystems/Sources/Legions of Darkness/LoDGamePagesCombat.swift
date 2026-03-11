//
//  LoDGamePagesCombat.swift
//  DynamicalSystems
//
//  Legions of Darkness — Combat phase rule page (melee and ranged attacks).
//

import Foundation

extension LoD {

  static var combatPage: RulePage<State, Action> {
    RulePage(
      name: "Combat",
      rules: [
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining > 0 },
          actions: { state in
            var actions: [Action] = []

            // Melee attacks (if allowed this turn, limited by men-at-arms count)
            let meleeLimit = state.defenders[.menAtArms] ?? 0
            if !state.noMeleeThisTurn && state.meleeAttacksThisTurn < meleeLimit {
              for slot in ArmySlot.allCases {
                guard let space = state.armyPosition[slot] else { continue }
                if slot.track.isMeleeRange(space: space) {
                  if slot.track == .gate {
                    if state.gateAttackTargets().contains(slot) {
                      actions.append(.combat(.meleeAttack(
                        slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicSword: nil)))
                    }
                  } else {
                    actions.append(.combat(.meleeAttack(
                      slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicSword: nil)))
                  }
                }
              }
            }

            // Ranged attacks (archers > 0, not Terror track, limited by archers count)
            let rangedLimit = state.defenders[.archers] ?? 0
            if rangedLimit > 0 && state.rangedAttacksThisTurn < rangedLimit {
              for slot in ArmySlot.allCases {
                guard state.armyPosition[slot] != nil else { continue }
                guard slot.track != .terror else { continue }
                if slot.track == .gate {
                  if state.gateAttackTargets().contains(slot) {
                    actions.append(.combat(.rangedAttack(
                      slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicBow: nil)))
                  }
                } else {
                  actions.append(.combat(.rangedAttack(
                    slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicBow: nil)))
                }
              }
            }

            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .combat = action else { return nil }
        let logs = state.resolveDieRollWithPaladinCheck(action, phase: .action)
        return (logs, [])
      }
    )
  }
}
