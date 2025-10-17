//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

import ComposableArchitecture
import SwiftUI

protocol LookaheadReducer<State, Action>: Reducer {
  associatedtype Rule
  static func rules() -> [Rule]
  func allowedActions(state: State) -> [Action]
}

enum Column: Int, CaseIterable, Equatable, Hashable {
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

enum Piece: Int, CaseIterable, Equatable, Hashable {
  case none    = 0
  case white1  = 1,  white2, white3
  case red     = 10
  case red2    = 12, red3, red4, red5, red6, red7, red8, red9, red10, red11, red12
  case blue    = 30
  case blue2   = 32, blue3, blue4, blue5, blue6, blue7, blue8, blue9, blue10, blue11, blue12
  case green   = 50
  case green2  = 52, green3, green4, green5, green6, green7, green8, green9, green10, green11, green12
  case yellow  = 70
  case yellow2 = 72, yellow3, yellow4, yellow5, yellow6, yellow7, yellow8, yellow9, yellow10, yellow11, yellow12
  var name: String {
    String(describing: self)
  }
  static func whiteSet() -> Set<Piece> {
    Set([.white1, .white2, .white3])
  }
  
  static func redSet() -> Set<Piece> {
    Set([.red2, .red3, .red4, .red5, .red6, .red7, .red8, .red9, .red10, .red11, .red12])
  }
  
  static func greenSet() -> Set<Piece> {
    Set([.green2, .green3, .green4, .green5, .green6, .green7, .green8, .green9, .green10, .green11, .green12])
  }
  
  static func blueSet() -> Set<Piece> {
    Set([.blue2, .blue3, .blue4, .blue5, .blue6, .blue7, .blue8, .blue9, .blue10, .blue11, .blue12])
  }
  
  static func yellowSet() -> Set<Piece> {
    Set([.yellow2, .yellow3, .yellow4, .yellow5, .yellow6, .yellow7, .yellow8, .yellow9, .yellow10, .yellow11, .yellow12])
  }
  
}

enum DSix: Int, CaseIterable, Equatable, Hashable {
  case none = 0, one = 1, two, three, four, five, six
  
  static func random() -> DSix {
    return DSix.four
  }
  
  var name: String {
    String(describing: self)
  }
}

enum Die: Int, CaseIterable, Equatable, Hashable {
  case die1 = 1, die2, die3, die4
  var name: String {
    String(describing: self)
  }
}

typealias Board = [Column: [Int]]
struct BoardSpot: Hashable, Equatable {
  let col: Column
  let row: Int
  var name: String {
    "\(col.name)\(row)"
  }
}

struct PiecePosition: Hashable, Equatable {
  var piece: Piece
  var position: BoardSpot
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

//let board: Board = [
//  Column.two:    [Int](repeating: 0, count: colHeights[Column.two]!),
//  Column.three:  [Int](repeating: 0, count: colHeights[Column.three]!),
//  Column.four:   [Int](repeating: 0, count: colHeights[Column.four]!),
//  Column.five:   [Int](repeating: 0, count: colHeights[Column.five]!),
//  Column.six:    [Int](repeating: 0, count: colHeights[Column.six]!),
//  Column.seven:  [Int](repeating: 0, count: colHeights[Column.seven]!),
//  Column.eight:  [Int](repeating: 0, count: colHeights[Column.eight]!),
//  Column.nine:   [Int](repeating: 0, count: colHeights[Column.nine]!),
//  Column.ten:    [Int](repeating: 0, count: colHeights[Column.ten]!),
//  Column.eleven: [Int](repeating: 0, count: colHeights[Column.eleven]!),
//  Column.twelve: [Int](repeating: 0, count: colHeights[Column.twelve]!)
//]
//
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
    var position: [Piece: BoardSpot] = [:]
    var dice: [Die: DSix] = [:]
    var assignedDicePair = Column.none
    var player = Player.twop(.player1)
    var phase = Phase.notRolled
    
    init() {
      for piece in Piece.allCases {
        position[piece] = BoardSpot(col: .none, row: 0)
      }
      for die in Die.allCases {
        dice[die] = DSix.none
      }
      assignedDicePair = Column.none
      player = Player.twop(PlayerAmongTwo.player1)
      phase = Phase.notRolled
    }
    
    func piecesAt(_ spot: BoardSpot) -> [Piece] {
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
      let whites = [Piece.white1, .white2, .white3]
      var white = whites.first(where: {position[$0]?.col == col} )
      if white == nil {
        white = whites.first(where: {position[$0]?.col == Column.none})
      }
      let row = position[white!]?.row
      position[white!] = BoardSpot(col: col, row: row! + 1)
    }
    
