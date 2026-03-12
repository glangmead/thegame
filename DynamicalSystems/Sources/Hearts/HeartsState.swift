//
//  HeartsState.swift
//  DynamicalSystems
//
//  Hearts — Game state: hands, tricks, scores, legal plays, passing, scoring.
//

import Foundation

extension Hearts {
  struct State: HistoryTracking, GameState, Equatable, Sendable {
    // swiftlint:disable nesting
    // GameComponents typealiases (required for GameState conformance)
    typealias Player = Hearts.Seat
    typealias Phase = Hearts.Phase
    typealias Piece = Hearts.Card
    typealias Position = Hearts.CardPosition
    typealias PiecePosition = Hearts.CardPosition
    // swiftlint:enable nesting

    // GameState
    var name = "Hearts"
    var player: Seat
    var players: [Seat] = Seat.allCases
    var ended = false
    var endedInVictoryFor: [Seat] = []
    var endedInDefeatFor: [Seat] = []
    var position: [Card: CardPosition] = [:]

    // HistoryTracking
    var history: [Action] = []
    var phase: Phase

    // Game-specific
    var hands: [Seat: [Card]]
    var currentTrick: [TrickPlay]
    var trickLeader: Seat
    var heartsBroken: Bool
    var gameAcknowledged: Bool
    var passingState: PassingState?
    var tricksTaken: [Seat: [[Card]]]
    var handPenalties: [Seat: Int]
    var cumulativeScores: [Seat: Int]
    var handNumber: Int
    var turnNumber: Int
    var config: HeartsConfig

    // swiftlint:disable:next nesting
    struct PassingState: Equatable, Sendable {
      var selected: [Card] = []
      var direction: PassDirection
    }
  }
}

// MARK: - Derived Properties

extension Hearts.State {
  var passDirection: Hearts.PassDirection {
    Hearts.PassDirection.forHand(handNumber)
  }

  var isTerminal: Bool {
    ended && gameAcknowledged
  }

  var holderOfTwoOfClubs: Hearts.Seat {
    for seat in Hearts.Seat.allCases where hands[seat]?.contains(Hearts.twoOfClubs) == true {
      return seat
    }
    return .south
  }
}

// MARK: - Setup

extension Hearts.State {
  static func newGame(
    config: Hearts.HeartsConfig = Hearts.HeartsConfig(),
    shuffledDeck: [Hearts.Card]
  ) -> Hearts.State {
    var state = Hearts.State(
      player: .south,
      phase: .passing,
      hands: Dictionary(uniqueKeysWithValues: Hearts.Seat.allCases.map { ($0, [Hearts.Card]()) }),
      currentTrick: [],
      trickLeader: .south,
      heartsBroken: false,
      gameAcknowledged: false,
      tricksTaken: Dictionary(uniqueKeysWithValues: Hearts.Seat.allCases.map { ($0, [[Hearts.Card]]()) }),
      handPenalties: Dictionary(uniqueKeysWithValues: Hearts.Seat.allCases.map { ($0, 0) }),
      cumulativeScores: Dictionary(uniqueKeysWithValues: Hearts.Seat.allCases.map { ($0, 0) }),
      handNumber: 0,
      turnNumber: 0,
      config: config
    )
    state.deal(from: shuffledDeck)

    let passDir = Hearts.PassDirection.forHand(0)
    if passDir != .none {
      state.phase = .passing
      state.passingState = Hearts.State.PassingState(direction: passDir)
    } else {
      state.phase = .playing
      state.player = state.holderOfTwoOfClubs
      state.turnNumber = 1
    }
    return state
  }

  mutating func deal(from shuffledDeck: [Hearts.Card]) {
    for (index, card) in shuffledDeck.prefix(52).enumerated() {
      let seat = Hearts.Seat(rawValue: index % 4)!
      hands[seat, default: []].append(card)
    }
    for seat in Hearts.Seat.allCases {
      hands[seat]?.sort()
    }
    syncPositions()
  }

