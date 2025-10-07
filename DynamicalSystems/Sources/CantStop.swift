//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

import ComposableArchitecture
import SwiftUI

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

enum DSix: Int, CaseIterable {
  case one = 1, two, three, four, five, six
  
  static func random() -> DSix {
    return DSix.allCases.randomElement()!
  }
}

enum Column: Int {
  case none = 0
  case two = 2, three, four, five, six, seven, eight, nine, ten, eleven, twelve
}

let colHeights: [Column: Int] = [
  .two:   3,  .three: 5, .four: 7, .five:   9, .six:    11, .seven: 13,
  .eight: 11, .nine:  9, .ten:  7, .eleven: 5, .twelve: 3,
]

enum Piece: Int {
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
}

enum Die {
  case die1, die2, die3, die4
}

typealias Board = [Column: [Int]]
struct BoardSpot: Hashable, Equatable {
  let col: Column
  let row: Int
}

struct PiecePosition: Hashable, Equatable {
  var piece: Piece
  var position: BoardSpot
}

struct DieValue: Hashable, Equatable {
  var die: Die
  var value: DSix
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
}

enum PlayerAmongThree: Int, Hashable, Equatable {
  case player1 = 10
  case player2 = 30
  case player3 = 50
}

enum PlayerAmongFour: Int, Hashable, Equatable {
  case player1 = 10
  case player2 = 30
  case player3 = 50
  case player4 = 70
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
}

// the base space of game components
enum Component: Hashable, Equatable {
  case piece(Piece)
  case die(Die)
  case player
  case phase
}

// patch a function with an exception x ↦ y
func override(base: (Piece) -> BoardSpot, exception: PiecePosition) -> (Piece) -> BoardSpot {
  return { piece in
    if piece == exception.piece {
      return exception.position
    }
    return base(piece)
  }
}

func override(base: (Die) -> DSix, exception: DieValue) -> (Die) -> DSix {
  return { die in
    if die == exception.die {
      return exception.value
    }
    return base(die)
  }
}

struct Tuple2<A, B> {
  let fst: A
  let snd: B
}

typealias Pair<A> = Tuple2<A, A>

extension Tuple2: Equatable where A: Equatable, B: Equatable {
  static func == (lhs: Tuple2<A, B>, rhs: Tuple2<A, B>) -> Bool {
    return lhs.fst == rhs.fst && lhs.snd == rhs.snd
  }
}

extension Tuple2: Hashable where A: Hashable, B: Hashable {}

// the pi type of the family, i.e. a type of sections of the family
struct State {
  var position: (Piece) -> BoardSpot
  var dice: [DSix]
  var assignedDice: [Column]
  var player: Player
  var phase: Phase
  
  mutating func advanceWhite(in col: Column) {
    [Piece.white1, .white2, .white3].forEach { white in
      if position(white).col == col {
        let row = position(white).row
        position = override(
          base: position,
          exception: PiecePosition(
            piece: white,
            position: BoardSpot(
              col: col,
              row: row + 1
            )
          )
        )
      }
    }
  }
  
