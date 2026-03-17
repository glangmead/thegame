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
  func gateBreachAtTimeZero() {
    // Reproduce: gate orcs breach before any time advancement.
    // Card sequence: Death from Above (4), Riders in the Sky (17),
    // Scouting Attack/gate (18), Barricade and Pray (15).
    // All have time=0. Gate gets 4 advance icons across 4 cards.
    // Both orcs start tied at 4, so both advance on each gate icon:
    //   Card 2 (1 gate icon): 4→3 both
    //   Card 3 (1 gate icon): 3→2 both
    //   Card 4 (2 gate icons): 2→1 both, then 1→0 both → breach + defeat
    let card4 = LoD.dayCards.first { $0.number == 4 }!
    let card17 = LoD.dayCards.first { $0.number == 17 }!
    let card18 = LoD.dayCards.first { $0.number == 18 }!
    let card15 = LoD.dayCards.first { $0.number == 15 }!
    let filler = LoD.dayCards.first { $0.number == 3 }!

    let deckOrder = [card4, card17, card18, card15]
      + Array(repeating: filler, count: 16)

    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: deckOrder
    )
    var state = game.newState()

    // Play 4 turns with no player attacks (endPlayerTurn immediately)
    for _ in 0..<4 {
      guard !state.ended else { break }
      _ = game.reduce(into: &state, action: .drawCard)
      // Skip event if needed
      let actions = game.allowedActions(state: state)
      if actions.contains(.endPlayerTurn) {
        _ = game.reduce(into: &state, action: .endPlayerTurn)
      }
    }

    // Game should have ended in defeat with time still at 0
    #expect(state.ended == true)
    #expect(state.timePosition == 0, "All 4 cards have time=0, so time should not advance")
    #expect(state.outcome == .defeatBreached)
  }

  @Test
  func eventWithAllHeroesDead() {
    // Assassin's Creedo (card 30) offers one resolution per living hero.
    // When all heroes are dead, the event must still produce an action.
    let card30 = LoD.nightCards.first { $0.number == 30 }!
    let filler = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: filler, count: 20),
      shuffledNightCards: [card30] + Array(repeating: filler, count: 19)
    )
    var state = game.newState()

    // Kill all heroes
    for hero in LoD.HeroType.allCases {
      state.heroDead.insert(hero)
      state.heroLocation.removeValue(forKey: hero)
    }
    #expect(state.livingHeroes.isEmpty)

    // Advance time to a night space so card 30 is drawn
    state.timePosition = 8  // first night space

    // Draw and process
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.currentCard?.number == 30)

    // Event phase should still offer an action
    let actions = game.allowedActions(state: state)
    #expect(!actions.isEmpty, "Assassin's Creedo must be resolvable with no heroes alive")
  }

  @Test
  func totalCardTimeIsInsufficient() {
    // The total time across all 36 cards is 13 but the time
    // track needs 15 advances to reach Final Twilight.
    // Victory requires both Forlorn Hope quests (+1 each) to succeed.
    let dayTime = LoD.dayCards.reduce(0) { $0 + $1.time }
    let nightTime = LoD.nightCards.reduce(0) { $0 + $1.time }
    let totalCardTime = dayTime + nightTime
    #expect(totalCardTime == 13, "Total card time: \(totalCardTime)")
    #expect(totalCardTime < 15, "Cards alone cannot reach Final Twilight (need 15)")

    // Forlorn Hope quest appears on cards 3 and 13, each gives +1 time
    let forlornHopeCards = LoD.allCards.filter {
      $0.quest?.title == "Forlorn Hope"
    }
    #expect(forlornHopeCards.count == 2)
    #expect(totalCardTime + forlornHopeCards.count == 15,
            "Both Forlorn Hope quests must succeed for victory")
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
