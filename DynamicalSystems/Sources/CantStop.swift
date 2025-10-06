//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

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
  .two:    3,
  .three:  5,
  .four:   7,
  .five:   9,
  .six:    11,
  .seven:  13,
  .eight:  11,
  .nine:   9,
  .ten:    7,
  .eleven: 5,
  .twelve: 3,
]

enum Piece {
  case none
  case white1, white2, white3
  case red2, red3, red4, red5, red6, red7, red8, red9, red10, red11, red12
  case blue2, blue3, blue4, blue5, blue6, blue7, blue8, blue9, blue10, blue11, blue12
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

enum PlayerAmongTwo {
  case player1
  case player2
}

enum PlayerAmongThree {
  case player1
  case player2
  case player3
}

enum PlayerAmongFour {
  case player1
  case player2
  case player3
  case player4
}

enum Player: Equatable, Hashable {
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

enum Phase {
  case notRolled
  case rolled
}

// the base space of game components
enum Component: Hashable {
  case piece(Piece)
  case die(Die)
  case player
  case phase
}

// The classifying type is the sum {Board} + {Player} + {Phase}
// So over each component lies all the points in that union, which we called Universe.

// values the components can have (the points in the type {Board} + {Player} + {Phase})
//enum Universe {
//  case position(Board)
//  case player(Player)
//  case phase(Phase)
//}

// A type family over Component (a map to {Board} + {Player} + {Phase}, but where we assign each case to a single specific case)
//enum Family {
//  case piece((Piece) -> Board)
//  case player(Player)
//  case phase(Phase)
//}

// patch a function with an exception x ↦ y
func override(base: (Piece) -> BoardSpot, exception: PiecePosition) -> (Piece) -> BoardSpot {
  return { piece in
    if piece == exception.piece {
      return exception.position
    }
    return base(piece)
  }
}

// the pi type of the family, i.e. a type of sections of the family
struct State {
  var position: (Piece) -> BoardSpot
  var value: (Die) -> DSix
  var player: Player
  var phase: Phase
}


// the sigma type of the type family: pairs of (component, value)
// the state will indicate who is performing the action
enum Action: Hashable, Equatable {
  // the state of one piece
  case piecePosition(PiecePosition)
  case player(Player)
  case phase(Phase)

  // actions that are not updates of a component
  case pass
  case rollDice
  case assignDice
  