  mutating func syncPositions() {
    position.removeAll()
    for seat in Hearts.Seat.allCases {
      for card in hands[seat] ?? [] {
        position[card] = .inHand(seat)
      }
    }
    for (index, play) in currentTrick.enumerated() {
      position[play.card] = .inTrick(seatIndex: index)
    }
    for seat in Hearts.Seat.allCases {
      for trick in tricksTaken[seat] ?? [] {
        for card in trick {
          position[card] = .inWonPile(seat)
        }
      }
    }
  }
}

// MARK: - Legal Plays

extension Hearts.State {
  var legalPlays: [Hearts.Card] {
    guard let hand = hands[player], !hand.isEmpty else { return [] }

    // First trick of the hand, leading: must play 2♣
    if turnNumber == 1 && currentTrick.isEmpty {
      return [Hearts.twoOfClubs]
    }

    if currentTrick.isEmpty {
      return legalLeads(hand: hand)
    } else {
      return legalFollows(hand: hand)
    }
  }

  private func legalLeads(hand: [Hearts.Card]) -> [Hearts.Card] {
    if heartsBroken { return hand }
    let nonHearts = hand.filter { $0.suit != .hearts }
    return nonHearts.isEmpty ? hand : nonHearts
  }

  private func legalFollows(hand: [Hearts.Card]) -> [Hearts.Card] {
    let ledSuit = currentTrick[0].card.suit
    let inSuit = hand.filter { $0.suit == ledSuit }
    if !inSuit.isEmpty { return inSuit }

    // Void in led suit — can play anything
    // Exception: first trick, can't play penalty cards unless hand is only penalty cards
    if turnNumber == 1 {
      let nonPenalty = hand.filter { !Hearts.isPenaltyCard($0) }
      return nonPenalty.isEmpty ? hand : nonPenalty
    }
    return hand
  }
}

// MARK: - Trick Resolution

extension Hearts.State {
  var trickWinner: Hearts.Seat? {
    guard currentTrick.count == 4 else { return nil }
    let ledSuit = currentTrick[0].card.suit
    return currentTrick
      .filter { $0.card.suit == ledSuit }
      .max(by: { $0.card.rank < $1.card.rank })?
      .seat
  }

  mutating func resolveTrick() {
    guard let winner = trickWinner else { return }
    let cards = currentTrick.map(\.card)
    tricksTaken[winner, default: []].append(cards)

    if !heartsBroken {
      if currentTrick.contains(where: { Hearts.isPenaltyCard($0.card) }) {
        heartsBroken = true
      }
    }

    currentTrick.removeAll()
    trickLeader = winner
    player = winner
    turnNumber += 1
    syncPositions()
  }
}

// MARK: - Passing

extension Hearts.State {
  mutating func executePasses(
    humanCards: [Hearts.Card],
    aiPasses: [Hearts.Seat: [Hearts.Card]]
  ) {
    let direction = passingState?.direction ?? passDirection

    var allPasses: [Hearts.Seat: [Hearts.Card]] = aiPasses
    if let humanSeat = config.humanSeat {
      allPasses[humanSeat] = humanCards
    }
    // Auto-fill any seat still missing (e.g. during MCTS simulation)
    for seat in Hearts.Seat.allCases where allPasses[seat] == nil {
      allPasses[seat] = Array(hands[seat]?.prefix(3) ?? [])
    }

    let offset: Int
    switch direction {
    case .left: offset = 1
    case .right: offset = 3
    case .across: offset = 2
    case .none: return
    }

    var incoming: [Hearts.Seat: [Hearts.Card]] = [:]
    for seat in Hearts.Seat.allCases {
      let recipient = seat.offset(by: offset)
      incoming[recipient] = allPasses[seat]
    }

    for seat in Hearts.Seat.allCases {
      let passed = allPasses[seat] ?? []
      hands[seat]?.removeAll(where: { passed.contains($0) })
      hands[seat]?.append(contentsOf: incoming[seat] ?? [])
      hands[seat]?.sort()
    }

    passingState = nil
    player = holderOfTwoOfClubs
    phase = .playing
    turnNumber = 1
    syncPositions()
  }
}

