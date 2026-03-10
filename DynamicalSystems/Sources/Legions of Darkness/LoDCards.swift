//
//  LoDCards.swift
//  DynamicalSystems
//
//  Legions of Darkness — Card data (36 cards: 20 day, 16 night).
//  Data sourced from card images and verified by user.
//

import Foundation

extension LoDComponents {

  private struct CardContainer: Codable {
    let cards: [Card]
  }

  static let allCards: [Card] = {
    let data = cardJSON.data(using: .utf8)!
    do {
      return try JSONDecoder().decode(CardContainer.self, from: data).cards
    } catch {
      fatalError("Failed to decode LoD card JSON: \(error)")
    }
  }()

  static var dayCards: [Card] { allCards.filter { $0.deck == .day } }
  static var nightCards: [Card] { allCards.filter { $0.deck == .night } }
}
