//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

import SwiftUI

enum DSix: Int, CaseIterable {
  case one = 1, two, three, four, five, six
  
  static func random() -> DSix {
    return DSix.allCases.randomElement()!
  }
}

enum CSColumn: Int {
  case none = 0
  case two = 2, three, four, five, six, seven, eight, nine, ten, eleven, twelve
}

let columnHeightsInclusive = [
  CSColumn.two:    3,
  CSColumn.three:  5,
  CSColumn.four:   7,
  CSColumn.five:   9,
  CSColumn.six:    11,
  CSColumn.seven:  13,
  CSColumn.eight:  11,
  CSColumn.nine:   9,
  CSColumn.ten:    7,
  CSColumn.eleven: 5,
  CSColumn.twelve: 3,
]

struct CSWhitePiece {
  var pos: CSColumn
}

struct CSPlayerSaves {
  let player: Int
  let saves: Dictionary<CSColumn, Int>
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

func twod6_total(_ dice: (DSix, DSix)) -> CSColumn {
  return CSColumn(rawValue: dice.0.rawValue + dice.1.rawValue) ?? .none
}

let movePiece = OptionalStateLens<CSWhitePiece, (DSix, DSix), CSWhitePiece>(
  down: { $0 },
  up: { (piece, dice) in
    if (piece.pos == .none) || (twod6_total(dice) == piece.pos) {
      var movedPiece = piece
      movedPiece.pos = CSColumn(rawValue: piece.pos.rawValue + 1)!
      return movedPiece
    } else {
      return nil
    }
  }
)

let possibleMoves = PossibleStateLens<
  (CSWhitePiece, CSWhitePiece, CSWhitePiece),
  (DSix, DSix, DSix, DSix),
  (CSWhitePiece, CSWhitePiece, CSWhitePiece)
>(
  down: { $0 },
  up: { (pieces, dice) in
    return []
  }
)

struct CantStopView: View {
  var body: some View {
    Text("Hello from Can‘t Stop™®")
      .font(.largeTitle)
  }
}

#Preview("Can't Stop™®") {
  CantStopView()
}
