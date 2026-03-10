//
//  LoDComposedGameActionTests.swift
//  DynamicalSystems
//
//  Tests for LoD composed game action phase and heroic phase.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDComposedGameActionTests {

  // MARK: - Action Phase Tests

  @Test
  func composedGameActionBudget() {
    // Card #2 has 4 actions, no event. With normal morale, budget = 4.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.actionBudget == 4)
    #expect(state.actionBudgetRemaining == 4)

    // Do a chant (priests > 0, costs 1 action point)
    _ = game.reduce(into: &state, action: .chant(dieRoll: 6))
    #expect(state.actionBudgetRemaining == 3)

    // Pass with budget remaining
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(.passActions))
  }

  @Test
  func composedGameActionBudgetExhausted() {
    // Use a card with 1 action point. After one action, only pass is offered.
    // Card #26 has 1 action point.
    let card26 = LoD.nightCards.first { $0.number == 26 }!
    // We need to be on a night time space to draw night cards.
    // Instead, just set up manually.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card26], // Put night card in day pile for test
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Card 26 has event "Council of Heroes", so we need to resolve it.
    _ = game.reduce(into: &state, action: .drawCard)

    // Card 26 has event, so we're in event phase
    if state.phase == .event {
      _ = game.reduce(into: &state, action: .resolveEvent(LoD.EventResolution()))
    }
    #expect(state.phase == .action)
    #expect(state.actionBudget == 1)

    // Do one chant
    _ = game.reduce(into: &state, action: .chant(dieRoll: 6))
    #expect(state.actionBudgetRemaining == 0)

    // Only pass should be offered
    let actions = game.allowedActions(state: state)
    #expect(actions == [.passActions])
  }

  @Test
  func composedGameMeleeAttack() {
    // Card #3: no event, no advances, 2 actions.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Move east army to melee range (space 2)
    state.armyPosition[.east] = 2

    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Melee attack on east with a strong roll
    // Card #3 has attack DRM -1, so roll 6 + (-1) = 5. Goblin str 2. 5 > 2 = hit.
    _ = game.reduce(
      into: &state,
      action: .meleeAttack(
        .east, dieRoll: 6,
        bloodyBattleDefender: nil, useMagicSword: nil))

    // Army pushed back from space 2 to space 3
    #expect(state.armyPosition[.east]! == 3)
    #expect(state.actionBudgetRemaining == 1) // 2 - 1 = 1
  }

  @Test
  func composedGameRangedAttack() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Ranged attack on east army (at space 5 after advance)
    let eastPos = state.armyPosition[.east]!
    _ = game.reduce(into: &state, action: .rangedAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicBow: nil))

    // Roll 6 + card2 gate DRM (doesn't apply to east) vs goblin str 2 → hit
    #expect(state.armyPosition[.east]! > eastPos)
  }

  // MARK: - Heroic Phase Tests

  @Test
  func composedGameHeroicPhase() {
    // After passing actions, we enter heroic phase.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)
    #expect(state.heroicBudget == 2) // card 2 has heroics: 2
    #expect(state.heroicBudgetRemaining == 2)

    let actions = game.allowedActions(state: state)
    // Should offer moveHero, rally, passHeroics, etc.
    #expect(actions.contains(.passHeroics))
    #expect(actions.contains(where: { if case .moveHero = $0 { return true }; return false }))
    #expect(actions.contains(where: { if case .rally = $0 { return true }; return false }))
  }

  @Test
  func composedGameMoveHeroAndAttack() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Put east army at space 3 (melee range for warrior)
    state.armyPosition[.east] = 3

    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)

    // Move warrior to east track
    _ = game.reduce(into: &state, action: .moveHero(.warrior, .onTrack(.east)))
    #expect(state.heroLocation[.warrior] == .onTrack(.east))
    #expect(state.heroicBudgetRemaining == 1)

    // Heroic attack with warrior on east army
    _ = game.reduce(into: &state, action: .heroicAttack(.warrior, .east, dieRoll: 5))
    #expect(state.heroicBudgetRemaining == 0)

    // Budget exhausted → only pass offered
    let actions = game.allowedActions(state: state)
    #expect(actions == [.passHeroics])
  }

  @Test
  func composedGameRally() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.morale = .low

    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)

    // Rally with high roll → morale should raise
    _ = game.reduce(into: &state, action: .rally(dieRoll: 6))
    #expect(state.morale == .normal)
  }

  @Test
  func composedGameHeroicPassCascadesToHousekeeping() {
    // passHeroics should auto-cascade to performHousekeeping.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    _ = game.reduce(into: &state, action: .passHeroics)

    // Should be back to card phase after housekeeping
    #expect(state.phase == .card)
    // Time should have advanced by card's time value
    #expect(state.timePosition == card2.time)
  }

}
