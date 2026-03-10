//
//  LoDDeckTests.swift
//  DynamicalSystems
//
//  Tests for LoD deck management (rule 3.0).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDDeckTests {

  // MARK: - Deck Management (rule 3.0)

  @Test
  func deckSetupCardCounts() {
    // After setup, day draw pile has 20 cards, night has 16, discards empty.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks()
    #expect(state.dayDrawPile.count == 20)
    #expect(state.nightDrawPile.count == 16)
    #expect(state.dayDiscardPile.isEmpty)
    #expect(state.nightDiscardPile.isEmpty)
  }

  @Test
  func noCurrentCardAfterSetup() {
    // No card drawn yet after setup.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks()
    #expect(state.currentCard == nil)
  }

  @Test
  func drawFromDayOnDaySpace() {
    // On a day space (position 1), draw from day deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1 // day space

    let card = state.drawCard()
    #expect(card != nil)
    #expect(card!.deck == .day)
    #expect(state.currentCard == card)
    #expect(state.dayDrawPile.count == 19)
    #expect(state.nightDrawPile.count == 16) // unchanged
  }

  @Test
  func drawFromDayOnDawnSpace() {
    // Dawn spaces also draw from the day deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 0 // First Dawn

    let card = state.drawCard()
    #expect(card!.deck == .day)
  }

  @Test
  func drawFromNightOnNightSpace() {
    // On a night space (position 4), draw from night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 4 // night space

    let card = state.drawCard()
    #expect(card != nil)
    #expect(card!.deck == .night)
    #expect(state.currentCard == card)
    #expect(state.nightDrawPile.count == 15)
    #expect(state.dayDrawPile.count == 20) // unchanged
  }

  @Test
  func drawFromNightOnTwilightSpace() {
    // Twilight spaces draw from the night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 3 // first twilight

    let card = state.drawCard()
    #expect(card!.deck == .night)
  }

  @Test
  func drawSetsCurrentCard() {
    // After drawing, currentCard is set to the drawn card.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let card = state.drawCard()
    #expect(state.currentCard == card)
    #expect(card!.number == LoD.dayCards[0].number)
  }

  @Test
  func drawReducesPile() {
    // Drawing removes the top card from the draw pile.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    _ = state.drawCard()
    #expect(state.dayDrawPile.count == 19)
    _ = state.drawCard()
    #expect(state.dayDrawPile.count == 18)
  }

  @Test
  func drawDiscardsPreviousCard() {
    // Drawing a new card discards the previous current card.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let first = state.drawCard()!
    let second = state.drawCard()!
    #expect(second != first)
    #expect(state.currentCard == second)
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == first)
  }

  @Test
  func drawReshufflesWhenEmpty() {
    // Rule 3.0: When draw pile is empty, discard pile is reshuffled back in.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Set up with just 1 day card so the pile empties quickly.
    let oneCard = [LoD.dayCards[0]]
    state.setupDecks(shuffledDayCards: oneCard, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    // Draw the only card.
    let first = state.drawCard()!
    #expect(state.dayDrawPile.isEmpty)

    // Draw again — should reshuffle discard back into draw pile.
    // Use deterministic reshuffle order.
    let card = state.drawCard(reshuffleOrder: [first])
    #expect(card == first) // same card reshuffled back
    #expect(state.dayDiscardPile.isEmpty) // discard was moved to draw pile
  }

}
