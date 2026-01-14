//
//  CantStopText.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 1/14/26.
//

import Foundation
import TextTable

extension CantStop.State: TextTableAble {

  struct CantStopPositionDisplay: CustomStringConvertible {
    let col: CantStop.Column
    let row: Int
    let pieces: [Piece]
    var description: String {
      row <= CantStop.colHeights()[col]! ?
        (
          pieces.isEmpty ? "___" :
            pieces.reduce("", { $0.description + $1.description} )
        ) : "   "
    }
  }
  
  struct CantStopColDisplay {
    let col: Int
    let positions: [CantStopPositionDisplay]
  }
  
  struct CantStopDisplay {
    let cols: [CantStopColDisplay]
  }
  
  var display: CantStopDisplay {
    CantStopDisplay(
      cols: CantStop.Column.allCases.filter({$0 != CantStop.Column.none}).map { col in
        CantStopColDisplay(
          col: col.rawValue,
          positions: (1...12).map { row in
            let pieces = piecesAt([Position(col: col, row: row)])
            return CantStopPositionDisplay(col: col, row: row, pieces: pieces)
          }
        )
      }
    )
  }
  
  func printTable<Target>(to: inout Target) where Target: TextOutputStream {
    let colTextTable = TextTable<CantStopColDisplay> { colDisplay in
      [Column(title: "#", value: colDisplay.col)] + (1...12).map { row in
        Column(title: "",  value: colDisplay.positions[row-1])
      }
    }
    colTextTable.print(display.cols)
  }
}
