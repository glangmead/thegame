//
//  HeartsComponentsTests.swift
//  DynamicalSystems
//
//  Tests for Hearts component types: cards, ordering, deck, penalty points.
//

import Testing
import Foundation

@MainActor
struct HeartsComponentsTests {

  // MARK: - Card Ordering

  @Test
  func cardComparison_sameSuit_orderedByRank() {
    let low = Hearts.Card(suit: .clubs, rank: .two)
    let high = Hearts.Card(suit: .clubs, rank: .ace)
    #expect(low < high)
  }

  @Test
  func cardComparison_differentSuit_orderedBySuit() {
    let club = Hearts.Card(suit: .clubs, rank: .ace)
    let heart = Hearts.Card(suit: .hearts, rank: .two)
    #expect(club < heart)
  }

  @Test
  func suitOrdering() {
    let suits = Hearts.Card.Suit.allCases
    #expect(suits == [.clubs, .diamonds, .spades, .hearts])
  }

  @Test
  func rankOrdering() {
    #expect(Hearts.Card.Rank.two < .three)
    #expect(Hearts.Card.Rank.king < .ace)
    #expect(Hearts.Card.Rank.ten < .jack)
  }

  // MARK: - Deck

  @Test
  func fullDeckHas52Cards() {
    #expect(Hearts.fullDeck.count == 52)
  }

  @Test
  func fullDeckHasNoDuplicates() {
    let unique = Set(Hearts.fullDeck)
    #expect(unique.count == 52)
  }

  @Test
  func fullDeckContainsSpecialCards() {
    #expect(Hearts.fullDeck.contains(Hearts.twoOfClubs))
    #expect(Hearts.fullDeck.contains(Hearts.queenOfSpades))
    #expect(Hearts.fullDeck.contains(Hearts.jackOfDiamonds))
  }

  // MARK: - Penalty Points

  @Test
  func penaltyPoints_hearts() {
    let card = Hearts.Card(suit: .hearts, rank: .five)
    #expect(Hearts.penaltyPoints(for: card) == 1)
  }

  @Test
  func penaltyPoints_queenOfSpades() {
    #expect(Hearts.penaltyPoints(for: Hearts.queenOfSpades) == 13)
  }

  @Test
  func penaltyPoints_nonPenaltyCard() {
    let card = Hearts.Card(suit: .clubs, rank: .ace)
    #expect(Hearts.penaltyPoints(for: card) == 0)
  }

  @Test
  func penaltyPoints_jackOfDiamonds_isZero() {
    #expect(Hearts.penaltyPoints(for: Hearts.jackOfDiamonds) == 0)
  }

  @Test
  func isPenaltyCard() {
    #expect(Hearts.isPenaltyCard(Hearts.queenOfSpades))
    #expect(Hearts.isPenaltyCard(Hearts.Card(suit: .hearts, rank: .ace)))
    #expect(!Hearts.isPenaltyCard(Hearts.Card(suit: .clubs, rank: .king)))
  }

  // MARK: - PassDirection

  @Test
  func passDirectionRotation() {
    #expect(Hearts.PassDirection.forHand(0) == .left)
    #expect(Hearts.PassDirection.forHand(1) == .right)
    #expect(Hearts.PassDirection.forHand(2) == .across)
    #expect(Hearts.PassDirection.forHand(3) == .none)
    #expect(Hearts.PassDirection.forHand(4) == .left)
  }

  // MARK: - Seat

  @Test
  func seatNext() {
    #expect(Hearts.Seat.north.next == .east)
    #expect(Hearts.Seat.east.next == .south)
    #expect(Hearts.Seat.south.next == .west)
    #expect(Hearts.Seat.west.next == .north)
  }

  @Test
  func seatOffset() {
    #expect(Hearts.Seat.south.offset(by: 1) == .west)
    #expect(Hearts.Seat.south.offset(by: 2) == .north)
    #expect(Hearts.Seat.south.offset(by: 3) == .east)
  }

  // MARK: - Card Description

  @Test
  func cardDescription() {
    let card = Hearts.Card(suit: .spades, rank: .queen)
    #expect(card.description == "Q♠️")
  }
}
