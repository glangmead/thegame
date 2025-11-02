//
//  Game.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/30/25.
//

import ComposableArchitecture
import Foundation

protocol GameComponents {
  associatedtype Phase
  associatedtype Piece: Hashable
  associatedtype PiecePosition
  associatedtype Player
  associatedtype Position
}

protocol StatePredicates {
  associatedtype StatePredicate
}

protocol GameState: GameComponents, Equatable {
  var player: Player { get set }
  var players: [Player] { get set }
  var ended: Bool { get set }
  var position: [Piece: Position] { get set }
}

protocol LookaheadReducer<State, Action>: Reducer {
  associatedtype Rule
  static func rules() -> [Rule]
  static func allowedActions(state: State) -> [Action]
}

