//
//  Components.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import Foundation

enum Column: Int, CaseIterable, Equatable, Hashable, RawComparable {
  case none = 0
  case two = 2, three, four, five, six, seven, eight, nine, ten, eleven, twelve
  
  var name: String {
    String(describing: self)
  }
}

let colHeights: [Column: Int] = [
  .two:   3,  .three: 5, .four: 7, .five:   9, .six:    11, .seven: 13,
  .eight: 11, .nine:  9, .ten:  7, .eleven: 5, .twelve: 3,
]

enum WhitePiece: Int, CaseIterable, Hashable {
  case white1  = 1,  white2, white3
}

enum Player1Piece: Int, CaseIterable, Hashable {
  case p1p02 = 2, p1p03, p1p04, p1p05, p1p06, p1p07, p1p08, p1p09, p1p10, p1p11, p1p12
}

enum Player2Piece: Int, CaseIterable, Hashable {
  case p2p02 = 2, p2p03, p2p04, p2p05, p2p06, p2p07, p2p08, p2p09, p1p10, p2p11, p2p12
}

enum Player3Piece: Int, CaseIterable, Hashable {
  case p3p02 = 2, p3p03, p3p04, p3p05, p3p06, p3p07, p3p08, p3p09, p3p10, p3p11, p3p12
}

enum Player4Piece: Int, CaseIterable, Hashable {
  case p4p02 = 2, p4p03, p4p04, p4p05, p4p06, p4p07, p4p08, p4p09, p4p10, p4p11, p4p12
}

enum Piece: CaseIterable, Equatable, Hashable {
  case none
  case white(WhitePiece)
  case p1(Player1Piece)
  case p2(Player2Piece)
  case p3(Player3Piece)
  case p4(Player4Piece)
  
  func isWhite() -> Bool {
    switch self {
    case .white(_):
      return true
    default:
      return false
    }
  }
  
  func isPlayer1() -> Bool {
    switch self {
    case .p1(_):
      return true
    default:
      return false
    }
  }
  
  func isPlayer2() -> Bool {
    switch self {
    case .p2(_):
      return true
    default:
      return false
    }
  }
  
  func isPlayer3() -> Bool {
    switch self {
    case .p3(_):
      return true
    default:
      return false
    }
  }
  
  func isPlayer4() -> Bool {
    switch self {
    case .p4(_):
      return true
    default:
      return false
    }
  }
  
  static var allCases: [Piece] {
    return [Piece.none]
    + WhitePiece.allCases.map { Piece.white($0) }
    + Player1Piece.allCases.map { Piece.p1($0) }
    + Player2Piece.allCases.map { Piece.p2($0) }
    + Player3Piece.allCases.map { Piece.p3($0) }
    + Player4Piece.allCases.map { Piece.p4($0) }
  }
  
  var name: String {
    String(describing: self)
  }
}

enum DSix: Int, CaseIterable, Equatable, Hashable, RawComparable {
  case none = 0, one = 1, two, three, four, five, six
  
  static func random() -> DSix {
    return DSix.allCases.filter { $0 != .none}.randomElement()!
  }
  
  var name: String {
    String(describing: self)
  }
}

enum Die: Int, CaseIterable, Equatable, Hashable, RawComparable {
  case die1 = 1, die2, die3, die4
  var name: String {
    String(describing: self)
  }
}

struct Position: Hashable, Equatable {
  let col: Column
  let row: Int
  var name: String {
    "\(col.name)\(row)"
  }
}

struct PiecePosition: Hashable, Equatable {
  var piece: Piece
  var position: Position
  var name: String {
    "\(piece.name): \(position.name)"
  }
}

struct DieValue: Hashable, Equatable {
  var die: Die
  var value: DSix
  var name: String {
    "\(die.name): \(value.name)"
  }
}

enum PlayerAmongTwo: Int, Hashable, Equatable {
  case player1 = 10
  case player2 = 30
  var name: String {
    switch self {
    case .player1:
      return "P1"
    case .player2:
      return "P2"
    }
  }
}

enum PlayerAmongThree: Int, Hashable, Equatable {
  case player1 = 10
  case player2 = 30
  case player3 = 50
  var name: String {
    switch self {
    case .player1:
      return "P1"
    case .player2:
      return "P2"
    case .player3:
      return "P3"
    }
  }
}

enum PlayerAmongFour: Int, Hashable, Equatable {
  case player1 = 10
  case player2 = 30
  case player3 = 50
  case player4 = 70
  var name: String {
    switch self {
    case .player1:
      return "P1"
    case .player2:
      return "P2"
    case .player3:
      return "P3"
    case .player4:
      return "P4"
    }
  }
}

enum Player: Hashable, Equatable {
  case twop(PlayerAmongTwo)
  case threep(PlayerAmongThree)
  case fourp(PlayerAmongFour)
  
  func nextPlayer() -> Player {
    switch self {
    case let .twop(p):
      switch p {
      case .player1:
        return .twop(.player2)
      case .player2:
        return .twop(.player1)
      }
    case let .threep(p):
      switch p {
      case .player1:
        return .threep(.player2)
      case .player2:
        return .threep(.player3)
      case .player3:
        return .threep(.player1)
      }
    case let .fourp(p):
      switch p {
      case .player1:
        return .fourp(.player2)
      case .player2:
        return .fourp(.player3)
      case .player3:
        return .fourp(.player4)
      case .player4:
        return .fourp(.player1)
      }
    }
  }
}

enum Phase: Hashable, Equatable {
  case notRolled
  case rolled
  var name: String {
    return String(describing: self)
  }
}

// the base space of game components
enum Component: Hashable, Equatable {
  case piece(Piece)
  case die(Die)
  case player
  case phase
  var name: String {
    return String(describing: self)
  }
}