  mutating func savePlace() {
    var playerInt = 0
    switch player {
    case let .twop(p):
    case let .threep(p):
    case let .fourp(p):
      playerInt = p.rawValue
    }
    [Piece.white1, .white2, .white3].forEach { white in
      // move a colored piece to that spot
      position = override(base: position, exception: PiecePosition(
        piece: Piece(rawValue: (playerInt + position(white).col.rawValue))!,
        position: BoardSpot(col: position(white).col, row: position(white).row)
      ))
      // move the white piece off the board
      position = override(base: position, exception: PiecePosition(
        piece: white,
        position: BoardSpot(col: .none, row: 0)
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
  case assignDice([Column])
  case progressColumns
  
  // recursive: collections of actions
  case doAll(Set<Action>)
}

typealias StatePredicate = (State) -> Bool // maybe one day a Predicate type

struct ConditionalAction {
  let condition: StatePredicate
  let actions: (State) -> Set<Action>
}

typealias Rule = ConditionalAction

// the rules are captured by a set of ConditionalActions

let ROLL =   Rule(condition: { $0.phase == .notRolled }, actions: { _ in [.rollDice] })
let PASS =   Rule(condition: { $0.phase == .notRolled }, actions: { _ in [.pass] })
let ASSIGN = Rule(
  condition: { $0.phase == .rolled },
  actions: { state in
    let dicePairings: [[[Int]]] = [ [ [0, 1], [2, 3] ], [ [0, 2], [1, 3] ], [ [0, 3], [1, 2] ] ]
    return Set(
      dicePairings.compactMap { pairing in
        var legalColumns = [[Column]]()
        let col1 = twod6_total( (state.dice[pairing[0][0] ], state.dice[pairing[0][1]]) )
        let col2 = twod6_total( (state.dice[pairing[1][0] ], state.dice[pairing[1][1] ]) )
        let whiteCols = [Piece.white1, .white2, .white3].map { state.position($0).col }
        
        // scenarios for a dice-pair that don't depend what we do with the other pair:
        //   - there's a white in that column (✅)
        //   - the column is claimed (✅)
        //   - there's no white in that column and all whites are claimed and the column is not claimed (❌)
        //   - there are >= 2 free white pieces
        // scenario where the dice-pair can be used but it might block the second dice-pair from being used:
        //   - there is 1 free white piece
        // QUESTION: should we program all that in? or just actually run the state machine after the first pair?
        // Maybe the "action" is to assign ONE dice pair, and then the situation may have changed for the second.
        // We can do that in both orders with a higher-level combinator. We can offer the total result as a dual action.
        // The higher-level thing would take a list of two items and return all the unique legal action-pairs that result from doing them in one order then the other order.
        // (a, b) -> action1 only, action2 only, action1 and action 2
        
        return .doAll(Set(legalColumns.map { Action.assignDice($0) }))
      }
    )
  }
)

struct CantStop {
  var rules = [ROLL, PASS, ASSIGN]
  var state: State
  init() {
    self.state = State(
      position: { _ in return BoardSpot(col: .none, row: 0)},
      dice:         [DSix.one, DSix.one, DSix.one, DSix.one],
      assignedDice: [],
      player:       Player.twop(PlayerAmongTwo.player1),
      phase:        Phase.notRolled
    )
  }
  
  func legalActions() -> [Action] {
    rules.compactMap { rule in
      if rule.condition(state) {
        return rule.action
      } else {
        return nil
      }
    }
  }
  
  static func reduce(state: inout State, action: Action) {
    switch action {
    case let .movePieceTo(ppos):
      state.position = override(base: state.position, exception: ppos)
    case .advancePlayer:
      state.player = state.player.nextPlayer()
      state.phase = .notRolled
    case .pass:
      state.savePlace()
      state.player = state.player.nextPlayer()
      state.phase = .notRolled
    case .rollDice:
      state.dice = roll_nD6(4)
      state.phase = .rolled
    case .assignDice:
      // TODO: choose an assignment!
    case .progressColumns:
      state.assignedDice.forEach { col in
        state.advanceWhite(in: col)
      }
    case let .doAll(actions):
      actions.forEach {action in
        reduce(state: &state, action: action)
      }
    }
  }
}

func roll_nD6(_ num: Int) -> [DSix] {
  var result = [DSix]()
  for _ in 0..<num {
    result.append(DSix.random())
  }
  return result
}

func dice_total(_ dice: [DSix]) -> Int {
  return dice.reduce(0, { partial, die in
    return partial + die.rawValue
  })
}

func twod6_total(_ dice: (DSix, DSix)) -> Column {
  return Column(rawValue: dice.0.rawValue + dice.1.rawValue) ?? .none
}

struct CantStopView: View {
  var body: some View {
    Text("Hello from Sid Sackson‘s Can‘t Stop™®")
      .font(.largeTitle)
  }
}

#Preview("Can't Stop™®") {
  CantStopView()
}
