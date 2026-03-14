//
//  HeartsComponents.swift
//  DynamicalSystems
//
//  Hearts — Component definitions: seats, cards, phases, config.
//

import Foundation

typealias Hearts = HeartsComponents

struct HeartsComponents: GameComponents {
  typealias Piece = Card
  typealias PiecePosition = CardPosition
  typealias Player = Seat
  typealias Position = CardPosition

  // MARK: - Seat

  enum Seat: Int, CaseIterable, Hashable, Sendable, CustomStringConvertible {
    case north = 0, east, south, west

    var next: Seat { Seat(rawValue: (rawValue + 1) % 4)! }

    func offset(by seats: Int) -> Seat {
      Seat(rawValue: ((rawValue + seats) % 4 + 4) % 4)!
    }

    var description: String {
      switch self {
      case .north: "North"
      case .east: "East"
      case .south: "South"
      case .west: "West"
      }
    }
  }

  // MARK: - Card

  struct Card: Hashable, Comparable, Sendable, CustomStringConvertible {
    // swiftlint:disable:next nesting
    enum Suit: Int, CaseIterable, RawComparable, Sendable {
      case clubs, diamonds, spades, hearts

      var symbol: String {
        switch self {
        case .clubs: "♣️"
        case .diamonds: "♦️"
        case .spades: "♠️"
        case .hearts: "❤️"
        }
      }

      var isRed: Bool {
        self == .diamonds || self == .hearts
      }
    }

    // swiftlint:disable:next nesting
    enum Rank: Int, CaseIterable, RawComparable, Sendable {
      case two = 2, three, four, five, six, seven, eight, nine, ten
      case jack, queen, king, ace

      var symbol: String {
        switch self {
        case .two: "2"
        case .three: "3"
        case .four: "4"
        case .five: "5"
        case .six: "6"
        case .seven: "7"
        case .eight: "8"
        case .nine: "9"
        case .ten: "10"
        case .jack: "J"
        case .queen: "Q"
        case .king: "K"
        case .ace: "A"
        }
      }
    }

    let suit: Suit
    let rank: Rank

    static func < (lhs: Card, rhs: Card) -> Bool {
      if lhs.suit != rhs.suit { return lhs.suit < rhs.suit }
      return lhs.rank < rhs.rank
    }

    var description: String { "\(rank.symbol)\(suit.symbol)" }
  }

  // MARK: - TrickPlay

  struct TrickPlay: Equatable, Hashable, Sendable {
    let seat: Seat
    let card: Card
  }

  // MARK: - PassDirection

  enum PassDirection: Sendable, Equatable, CustomStringConvertible {
    case left, right, across, none

    static func forHand(_ handNumber: Int) -> PassDirection {
      switch handNumber % 4 {
      case 0: .left
      case 1: .right
      case 2: .across
      default: .none
      }
    }

    var description: String {
      switch self {
      case .left: "Left"
      case .right: "Right"
      case .across: "Across"
      case .none: "Hold"
      }
    }
  }

  // MARK: - Phase

  enum Phase: String, Hashable, Sendable {
    case passing, playing, trickResolution, handEnd, gameEnd
  }

  // MARK: - CardPosition

  enum CardPosition: Hashable, Sendable {
    case inHand(Seat)
    case inTrick(seatIndex: Int)
    case inWonPile(Seat)
    case inDeck
  }

  // MARK: - Config

  struct HeartsConfig: Equatable, Sendable {
    var playerModes: [Seat: PlayerMode] = [
      .north: .fastAI,
      .east: .fastAI,
      .south: .interactive,
      .west: .fastAI
    ]
    var scoreLimit: Int = 100

    var humanSeat: Seat? {
      playerModes.first(where: { $0.value == .interactive })?.key
    }
  }

  // MARK: - Constants

  static let fullDeck: [Card] = Card.Suit.allCases.flatMap { suit in
    Card.Rank.allCases.map { rank in Card(suit: suit, rank: rank) }
  }

  static let twoOfClubs = Card(suit: .clubs, rank: .two)
  static let queenOfSpades = Card(suit: .spades, rank: .queen)
  static let jackOfDiamonds = Card(suit: .diamonds, rank: .jack)

  static func penaltyPoints(for card: Card) -> Int {
    if card.suit == .hearts { return 1 }
    if card == queenOfSpades { return 13 }
    return 0
  }

  static func isPenaltyCard(_ card: Card) -> Bool {
    card.suit == .hearts || card == queenOfSpades
  }
}
