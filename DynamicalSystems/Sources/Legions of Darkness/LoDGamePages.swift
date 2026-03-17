//
//  LoDGamePages.swift
//  DynamicalSystems
//
//  Legions of Darkness — Card, Army, and Event phase RulePages.
//

import Foundation

extension LoD {

  // MARK: - Card Phase

  static var cardPage: RulePage<State, Action> {
    RulePage(
      name: "Card Phase",
      rules: [
        GameRule(
          condition: { $0.phase == .card },
          actions: { _ in [.drawCard] }
        )
      ],
      reduce: { state, action in
        guard case .drawCard = action else { return nil }
        state.drawCard()
        let logs = cardLogs(for: state.currentCard)
        return (logs, [.advanceArmies])
      }
    )
  }

  // MARK: - Card Log Formatting

  private static func cardLogs(for card: Card?) -> [Log] {
    guard let card else { return [Log(msg: "Drew card: none")] }
    var logs: [Log] = []
    let advances = card.advances.map(\.rawValue).joined(separator: ", ")
    logs.append(Log(msg: "Card #\(card.number): \(card.title) (\(card.deck.rawValue))"))
    logs.append(Log(msg: "  Advances: \(advances), Time: \(card.time)"))
    logs.append(Log(msg: "  Actions: \(card.actions), Heroics: \(card.heroics)"))
    if !card.actionDRMs.isEmpty {
      let drms = card.actionDRMs.map { "\($0.action.rawValue) \($0.value > 0 ? "+" : "")\($0.value)" }
      logs.append(Log(msg: "  Action DRMs: \(drms.joined(separator: ", "))"))
    }
    if !card.heroicDRMs.isEmpty {
      let drms = card.heroicDRMs.map { "\($0.action.rawValue) \($0.value > 0 ? "+" : "")\($0.value)" }
      logs.append(Log(msg: "  Heroic DRMs: \(drms.joined(separator: ", "))"))
    }
    if let event = card.event {
      logs.append(Log(msg: "  Event: \(event.title)"))
      logs.append(Log(msg: "    \(event.text)"))
    }
    if let quest = card.quest {
      logs.append(Log(msg: "  Quest: \(quest.title) (target \(quest.target))"))
      logs.append(Log(msg: "    \(quest.text)"))
      logs.append(Log(msg: "    Reward: \(quest.reward)"))
      if let penalty = quest.penalty {
        logs.append(Log(msg: "    Penalty: \(penalty)"))
      }
    }
    if let bloodyBattle = card.bloodyBattle {
      logs.append(Log(msg: "  Bloody battle: \(bloodyBattle.rawValue)"))
    }
    return logs
  }

  // MARK: - Army Phase

  static var armyPage: RulePage<State, Action> {
    RulePage(
      name: "Army Phase",
      rules: [
        // Bloody battle Gate tie — player chooses placement
        GameRule(
          condition: { $0.phase == .army && $0.pendingBloodyBattleChoices != nil },
          actions: { state in
            (state.pendingBloodyBattleChoices ?? []).map { .chooseBloodyBattle($0) }
          }
        )
      ],
      reduce: { state, action in
        // Handle bloody battle choice
        if case .chooseBloodyBattle(let slot) = action {
          state.bloodyBattleArmy = slot
          state.pendingBloodyBattleChoices = nil
          let logs = [Log(msg: "Bloody battle marker placed on \(slot)")]
          if state.currentCard?.event != nil {
            state.phase = .event
            return (logs, [])
          } else {
            return (logs, [.skipEvent])
          }
        }

        guard case .advanceArmies = action else { return nil }
        var logs: [Log] = []
        if let card = state.currentCard {
          for track in card.advances {
            let results = state.advanceArmyOnTrack(track)
            for result in results {
              logs.append(Log(msg: "Army advance on \(track): \(result)"))
              // Check for acid upgrade free melee attack (rule 6.3)
              if case .advanced(let slot, _, let destination) = result,
                destination == 1,
                state.upgrades[slot.track] == .acid,
                !state.acidUsedThisTurn {
                let dieRoll = LoD.rollDie()
                let attackResult = state.resolveAttack(
                  on: slot, attackType: .melee, dieRoll: dieRoll, drm: 0)
                state.acidUsedThisTurn = true
                logs.append(Log(msg: "Acid free melee attack on \(slot): \(attackResult)"))
              }
            }
          }
          // Set bloody battle marker if card specifies it
          if let bloodyBattleTrack = card.bloodyBattle {
            let slotsOnTrack = ArmySlot.allCases.filter {
              $0.track == bloodyBattleTrack && state.armyPosition[$0] != nil
            }
            if bloodyBattleTrack == .gate && slotsOnTrack.count == 2 {
              let pos1 = state.armyPosition[slotsOnTrack[0]]!
              let pos2 = state.armyPosition[slotsOnTrack[1]]!
              if pos1 == pos2 {
                // Tied — player chooses
                state.pendingBloodyBattleChoices = slotsOnTrack
                logs.append(Log(msg: "Bloody battle: Gate armies tied — choose placement"))
              } else {
                // Pick closest
                let closest = pos1 < pos2 ? slotsOnTrack[0] : slotsOnTrack[1]
                state.bloodyBattleArmy = closest
                logs.append(Log(msg: "Bloody battle marker placed on \(closest)"))
              }
            } else if let first = slotsOnTrack.first {
              state.bloodyBattleArmy = first
              logs.append(Log(msg: "Bloody battle marker placed on \(first)"))
            }
          }
        }
        // If pending BB choice, stay in army phase for player input
        if state.pendingBloodyBattleChoices != nil {
          state.phase = .army
          return (logs, [])
        }
        // Transition: if card has event, offer resolveEvent; otherwise skip
        if state.currentCard?.event != nil {
          return (logs, []) // stop — rules will offer resolveEvent
        } else {
          return (logs, [.skipEvent])
        }
      }
    )
  }

