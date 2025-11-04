//
//  Components.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import Foundation
import Gen

extension CantStop: GameComponents {
  
  /// Components and players
  ///
  enum Player: Hashable, Equatable, CaseIterable, Cyclic {
    case player1, player2, player3, player4
    
    var name: String {
      switch self {
      case .player1:
        return "Player 1"
      case .player2:
        return "Player 2"
      case .player3:
        return "Player 3"
      case .player4:
        return "Player 4"
      }
    }
    
    func next() -> Player {
      switch self {
      case .player1:
        return .player2
      case .player2:
        return .player3
      case .player3:
        return .player4
      case .player4:
        return .player1
      }
    }
  }
  
  enum WhitePiece: Int, CaseIterable, Hashable {
    case white1  = 1,  white2, white3
  }
  
  enum Piece: CaseIterable, Equatable, Hashable {
    case none
    case white(WhitePiece)
    case placeholder(Player, Column)
    
    // all the associated values of a particular case
    static var whitePieces: [Piece] { WhitePiece.allCases.map{ Piece.white($0) } }
    
    static func placeholders(for player: Player) -> [Piece] {
      return Column.allCases.map { return .placeholder(player, $0) }
    }
    
    static var allCases: [Piece] {
      return [Piece.none]
      + WhitePiece.allCases.map { Piece.white($0) }
      + Player.allCases.flatMap { placeholders(for: $0) }
    }
    
    var name: String {
      switch self {
      case .white(let w):
        String(describing: w)
      case let .placeholder(player, _):
        "\(player.name)" // omit col because it's visible elsewhere
      default:
        String(describing: self)
      }
    }
  }
  
  enum Die: Int, CaseIterable, Equatable, Hashable, RawComparable {
    case die1 = 1, die2, die3, die4
    var name: String {
      String(describing: self)
    }
  }
  
  /// Board positions/spaces/values (including values of singletons such as "the phase")
  ///
  enum Column: Int, CaseIterable, Equatable, Hashable, RawComparable {
    case none = 0
    case two = 2, three, four, five, six, seven, eight, nine, ten, eleven, twelve
    
    var name: String {
      String(describing: self)
    }
  }
  
//  static func colHeights() -> [Column: Int] {
//    [.two:   2,  .three: 2, .four: 2, .five:   2, .six:    2, .seven: 2,
//      .eight: 2, .nine:  2, .ten:  2, .eleven: 2, .twelve: 2,]
//  }
  
  static func colHeights() -> [Column: Int] {
    [.two:   3,  .three: 5, .four: 7, .five:   9, .six:    11, .seven: 13,
     .eight: 11, .nine:  9, .ten:  7, .eleven: 5, .twelve: 3,]
  }
  
  struct Position: Hashable, Equatable {
    var col: Column
    var row: Int
    var name: String {
      "\(col.name)\(row)"
    }
  }
  
  static func columnTops() -> [Position] {
    Column.allCases.filter({$0 != Column.none}).map { col in Position(col: col, row: colHeights()[col] ?? 0) }
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
  
  enum Phase: Hashable, Equatable, Cyclic {
    case notRolled
    case rolled
    var name: String {
      return String(describing: self)
    }
    func next() -> Phase {
      switch self {
      case .notRolled:
        return .rolled
      case .rolled:
        return .notRolled
      }
    }
  }
}

