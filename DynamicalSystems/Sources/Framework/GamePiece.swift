//
//  GamePiece.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

/// A game piece — element of the base space of the state bundle.
/// Named `GamePiece` to avoid collision with existing game-specific `Piece` types
/// during the migration period.
struct GamePiece: Codable, Identifiable {
  let id: Int
  var kind: PieceKind
  var owner: PlayerID?
  var displayName: String?
  var displayValues: [String: Int] = [:]

  enum PieceKind: Codable, Equatable, Hashable {
    case token
    case die(sides: Int)
    case card

    var layoutKey: String {
      switch self {
      case .token: "token"
      case .die: "die"
      case .card: "card"
      }
    }
  }
}

extension GamePiece: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension GamePiece: Equatable {
  static func == (lhs: GamePiece, rhs: GamePiece) -> Bool {
    lhs.id == rhs.id
  }
}

/// A player identifier, decoupled from game-specific player enums.
struct PlayerID: Hashable, Codable, Equatable, CustomStringConvertible {
  let raw: Int
  init(_ raw: Int) { self.raw = raw }
  var description: String { "player(\(raw))" }
}

/// The fiber value for a piece — its position and type-specific state.
/// Which case is inhabited is determined by the base point's PieceKind.
enum PieceValue: Codable, Equatable, Hashable {
  // swiftlint:disable:next identifier_name
  case at(SiteID)
  case dieShowing(face: Int, at: SiteID?) // swiftlint:disable:this identifier_name
  // swiftlint:disable:next identifier_name
  case cardState(name: String, faceUp: Bool, isRed: Bool, rotation: CGFloat, at: SiteID?)

  /// The site this piece occupies, regardless of kind.
  var site: SiteID? {
    switch self {
    case .at(let siteID): return siteID
    case .dieShowing(_, let siteID): return siteID
    case .cardState(_, _, _, _, let siteID): return siteID
    }
  }
}
