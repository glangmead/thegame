//
//  LoDGamePagesMagic.swift
//  DynamicalSystems
//
//  Legions of Darkness — Magic phase rule page (chant, memorize, pray).
//

import Foundation

extension LoD {

  static var magicPage: RulePage<State, Action> {
    RulePage(
      name: "Magic",
      rules: [
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining > 0 && !$0.isInSubResolution },
          actions: { state in
            var actions: [Action] = []
            if state.defenderValue(for: .priests) > 0 {
              actions.append(.magic(.chant))
            }
            if !state.faceDownArcaneSpells.isEmpty {
              actions.append(.magic(.memorize))
            }
            if !state.faceDownDivineSpells.isEmpty {
              actions.append(.magic(.pray))
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .magic(let magicAction) = action else { return nil }
        var logs: [Log] = []
        switch magicAction {
        case .chant:
          let chantLogs = state.resolveDieRollWithPaladinCheck(action, phase: .action)
          return (chantLogs, [])
        case .memorize:
          let spell = LoD.drawRandomSpell(state.faceDownArcaneSpells)
          if let spell {
            let success = state.memorize(spell: spell)
            logs.append(Log(msg: "Memorize \(spell): \(success ? "success" : "failed")"))
          }
          return (logs, [])
        case .pray:
          let spell = LoD.drawRandomSpell(state.faceDownDivineSpells)
          if let spell {
            let success = state.pray(spell: spell)
            logs.append(Log(msg: "Pray \(spell): \(success ? "success" : "failed")"))
          }
          return (logs, [])
        }
      }
    )
  }
}