  // recursive: collections of actions
  case actionSet(Set<Action>)
  case actionList(Array<Action>)
}

typealias Condition = (State) -> Bool // maybe one day a Predicate

struct ConditionalAction {
  let condition: Condition
  let action: Action
}

typealias Rule = ConditionalAction

// the rules are captured by a set of ConditionalActions

let ROLL =   Rule(condition: { $0.phase == .notRolled }, action: .rollDice)
let PASS =   Rule(condition: { $0.phase == .notRolled }, action: .pass)
let ASSIGN = Rule(condition: { $0.phase == .rolled },    action: .assignDice)

struct CantStop {
  var rules = [ROLL, PASS, ASSIGN]
  var state: State
  init() {
    state = State(
      position: { _ in return BoardSpot(col: .none, row: 0)},
      value:    { _ in return DSix.one },
      player:   Player.twop(PlayerAmongTwo.player1),
      phase:    Phase.notRolled
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
    case let .piecePosition(ppos):
      state.position = override(base: state.position, exception: ppos)
    case let .player(newPlayer):
      state.player = newPlayer
    case let .phase(newPhase):
      state.phase = newPhase
    case .pass:
      state.player = state.player.nextPlayer()
      // TODO: remove white pieces, place colored pieces
    case .rollDice:
      // TODO: set the state of the dice
    case .assignDice:
      // TODO: move the relevant white pieces
    case let .actionSet(actions):
      actions.forEach {action in
        reduce(state: &state, action: action)
      }
    case let .actionList(actions):
      actions.forEach {action in
        reduce(state: &state, action: action)
      }
    }
  }
}


// a term on the surface, and an action inside
// the term should be some element or tuple of elements in the state
// or there could be such a thing as a partial state, which nils out some of the state
// then we could match state to partial state and they'd both be partial states, and nil would match anything?
// StatePredicate -> Action
// State -> [StatePredicate] -> [Action]
// #Predicate<State>

//func legalComponents(_ state: State) -> Set<Component> {
//  var legalComponents = Set<Component>([])
//  
//  if state.phase == .notRolled {
//    // one can roll the dice or save your place with your colored pieces
//    
//    // the dice
//    legalComponents.insert(.die(.die1))
//    legalComponents.insert(.die(.die2))
//    legalComponents.insert(.die(.die3))
//    legalComponents.insert(.die(.die4))
//    
//    // one's colored pieces
//    switch state.player {
//    case .twop(.player1), .threep(.player1), .fourp(.player1):
//      legalComponents.insert(.piece(.red2))
//      legalComponents.insert(.piece(.red3))
//      legalComponents.insert(.piece(.red4))
//      legalComponents.insert(.piece(.red5))
//      legalComponents.insert(.piece(.red6))
//      legalComponents.insert(.piece(.red7))
//      legalComponents.insert(.piece(.red8))
//      legalComponents.insert(.piece(.red9))
//      legalComponents.insert(.piece(.red10))
//      legalComponents.insert(.piece(.red11))
//      legalComponents.insert(.piece(.red12))
//    case .twop(.player2), .threep(.player2), .fourp(.player2):
//      legalComponents.insert(.piece(.blue2))
//      legalComponents.insert(.piece(.blue3))
//      legalComponents.insert(.piece(.blue4))
//      legalComponents.insert(.piece(.blue5))
//      legalComponents.insert(.piece(.blue6))
//      legalComponents.insert(.piece(.blue7))
//      legalComponents.insert(.piece(.blue8))
//      legalComponents.insert(.piece(.blue9))
//      legalComponents.insert(.piece(.blue10))
//      legalComponents.insert(.piece(.blue11))
//      legalComponents.insert(.piece(.blue12))
//    default:
//      // TODO: support 3, 4 players
//      print("more than 2 players not supported")
//    }
//  } else {
//    // one can apply the dice to the white pieces
//    legalComponents.insert(.piece(.white1))
//    legalComponents.insert(.piece(.white2))
//    legalComponents.insert(.piece(.white3))
//  }
//  
//  return legalComponents
//}

//func possibleActions(_ state: State) -> Set<Action> {
//  // state.piece is where all the pieces are
//  // state.player is which player's turn it is
//  // state.phase is which phase of the player's turn it is
//  var legal = Set<Action>([])
//  var legalComponents = legalComponents(state)
//  
//  if state.phase == .notRolled {
//    // before you roll, you can choose to roll or pass
//    legal.insert(.rollDice)
//    legal.insert(.pass)
//  } else {
//    // the dice are rolled and the user must allocate them if possible
//    
//    // compute the three pairs of columns supported by the dice
//    let col11 = twod6_total((state.value(.die1), state.value(.die2)))
//    let col12 = twod6_total((state.value(.die3), state.value(.die4)))
//
//    let col21 = twod6_total((state.value(.die1), state.value(.die3)))
//    let col22 = twod6_total((state.value(.die2), state.value(.die4)))
//
//    let col31 = twod6_total((state.value(.die1), state.value(.die4)))
//    let col32 = twod6_total((state.value(.die3), state.value(.die2)))
//    
//    // now check the state of the white pieces, with height 0 indicating an unallocated white piece
//    let (col1, height1) = state.position(.white1)
//    let (col2, height2) = state.position(.white2)
//    let (col3, height3) = state.position(.white3)
//    
//    let white1Unallocated = height1 == 0
//    let white2Unallocated = height2 == 0
//    let white3Unallocated = height3 == 0
//    let someWhiteUnallocated = (white1Unallocated || white2Unallocated || white3Unallocated)
//    
//    
//  }
//  
//  return []
//}

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
