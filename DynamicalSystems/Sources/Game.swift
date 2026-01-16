//
//  Game.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/30/25.
//

import ComposableArchitecture
import Foundation

/// Notes from Ludii
///
/// Components:
///   Piece (e.g. Marker, Disc, Scale, Colour, Pawn, Soldier, Tank, Jaguar, Dog), flippable
///   Dice (d:4, optional faces: { a b c d })
///   Domino
///   Card
///   Tile (to play on cells, same shape as cells)
/// Container:
///   Dice
///   Board (sites: cells/faces, edges, vertices)
///     helpers: columns, rows, perimeter, corners, major, minor, top, bottom, left, right
///     edges are between vertices AND between faces
///     generators: graph (list vertices w/ 2D coords, list edges as pairs of indices, list cells as lists of indices)
///     play on vertices, edges, and/or faces
///     generator helpers: brickwork, celtic, hex, mesh, morris, square, tiling, triangular, ...
///     generator helpers: add, remove, hole, intersect, keep, rotate, skew, ...
///     relations: neighbors, neighbors of distance d
///     cell/face can have "values", e.g. sudoku having 1-9: (board (square 9) (values Cell (range 1 9)))
///     Direction:
///       Relative, Absolute (forward, forwards (like a cone for a tank))
///       Facing: Spatial, Rotational, Compass
///     Track:
///       extra data referring to the board sites; can use direction commands
///       can be directed, or loop
///       end (one space off the end of the track)
///       a player's hand could have a track(?)
///   Hand
///   Deck

protocol GameComponents {
  associatedtype Phase
  associatedtype Piece: Equatable, Hashable
  associatedtype PiecePosition
  associatedtype Player: Equatable, Hashable
  associatedtype Position
}

protocol StatePredicates {
  associatedtype StatePredicate
}

protocol GameState: GameComponents, Equatable {
  var name: String { get }
  var player: Player { get set }
  var players: [Player] { get set }
  var ended: Bool { get set }
  var endedInVictoryFor: [Player] { get set }
  var endedInDefeatFor: [Player] { get set }
  var position: [Piece: Position] { get set }
}

protocol LookaheadReducer<State, Action>: Reducer {
  associatedtype Rule
  func newState() -> State
  func rules() -> [Rule]
  func allowedActions(state: State) -> [Action]
  func reduce(into: inout State, action: Action) -> [Log]
}

struct Log: Hashable, Equatable, Sendable {
  let msg: String
}

protocol ComputerPlayer<State, Action> {
  associatedtype State
  associatedtype Action
  func chooseAction(state: State, game: any LookaheadReducer<State, Action>) -> Action
}

struct Track: Equatable, Hashable {
  let length: Int
  var names: [String] = []
}

typealias TrackPos = Int

// TODO: remove .none
enum DSix: Int, CaseIterable, Equatable, Hashable, RawComparable, Linear {
  case none = 0, one = 1, two, three, four, five, six
  
  static func allFaces() -> [DSix] {
    DSix.allCases.filter { $0 != DSix.none}
  }
  
  static func roll() -> DSix {
    DSix.allFaces().randomElement()!
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
    } else {
      val = max(val, 0)
    }
    return DSix(rawValue: val)!
  }
  
  static func greater(_ lhs: DSix, _ rhs: DSix) -> Bool {
    return lhs.rawValue > rhs.rawValue
  }
  
  static func compare(_ lhs: DSix, _ rhs: DSix) -> Trichotomy {
    return Int.compare(lhs.rawValue, rhs.rawValue)
  }
  
  var name: String {
    String(describing: self)
  }
  
  func next() -> Self {
    switch self {
    case .one, .two, .three, .four, .five:
      return DSix(rawValue: rawValue + 1)!
    case .six:
      return .six
    default:
      return self
    }
  }
  
  var start: Self {
    return .one
  }
  
  var end: Self {
    return .six
  }
}

enum Trichotomy {
  case larger
  case smaller
  case equal
}

extension Int {
  static func compare(_ lhs: Int, _ rhs: Int) -> Trichotomy {
    if lhs > rhs {
      return .larger
    } else if rhs > lhs {
      return .smaller
    } else {
      return .equal
    }
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

struct TwoParamCRT<T, U, V> {
  var result: (_ tee: T, _ you: U) -> V
}

struct ThreeParamCRT<T, U, V, W> {
  var result: (_ tee: T, _ you: U, _ vee: V) -> W
}

protocol AnytimePlayer {
  associatedtype Action: Hashable
  func recommendation(iters: Int, numRollouts: Int) -> [Action:(Float, Float)]
}
