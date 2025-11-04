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

enum DSix: Int, CaseIterable, Equatable, Hashable, RawComparable, Linear {
  case none = 0, one = 1, two, three, four, five, six
  
  static func allFaces() -> [DSix] {
    DSix.allCases.filter { $0 != .none}
  }
  
  static func sum(_ lhs: DSix, _ rhs: DSix, clamp: Bool = true) -> DSix {
    var val = lhs.rawValue + rhs.rawValue
    if clamp {
      val = min(val, 6)
    }
    return DSix(rawValue: val)!
  }
  
  static func minus(_ lhs: DSix, _ rhs: DSix, clamp: Bool = true) -> DSix {
    var val = lhs.rawValue - rhs.rawValue
    if clamp {
      val = max(val, 1)
    }
    return DSix(rawValue: val)!
  }
  
  var name: String {
    String(describing: self)
  }
  
  func next() -> Self {
    switch self {
    case .none:
      return .none
    case .one, .two, .three, .four, .five:
      return DSix(rawValue: rawValue + 1)!
    case .six:
      return .six
    }
  }
  
  var start: Self {
    return .one
  }
  
  var end: Self {
    return .six
  }
}

protocol Cyclic {
  func next() -> Self
}

protocol Linear {
  func next() -> Self
  var start: Self { get }
  var end: Self { get }
}
