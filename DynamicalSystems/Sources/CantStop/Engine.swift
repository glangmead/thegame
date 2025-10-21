//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

import ComposableArchitecture
import Overture
import SwiftUI

protocol LookaheadReducer<State, Action>: Reducer {
  associatedtype Rule
  static func rules() -> [Rule]
  static func allowedActions(state: State) -> [Action]
}

@Reducer
struct CantStop: LookaheadReducer {
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
    
    mutating func savePlace() {
      for white in [Piece.white(.white1), Piece.white(.white2), Piece.white(.white3)] {
        let whitePos = Position(col: position[white]!.col, row: position[white]!.row)
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
  
  var situationSpecs: (Situation) -> StatePredicate = { situation in
    switch situation {
    case .whiteAtTop(let col):
      return { state in
        colHeights.contains(where: { (col, row) in
          state.piecesAt(Position(col: col, row: row)).allSatisfy({ $0 != Piece.white(.white1)})
        })
      }
    case .claimed(let col):
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
    case .won(let player):
      return { state in
        return false // TODO: implement
      }
    }
  }
  
  // the sigma type of the type family: pairs of (component, value)
  // The state will supply some context, such as who is performing the action
  enum Action: Hashable, Equatable {
    // the state of one piece
    case movePieceTo(PiecePosition)
    case advancePlayer
    
    // actions that are not updates of a component
    // But these could in fact be treated as such updates
    // The PhaseMarker is a piece, taking values in Phase.
    // There coudld be assignment boxes where two dice are placed.
    case pass
    case rollDice
    case assignDicePair(Pair<Die>)
    case progressColumn(Column)
    
    // recursive: ordered list of actions
    case sequence([Action])
    
    var name: String {
      switch self {
      case .movePieceTo(let ppos):
        return "\(ppos.name)"
      case .assignDicePair(let pair):
        return "\(pair.fst.name)/\(pair.snd.name)"
      case .sequence(let actions):
        let name = actions.map { $0.name }
          .joined(separator: " + ")
        return "(\(name))"
      case .progressColumn(let col):
        return "move \(col)"
      default:
        return String(describing: self)
      }
    }
  }
  
  struct ConditionalAction {
    let condition: StatePredicate
    let actions: (State) -> [Action]
    
    func append(_ second: ConditionalAction) -> ConditionalAction {
      return ConditionalAction(
        condition: self.condition, // to enter into this sequence, you just need the first condition to be met
        actions: pipe(
          { state in
            self.actions(state).flatMap { a1 in
              // advance the state by a1 to see if we can append any a2 to it
              var stateAfterA1 = state
              let _ = reduce(state: &stateAfterA1, action: a1)
              print(stateAfterA1.textDescription())
              if second.condition(stateAfterA1) {
                return
                  second.actions(stateAfterA1).map { a2 in
                    if a2 != a1 {
                      return Action.sequence([a1, a2])
                    } else {
                      return a1
                    }
                  }
                
              } else {
                return [a1]
              }
            }
          },
          Set.init, Array.init
        )
      )
    }
  }
  
  // the rules are captured by a set of ConditionalActions
  typealias Rule = ConditionalAction
  
  // Rule: State -> (Bool, [Action])
  // not a good name. the reducer is also rules
  // (State, Action) -> State
  static func rules() -> [Rule] {
    let rule1 = Rule(
      condition: { $0.phase == .notRolled },
      actions: { _ in [.rollDice, .pass] }
    )

    let rule2 = Rule(
      condition: { $0.phase == .rolled },
      actions: { state in
        // all pairs of rolled dice. dice with value .none have been assigned already
        let dicePairings: [Pair<Die>] = pairs(of: Die.allCases.filter { die in state.dice[die] != DSix.none})
        return dicePairings.compactMap { pairing in
          let col = twod6_total(pairing.map {state.dice[$0]!})
          let whiteCols = [Piece.white(.white1), Piece.white(.white2), Piece.white(.white3)].map { state.position[$0]!.col }
          if whiteCols.contains(col) || whiteCols.contains(.none) {
            return Action.sequence([.assignDicePair(pairing), .progressColumn(col)])
          }
          return nil
        }
      }
    )
    return [rule1, rule2.append(rule2)]
  }
    
  static func allowedActions(state: State) -> [Action] {
    CantStop.rules().flatMap { rule in
      if rule.condition(state) {
        return Array(Set(rule.actions(state)))
      } else {
        return [Action]()
      }
    }
  }
  
  static func reduce(state: inout State, action: Action) {
    switch action {
    case let .movePieceTo(ppos):
      state.position[ppos.piece] = ppos.position
    case .advancePlayer:
      state.player = state.player.nextPlayer()
      state.phase = .notRolled
    case .pass:
      state.savePlace()
      state.player = state.player.nextPlayer()
      state.phase = .notRolled
    case .rollDice:
      state.dice[.die1] = DSix.random()
      state.dice[.die2] = DSix.random()
      state.dice[.die3] = DSix.random()
      state.dice[.die4] = DSix.random()
      state.phase = .rolled
    case let .assignDicePair(pairing):
      // copy the resulting column to the assignedDicePair component
      state.assignedDicePair = CantStop.twod6_total(pairing.map { state.dice[$0]! })
      // erase/consume the values of these two dice
      for die in [pairing.fst, pairing.snd] {
        state.dice[die] = DSix.none
      }
    case let .progressColumn(col):
      state.advanceWhite(in: col)
      state.assignedDicePair = Column.none
      if Die.allCases.map({ state.dice[$0] }).allSatisfy({ $0 == DSix.none }) {
        state.phase = .notRolled
      }
    case let .sequence(actions):
      for action in actions {
        reduce(state: &state, action: action)
      }
    }
  }
  
  var body: some Reducer<State, Action> {
    Reduce { st, act in
      CantStop.reduce(state: &st, action: act)
      return .none
    }
  }
  
  static func twod6_total(_ dice: Pair<DSix>) -> Column {
    let col = Column(rawValue: dice.fst.rawValue + dice.snd.rawValue) ?? .none
    //print("\(dice.fst.name)/\(dice.fst.rawValue) + \(dice.snd.name)/\(dice.snd.rawValue) = \(col.name)")
    return col
  }
}

