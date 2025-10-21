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

enum WhitePiece: Int, CaseIterable, Hashable, Indistinguishable {
  case white1  = 1,  white2, white3
}

enum Player1Piece: Int, CaseIterable, Hashable, Indistinguishable {
  case p1p02 = 2, p1p03, p1p04, p1p05, p1p06, p1p07, p1p08, p1p09, p1p10, p1p11, p1p12
}

enum Player2Piece: Int, CaseIterable, Hashable, Indistinguishable {
  case p2p02 = 2, p2p03, p2p04, p2p05, p2p06, p2p07, p2p08, p2p09, p1p10, p2p11, p2p12
}

enum Player3Piece: Int, CaseIterable, Hashable, Indistinguishable {
  case p3p02 = 2, p3p03, p3p04, p3p05, p3p06, p3p07, p3p08, p3p09, p3p10, p3p11, p3p12
}

enum Player4Piece: Int, CaseIterable, Hashable, Indistinguishable {
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

func pairs<T>(of list: Array<T>) -> [Pair<T>] {
  var pairs = [Pair<T>]()
  let len = list.count
  for left in 0..<len {
    for right in left+1..<len {
      pairs.append(Pair<T>(fst: list[left], snd: list[right]))
    }
  }
  return pairs
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

struct CantStopView: View {
  let store: StoreOf<CantStop>
  
  var body: some View {
    Form {
      ForEach(Column.allCases, id: \.self) { col in
        if col != .none {
          ForEach(store.state.boardReport[col]!, id: \.self) { piece in
            let row = store.state.position[piece]!.row
            Text("\(col.name).\(row): \(piece.name)")
          }
        }
      }
      ForEach(Die.allCases, id: \.self) { die in
        let dieState = store.state.diceReport[die]!
        Text("\(die.name): \(dieState.name)")
      }
      ForEach(CantStop.allowedActions(state: store.state), id: \.self) { action in
        Button("\(action.name)") {
          store.send(action)
        }
      }
    }
  }
}

extension Array {
  static func uniques<T: Equatable>(_ input: Array<T>) -> Array<T> {
    var result = Array<T>()
    for val in input {
      if !result.contains(val) {
        result.append(val)
      }
    }
    return result
  }
}


#Preview("Can't Stop™®") {
  CantStopView(store: Store(initialState: CantStop.State()) {
    CantStop()
  })
}
