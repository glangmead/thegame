//
//  LoDHousekeepingTests.swift
//  DynamicalSystems
//
//  Tests for LoD Fortune spell, Housekeeping, and terror/defender defeat (rules 3.0, 9.2).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDHousekeepingTests {

  // MARK: - Fortune Spell (arcane, cost 4)

  @Test
  func fortunePeekShowsTopCards() {
    // Peek at the top 3 cards of the current deck without modifying state.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1 // day space → day deck

    let peeked = state.fortunePeek()
    #expect(peeked.count == 3)
    #expect(peeked[0] == LoD.dayCards[0])
    #expect(peeked[1] == LoD.dayCards[1])
    #expect(peeked[2] == LoD.dayCards[2])
    // Deck should be unchanged
    #expect(state.dayDrawPile.count == 20)
  }

  @Test
  func fortuneNormalReorders() {
    // Normal Fortune: look at top 3, put them back in a new order.
    // Reorder [0,1,2] → [2,0,1].
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let original = state.fortunePeek()
    state.applyFortune(newOrder: [2, 0, 1])

    #expect(state.dayDrawPile.count == 20) // no cards removed
    #expect(state.dayDrawPile[0] == original[2])
    #expect(state.dayDrawPile[1] == original[0])
    #expect(state.dayDrawPile[2] == original[1])
    #expect(state.dayDiscardPile.isEmpty) // nothing discarded
  }

  @Test
  func fortuneHeroicDiscardsOne() {
    // Heroic Fortune: discard 1, put remaining 2 back in chosen order.
    // Discard index 1, keep [0, 2] in order [2, 0].
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let original = state.fortunePeek()
    state.applyFortune(newOrder: [2, 0], discardIndex: 1)

    #expect(state.dayDrawPile.count == 19) // 20 - 3 + 2 = 19
    #expect(state.dayDrawPile[0] == original[2])
    #expect(state.dayDrawPile[1] == original[0])
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == original[1]) // middle card discarded
  }

  @Test
  func fortuneOperatesOnNightDeck() {
    // On a night time space, Fortune operates on the night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 4 // night space

    let peeked = state.fortunePeek()
    #expect(peeked[0] == LoD.nightCards[0])

    state.applyFortune(newOrder: [1, 0, 2])
    #expect(state.nightDrawPile[0] == LoD.nightCards[1])
    #expect(state.nightDrawPile[1] == LoD.nightCards[0])
    #expect(state.dayDrawPile.count == 20) // day deck untouched
  }

  // MARK: - Housekeeping (rule 3.0 step 5)

  @Test
  func housekeepingAdvancesTime() {
    // Housekeeping advances time by the current card's time value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Use a card with time = 1
    let timeCard = LoD.allCards.first { $0.time == 1 }!
    state.currentCard = timeCard
    #expect(state.timePosition == 0)

    state.performHousekeeping()
    #expect(state.timePosition == 1)
  }

  @Test
  func housekeepingZeroTimeNoAdvance() {
    // Card with time = 0 doesn't advance the time marker.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let zeroTimeCard = LoD.allCards.first { $0.time == 0 }!
    state.currentCard = zeroTimeCard
    #expect(state.timePosition == 0)

    state.performHousekeeping()
    #expect(state.timePosition == 0)
  }

  @Test
  func housekeepingResetsTurnEffects() {
    // Housekeeping resets all per-turn tracking.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let card = LoD.allCards.first { $0.time == 0 }!
    state.currentCard = card
    state.noMeleeThisTurn = true
    state.eventAttackDRMBonus = 1
    state.woundedHeroesCannotAct = true
    state.inspireDRMActive = true
    state.paladinRerollUsed = true
    state.bloodyBattlePaidThisTurn = true

    state.performHousekeeping()
    #expect(!state.noMeleeThisTurn)
    #expect(state.eventAttackDRMBonus == 0)
    #expect(!state.woundedHeroesCannotAct)
    #expect(!state.inspireDRMActive)
    #expect(!state.paladinRerollUsed)
    #expect(!state.bloodyBattlePaidThisTurn)
  }

  @Test
  func housekeepingChecksVictory() {
    // If time reaches Final Twilight (position 15), housekeeping triggers victory.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 14 // one space before final twilight
    let timeCard = LoD.allCards.first { $0.time == 1 }!
    state.currentCard = timeCard

    state.performHousekeeping()
    #expect(state.timePosition == 15)
    #expect(state.outcome == .victory)
  }

  @Test
  func housekeepingNoCardNoOp() {
    // No current card → housekeeping does nothing.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.currentCard = nil

    state.performHousekeeping()
    #expect(state.timePosition == 0) // unchanged
  }

  @Test
  func defeatByTerrorDefenderLoss() {
    // Terror/Sky army at space 1 causes defender loss. If that empties all
    // defenders → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.terror] = 1
    state.defenderPosition[.menAtArms] = 5
    state.defenderPosition[.archers] = 4
    state.defenderPosition[.priests] = 2

    // Terror tries to advance past space 1 → defenderLoss result
    let result = state.advanceArmy(.terror)
    #expect(result == .defenderLoss)
    // The advanceArmy itself doesn't auto-trigger loseDefender — the caller does.
    // But the state should still be ongoing until the defender is actually lost.
    #expect(state.outcome == .ongoing)

    // Caller acts on the defenderLoss result:
    state.loseDefender(.priests)
    #expect(state.outcome == .defeatAllDefendersLost)
  }

}
