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
  struct State: Equatable {
    var position: [Piece: Position] = [:]
    var dice: [Die: DSix] = [:]
    var assignedDicePair = Column.none
    var player = Player.twop(.player1)
    var phase = Phase.notRolled
    
    var whitePositions: Set<Position> {
      Set(WhitePiece.allCases.map { position[Piece.white($0)]! })
    }
    
    var player1Positions: Set<Position> {
      Set(Player1Piece.allCases.map { position[Piece.p1($0)]! })
    }
    
    var player2Positions: Set<Position> {
      Set(Player2Piece.allCases.map { position[Piece.p2($0)]! })
    }
    
    var player3Positions: Set<Position> {
      Set(Player3Piece.allCases.map { position[Piece.p3($0)]! })
    }
    
    var player4Positions: Set<Position> {
      Set(Player4Piece.allCases.map { position[Piece.p4($0)]! })
    }
    
    static func ==(lhs: State, rhs: State) -> Bool {
      return lhs.dice == rhs.dice &&
      lhs.assignedDicePair == rhs.assignedDicePair &&
      lhs.player == rhs.player &&
      lhs.phase == rhs.phase &&
      lhs.whitePositions == rhs.whitePositions &&
      lhs.player1Positions == rhs.player1Positions &&
      lhs.player2Positions == rhs.player2Positions &&
      lhs.player3Positions == rhs.player3Positions &&
      lhs.player4Positions == rhs.player4Positions
    }
    
    init() {
      for piece in Piece.allCases {
        position[piece] = Position(col: .none, row: 0)
      }
      for die in Die.allCases {
        dice[die] = DSix.none
      }
      assignedDicePair = Column.none
      player = Player.twop(PlayerAmongTwo.player1)
      phase = Phase.notRolled
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
    
    mutating func advanceWhite(in col: Column) {
      let whites = [Piece.white(.white1), Piece.white(.white2), Piece.white(.white3)]
      var white = whites.first(where: {position[$0]?.col == col} )
      if white == nil {
        white = whites.first(where: {position[$0]?.col == Column.none})
      }
      let row = position[white!]?.row
      position[white!] = Position(col: col, row: row! + 1)
    }
    
    mutating func clearWhite() {
      for white in Piece.whitePieces {
        position[white] = Position(col: .none, row: 0)
      }
    }
    
    mutating func savePlace() {
      for white in [Piece.white(.white1), Piece.white(.white2), Piece.white(.white3)] {
        guard let whitePos = position[white] else { continue }
        guard whitePos.col != Column.none else { continue }
        
        let savingPiece: Piece = switch player {
        case let .twop(p):
          switch p {
          case .player1:
              .p1(Player1Piece(rawValue: whitePos.col.rawValue)!)
          case .player2:
              .p2(Player2Piece(rawValue: whitePos.col.rawValue)!)
          }
        case let .threep(p):
          switch p {
          case .player1:
              .p1(Player1Piece(rawValue: whitePos.col.rawValue)!)
          case .player2:
              .p2(Player2Piece(rawValue: whitePos.col.rawValue)!)
          case.player3:
              .p3(Player3Piece(rawValue: whitePos.col.rawValue)!)
          }
        case let .fourp(p):
          switch p {
          case .player1:
              .p1(Player1Piece(rawValue: whitePos.col.rawValue)!)
          case .player2:
              .p2(Player2Piece(rawValue: whitePos.col.rawValue)!)
          case.player3:
              .p3(Player3Piece(rawValue: whitePos.col.rawValue)!)
          case.player4:
              .p4(Player4Piece(rawValue: whitePos.col.rawValue)!)
          }
        }
        // move a colored piece to that spot
        position[savingPiece] = whitePos
        // move the white piece off the board
        position[white] = Position(col: .none, row: 0)
      }
    }
  }
  
  typealias StatePredicate = (State) -> Bool // maybe one day a Predicate type
  
  enum Situation: Hashable, Equatable {
    case whiteAtTop(Column)
    case claimed(Column)
    case diceBusted
    case won(Player)
  }
  
  static func situationSpecs() -> ((Situation) -> StatePredicate) { return { situation in
    switch situation {
    case .whiteAtTop(_):
      return { state in
        colHeights.contains(where: { (col, row) in
          state.piecesAt(Position(col: col, row: row)).allSatisfy({ $0 != Piece.white(.white1)})
        })
      }
    case .claimed(_):
      return { state in
        return colHeights.contains(where: { (col, row) in
          state.piecesAt(Position(col: col, row: row)).allSatisfy({
            $0 != Piece.p1(.p1p02) &&
            $0 != Piece.p2(.p2p02) &&
            $0 != Piece.p3(.p3p02) &&
            $0 != Piece.p4(.p4p02)
          })
        })
      }
    case .diceBusted:
      return { state in
        return false // TODO: implement
      }
    case .won(_):
      return { state in
        return false // TODO: implement
      }
    }
  }
  }
}
