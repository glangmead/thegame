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
        return (logs, [.advanceArmies(acidAttackDieRolls: [:])])
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
    }
    if let quest = card.quest {
      logs.append(Log(msg: "  Quest: \(quest.title) (target \(quest.target))"))
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
      rules: [],  // automatic — no player choices
      reduce: { state, action in
        guard case .advanceArmies(let acidAttackDieRolls) = action else { return nil }
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
                !state.acidUsedThisTurn,
                let dieRoll = acidAttackDieRolls[slot] {
                let attackResult = state.resolveAttack(on: slot, attackType: .melee, dieRoll: dieRoll, drm: 0)
                state.acidUsedThisTurn = true
                logs.append(Log(msg: "Acid free melee attack on \(slot): \(attackResult)"))
              }
            }
          }
          // Set bloody battle marker if card specifies it
          if let bloodyBattleTrack = card.bloodyBattle {
            for slot in ArmySlot.allCases where slot.track == bloodyBattleTrack {
              if state.armyPosition[slot] != nil {
                state.bloodyBattleArmy = slot
                logs.append(Log(msg: "Bloody battle marker placed on \(slot)"))
                break
              }
            }
          }
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
            state.phase == .event && state.currentCard?.event != nil
          },
          actions: { _ in
            // Offer resolveEvent with placeholder resolution.
            // The caller fills in die rolls and choices.
            [.resolveEvent(EventResolution())]
          }
        )
      ],
      reduce: { state, action in
        switch action {
        case .skipEvent:
          return ([Log(msg: "No event this turn")], [])

        case .resolveEvent(var resolution):
          guard let card = state.currentCard else {
            return ([Log(msg: "No card for event")], [])
          }
          resolution.dieRoll = State.effectiveDie(resolution.dieRoll)
          if let barricadeRoll = resolution.barricadeDieRoll {
            resolution.barricadeDieRoll = State.effectiveDie(barricadeRoll)
          }
          var logs: [Log] = []

          switch card.number {
          case 1: // Catapult Shrapnel
            state.eventCatapultShrapnel(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "Catapult Shrapnel: rolled \(resolution.dieRoll)"))

          case 4: // Rocks of Ages
            state.eventRocksOfAges(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "Rocks of Ages: rolled \(resolution.dieRoll)"))

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
            state.eventLamentation(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "Lamentation: rolled \(resolution.dieRoll)"))

          case 17: // Reign of Arrows
            state.eventReignOfArrows(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "Reign of Arrows: rolled \(resolution.dieRoll)"))

          case 18: // Trapped by Flames
            state.eventTrappedByFlames(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "Trapped by Flames: rolled \(resolution.dieRoll)"))

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
              state.eventBloodyHandprints(dieRoll: resolution.dieRoll, chosenHero: hero)
              logs.append(Log(msg: "Bloody Handprints: rolled \(resolution.dieRoll), hero \(hero)"))
            }

          case 26: // Council of Heroes
            state.eventCouncilOfHeroes()
            logs.append(Log(msg: "Council of Heroes"))

          case 27: // Midnight Magic
            state.eventMidnightMagic(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "Midnight Magic: rolled \(resolution.dieRoll)"))

          case 29: // Death and Despair
            let results = state.eventDeathAndDespair(
              dieRoll: resolution.dieRoll,
              heroesToWound: resolution.sacrificedHeroes,
              defendersToLose: resolution.sacrificedDefenders,
              chosenSlot: resolution.chosenSlot,
              dieRollForBarricade: resolution.barricadeDieRoll
            )
            for result in results {
              logs.append(Log(msg: "Death and Despair: \(result)"))
            }

          case 30: // Assassin's Creedo
            state.eventAssassinsCreedo(dieRoll: resolution.dieRoll, chosenHero: resolution.chosenHero)
            logs.append(Log(msg: "Assassin's Creedo: rolled \(resolution.dieRoll)"))

          case 31: // In the Pale Moonlight
            state.eventPaleMoonlight()
            logs.append(Log(msg: "In the Pale Moonlight"))

          case 32: // By the Light of the Moon (same as Midnight Magic)
            state.eventMidnightMagic(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "By the Light of the Moon: rolled \(resolution.dieRoll)"))

          case 33: // Deserters in the Dark
            state.eventDeserters(loseTwoDefenders: resolution.deserterDefenders)
            logs.append(Log(msg: "Deserters in the Dark"))

          case 34: // The Waning Moon
            state.eventWaningMoon(dieRoll: resolution.dieRoll)
            logs.append(Log(msg: "Waning Moon: rolled \(resolution.dieRoll)"))

          case 35: // Mystic Forces Reborn
            state.eventMysticForcesReborn(dieRoll: resolution.dieRoll, randomSpell: resolution.randomSpell)
            logs.append(Log(msg: "Mystic Forces Reborn: rolled \(resolution.dieRoll)"))

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

          return (logs, [])

        default:
          return nil
        }
      }
    )
  }

}
