//
//  State.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import ComposableArchitecture

extension CantStop: StatePredicates {
  typealias StatePredicate = (State) -> Bool // maybe one day a Predicate type
  
  // The pi type of the family, i.e. a type of sections of the family.
  // In that light, members like player: Player are maps from the unit type to Player.
  @ObservableState
  struct State: Equatable, Hashable, Sendable, GameState, CustomStringConvertible {
    typealias Player = CantStop.Player
    typealias Phase = CantStop.Phase
    typealias Piece = CantStop.Piece
    typealias Position = CantStop.Position
    typealias PiecePosition = CantStop.PiecePosition
    
    var name: String {
      "F My Luck"
    }
    // TODO: force-query w/ extension Dictionary { subscript(force key: Key) -> Value {} } like in https://stackoverflow.com/questions/59793783/force-swift-dictionary-to-return-a-non-optional-or-assert
    var position = [Piece: Position]()
    var dice = [Die: DSix]()
    var assignedDicePair: Column
    var player: Player
    var players: [Player] // which players are playing
    var ended = false
    var endedInVictory = false
    var endedInDefeat = false
    
    var description: String {
      ""
    }
    
    init() {
      assignedDicePair = Column.none
      player = Player.player1
      players = [.player1, .player2]
      for piece in Piece.allCases {
        switch piece {
        case let .placeholder(_, col):
          position[piece] = Position(col: col, row: 0)
        default:
          position[piece] = Position(col: .none, row: 0)
        }
      }
      for die in Die.allCases {
        dice[die] = DSix.none
      }
    }
    
    static func equiv(lhs: State, rhs: State) -> Bool {
      return
        lhs.ended                                ==  rhs.ended &&
        lhs.player                               ==  rhs.player &&
        lhs.players                              ==  rhs.players &&
        lhs.whitePositions                       ==  rhs.whitePositions &&
        lhs.placeholderPositions(for: .player1)  ==  rhs.placeholderPositions(for: .player1) &&
        lhs.placeholderPositions(for: .player2)  ==  rhs.placeholderPositions(for: .player2) &&
        lhs.placeholderPositions(for: .player3)  ==  rhs.placeholderPositions(for: .player3) &&
        lhs.placeholderPositions(for: .player4)  ==  rhs.placeholderPositions(for: .player4)
    }

    // MARK: - semantic queries
    
    var whitePositions: Set<Position> {
      Set(WhitePiece.allCases.map { position[Piece.white($0)]! })
    }
    
    func whiteIn(col: Column) -> Piece? {
      Piece.whitePieces.first(where: {position[$0]?.col == col} )
    }
    
    func placeholderPositions(for thePlayer: Player) -> Set<Position> {
      Set(Piece.placeholders(for: thePlayer).map { position[$0]! })
    }
    
    /// The player's high-water mark in a column
    func farthestAlong(in col: Column) -> Int {
      var whiteHeight = 0
      if let white = Piece.whitePieces.first(where: {position[$0]?.col == col}) {
        whiteHeight = position[white]?.row ?? 0
      }
      let placeholderHeight = position[Piece.placeholder(player, col)]?.row ?? 0
      return max(placeholderHeight, whiteHeight)
    }
    
    func rolledDice() -> [Die] {
      Die.allCases.filter { die in dice[die] != DSix.none}
    }
    
    func colIsWon(_ col: Column) -> Bool {
      return col != Column.none &&
        piecesAt([Position(col: col, row: colHeights()[col]!)]).anySatisfy({ piece in
          switch piece {
          case .placeholder:
            return true
          default:
            return false
          }
        }
        )
    }
    
    func wonCols() -> [Column] {
      Column.allCases.filter({ colIsWon($0)})
    }
    
    func winAchieved() -> Bool {
      let piecesAtTop = Set(piecesAt(columnTops()))
      return piecesAtTop.intersection(Piece.placeholders(for: player) + Piece.whitePieces).count >= 3
    }
    
    func piecesAt(_ spots: [Position]) -> [Piece] {
      return spots.flatMap { spot in
        Piece.allCases.filter {
          position[$0] == spot
        }
      }
    }
    
    var boardReport: [Column: [Piece]] {
      var report: [Column: [Piece]] = [:]
      for col in Column.allCases {
        report[col] = []
      }
      for piece in Piece.allCases {
        report[self.position[piece]!.col]!.append(piece)
      }
      return report
    }
    
    var diceReport: [Die: DSix] {
      var report: [Die: DSix] = [:]
      for die in Die.allCases {
        report[die] = dice[die]!
      }
      return report
    }

    // MARK: - mutating
    
    mutating func advancePlayer() {
      player = player.next()
      // advance until we get to the next player actually playing in this game
      while !players.contains(player) {
        player = player.next()
      }
    }
    
    mutating func clearWhite() {
      for white in Piece.whitePieces {
        position[white] = Position(col: .none, row: 0)
      }
    }
    
    mutating func clearDice() {
      for die in Die.allCases {
        dice[die] = DSix.none
      }
    }
    
    mutating func savePlace() {
      for col in Column.allCases {
        position[Piece.placeholder(player, col)] = Position(col: col, row: farthestAlong(in: col))
      }
      clearWhite()
    }
  }
}