// MARK: - Scoring

extension Hearts.State {
  func isShootingTheMoon(seat: Hearts.Seat) -> Bool {
    let wonCards = (tricksTaken[seat] ?? []).flatMap { $0 }
    let heartCount = wonCards.filter { $0.suit == .hearts }.count
    let hasQueenOfSpades = wonCards.contains(Hearts.queenOfSpades)
    return heartCount == 13 && hasQueenOfSpades
  }

  mutating func scoreCurrentHand() {
    for seat in Hearts.Seat.allCases {
      let wonCards = (tricksTaken[seat] ?? []).flatMap { $0 }
      var penalty = wonCards.reduce(0) { $0 + Hearts.penaltyPoints(for: $1) }
      if wonCards.contains(Hearts.jackOfDiamonds) {
        penalty -= 10
      }
      handPenalties[seat] = penalty
    }

    // Shooting the moon (Old Moon)
    for seat in Hearts.Seat.allCases where isShootingTheMoon(seat: seat) {
      handPenalties[seat] = 0
      for other in Hearts.Seat.allCases where other != seat {
        handPenalties[other] = 26
      }
      break
    }

    for seat in Hearts.Seat.allCases {
      cumulativeScores[seat, default: 0] += handPenalties[seat, default: 0]
    }

    let maxScore = cumulativeScores.values.max() ?? 0
    if maxScore >= config.scoreLimit {
      ended = true
      let minScore = cumulativeScores.values.min() ?? 0
      for seat in Hearts.Seat.allCases {
        if cumulativeScores[seat] == minScore {
          endedInVictoryFor.append(seat)
        } else {
          endedInDefeatFor.append(seat)
        }
      }
      phase = .gameEnd
    }
  }

  mutating func startNewHand(shuffledDeck: [Hearts.Card]) {
    handNumber += 1
    turnNumber = 0
    heartsBroken = false
    currentTrick.removeAll()
    for seat in Hearts.Seat.allCases {
      hands[seat] = []
      tricksTaken[seat] = []
      handPenalties[seat] = 0
    }
    deal(from: shuffledDeck)
    passingState = nil

    let passDir = Hearts.PassDirection.forHand(handNumber)
    if passDir != .none {
      phase = .passing
      player = config.humanSeat ?? .south
      passingState = PassingState(direction: passDir)
    } else {
      phase = .playing
      player = holderOfTwoOfClubs
      turnNumber = 1
    }
  }
}

// MARK: - CustomStringConvertible

extension Hearts.State: CustomStringConvertible {
  var description: String {
    var lines: [String] = []
    lines.append("═══ Hearts: Hand \(handNumber + 1) / Trick \(turnNumber) ═══")
    lines.append(
      "Pass: \(passDirection) | Hearts: \(heartsBroken ? "broken" : "unbroken")")
    lines.append("")
    for seat in Hearts.Seat.allCases {
      let hand = hands[seat] ?? []
      let isHuman = seat == config.humanSeat
      let label = isHuman ? "(You)" : "(AI)"
      let cards = isHuman
        ? hand.map(\.description).joined(separator: " ")
        : "[\(hand.count) cards]"
      lines.append("  \(seat) \(label): \(cards)")
    }
    lines.append("")
    if !currentTrick.isEmpty {
      let trickStr = currentTrick
        .map { "\($0.seat)→\($0.card)" }
        .joined(separator: "  ")
      lines.append("  Trick: \(trickStr)")
    }
    lines.append("")
    let scoreStr = Hearts.Seat.allCases.map {
      "\($0.description.prefix(1)):\(cumulativeScores[$0] ?? 0)"
    }.joined(separator: "  ")
    lines.append("  Scores:  \(scoreStr)")
    return lines.joined(separator: "\n")
  }
}
