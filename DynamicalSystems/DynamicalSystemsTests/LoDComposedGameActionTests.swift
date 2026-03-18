//
//  LoDComposedGameActionTests.swift
//  DynamicalSystems
//
//  Tests for LoD composed game action phase (actions and heroics interleaved).
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
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .magic(.chant))
    }
    #expect(state.actionBudgetRemaining == 3)

    // End turn with budget remaining
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(.endPlayerTurn))
  }

  @Test
  func composedGameActionBudgetExhausted() {
    // Use a card with 1 action point. After one action, action-cost options
    // (combat, build, magic, non-heroic quest) should not be offered,
    // but heroic options remain if heroic budget > 0.
    // Card #26 has 1 action, 3 heroics, event "Council of Heroes".
    let card26 = LoD.nightCards.first { $0.number == 26 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card26],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    _ = game.reduce(into: &state, action: .drawCard)
    if state.phase == .event {
      _ = game.reduce(into: &state, action: .councilOfHeroes)
    }
    #expect(state.phase == .action)
    #expect(state.actionBudgetRemaining == 1)

    // Do one chant — exhausts action budget
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .magic(.chant))
    }
    #expect(state.actionBudgetRemaining == 0)
    #expect(state.heroicBudgetRemaining == 3)

    // Action-cost options gone, heroic options remain
    let actions = game.allowedActions(state: state)
    #expect(!actions.contains(where: { if case .combat = $0 { return true }; return false }))
    #expect(!actions.contains(where: { if case .build = $0 { return true }; return false }))
    #expect(!actions.contains(where: { if case .magic = $0 { return true }; return false }))
    #expect(actions.contains(.endPlayerTurn))
    // Heroic actions still available
    #expect(actions.contains(where: { if case .heroic = $0 { return true }; return false }))
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
    // Resolve Gate bloody battle tie if needed (card #3 has gate BB)
    if state.pendingBloodyBattleChoices != nil {
      _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
    }
    #expect(state.phase == .action)

    // Melee attack on east with a strong roll
    // Card #3 has attack DRM -1, so roll 6 + (-1) = 5. Goblin str 2. 5 > 2 = hit.
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: nil)))
    }

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
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.rangedAttack(
          .east,
          bloodyBattleDefender: nil, useMagicBow: nil)))
    }

    // Roll 6 + card2 gate DRM (doesn't apply to east) vs goblin str 2 → hit
    #expect(state.armyPosition[.east]! > eastPos)
  }

  // MARK: - Heroic Action Tests

  @Test
  func composedGameHeroicActionsInActionPhase() {
    // Heroic actions are available in the action phase alongside regular actions.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.heroicBudget == 2) // card 2 has heroics: 2
    #expect(state.heroicBudgetRemaining == 2)

    let actions = game.allowedActions(state: state)
    // Should offer moveHero, rally, endPlayerTurn, etc.
    #expect(actions.contains(.endPlayerTurn))
    #expect(actions.contains(where: { if case .heroic(.moveHero) = $0 { return true }; return false }))
    #expect(actions.contains(where: { if case .heroic(.rally) = $0 { return true }; return false }))
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
    #expect(state.phase == .action)

    // Move warrior to east track
    _ = game.reduce(into: &state, action: .heroic(.moveHero(.warrior, .onTrack(.east))))
    #expect(state.heroLocation[.warrior] == .onTrack(.east))
    #expect(state.heroicBudgetRemaining == 1)

    // Heroic attack with warrior on east army
    LoD.$rollDie.withValue({ 5 }) {
      _ = game.reduce(into: &state, action: .heroic(.heroicAttack(.warrior, .east)))
    }
    #expect(state.heroicBudgetRemaining == 0)
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

    // Rally with high roll → morale should raise
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .heroic(.rally))
    }
    #expect(state.morale == .normal)
  }

  @Test
  func composedGameEndTurnCascadesToHousekeeping() {
    // endPlayerTurn should auto-cascade to performHousekeeping.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .endPlayerTurn)

    // Should be back to card phase after housekeeping
    #expect(state.phase == .card)
    // Time should have advanced by card's time value
    #expect(state.timePosition == card2.time)
  }

}
