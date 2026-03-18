//
//  LoDEventPagesSimple.swift
//  DynamicalSystems
//
//  Legions of Darkness — No-choice event pages and noEventPage.
//

import Foundation

extension LoD {

  // MARK: - No Event

  static var noEventPage: RulePage<State, Action> {
    RulePage(
      name: "No Event",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.event == nil },
          actions: { _ in [.skipEvent] }
        )
      ],
      reduce: { state, action in
        guard case .skipEvent = action else { return nil }
        state.phase = .action
        return ([Log(msg: "No event this turn")], [])
      }
    )
  }

  // MARK: - Card 1: Catapult Shrapnel

  static var catapultShrapnelPage: RulePage<State, Action> {
    RulePage(
      name: "Catapult Shrapnel",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 1 },
          actions: { _ in [.catapultShrapnel] }
        )
      ],
      reduce: { state, action in
        guard case .catapultShrapnel = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventCatapultShrapnel(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Catapult Shrapnel: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 4: Rocks of Ages

  static var rocksOfAgesPage: RulePage<State, Action> {
    RulePage(
      name: "Rocks of Ages",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 4 },
          actions: { _ in [.rocksOfAges] }
        )
      ],
      reduce: { state, action in
        guard case .rocksOfAges = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventRocksOfAges(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Rocks of Ages: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 8: Acts of Valor

  static var actsOfValorPage: RulePage<State, Action> {
    RulePage(
      name: "Acts of Valor",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 8 },
          actions: { _ in [.actsOfValor] }
        )
      ],
      reduce: { state, action in
        guard case .actsOfValor = action else { return nil }
        state.eventActsOfValor()
        state.phase = .action
        return ([Log(msg: "Acts of Valor")], [])
      }
    )
  }

  // MARK: - Card 9: Distracted Defenders

  static var distractedDefendersPage: RulePage<State, Action> {
    RulePage(
      name: "Distracted Defenders",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 9 },
          actions: { _ in [.distractedDefenders] }
        )
      ],
      reduce: { state, action in
        guard case .distractedDefenders = action else { return nil }
        let results = state.eventDistractedDefenders()
        state.phase = .action
        return (results.map { Log(msg: "Distracted Defenders: \($0)") }, [])
      }
    )
  }

  // MARK: - Card 14: Broken Walls

  static var brokenWallsPage: RulePage<State, Action> {
    RulePage(
      name: "Broken Walls",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 14 },
          actions: { _ in [.brokenWalls] }
        )
      ],
      reduce: { state, action in
        guard case .brokenWalls = action else { return nil }
        let results = state.eventBrokenWalls()
        state.phase = .action
        return (results.map { Log(msg: "Broken Walls: \($0)") }, [])
      }
    )
  }

  // MARK: - Card 16: Lamentation of the Women

  static var lamentationPage: RulePage<State, Action> {
    RulePage(
      name: "Lamentation",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 16 },
          actions: { _ in [.lamentationOfWomen] }
        )
      ],
      reduce: { state, action in
        guard case .lamentationOfWomen = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventLamentation(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Lamentation: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 17: Reign of Arrows

  static var reignOfArrowsPage: RulePage<State, Action> {
    RulePage(
      name: "Reign of Arrows",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 17 },
          actions: { _ in [.reignOfArrows] }
        )
      ],
      reduce: { state, action in
        guard case .reignOfArrows = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventReignOfArrows(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Reign of Arrows: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 18: Trapped by Flames

  static var trappedByFlamesPage: RulePage<State, Action> {
    RulePage(
      name: "Trapped by Flames",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 18 },
          actions: { _ in [.trappedByFlames] }
        )
      ],
      reduce: { state, action in
        guard case .trappedByFlames = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventTrappedByFlames(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Trapped by Flames: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 20: Banners in the Distance

  static var bannersInDistancePage: RulePage<State, Action> {
    RulePage(
      name: "Banners in the Distance",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 20 },
          actions: { _ in [.bannersInDistance] }
        )
      ],
      reduce: { state, action in
        guard case .bannersInDistance = action else { return nil }
        let results = state.eventBannersInDistance()
        state.phase = .action
        return (results.map { Log(msg: "Banners in the Distance: \($0)") }, [])
      }
    )
  }

  // MARK: - Card 23: Campfires in the Distance

  static var campfiresPage: RulePage<State, Action> {
    RulePage(
      name: "Campfires",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 23 },
          actions: { _ in [.campfires] }
        )
      ],
      reduce: { state, action in
        guard case .campfires = action else { return nil }
        let results = state.eventCampfires()
        state.phase = .action
        return (results.map { Log(msg: "Campfires in the Distance: \($0)") }, [])
      }
    )
  }

  // MARK: - Card 26: Council of Heroes

  static var councilOfHeroesPage: RulePage<State, Action> {
    RulePage(
      name: "Council of Heroes",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 26 },
          actions: { _ in [.councilOfHeroes] }
        )
      ],
      reduce: { state, action in
        guard case .councilOfHeroes = action else { return nil }
        state.eventCouncilOfHeroes()
        state.phase = .action
        return ([Log(msg: "Council of Heroes")], [])
      }
    )
  }

  // MARK: - Cards 27 + 32: Midnight Magic / By the Light of the Moon

  static var midnightMagicPage: RulePage<State, Action> {
    RulePage(
      name: "Midnight Magic",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .event
              && (state.currentCard?.number == 27 || state.currentCard?.number == 32)
          },
          actions: { _ in [.midnightMagic] }
        )
      ],
      reduce: { state, action in
        guard case .midnightMagic = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventMidnightMagic(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Midnight Magic: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 31: In the Pale Moonlight

  static var paleMoonlightPage: RulePage<State, Action> {
    RulePage(
      name: "Pale Moonlight",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 31 },
          actions: { _ in [.paleMoonlight] }
        )
      ],
      reduce: { state, action in
        guard case .paleMoonlight = action else { return nil }
        state.eventPaleMoonlight()
        state.phase = .action
        return ([Log(msg: "In the Pale Moonlight")], [])
      }
    )
  }

  // MARK: - Card 34: The Waning Moon

  static var waningMoonPage: RulePage<State, Action> {
    RulePage(
      name: "Waning Moon",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 34 },
          actions: { _ in [.waningMoon] }
        )
      ],
      reduce: { state, action in
        guard case .waningMoon = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventWaningMoon(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Waning Moon: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 35: Mystic Forces Reborn

  static var mysticForcesRebornPage: RulePage<State, Action> {
    RulePage(
      name: "Mystic Forces Reborn",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 35 },
          actions: { _ in [.mysticForcesReborn] }
        )
      ],
      reduce: { state, action in
        guard case .mysticForcesReborn = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventMysticForcesReborn(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(msg: "Mystic Forces Reborn: rolled \(dieRoll)")], [])
      }
    )
  }

  // MARK: - Card 29: Death and Despair (trigger only)

  static var deathAndDespairEventPage: RulePage<State, Action> {
    RulePage(
      name: "Death and Despair Event",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 29 },
          actions: { _ in [.deathAndDespairEvent] }
        )
      ],
      reduce: { state, action in
        guard case .deathAndDespairEvent = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.deathAndDespairState = DeathAndDespairState(dieRoll: dieRoll)
        state.phase = .action
        return ([Log(
          msg: "Death and Despair: rolled \(dieRoll). Choose sacrifices to reduce advance."
        )], [])
      }
    )
  }
}
