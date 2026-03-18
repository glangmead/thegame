//
//  LoDDivineWrathPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Divine Wrath spell page.
//

import Foundation

extension LoD {

  static var divineWrathPage: RulePage<State, Action> {
    RulePage(
      name: "Divine Wrath",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .action && !state.isInSubResolution
              && state.actionBudgetRemaining > 0
              && state.knownSpells.contains(.divineWrath)
              && state.divineEnergy >= SpellType.divineWrath.energyCost
          },
          actions: { state in
            var actions: [Action] = []
            let slots = ArmySlot.allCases.filter { state.armyPosition[$0] != nil }
            // Normal: 1 target
            for slot in slots {
              actions.append(.divineWrath(slots: [slot], heroic: false))
            }
            // Heroic: 2 different targets (ordered pairs)
            if state.canHeroicCast(.divineWrath) {
              for idx in 0..<slots.count {
                for jdx in 0..<slots.count where idx != jdx {
                  actions.append(.divineWrath(slots: [slots[idx], slots[jdx]], heroic: true))
                }
              }
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .divineWrath(let slots, let heroic) = action else { return nil }
        let castResult = state.castSpell(.divineWrath, heroic: heroic)
        guard case .success = castResult else { return nil }
        let targets = slots.map { (slot: $0, dieRoll: LoD.rollDie()) }
        let results = state.applyDivineWrath(targets: targets)
        var logs: [Log] = []
        for (index, result) in results.enumerated() {
          logs.append(Log(msg: "Divine Wrath attack \(index + 1): \(result)"))
        }
        return (logs, [])
      }
    )
  }
}
