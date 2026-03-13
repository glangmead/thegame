//
//  LoDGameLoopTests.swift
//  DynamicalSystems
//
//  Tests for LoD full game loop integration.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDGameLoopTests {

  // MARK: - Full Game Loop Integration

  @Test
  func fullGameVictoryPlaythrough() {
    // Play through all 16 time positions using a safe card (no event, time: 1)
    // to reach Final Twilight and trigger victory.
    let card3 = LoD.dayCards.first { $0.number == 3 }!  // "All is Quiet", time: 1, no event
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 20),
      shuffledNightCards: Array(repeating: card3, count: 20)
    )
    var state = game.newState()
    #expect(state.phase == .card)
    #expect(state.outcome == .ongoing)

    // Play 15 turns (time advances from 0 to 15)
    for turn in 0..<15 {
      let actions = game.allowedActions(state: state)
      #expect(actions.contains(.drawCard), "Turn \(turn): expected drawCard in \(state.phase)")
      _ = game.reduce(into: &state, action: .drawCard)
      _ = game.reduce(into: &state, action: .endPlayerTurn)
    }

    // After 15 turns with time: 1 each, we should be at Final Twilight
    #expect(state.timePosition == 15)
    #expect(state.ended == true)
    #expect(state.victory == true)
    #expect(state.outcome == .victory)

    // Priority page should offer claimVictory
    let actions = game.allowedActions(state: state)
    #expect(actions == [LoD.Action.claimVictory])

    // Acknowledge victory → terminal
    _ = game.reduce(into: &state, action: .claimVictory)
    #expect(state.gameAcknowledged == true)
    #expect(game.isTerminal(state: state))
    #expect(game.allowedActions(state: state).isEmpty)
  }

  @Test
  func fullGameDefeatByBreach() {
    // Use a card that advances East army until it breaches and enters castle.
    // Card #6 advances East only, time: 1, no event.
    let card6 = LoD.dayCards.first { $0.number == 6 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card6, count: 20),
      shuffledNightCards: Array(repeating: card6, count: 20)
    )
    var state = game.newState()

    // Play turns until defeat
    var turnCount = 0
    while !state.ended && turnCount < 20 {
      _ = game.reduce(into: &state, action: .drawCard)
      _ = game.reduce(into: &state, action: .endPlayerTurn)
      turnCount += 1
    }

    // Game should have ended in defeat (East army breached)
    #expect(state.ended == true)
    #expect(state.victory == false)
    #expect(state.outcome == .defeatBreached)

    // Priority page should offer declareLoss
    let actions = game.allowedActions(state: state)
    #expect(actions == [LoD.Action.declareLoss])

    // Acknowledge defeat → terminal
    _ = game.reduce(into: &state, action: .declareLoss)
    #expect(state.gameAcknowledged == true)
    #expect(game.isTerminal(state: state))
    #expect(game.allowedActions(state: state).isEmpty)
  }

}
