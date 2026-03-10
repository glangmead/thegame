//
//  LoDGame.swift
//  DynamicalSystems
//
//  Legions of Darkness — RulePages and composed game via oapply.
//

import Foundation

extension LoD {

  // MARK: - Rule Pages

  static var cardPage: RulePage<State, Action> {
    RulePage(
      name: "Card Phase",
      rules: [
        GameRule(
          condition: { $0.phase == .card },
          actions: { _ in [.drawCard] }
        ),
      ],
      reduce: { state, action in
        guard case .drawCard = action else { return nil }
        state.drawCard()
        return ([Log(msg: "Drew card: \(state.currentCard?.title ?? "none")")],
                [.advanceArmies])
      }
    )
  }

  static var armyPage: RulePage<State, Action> {
    RulePage(
      name: "Army Phase",
      rules: [],  // automatic — no player choices
      reduce: { state, action in
        guard case .advanceArmies = action else { return nil }
        var logs: [Log] = []
        if let card = state.currentCard {
          for track in card.advances {
            let results = state.advanceArmyOnTrack(track)
            for r in results {
              logs.append(Log(msg: "Army advance on \(track): \(r)"))
            }
          }
          // Set bloody battle marker if card specifies it
          if let bb = card.bloodyBattle {
            for slot in ArmySlot.allCases where slot.track == bb {
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
        ),
      ],
      reduce: { state, action in
        switch action {
        case .skipEvent:
          return ([Log(msg: "No event this turn")], [])

        case .resolveEvent(let resolution):
          guard let card = state.currentCard else {
            return ([Log(msg: "No card for event")], [])
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
            for r in results {
              logs.append(Log(msg: "Distracted Defenders: \(r)"))
            }

          case 11: // Harbingers of Doom
            let results = state.eventHarbingers(chosenSlot: resolution.chosenSlot)
            for r in results {
              logs.append(Log(msg: "Harbingers of Doom: \(r)"))
            }

          case 14: // Broken Walls
            let results = state.eventBrokenWalls()
            for r in results {
              logs.append(Log(msg: "Broken Walls: \(r)"))
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
            for r in results {
              logs.append(Log(msg: "Banners in the Distance: \(r)"))
            }

          case 23: // Campfires in the Distance
            let results = state.eventCampfires()
            for r in results {
              logs.append(Log(msg: "Campfires in the Distance: \(r)"))
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
            for r in results {
              logs.append(Log(msg: "Death and Despair: \(r)"))
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
            for r in results {
              logs.append(Log(msg: "Bump in the Night: \(r)"))
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

  // MARK: - Action Phase

  static var actionPage: RulePage<State, Action> {
    RulePage(
      name: "Action Phase",
      rules: [
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining > 0 },
          actions: { state in
            var actions: [Action] = []

            // Melee attacks (if allowed this turn)
            if !state.noMeleeThisTurn {
              for slot in ArmySlot.allCases {
                guard let space = state.armyPosition[slot] else { continue }
                if slot.track.isMeleeRange(space: space) {
                  // Gate targeting rule
                  if slot.track == .gate {
                    if state.gateAttackTargets().contains(slot) {
                      actions.append(.meleeAttack(slot, dieRoll: 0))
                    }
                  } else {
                    actions.append(.meleeAttack(slot, dieRoll: 0))
                  }
                }
              }
            }

            // Ranged attacks (archers > 0, not Terror track)
            if (state.defenders[.archers] ?? 0) > 0 {
              for slot in ArmySlot.allCases {
                guard state.armyPosition[slot] != nil else { continue }
                guard slot.track != .terror else { continue }
                if slot.track == .gate {
                  if state.gateAttackTargets().contains(slot) {
                    actions.append(.rangedAttack(slot, dieRoll: 0))
                  }
                } else {
                  actions.append(.rangedAttack(slot, dieRoll: 0))
                }
              }
            }

            // Build upgrades (on unbreached walls without existing upgrades)
            for track in Track.walls {
              if !state.breaches.contains(track) && state.upgrades[track] == nil {
                for upgrade in UpgradeType.allCases {
                  actions.append(.buildUpgrade(upgrade, track, dieRoll: 0))
                }
              }
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
              actions.append(.questAction(dieRoll: 0))
            }

            // Always offer pass
            actions.append(.passActions)

            return actions
          }
        ),
        // When budget is exhausted, only offer pass
        GameRule(
          condition: { $0.phase == .action && $0.actionBudgetRemaining == 0 },
          actions: { _ in [.passActions] }
        ),
      ],
      reduce: { state, action in
        var logs: [Log] = []

        switch action {
        case .meleeAttack(let slot, let dieRoll):
          let drm = state.totalAttackDRM(slot: slot, attackType: .melee)
          let result = state.resolveAttack(on: slot, attackType: .melee, dieRoll: dieRoll, drm: drm)
          logs.append(Log(msg: "Melee attack on \(slot): \(result)"))
          return (logs, [])

        case .rangedAttack(let slot, let dieRoll):
          let drm = state.totalAttackDRM(slot: slot, attackType: .ranged)
          let result = state.resolveAttack(on: slot, attackType: .ranged, dieRoll: dieRoll, drm: drm)
          logs.append(Log(msg: "Ranged attack on \(slot): \(result)"))
          return (logs, [])

        case .buildUpgrade(let upgrade, let track, let dieRoll):
          let drm = state.totalBuildDRM()
          let result = state.build(upgrade: upgrade, on: track, dieRoll: dieRoll, drm: drm)
          logs.append(Log(msg: "Build \(upgrade) on \(track): \(result)"))
          return (logs, [])

        case .chant(let dieRoll):
          let drm = state.totalChantDRM()
          let success = state.chant(dieRoll: dieRoll, drm: drm)
          logs.append(Log(msg: "Chant: \(success ? "success" : "failed")"))
          return (logs, [])

        case .memorize(let spell):
          let success = state.memorize(spell: spell)
          logs.append(Log(msg: "Memorize \(spell): \(success ? "success" : "failed")"))
          return (logs, [])

        case .pray(let spell):
          let success = state.pray(spell: spell)
          logs.append(Log(msg: "Pray \(spell): \(success ? "success" : "failed")"))
          return (logs, [])

        case .questAction(let dieRoll):
          let result = state.attemptQuest(isHeroic: false, dieRoll: dieRoll)
          logs.append(Log(msg: "Quest (action): \(result)"))
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
              actions.append(.questHeroic(dieRoll: 0))
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
        ),
      ],
      reduce: { state, action in
        var logs: [Log] = []

        switch action {
        case .moveHero(let hero, let location):
          state.moveHero(hero, to: location)
          logs.append(Log(msg: "Hero \(hero) moved to \(location)"))
          return (logs, [])

        case .heroicAttack(let hero, let slot, let dieRoll):
          let result = state.resolveHeroicAttack(hero: hero, on: slot, dieRoll: dieRoll)
          switch result {
          case .success(let r):
            logs.append(Log(msg: "Heroic attack by \(hero) on \(slot): \(r.attackResult)"))
            if r.heroWounded { logs.append(Log(msg: "Hero \(hero) wounded!")) }
            if r.heroKilled { logs.append(Log(msg: "Hero \(hero) killed!")) }
          case .failure(let err):
            logs.append(Log(msg: "Heroic attack error: \(err)"))
          }
          return (logs, [])

        case .rally(let dieRoll):
          let drm = state.totalRallyDRM()
          let success = state.rally(dieRoll: dieRoll, drm: drm)
          logs.append(Log(msg: "Rally: \(success ? "success" : "failed")"))
          return (logs, [])

        case .questHeroic(let dieRoll):
          let result = state.attemptQuest(isHeroic: true, dieRoll: dieRoll)
          logs.append(Log(msg: "Quest (heroic): \(result)"))
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

  // MARK: - Composed Game

  /// Create a composed game for the Greenskin Horde scenario.
  /// All RulePages are wired together via oapply.
  static func composedGame(
    windsOfMagicArcane: Int,
    heroes: [HeroType] = [.warrior, .wizard, .cleric],
    shuffledDayCards: [Card]? = nil,
    shuffledNightCards: [Card]? = nil
  ) -> ComposedGame<State> {
    oapply(
      pages: [cardPage, armyPage, eventPage, actionPage, heroicPage, housekeepingPage],
      priorities: [],
      initialState: {
        var state = greenskinSetup(
          windsOfMagicArcane: windsOfMagicArcane,
          heroes: heroes
        )
        state.setupDecks(
          shuffledDayCards: shuffledDayCards,
          shuffledNightCards: shuffledNightCards
        )
        return state
      },
      isTerminal: { $0.ended },
      phaseForAction: { action in
        switch action {
        case .drawCard: return .army
        case .advanceArmies: return .event
        case .skipEvent: return .action
        case .resolveEvent: return .action
        case .meleeAttack, .rangedAttack, .buildUpgrade, .chant,
             .memorize, .pray, .questAction:
          return nil  // stay in action phase
        case .passActions: return .heroic
        case .moveHero, .heroicAttack, .rally, .questHeroic:
          return nil  // stay in heroic phase
        case .passHeroics: return .housekeeping
        case .performHousekeeping: return .card
        }
      }
    )
  }
}
