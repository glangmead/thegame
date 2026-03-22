//
//  HeartsPieceAdapter.swift
//  DynamicalSystems
//
//  Hearts — Maps game state to GamePiece/GameSection for SpriteKit rendering.
//

import CoreGraphics
import Foundation

struct HeartsPieceAdapter {
  private static let seatRotation: [Hearts.Seat: CGFloat] = [
    .north: .pi,
    .east: .pi / 2,
    .south: 0,
    .west: -.pi / 2
  ]
  // Piece IDs: 0-51 for the 52 cards (sorted by fullDeck order)
  private static let cardIDs: [Hearts.Card: Int] = {
    var map: [Hearts.Card: Int] = [:]
    for (index, card) in Hearts.fullDeck.enumerated() {
      map[card] = index
    }
    return map
  }()

  static func pieces() -> [GamePiece] {
    Hearts.fullDeck.enumerated().map { index, card in
      GamePiece(id: index, kind: .card, displayName: card.description)
    }
  }

  static func section(from state: Hearts.State, graph: SiteGraph) -> GameSection {
    var result: GameSection = [:]

    let seatToHand: [Hearts.Seat: SiteID] = [
      .north: HeartsGraph.northHand,
      .east: HeartsGraph.eastHand,
      .south: HeartsGraph.southHand,
      .west: HeartsGraph.westHand
    ]

    let seatToTrick: [Hearts.Seat: SiteID] = [
      .north: HeartsGraph.northTrick,
      .east: HeartsGraph.eastTrick,
      .south: HeartsGraph.southTrick,
      .west: HeartsGraph.westTrick
    ]

    let seatToPile: [Hearts.Seat: SiteID] = [
      .north: HeartsGraph.northPile,
      .east: HeartsGraph.eastPile,
      .south: HeartsGraph.southPile,
      .west: HeartsGraph.westPile
    ]

    // Cards in hands
    for seat in Hearts.Seat.allCases {
      let siteID = seatToHand[seat]!
      let isFaceUp = seat == state.config.humanSeat
      for card in state.hands[seat] ?? [] {
        guard let pieceID = cardIDs[card] else { continue }
        let piece = GamePiece(id: pieceID, kind: .card, displayName: card.description)
        result[piece] = .cardState(
          name: card.description, faceUp: isFaceUp, isRed: card.suit.isRed,
          rotation: seatRotation[seat] ?? 0, at: siteID)
      }
    }

    // Cards in current trick
    for play in state.currentTrick {
      let siteID = seatToTrick[play.seat]!
      guard let pieceID = cardIDs[play.card] else { continue }
      let piece = GamePiece(id: pieceID, kind: .card, displayName: play.card.description)
      result[piece] = .cardState(
        name: play.card.description, faceUp: true, isRed: play.card.suit.isRed,
        rotation: 0, at: siteID)
    }

    // Won piles (just show count indicator via first card)
    for seat in Hearts.Seat.allCases {
      let tricks = state.tricksTaken[seat] ?? []
      let totalCards = tricks.flatMap { $0 }.count
      if totalCards > 0, let firstCard = tricks.first?.first {
        let siteID = seatToPile[seat]!
        guard let pieceID = cardIDs[firstCard] else { continue }
        let piece = GamePiece(
          id: pieceID, kind: .card, displayName: "\(totalCards) cards")
        result[piece] = .cardState(
          name: "\(totalCards)", faceUp: false, isRed: false,
          rotation: seatRotation[seat] ?? 0, at: siteID)
      }
    }

    return result
  }
}