    mutating func savePlace() {
      var playerInt = 0
      switch player {
      case let .twop(p):
        playerInt = p.rawValue
      case let .threep(p):
        playerInt = p.rawValue
      case let .fourp(p):
        playerInt = p.rawValue
      }
      [Piece.white1, .white2, .white3].forEach { white in
        // move a colored piece to that spot
        position[Piece(rawValue: (playerInt + position[white]!.col.rawValue))!] = BoardSpot(col: position[white]!.col, row: position[white]!.row)
        // move the white piece off the board
        position[white] = BoardSpot(col: .none, row: 0)
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
          !Set(state.piecesAt(BoardSpot(col: col, row: row))).isDisjoint(with: Piece.whiteSet())
        })
      }
    case .claimed(let col):
      return { state in
        let coloredPieces = Piece.redSet().union(Piece.greenSet()).union(Piece.blueSet()).union(Piece.yellowSet())
        return colHeights.contains(where: { (col, row) in
          !Set(state.piecesAt(BoardSpot(col: col, row: row))).isDisjoint(with: coloredPieces)
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
    case progressColumns
    
    // recursive: ordered list of actions
    case sequence([Action])
    
    var name: String {
      switch self {
      case .movePieceTo(let ppos):
        return "\(ppos.name)"
      case .assignDicePair(let pair):
        return "\(pair.fst.name), \(pair.snd.name)"
      case .sequence(let actions):
        return actions.map { $0.name }
          .joined(separator: ", ")
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
        actions: { state in
          self.actions(state).flatMap { a1 in
            var nextState = state
            let _ = reduce(state: &nextState, action: a1)
            if second.condition(nextState) {
              return second.actions(nextState).map { a2 in
                return Action.sequence([a1, a2])
              }
            } else {
              return [a1]
            }
          }
        }
      )
    }
  }
  
  // the rules are captured by a set of ConditionalActions
  typealias Rule = ConditionalAction
  
  // Rule: State -> (Bool, [Action])
  // not a good name. the reducer is also rules
  // (State, Action) -> State
  static func rules() -> [Rule] {
    let rule1 = Rule(condition: { $0.phase == .notRolled }, actions: { _ in [.rollDice, .pass] })
    // TODO: is the next rule a composition of smaller rules?
    let rule2 = Rule(
      condition: { $0.phase == .rolled },
      actions: { state in
        // all pairs of rolled dice. dice with value .none have been assigned already
        let dicePairings: [Pair<Die>] = pairs(of: Die.allCases.filter { die in state.dice[die] != DSix.none})
        return dicePairings.compactMap { pairing in
          let col = twod6_total(pairing.map {state.dice[$0]!})
          let whiteCols = [Piece.white1, .white2, .white3].map { state.position[$0]!.col }
          if whiteCols.contains(col) || whiteCols.contains(.none) {
            return Action.sequence([.assignDicePair(pairing), .progressColumns])
          }
          return nil
        }
      }
    )
    return [rule1, rule2.append(rule2)]
  }
  
  func allowedActions(state: State) -> [Action] {
    CantStop.rules().flatMap { rule in
      if rule.condition(state) {
        return rule.actions(state)
      } else {
        return [Action]()
      }
    }
  }
  
  static func reduce(state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case let .movePieceTo(ppos):
      state.position[ppos.piece] = ppos.position
      return .none
    case .advancePlayer:
      state.player = state.player.nextPlayer()
      state.phase = .notRolled
      return .none
    case .pass:
      state.savePlace()
      state.player = state.player.nextPlayer()
      state.phase = .notRolled
      return .none
    case .rollDice:
      state.dice[.die1] = DSix.random()
      state.dice[.die2] = DSix.random()
      state.dice[.die3] = DSix.random()
      state.dice[.die4] = DSix.random()
      state.phase = .rolled
      return .none
    case let .assignDicePair(pairing):
      // copy the resulting column to the assignedDicePair component
      state.assignedDicePair = CantStop.twod6_total(pairing.map { state.dice[$0]! })
      // erase/consume the values of these two dice
      for die in [pairing.fst, pairing.snd] {
        state.dice[die] = DSix.none
      }
      return .none
    case .progressColumns:
      state.advanceWhite(in: state.assignedDicePair)
      state.assignedDicePair = Column.none
      if Die.allCases.map({ state.dice[$0] }).allSatisfy({ $0 == DSix.none }) {
        state.phase = .notRolled
      }
      return .none
    case let .sequence(actions):
      return Effect<Action>.concatenate(
        actions.map { .send($0) }
      )
    }
  }
  
  var body: some Reducer<State, Action> {
    Reduce { st, act in
      return CantStop.reduce(state: &st, action: act)
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
      ForEach(CantStop().allowedActions(state: store.state), id: \.self) { action in
        Button("\(action.name)") {
          store.send(action)
        }
      }
    }
  }
}


#Preview("Can't Stop™®") {
  CantStopView(store: Store(initialState: CantStop.State()) {
    CantStop()
  })
}
