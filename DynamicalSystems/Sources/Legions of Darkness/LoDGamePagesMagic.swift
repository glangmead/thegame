//
//  LoDGamePagesMagic.swift
//  DynamicalSystems
//
//  Legions of Darkness — Magic phase rule page (chant, memorize, pray, cast).
//

import Foundation

extension LoD {

  static var magicPage: RulePage<State, Action> {
    RulePage(
      name: "Magic",
      rules: [
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining > 0 },
          actions: { state in
            var actions: [Action] = []

            // Chant (if priests > 0)
            if (state.defenders[.priests] ?? 0) > 0 {
              actions.append(.magic(.chant(dieRoll: 0)))
            }

            // Memorize (one action, random draw from face-down arcane spells)
            if !state.faceDownArcaneSpells.isEmpty {
              actions.append(.magic(.memorize(randomSpell: nil)))
            }

            // Pray (one action, random draw from face-down divine spells)
            if !state.faceDownDivineSpells.isEmpty {
              actions.append(.magic(.pray(randomSpell: nil)))
            }

            // Cast known spells with sufficient energy
            for spell in state.knownSpells {
              let cost = spell.energyCost
              let hasEnergy = spell.isArcane
                ? state.arcaneEnergy >= cost
                : state.divineEnergy >= cost
              if hasEnergy {
                actions.append(.magic(.castSpell(spell, heroic: false, SpellCastParams())))
                if state.canHeroicCast(spell) {
                  actions.append(.magic(.castSpell(spell, heroic: true, SpellCastParams())))
                }
              }
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

        case .memorize(let randomSpell):
          let spell = randomSpell ?? state.faceDownArcaneSpells.randomElement()
          if let spell {
            let success = state.memorize(spell: spell)
            logs.append(Log(msg: "Memorize \(spell): \(success ? "success" : "failed")"))
          }
          return (logs, [])

        case .pray(let randomSpell):
          let spell = randomSpell ?? state.faceDownDivineSpells.randomElement()
          if let spell {
            let success = state.pray(spell: spell)
            logs.append(Log(msg: "Pray \(spell): \(success ? "success" : "failed")"))
          }
          return (logs, [])

        case .castSpell(let spell, let heroic, let params):
          let castResult = state.castSpell(spell, heroic: heroic)
          switch castResult {
          case .success:
            logs.append(Log(msg: "Cast \(spell)\(heroic ? " (heroic)" : "")"))
            logs += state.applySpellEffect(spell: spell, heroic: heroic, params: params)
          case .spellNotKnown:
            logs.append(Log(msg: "Cannot cast \(spell): not known"))
          case .insufficientEnergy:
            logs.append(Log(msg: "Cannot cast \(spell): insufficient energy"))
          case .heroicRequiresHero:
            logs.append(Log(msg: "Cannot cast \(spell) heroically: no hero"))
          }
          return (logs, [])
        }
      }
    )
  }
}
