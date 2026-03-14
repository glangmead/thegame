//
//  HeartsAction.swift
//  DynamicalSystems
//
//  Hearts — Action enum. Random values (deck shuffle) are packed into
//  the action for deterministic replay.
//

import Foundation

extension Hearts {
  // Note: Action cannot auto-derive Hashable because startNewHand
  // contains an Array payload used only for deterministic replay.
  // Manual conformance treats that case as identity-equal.
  enum Action: CustomStringConvertible {
    // Passing phase
    case selectPassCard(Card)
    case confirmPass

    // Playing phase
    case playCard(Card)

    // Trick resolution
    case resolveTrick

    // Hand end
    case scoreHand
    case startNewHand(shuffledDeck: [Card])

    // Game end
    case declareWinner

    var description: String {
      switch self {
      case .selectPassCard(let card):
        "Select \(card) to pass"
      case .confirmPass:
        "Confirm pass"
      case .playCard(let card):
        "Play \(card)"
      case .resolveTrick:
        "Resolve trick"
      case .scoreHand:
        "Score hand"
      case .startNewHand:
        "Deal new hand"
      case .declareWinner:
        "Declare winner"
      }
    }
  }
}

extension Hearts.Action: Equatable {
  static func == (lhs: Hearts.Action, rhs: Hearts.Action) -> Bool {
    switch (lhs, rhs) {
    case (.selectPassCard(let lCard), .selectPassCard(let rCard)): return lCard == rCard
    case (.confirmPass, .confirmPass): return true
    case (.playCard(let lCard), .playCard(let rCard)): return lCard == rCard
    case (.resolveTrick, .resolveTrick): return true
    case (.scoreHand, .scoreHand): return true
    case (.startNewHand, .startNewHand): return true
    case (.declareWinner, .declareWinner): return true
    default: return false
    }
  }
}

extension Hearts.Action: Hashable {
  func hash(into hasher: inout Hasher) {
    switch self {
    case .selectPassCard(let card):
      hasher.combine(0)
      hasher.combine(card)
    case .confirmPass:
      hasher.combine(1)
    case .playCard(let card):
      hasher.combine(2)
      hasher.combine(card)
    case .resolveTrick:
      hasher.combine(3)
    case .scoreHand:
      hasher.combine(4)
    case .startNewHand:
      hasher.combine(5)
    case .declareWinner:
      hasher.combine(6)
    }
  }
}
