//
//  LoDChainLightningPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Chain Lightning multi-step sub-resolution page.
//

import Foundation

extension LoD {

  // MARK: - Chain Lightning Sub-State

  struct ChainLightningState: Equatable, Sendable {
    let heroic: Bool
    var boltIndex: Int = 0             // 0, 1, or 2
    var results: [State.AttackResult] = []   // results of completed bolts
    var usedSlots: [ArmySlot] = []     // slots targeted so far

    var drmsForCurrentBolt: Int {
      let base = heroic ? [3, 2, 1] : [2, 1, 0]
      guard boltIndex < base.count else { return 0 }
      return base[boltIndex]
    }

    var isComplete: Bool { boltIndex >= 3 }
  }

  // MARK: - Chain Lightning Sub-Action

  enum ChainLightningAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Chain Lightning"

    case targetBolt(ArmySlot)

    var description: String {
      switch self {
      case .targetBolt(let slot):
        return "Lightning bolt \u{2192} \(slot.rawValue.capitalized)"
      }
    }
  }

  // MARK: - Chain Lightning RulePage

  static var chainLightningPage: RulePage<State, Action> {
    RulePage(
      name: "Chain Lightning",
      rules: [
        GameRule(
          condition: { $0.chainLightningState != nil && !($0.chainLightningState!.isComplete) },
          actions: { state in
            ArmySlot.allCases.compactMap { slot in
              guard state.armyPosition[slot] != nil else { return nil }
              return Action.chainLightning(.targetBolt(slot))
            }
          }
        )
      ],
      reduce: { state, action in
        guard case .chainLightning(.targetBolt(let slot)) = action else { return nil }
        guard var clState = state.chainLightningState else { return nil }

        let effectiveRoll = LoD.rollDie()
        let additionalDRM = state.inspireDRMActive ? 1 : 0
        let result = state.resolveAttack(
          on: slot,
          attackType: .ranged,
          dieRoll: effectiveRoll,
          drm: clState.drmsForCurrentBolt + additionalDRM,
          isMagical: true
        )

        clState.results.append(result)
        clState.usedSlots.append(slot)
        clState.boltIndex += 1

        var logs = [Log(msg: "Chain Lightning bolt \(clState.boltIndex): \(result)")]

        if clState.isComplete {
          state.chainLightningState = nil
          logs.append(Log(msg: "Chain Lightning complete"))
        } else {
          state.chainLightningState = clState
        }

        return (logs, [])
      }
    )
  }
}
