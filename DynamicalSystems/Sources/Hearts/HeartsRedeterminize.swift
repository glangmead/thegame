//
//  HeartsRedeterminize.swift
//  DynamicalSystems
//
//  Hearts — Information-set MCTS redeterminization with void constraints.
//

import Foundation

// MARK: - Redeterminize (information-set MCTS)

extension Hearts.State {
  func redeterminize() -> Self {
    var rng = SystemRandomNumberGenerator()
    return redeterminize(using: &rng)
  }

  func redeterminize(using generator: inout some RandomNumberGenerator) -> Self {
    guard let humanSeat = config.humanSeat else { return self }

    let opponentSeats = Hearts.Seat.allCases.filter { $0 != humanSeat }
    let opponentCardCount = opponentSeats.reduce(0) { $0 + (hands[$1]?.count ?? 0) }
    guard opponentCardCount > 1 else { return self }

    let voids = computeVoidConstraints(humanSeat: humanSeat)

    var pool = opponentSeats.flatMap { hands[$0] ?? [] }
    let counts = Dictionary(uniqueKeysWithValues: opponentSeats.map { ($0, hands[$0]?.count ?? 0) })

    for _ in 0..<100 {
      pool.shuffle(using: &generator)

      var candidate: [Hearts.Seat: [Hearts.Card]] = [:]
      var offset = 0
      var valid = true
      for seat in opponentSeats {
        let count = counts[seat]!
        let cards = Array(pool[offset..<(offset + count)])
        if let seatVoids = voids[seat] {
          if cards.contains(where: { seatVoids.contains($0.suit) }) {
            valid = false
            break
          }
        }
        candidate[seat] = cards
        offset += count
      }

      if valid {
        var copy = self
        for seat in opponentSeats {
          copy.hands[seat] = candidate[seat]?.sorted()
        }
        copy.syncPositions()
        return copy
      }
    }

    return self
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func computeVoidConstraints(
    humanSeat: Hearts.Seat
  ) -> [Hearts.Seat: Set<Hearts.Card.Suit>] {
    // Find current hand's start in history
    let handStartIndex: Int
    if let lastNewHand = history.lastIndex(where: {
      if case .startNewHand = $0 { return true }
      return false
    }) {
      handStartIndex = lastNewHand + 1
    } else {
      handStartIndex = 0
    }

    // Extract playCard actions from the current hand
    let playedCards: [Hearts.Card] = history[handStartIndex...].compactMap {
      if case .playCard(let card) = $0 { return card }
      return nil
    }

    // Group into completed tricks of 4
    var completedTricks: [[Hearts.Card]] = []
    var idx = 0
    while idx + 4 <= playedCards.count {
      completedTricks.append(Array(playedCards[idx..<(idx + 4)]))
      idx += 4
    }

    var voids: [Hearts.Seat: Set<Hearts.Card.Suit>] = [:]

    // Backward-trace trick leaders from the current trick leader
    var nextTrickLeader = trickLeader
    for trick in completedTricks.reversed() {
      let ledSuit = trick[0].suit
      // Find winning index: position of highest card matching led suit
      var winningIndex = 0
      for (pos, card) in trick.enumerated() where card.suit == ledSuit {
        if card.rank > trick[winningIndex].rank || trick[winningIndex].suit != ledSuit {
          winningIndex = pos
        }
      }
      // winner = leader.offset(by: winningIndex) = nextTrickLeader
      // so leader = nextTrickLeader.offset(by: -winningIndex)
      let leader = nextTrickLeader.offset(by: -winningIndex)

      for cardIndex in 1..<4 {
        let follower = leader.offset(by: cardIndex)
        if follower != humanSeat && trick[cardIndex].suit != ledSuit {
          voids[follower, default: []].insert(ledSuit)
        }
      }

      nextTrickLeader = leader
    }

    // Handle in-progress trick
    if !currentTrick.isEmpty {
      let ledSuit = currentTrick[0].card.suit
      for play in currentTrick.dropFirst() {
        if play.seat != humanSeat && play.card.suit != ledSuit {
          voids[play.seat, default: []].insert(ledSuit)
        }
      }
    }

    return voids
  }
}
