//
//  State.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import ComposableArchitecture

extension CantStop {
  // the pi type of the family, i.e. a type of sections of the family
  // I could go farther here, having slots on the board for the assignment of dice, and even slots on the board for a dice roll, where the die becomes just a featureless token occupying a "Four" space.
  // Similarly the player and phase could be marked with tokens.
  @ObservableState
  struct State: Equatable, Sendable {
    var position = [Piece: Position]() // TODO: use extension Dictionary { subscript(force key: Key) -> Value {} } like in https://stackoverflow.com/questions/59793783/force-swift-dictionary-to-return-a-non-optional-or-assert
    var dice = [Die: DSix]()
    var assignedDicePair: Column
    var player: Player
    var players: [Player] // which players are playing
    var phase: Phase
    
    var whitePositions: Set<Position> {
      Set(WhitePiece.allCases.map { position[Piece.white($0)]! })
    }
    
    func placeholderPositions(for thePlayer: Player) -> Set<Position> {
      Set(Piece.placeholders(for: thePlayer).map { position[$0]! })
    }
    
    var piecesAtTop: Set<Piece> {
      Set(columnTops.flatMap { piecesAt($0) })
    }
    
    mutating func advancePlayer() {
      player = player.next()
      // advance until we get to the next player actually playing in this game
      while !players.contains(player) {
        player = player.next()
      }
      phase = .notRolled
    }
    
    static func ==(lhs: State, rhs: State) -> Bool {
      return
        lhs.dice                                 ==  rhs.dice &&
        lhs.assignedDicePair                     ==  rhs.assignedDicePair &&
        lhs.player                               ==  rhs.player &&
        lhs.players                              ==  rhs.players &&
        lhs.phase                                ==  rhs.phase &&
        lhs.whitePositions                       ==  rhs.whitePositions &&
        lhs.placeholderPositions(for: .player1)  ==  rhs.placeholderPositions(for: .player1) &&
        lhs.placeholderPositions(for: .player2)  ==  rhs.placeholderPositions(for: .player2) &&
        lhs.placeholderPositions(for: .player3)  ==  rhs.placeholderPositions(for: .player3) &&
        lhs.placeholderPositions(for: .player4)  ==  rhs.placeholderPositions(for: .player4)
    }
    
    init() {
      assignedDicePair = Column.none
      player = Player.player1
      phase = Phase.notRolled
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
    
    func win() -> Bool {
      let piecesAtTop = piecesAtTop
      let p1wins = piecesAtTop.intersection(Piece.placeholders(for: .player1)).count >= 3
      let p2wins = piecesAtTop.intersection(Piece.placeholders(for: .player2)).count >= 3
      let p3wins = piecesAtTop.intersection(Piece.placeholders(for: .player3)).count >= 3
      let p4wins = piecesAtTop.intersection(Piece.placeholders(for: .player4)).count >= 3
      return p1wins || p2wins || p3wins || p4wins
    }
    
    func textDescription() -> String {
      let dr = diceReport
      //      let br = boardReport
      var result = "Dice: "
      for die in Die.allCases {
        result += "\(die.name)=\(dr[die]!.name) "
      }
      return result
    }
    
    func piecesAt(_ spot: Position) -> [Piece] {
      return Piece.allCases.filter {
        position[$0] == spot
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

    // semantic positions
    func farthestAlong(for thePlayer: Player, in col: Column) -> Int {
      var whiteHeight = 0
      if let white = Piece.whitePieces.first(where: {position[$0]?.col == col}) {
        whiteHeight = position[white]?.row ?? 0
      }
      let placeholderHeight = position[Piece.placeholder(thePlayer, col)]?.row ?? 0
      return max(placeholderHeight, whiteHeight)
    }
        
    // composite action?
    mutating func clearWhite() {
      for white in Piece.whitePieces {
        position[white] = Position(col: .none, row: 0)
      }
    }
    
    // composite action?
    mutating func savePlace() {
      for white in Piece.whitePieces {
        guard let whitePos = position[white] else { continue }
        guard whitePos.col != Column.none else { continue }
        
        let savingPiece: Piece = Piece.placeholder(player, whitePos.col)
        // move a colored piece to that spot
        position[savingPiece] = whitePos
        // move the white piece off the board
        position[white] = Position(col: .none, row: 0)
        
        for die in Die.allCases {
          dice[die] = DSix.none
        }
      }
    }
  }
  
  typealias StatePredicate = (State) -> Bool // maybe one day a Predicate type
  
}
