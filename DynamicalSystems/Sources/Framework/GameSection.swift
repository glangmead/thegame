//
//  GameSection.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

/// A section of the state bundle: maps pieces to their fiber values.
typealias GameSection = [GamePiece: PieceValue]

extension Dictionary where Key == GamePiece, Value == PieceValue {

    /// All pieces at a given site.
    func piecesAt(_ site: SiteID) -> [GamePiece] {
        filter { $0.value.site == site }.map(\.key)
    }

    /// Single piece at a site (nil if none, first if multiple).
    func pieceAt(_ site: SiteID) -> GamePiece? {
        first { $0.value.site == site }?.key
    }

    /// All pieces owned by a player at a given site.
    func piecesAt(_ site: SiteID, ownedBy player: PlayerID) -> [GamePiece] {
        filter { $0.value.site == site && $0.key.owner == player }.map(\.key)
    }
}
