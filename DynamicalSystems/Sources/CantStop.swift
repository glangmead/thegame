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
  var rules: [Rule] { get set }
  func allowedActions(state: State) -> [Action]
}

// A State may often be decomposed into a collection of variables, and a choice of value for each.
// By "variable" we mean an entire type, like "enum Piece". There may be multiple pieces, so multiple copies of "enum Piece."
// This is a map f from Fin n to Enum, the classifying space of enums.
// Over Enum is a type family Enum_* of values each can take on.
// The pi type of this family f is the set/type S of states.

// The type A of actions would then be some sparse set of new values for some of the variables. Maybe we can assume that we can always decompose them into a new value for *one* variable.

// This makes the lens S x A -> S very transparent: it's to patch S with A's choice of value!

// The set of possible actions is a map S -> PA (power set of A). This would start off as the sigma type of f, i.e. choose one variable and a value for it. But then we'd cut that down. We might eliminate the trivial ones that don't differ from S. And some might be illegal.

// Legality could maybe then be viewed as a function \pit f x \sit f -> Bool, i.e. given a state S (a term of \pit) and a candidate new value (a term of \sit), is it legal.

// Let's be skeptical of this model. What game mechanics don't obviously fit?
// - player turn
// - turn phase
// - having a bunch of cards with rules on them

enum Column: Int, CaseIterable, Equatable {
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

enum Piece: Int, CaseIterable, Equatable {
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
}

enum DSix: Int, CaseIterable, Equatable {
  case none = 0, one = 1, two, three, four, five, six
  
