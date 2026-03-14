//
//  MCState.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

extension MalayanCampaign: StatePredicates {
  typealias StatePredicate = (State) -> Bool

  struct State: HistoryTracking, Equatable, Sendable, GameState, CustomStringConvertible {

    // swiftlint:disable:next nesting
    typealias Player   = MalayanCampaignComponents.Player
    // swiftlint:disable:next nesting
    typealias Phase    = MalayanCampaignComponents.Phase
    // swiftlint:disable:next nesting
    typealias Piece    = MalayanCampaignComponents.Piece
    // swiftlint:disable:next nesting
    typealias Position = MalayanCampaignComponents.Position
    // swiftlint:disable:next nesting
    typealias Location = MalayanCampaignComponents.Location
    // swiftlint:disable:next nesting
    typealias PiecePosition = MalayanCampaignComponents.PiecePosition

    var history = [MalayanCampaign.Action]()
    var player: Player = .solo
    var players: [Player] = [.solo]
    var phase: Phase = .setup
    var ended: Bool = false
    var endedInVictoryFor = [Player]()
    var endedInDefeatFor = [Player]()
    var position: [Piece: Position] = [:]
    var strength: [Piece: DSix] = [:]
    var turnNumber = 1

    var alliesOnBoard: [Piece] {
      Piece.allies().filter {
        if case .at = position[$0] { return true }
        return false
      }
    }

    var japaneseOnBoard: [Piece] {
      Piece.japanese().filter {
        if case .at = position[$0] { return true }
        return false
      }
    }

    func location(of piece: Piece) -> Location? {
      if case .at(let loc) = position[piece] { return loc }
      return nil
    }

    func alliesAt(_ loc: Location) -> [Piece] {
      Piece.allies().filter { location(of: $0) == loc }
    }

    func japaneseAt(_ loc: Location) -> Piece? {
      Piece.japanese().first { location(of: $0) == loc }
    }

    /// Next location toward Singapore on the appropriate road for a Japanese unit.
    func nextLocationTowardSingapore(for piece: Piece) -> Location? {
      guard let loc = location(of: piece) else { return nil }
      let road: [Location]
      switch piece {
      case .japTrunk: road = MalayanCampaignComponents.trunkRoad
      case .japEastern: road = MalayanCampaignComponents.easternRoad
      default: return nil
      }
      guard let idx = road.firstIndex(of: loc), idx + 1 < road.count else { return nil }
      return road[idx + 1]
    }

    /// Next location toward Singapore for an allied withdrawal.
    /// Allied units move along whichever road they are currently on, toward Singapore.
    func nextWithdrawalLocation(for piece: Piece) -> Location? {
      guard let loc = location(of: piece) else { return nil }
      // Check trunk road
      if let idx = MalayanCampaignComponents.trunkRoad.firstIndex(of: loc),
        idx + 1 < MalayanCampaignComponents.trunkRoad.count {
        return MalayanCampaignComponents.trunkRoad[idx + 1]
      }
      // Check eastern road
      if let idx = MalayanCampaignComponents.easternRoad.firstIndex(of: loc),
        idx + 1 < MalayanCampaignComponents.easternRoad.count {
        return MalayanCampaignComponents.easternRoad[idx + 1]
      }
      return nil
    }

    mutating func removePiece(_ piece: Piece) {
      position[piece] = .offBoard
      strength.removeValue(forKey: piece)
    }

    var description: String {
      var result = "T\(turnNumber): "
      for loc in Location.allCases {
        let allies = alliesAt(loc)
        let jap = japaneseAt(loc)
        if allies.isEmpty && jap == nil { continue }
        let allyStr = allies.map { "\($0.shortName)\(strength[$0]?.rawValue ?? 0)" }.joined(separator: ",")
        let japStr = jap.map { "\($0.shortName)\(strength[$0]?.rawValue ?? 0)" } ?? ""
        result += "\(loc): \(allyStr) \(japStr) | "
      }
      if endedInDefeatFor.isNonEmpty { result += "LOSS" } else if endedInVictoryFor.isNonEmpty { result += "WIN" }
      return result
    }
  }
}