  // MARK: - Event Phase

  static var eventPage: RulePage<State, Action> {
    RulePage(
      name: "Event Phase",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .event && state.currentCard?.event != nil && !state.isInSubResolution
          },
          actions: { state in
            guard let card = state.currentCard else { return [] }
            return state.concreteEventResolutions(for: card).map { .resolveEvent($0) }
          }
        )
      ],
      reduce: { state, action in
        switch action {
        case .skipEvent:
          state.snapshotActionBudget = state.actionBudget
          return ([Log(msg: "No event this turn")], [])

        case .resolveEvent(let resolution):
          guard let card = state.currentCard else {
            return ([Log(msg: "No card for event")], [])
          }
          let dieRoll = LoD.rollDie()
          var logs: [Log] = []

          switch card.number {
          case 1: // Catapult Shrapnel
            state.eventCatapultShrapnel(dieRoll: dieRoll)
            logs.append(Log(msg: "Catapult Shrapnel: rolled \(dieRoll)"))

          case 4: // Rocks of Ages
            state.eventRocksOfAges(dieRoll: dieRoll)
            logs.append(Log(msg: "Rocks of Ages: rolled \(dieRoll)"))

          case 8: // Acts of Valor
            state.eventActsOfValor(woundHeroes: resolution.woundHeroes)
            logs.append(Log(msg: "Acts of Valor: wound=\(resolution.woundHeroes)"))

          case 9: // Distracted Defenders
            let results = state.eventDistractedDefenders()
            for result in results {
              logs.append(Log(msg: "Distracted Defenders: \(result)"))
            }

          case 11: // Harbingers of Doom
            let results = state.eventHarbingers(chosenSlot: resolution.chosenSlot)
            for result in results {
              logs.append(Log(msg: "Harbingers of Doom: \(result)"))
            }

          case 14: // Broken Walls
            let results = state.eventBrokenWalls()
            for result in results {
              logs.append(Log(msg: "Broken Walls: \(result)"))
            }

          case 16: // Lamentation of the Women
            state.eventLamentation(dieRoll: dieRoll)
            logs.append(Log(msg: "Lamentation: rolled \(dieRoll)"))

          case 17: // Reign of Arrows
            state.eventReignOfArrows(dieRoll: dieRoll)
            logs.append(Log(msg: "Reign of Arrows: rolled \(dieRoll)"))

          case 18: // Trapped by Flames
            state.eventTrappedByFlames(dieRoll: dieRoll)
            logs.append(Log(msg: "Trapped by Flames: rolled \(dieRoll)"))

          case 20: // Banners in the Distance
            let results = state.eventBannersInDistance()
            for result in results {
              logs.append(Log(msg: "Banners in the Distance: \(result)"))
            }

          case 23: // Campfires in the Distance
            let results = state.eventCampfires()
            for result in results {
              logs.append(Log(msg: "Campfires in the Distance: \(result)"))
            }

          case 24: // Bloody Handprints
            if let hero = resolution.chosenHero {
              state.eventBloodyHandprints(dieRoll: dieRoll, chosenHero: hero)
              logs.append(Log(msg: "Bloody Handprints: rolled \(dieRoll), hero \(hero)"))
            }

          case 26: // Council of Heroes
            state.eventCouncilOfHeroes()
            logs.append(Log(msg: "Council of Heroes"))

          case 27: // Midnight Magic
            state.eventMidnightMagic(dieRoll: dieRoll)
            logs.append(Log(msg: "Midnight Magic: rolled \(dieRoll)"))

          case 29: // Death and Despair — enters multi-step sub-resolution
            state.deathAndDespairState = DeathAndDespairState(dieRoll: dieRoll)
            logs.append(Log(
              msg: "Death and Despair: rolled \(dieRoll). Choose sacrifices to reduce advance."
            ))

          case 30: // Assassin's Creedo
            state.eventAssassinsCreedo(dieRoll: dieRoll, chosenHero: resolution.chosenHero)
            logs.append(Log(msg: "Assassin's Creedo: rolled \(dieRoll)"))

          case 31: // In the Pale Moonlight
            state.eventPaleMoonlight()
            logs.append(Log(msg: "In the Pale Moonlight"))

          case 32: // By the Light of the Moon (same as Midnight Magic)
            state.eventMidnightMagic(dieRoll: dieRoll)
            logs.append(Log(msg: "By the Light of the Moon: rolled \(dieRoll)"))

          case 33: // Deserters in the Dark
            state.eventDeserters(loseTwoDefenders: resolution.deserterDefenders)
            logs.append(Log(msg: "Deserters in the Dark"))

          case 34: // The Waning Moon
            state.eventWaningMoon(dieRoll: dieRoll)
            logs.append(Log(msg: "Waning Moon: rolled \(dieRoll)"))

          case 35: // Mystic Forces Reborn
            state.eventMysticForcesReborn(dieRoll: dieRoll)
            logs.append(Log(msg: "Mystic Forces Reborn: rolled \(dieRoll)"))

          case 36: // Bump in the Night
            let results = state.eventBumpInTheNight(
              advanceSky: resolution.advanceSky,
              otherAdvances: resolution.otherAdvances
            )
            for result in results {
              logs.append(Log(msg: "Bump in the Night: \(result)"))
            }

          default:
            logs.append(Log(msg: "Unknown event on card \(card.number)"))
          }

          state.snapshotActionBudget = state.actionBudget
          return (logs, [])

        default:
          return nil
        }
      }
    )
  }

}