  static func random() -> DSix {
    return DSix.allCases.filter { $0 != .none}.randomElement()!
  }
  var name: String {
    String(describing: self)
  }
}

enum Die: Int, CaseIterable, Equatable {
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

let board: Board = [
  Column.two:    [Int](repeating: 0, count: colHeights[Column.two]!),
  Column.three:  [Int](repeating: 0, count: colHeights[Column.three]!),
  Column.four:   [Int](repeating: 0, count: colHeights[Column.four]!),
  Column.five:   [Int](repeating: 0, count: colHeights[Column.five]!),
  Column.six:    [Int](repeating: 0, count: colHeights[Column.six]!),
  Column.seven:  [Int](repeating: 0, count: colHeights[Column.seven]!),
  Column.eight:  [Int](repeating: 0, count: colHeights[Column.eight]!),
  Column.nine:   [Int](repeating: 0, count: colHeights[Column.nine]!),
  Column.ten:    [Int](repeating: 0, count: colHeights[Column.ten]!),
  Column.eleven: [Int](repeating: 0, count: colHeights[Column.eleven]!),
  Column.twelve: [Int](repeating: 0, count: colHeights[Column.twelve]!)
]

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

// patch a function from an equatable domain with an exception x ↦ y
func override<A: Equatable, B>(base: @escaping (A) -> B, exception: (a: A, b: B)) -> (A) -> B {
  return { domainPoint in
    if domainPoint == exception.0 {
      return exception.1
    }
    return base(domainPoint)
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

// the rules are captured by a set of ConditionalActions

@Reducer
struct CantStop: LookaheadReducer {
  typealias StatePredicate = (State) -> Bool // maybe one day a Predicate type
  
  struct ConditionalAction {
    let condition: StatePredicate
    let actions: (State) -> [Action]
  }
  
  typealias Rule = ConditionalAction
  
  var rules: [Rule] = [
    Rule(condition: { $0.phase == .notRolled }, actions: { _ in [.rollDice] }),
    Rule(condition: { $0.phase == .notRolled }, actions: { _ in [.pass] }),
    // TODO: is the next rule a composition of smaller rules?
    Rule(
      condition: { $0.phase == .rolled },
      actions: { state in
        // all pairs of rolled dice. dice with value .none have been assigned already
        let dicePairings: [Pair<Die>] = pairs(of: Die.allCases.filter { die in state.dice(die) != DSix.none})
        return dicePairings.compactMap { pairing in
          let col = twod6_total(pairing.map {state.dice($0)})
          let whiteCols = [Piece.white1, .white2, .white3].map { state.position($0).col }
          if whiteCols.contains(col) || whiteCols.contains(.none) {
            return Action.sequence([.assignDicePair(pairing), .progressColumns])
          }
          return nil
        }
      }
    ),
//    Rule(
//      condition: { $0.phase == .rolled },
//      actions: { state in
//        ASSIGN.actions(state).flatMap { a1 in
//          var nextState = state
//          CantStop.reduce(state: &nextState, action: a1)
//          let pairs = ASSIGN.actions(nextState).map { a2 in
//            CantStop.Action.sequence([a1, a2])
//          }
//          return pairs
//        }
//      }
//    )
  ]

  func allowedActions(state: State) -> [Action] {
    rules.flatMap { rule in
      if rule.condition(state) {
        return rule.actions(state)
      } else {
        return [Action]()
      }
    }
  }
  
  // the pi type of the family, i.e. a type of sections of the family
  @ObservableState
  struct State {
    var position: (Piece) -> BoardSpot = { _ in BoardSpot(col: .none, row: 0)}
    var dice: (Die) -> DSix = { _ in DSix.none }
    var assignedDicePair = Column.none
    var player = Player.twop(.player1)
    var phase = Phase.notRolled
    
    init() {
      position =         { _ in return BoardSpot(col: .none, row: 0)}
      dice =             { _ in return DSix.none }
      assignedDicePair = Column.none
      player =           Player.twop(PlayerAmongTwo.player1)
      phase =            Phase.notRolled
    }
    
    var boardReport: [Column: [Piece]] {
      var report: [Column: [Piece]] = [:]
      for col in Column.allCases {
        report[col] = []
      }
      for piece in Piece.allCases {
        report[self.position(piece).col]!.append(piece)
      }
      return report
    }
    
    var diceReport: [Die: DSix] {
      var report: [Die: DSix] = [:]
      for die in Die.allCases {
        report[die] = dice(die)
      }
      return report
    }
    
    mutating func advanceWhite(in col: Column) {
      let whites = [Piece.white1, .white2, .white3]
      var white = whites.first(where: {position($0).col == col} )
      if white == nil {
        white = whites.first(where: {position($0).col == .none})
      }
      let row = position(white!).row
      position = override(
        base: position,
        exception: (white!, BoardSpot(col: col, row: row + 1))
      )
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
        position = override(base: position, exception: (
          Piece(rawValue: (playerInt + position(white).col.rawValue))!,
          BoardSpot(col: position(white).col, row: position(white).row)
        ))
        // move the white piece off the board
        position = override(base: position, exception: (
          white,
          BoardSpot(col: .none, row: 0)
        ))
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
  
  struct ActionView: View {
    let action: Action
    var body: some View {
      Text(action.name)
    }
  }
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .movePieceTo(ppos):
        state.position = override(base: state.position, exception: (ppos.piece, ppos.position))
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
        let roll = [DSix.random(), DSix.random(), DSix.random(), DSix.random()]
        state.dice = { die in
          switch die {
          
          case .die1:
            return roll[0]
          case .die2:
            return roll[1]
          case .die3:
            return roll[2]
          case .die4:
            return roll[3]
          }
        }
        state.phase = .rolled
        return .none
      case let .assignDicePair(pairing):
        // copy the resulting column to the assignedDicePair component
        state.assignedDicePair = CantStop.twod6_total(pairing.map { state.dice($0) })
        // erase/consume the values of these two dice
        for die in [pairing.fst, pairing.snd] {
          state.dice = override(
            base: state.dice,
            exception: (die, DSix.none)
          )
        }
        return .none
      case .progressColumns:
        state.advanceWhite(in: state.assignedDicePair)
        state.assignedDicePair = Column.none
        return .none
      case let .sequence(actions):
        return Effect<Action>.concatenate(
          actions.map { .send($0) }
        )
      }
    }
  }

  static func twod6_total(_ dice: Pair<DSix>) -> Column {
    let col = Column(rawValue: dice.fst.rawValue + dice.snd.rawValue) ?? .none
    print("\(dice.fst.name)/\(dice.fst.rawValue) + \(dice.snd.name)/\(dice.snd.rawValue) = \(col.name)")
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
            Text("\(col.rawValue): \(piece.rawValue)")
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
