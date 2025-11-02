//
//  BCComponents.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import Foundation

extension BattleCard: GameComponents {
  enum Phase {
    case start
  }
  
  enum Piece: Hashable {
    case airborne
  }
  
  enum Player {
    case solo
  }
  
  enum PlayerTrack {
    case space1
  }
  
  enum OpponentTrack {
    case space1
  }
  
  enum Position {
    case player(PlayerTrack)
    case opponent(OpponentTrack)
  }
  
  struct PiecePosition {
    var piece: Piece
    var position: Position
  }
}
