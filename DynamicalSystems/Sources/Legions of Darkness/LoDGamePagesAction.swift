//
//  LoDGamePagesAction.swift
//  DynamicalSystems
//
//  Legions of Darkness — Action, Heroic, Paladin Re-roll, and Housekeeping RulePages.
//

import Foundation

extension LoD {

  // MARK: - Action Phase

  static var actionPage: RulePage<State, Action> {
    RulePage(
      name: "Action Phase",
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
                  // Gate targeting rule
                  if slot.track == .gate {
                    if state.gateAttackTargets().contains(slot) {
                      actions.append(.meleeAttack(slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicSword: nil))
                    }
                  } else {
                    actions.append(.meleeAttack(slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicSword: nil))
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
                    actions.append(.rangedAttack(slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicBow: nil))
                  }
                } else {
                  actions.append(.rangedAttack(slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicBow: nil))
                }
              }
            }

            // Build upgrades (on unbreached walls without existing upgrades and no army on space 1)
            for track in Track.walls {
              if !state.breaches.contains(track) && state.upgrades[track] == nil
                && !state.armyAtSpace1(on: track) {
                for upgrade in UpgradeType.allCases {
                  actions.append(.buildUpgrade(upgrade, track, dieRoll: 0))
                }
              }
            }

            // Build barricade (on breached walls, rule 6.3)
            for track in Track.walls where state.breaches.contains(track) {
              actions.append(.buildBarricade(track, dieRoll: 0))
            }

            // Chant (if priests > 0)
            if (state.defenders[.priests] ?? 0) > 0 {
              actions.append(.chant(dieRoll: 0))
            }

            // Memorize (face-down arcane spells)
            for spell in state.faceDownArcaneSpells {
              actions.append(.memorize(spell))
            }

            // Pray (face-down divine spells)
            for spell in state.faceDownDivineSpells {
              actions.append(.pray(spell))
            }

            // Quest (if card has a quest)
            if state.currentCard?.quest != nil {
              actions.append(.questAction(dieRoll: 0, reward: QuestRewardParams()))
            }

            // Cast known spells with sufficient energy
            for spell in state.knownSpells {
              let cost = spell.energyCost
              let hasEnergy = spell.isArcane
                ? state.arcaneEnergy >= cost
                : state.divineEnergy >= cost
              if hasEnergy {
                actions.append(.castSpell(spell, heroic: false, SpellCastParams()))
                if state.canHeroicCast(spell) {
                  actions.append(.castSpell(spell, heroic: true, SpellCastParams()))
                }
              }
            }

            // Rogue free move (rule 10.4) — doesn't cost an action
            if state.heroLocation[.rogue] != nil && !state.heroDead.contains(.rogue) {
              for track in Track.allCases {
                actions.append(.rogueMove(.onTrack(track)))
              }
              actions.append(.rogueMove(.reserves))
            }

            // Always offer pass
            actions.append(.passActions)

            return actions
          }
        ),
        // When budget is exhausted, only offer pass (but still allow rogue free move)
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining == 0 },
          actions: { state in
            var actions: [Action] = []
            if state.heroLocation[.rogue] != nil && !state.heroDead.contains(.rogue) {
              for track in Track.allCases {
                actions.append(.rogueMove(.onTrack(track)))
              }
              actions.append(.rogueMove(.reserves))
            }
            actions.append(.passActions)
            return actions
          }
        )
      ],
      reduce: { state, action in
        var logs: [Log] = []

        // Check if this is an action-phase die-roll action eligible for Paladin re-roll deferral
        switch action {
        case .meleeAttack, .rangedAttack, .buildUpgrade, .buildBarricade, .chant, .questAction:
          if state.canPaladinReroll {
            state.pendingDieRollAction = action
            state.phaseBeforePaladinReact = .action
            state.phase = .paladinReact
            logs.append(Log(msg: "Paladin may re-roll this die"))
            return (logs, [])
          }
          logs += state.resolveActionDieRoll(action)
          return (logs, [])

        case .buildBarricade(let track, let dieRoll):
          let drm = state.totalBuildDRM()
          let result = state.buildBarricade(on: track, dieRoll: dieRoll, drm: drm)
          logs.append(Log(msg: "Build barricade on \(track): \(result)"))
          return (logs, [])

        case .memorize(let spell):
          let success = state.memorize(spell: spell)
          logs.append(Log(msg: "Memorize \(spell): \(success ? "success" : "failed")"))
          return (logs, [])

        case .pray(let spell):
          let success = state.pray(spell: spell)
          logs.append(Log(msg: "Pray \(spell): \(success ? "success" : "failed")"))
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

        case .rogueMove(let location):
          state.moveHero(.rogue, to: location)
          // Free move — rogueMove is not counted in actionPointsSpent
          logs.append(Log(msg: "Rogue moved to \(location) (free)"))
          return (logs, [])

        case .passActions:
          logs.append(Log(msg: "Actions passed"))
          return (logs, [])

        default:
          return nil
        }
      }
    )
  }

  // MARK: - Heroic Phase

  static var heroicPage: RulePage<State, Action> {
    RulePage(
      name: "Heroic Phase",
      rules: [
        GameRule(
          condition: { $0.phase == .heroic && $0.heroicBudgetRemaining > 0 },
          actions: { state in
            var actions: [Action] = []
            let heroes = state.livingHeroes.filter { hero in
              // If woundedHeroesCannotAct, skip wounded heroes
              if state.woundedHeroesCannotAct && state.heroWounded.contains(hero) {
                return false
              }
              return true
            }

            // Move hero (to any track or reserves)
            for hero in heroes {
              for track in Track.allCases {
                actions.append(.moveHero(hero, .onTrack(track)))
              }
              actions.append(.moveHero(hero, .reserves))
            }

            // Heroic attack (hero must be on a track with an army)
            for hero in heroes {
              guard case .onTrack(let heroTrack) = state.heroLocation[hero] else { continue }
              for slot in ArmySlot.allCases where slot.track == heroTrack {
                guard state.armyPosition[slot] != nil else { continue }
                actions.append(.heroicAttack(hero, slot, dieRoll: 0))
              }
            }

            // Rally
            actions.append(.rally(dieRoll: 0))

            // Quest (heroic)
            if state.currentCard?.quest != nil {
              actions.append(.questHeroic(dieRoll: 0, reward: QuestRewardParams()))
            }

            // Always offer pass
            actions.append(.passHeroics)

            return actions
          }
        ),
        // When budget is exhausted, only offer pass
        GameRule(
          condition: { $0.phase == .heroic && $0.heroicBudgetRemaining == 0 },
          actions: { _ in [.passHeroics] }
        )
      ],
      reduce: { state, action in
        var logs: [Log] = []

        switch action {
        case .moveHero(let hero, let location):
          state.moveHero(hero, to: location)
          logs.append(Log(msg: "Hero \(hero) moved to \(location)"))
          return (logs, [])

        case .heroicAttack, .rally, .questHeroic:
          // Check if eligible for Paladin re-roll deferral
          if state.canPaladinReroll {
            state.pendingDieRollAction = action
            state.phaseBeforePaladinReact = .heroic
            state.phase = .paladinReact
            logs.append(Log(msg: "Paladin may re-roll this die"))
            return (logs, [])
          }
          logs += state.resolveHeroicDieRoll(action)
          return (logs, [])

        case .passHeroics:
          logs.append(Log(msg: "Heroics passed"))
          return (logs, [.performHousekeeping])

        default:
          return nil
        }
      }
    )
  }

  // MARK: - Paladin Re-roll (rule 10.2)

  static var paladinReactPage: RulePage<State, Action> {
    RulePage(
      name: "Paladin React",
      rules: [
        GameRule(
          condition: { $0.phase == .paladinReact && $0.pendingDieRollAction != nil },
          actions: { _ in
            [.paladinReroll(newDieRoll: 0), .declineReroll]
          }
        )
      ],
      reduce: { state, action in
        var logs: [Log] = []

        switch action {
        case .declineReroll:
          guard let pending = state.pendingDieRollAction else { return nil }
          let returnPhase = state.phaseBeforePaladinReact ?? .action

          // Resolve the deferred action
          if returnPhase == .action {
            logs += state.resolveActionDieRoll(pending)
          } else {
            logs += state.resolveHeroicDieRoll(pending)
          }

          state.pendingDieRollAction = nil
          state.phaseBeforePaladinReact = nil
          state.phase = returnPhase
          return (logs, [])

        case .paladinReroll(let newDieRoll):
          guard let pending = state.pendingDieRollAction else { return nil }
          let returnPhase = state.phaseBeforePaladinReact ?? .action

          // Modify the pending action with the new die roll
          let modifiedAction = State.withNewDieRoll(pending, newDieRoll: newDieRoll)
          logs.append(Log(msg: "Paladin re-roll: new die = \(newDieRoll)"))

          // Resolve with the new die roll
          if returnPhase == .action {
            logs += state.resolveActionDieRoll(modifiedAction)
          } else {
            logs += state.resolveHeroicDieRoll(modifiedAction)
          }

          state.usePaladinReroll()
          state.pendingDieRollAction = nil
          state.phaseBeforePaladinReact = nil
          state.phase = returnPhase
          return (logs, [])

        default:
          return nil
        }
      }
    )
  }

  // MARK: - Housekeeping

  static var housekeepingPage: RulePage<State, Action> {
    RulePage(
      name: "Housekeeping",
      rules: [],  // automatic — no player choices
      reduce: { state, action in
        guard case .performHousekeeping = action else { return nil }
        state.performHousekeeping()
        return ([Log(msg: "Housekeeping complete. Time: \(state.timePosition)")],
                [])  // stop — next allowedActions will offer drawCard
      }
    )
  }
}
