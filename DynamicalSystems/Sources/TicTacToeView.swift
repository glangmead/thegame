//
//  TicTacToeView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/10/25.
//

import SwiftUI

//
// MARK: Tic Tac Toe
//


enum TTTPlayer {
  case x, o
  var inverted: TTTPlayer {
    switch self {
    case .x: return .o
    case .o: return .x
    }
  }
}

enum TTTMark: Character, Identifiable {
  case none = "–"
  case x = "x"
  case o = "o"
  var id: Self { self }
  var inverted: TTTMark {
    switch self {
    case .none: return .none
    case .x: return .o
    case .o: return .x
    }
  }
}

struct TTTState {
  let boardSize: Int
  var board: [[TTTMark]]
  var lastMark: TTTMark = .o // the player who put the most recent mark shown on the board
  
  init(_ boardSize: Int) {
    self.boardSize = boardSize
    self.board = [[TTTMark]](
      repeating: [TTTMark](
        repeating:.none,
        count: boardSize),
      count: boardSize)
  }
  var lines: [[(Int, Int)]] {
    var lines: [[(Int, Int)]] = []
    let vec = Array(0..<self.boardSize)
    for i in 0..<self.boardSize {
      lines.append(vec.map{ ($0, i)})
      lines.append(vec.map{ (i, $0)})
      lines.append(vec.map{ ($0, $0)})
      lines.append(vec.map{ (-1 + self.boardSize - $0, $0)})
    }
    return lines
  }
  
  var terminal: Bool {
    return self.winner != nil
  }
  
  var winner: TTTMark? {
    for line in self.lines {
      let boardLine = line.map{ self.board[$0.0][$0.1] }
      for mark in [TTTMark.x, TTTMark.o] {
        if boardLine.allSatisfy({$0 == mark}) {
          return mark
        }
      }
    }
    return self.board.allSatisfy({$0.allSatisfy({$0 != .none})}) ? TTTMark.none : nil
  }
}

enum TTTAction {
  case placeMark(Int, Int, TTTMark)
}

/// This is the lens for making a move. up() returns a nil state if it's illegal.
let tttLens = OptionalStateLens<TTTState, TTTAction, TTTState>(
  down: { $0 },
  up: { (state, action) in
    switch action {
    case let .placeMark(row, col, mark):
      if state.board[row][col] == .none {
        var outState = state
        outState.board[row][col] = mark
        outState.lastMark = mark
        return outState
      } else {
        return nil
      }
    }
  }
)

/// This lens only supplies a meaningful upstream map, which returns all legal actions.
let tttPossibleLegalLens = Lens<[TTTAction], TTTState, Void, Void>(
  down: { s in return },
  up: { (state, _) in
    var legalActions: [TTTAction] = []
    let rows = 0..<state.boardSize
    let cols = 0..<state.boardSize
    for row in rows {
      for col in cols {
        if state.board[row][col] == .none {
          legalActions.append(.placeMark(row, col, state.lastMark.inverted))
        }
      }
    }
    return legalActions
  }
)

struct TicTacToeView: View {
  @State private var userGameSize: Int = 3
  @State private var gameState = TTTState(3)
  var body: some View {
    let gameSizeRange = 0..<gameState.boardSize
    VStack {
      Spacer()
      Text("Turn: \(gameState.lastMark.inverted)")
        .font(.largeTitle)
      Spacer()
      ForEach(gameSizeRange, id: \.self) { rowNum in
        HStack {
          ForEach(gameSizeRange, id: \.self) { colNum in
            spaceView(rowNum, colNum)
          }
        }
      }
      Spacer()
      if gameState.terminal {
        Text("\(gameState.winner!) wins!")
          .font(.largeTitle)
        Stepper("Board size \(userGameSize)", value: $userGameSize, in: 1...10)
        Button("Play again") {gameState = TTTState(userGameSize)}.buttonStyle(.borderedProminent).font(.largeTitle)
      }
      Spacer()
      Spacer()
    }
  }
  
  @ViewBuilder func spaceView(_ row: Int, _ col: Int) -> some View {
    let mark = gameState.board[row][col]
    switch mark {
    case .none:
      Button("\(mark.rawValue) ") {
        if !gameState.terminal {
          let tttAction = TTTAction.placeMark(row, col, gameState.lastMark == .x ? .o : .x)
          if let newState = tttLens.up((gameState, tttAction)) {
            self.gameState = newState
          }
        }
      }
      .font(.largeTitle)
    default:
      Text("\(mark.rawValue) ").font(.largeTitle)
    }
  }
  
}

#Preview("Tic Tac Toe") {
  TicTacToeView()
}
