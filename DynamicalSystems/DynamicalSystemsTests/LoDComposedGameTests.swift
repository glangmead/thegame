//
//  LoDComposedGameTests.swift
//  DynamicalSystems
//
//  Tests for LoD composed game (oapply): event phase, action phase,
//  budget tracking, quest rewards, spell casting.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDComposedGameTests {

  // MARK: - Composed Game (oapply)

  @Test
  func composedGameInitialState() {
    // The composed game creates a valid initial state in the card phase.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    let state = game.newState()

    #expect(state.phase == .card)
    #expect(state.dayDrawPile.count == 20)
    #expect(state.nightDrawPile.count == 16)
    #expect(state.history.isEmpty)
  }

  @Test
  func composedGameAllowedActionsInCardPhase() {
    // In card phase, only drawCard is offered.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    let state = game.newState()

    let actions = game.allowedActions(state: state)
    #expect(actions == [.drawCard])
  }

  @Test
  func composedGameFullTurnCascade() {
    // Use card #2 (no event) so drawCard cascades: drawCard → advanceArmies → skipEvent.
    // Then player explicitly ends turn.
    // endPlayerTurn cascades to performHousekeeping automatically.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    #expect(state.phase == .card)
    #expect(state.timePosition == 0)

    // Step 1: drawCard cascades through army and event (no-event card)
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.currentCard != nil)
    #expect(state.history.count == 3) // drawCard, advanceArmies, skipEvent

    // Step 2: end player turn → cascades to housekeeping → phase becomes card
    _ = game.reduce(into: &state, action: .endPlayerTurn)
    #expect(state.phase == .card)
    #expect(state.history.count == 5) // +endPlayerTurn, +performHousekeeping

    #expect(state.history[0] == .drawCard)
    #expect(state.history[1] == .advanceArmies(acidAttackDieRolls: [:]))
    #expect(state.history[2] == .skipEvent)
    #expect(state.history[3] == .endPlayerTurn)
    #expect(state.history[4] == .performHousekeeping)
  }

  @Test
  func composedGameTimeAdvancesOverTurns() {
    // Card #3 ("All is Quiet") has no event, no advances, time: 1, bloodyBattle: gate.
    // Safe for multiple turns without triggering breaches.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 5),
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    let initialTime = state.timePosition

    for _ in 0..<5 {
      let actions = game.allowedActions(state: state)
      #expect(actions.contains(.drawCard))
      _ = game.reduce(into: &state, action: .drawCard)
      // Card #3 has gate bloody battle — resolve pending choice if needed
      if state.pendingBloodyBattleChoices != nil {
        _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
      }
      _ = game.reduce(into: &state, action: .endPlayerTurn)
    }

    #expect(state.timePosition == initialTime + 5) // card3.time = 1 × 5 turns
  }

  @Test
  func composedGameTerminalState() {
    // When the game ends and is acknowledged, no actions are offered.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.ended = true
    state.gameAcknowledged = true

    let actions = game.allowedActions(state: state)
    #expect(actions.isEmpty)
  }

  @Test
  func composedGameArmiesAdvance() {
    // Card #2 advances: gate, gate, west, east.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    let eastBefore = state.armyPosition[.east]!
    let westBefore = state.armyPosition[.west]!

    _ = game.reduce(into: &state, action: .drawCard)

    // Card #2 advances east and west (and gate twice)
    #expect(state.armyPosition[.east]! < eastBefore)
    #expect(state.armyPosition[.west]! < westBefore)
  }

  // MARK: - Event Phase Tests

  @Test
  func composedGameEventPhaseWithEvent() {
    // Card #1 has event "Catapult Shrapnel". After drawCard cascade stops at event phase,
    // the player must provide resolveEvent.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1] + LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // drawCard cascades: drawCard → advanceArmies. Stops because card has event.
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .event)

    // Rules should offer resolveEvent
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(where: { if case .resolveEvent = $0 { return true }; return false }))

    // Resolve with die roll 5 (no effect for Catapult Shrapnel)
    var resolution = LoD.EventResolution()
    resolution.dieRoll = 5
    _ = game.reduce(into: &state, action: .resolveEvent(resolution))
    #expect(state.phase == .action)
    // Defenders unchanged (roll 4-6 = no effect)
    #expect(state.defenderValue(for: .archers) == 2)
    #expect(state.defenderValue(for: .menAtArms) == 3)
  }

  @Test
  func composedGameEventCatapultShrapnelLoseDefender() {
    // Catapult Shrapnel roll 1 → lose archer.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .event)

    var resolution = LoD.EventResolution()
    resolution.dieRoll = 1
    _ = game.reduce(into: &state, action: .resolveEvent(resolution))
    #expect(state.defenderPosition[.archers] == 1)
    #expect(state.defenderValue(for: .archers) == 2) // track [2,2,1,1,0]: still 2
  }

}
