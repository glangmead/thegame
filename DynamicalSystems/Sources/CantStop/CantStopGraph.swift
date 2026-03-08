//
//  CantStopGraph.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation
import CoreGraphics

struct CantStopGraph {
    /// Column numbers 2-12 with their heights.
    static let columnHeights: [(col: Int, height: Int)] = [
        (2, 3), (3, 5), (4, 7), (5, 9), (6, 11),
        (7, 13),
        (8, 11), (9, 9), (10, 7), (11, 5), (12, 3)
    ]

    /// Off-board site tag names
    static let whiteTray = "whiteTray"
    static let placeholderTray = "placeholderTray"
    static let diceTray = "diceTray"

    /// Build the CantStop board graph.
    static func board(cellSize: CGFloat = 40) -> SiteGraph {
        var graph = SiteGraph()

        // Create column tracks
        for (colNum, height) in columnHeights {
            var trackSites: [SiteID] = []
            for row in 0..<height {
                let pos = CGPoint(
                    x: CGFloat(colNum) * cellSize,
                    y: CGFloat(row) * cellSize
                )
                let id = graph.addSite(position: pos, tags: ["col\(colNum)", "board"])
                trackSites.append(id)
            }

            // Connect sequential
            for index in 0..<(trackSites.count - 1) {
                graph.connect(trackSites[index], to: trackSites[index + 1], direction: .next)
            }

            // Top/bottom shortcuts
            if let first = trackSites.first, let last = trackSites.last, trackSites.count > 1 {
                graph.sites[first]?.adjacency[.top] = last
                graph.sites[last]?.adjacency[.bottom] = first
            }

            graph.tracks["col\(colNum)"] = trackSites
        }

        // Off-board tray sites
        _ = graph.addSite(position: CGPoint(x: 0, y: -cellSize), tags: [whiteTray])
        _ = graph.addSite(position: CGPoint(x: 0, y: -2 * cellSize), tags: [placeholderTray])
        _ = graph.addSite(position: CGPoint(x: 0, y: -3 * cellSize), tags: [diceTray])

        return graph
    }

    /// Look up the SiteID for a given column and row.
    static func siteID(in graph: SiteGraph, col: Int, row: Int) -> SiteID? {
        guard let track = graph.tracks["col\(col)"] else { return nil }
        guard row >= 0 && row < track.count else { return nil }
        return track[row]
    }

    /// Look up the off-board tray site by tag name.
    static func traySite(in graph: SiteGraph, named name: String) -> SiteID? {
        graph.sites.values.first { $0.tags.contains(name) }?.id
    }
}

struct CantStopPieceAdapter {
    /// Stable ID mapping for GamePiece.
    /// Whites: 1-3 (matching WhitePiece.rawValue)
    /// Placeholders: 100 + playerIndex*20 + col.rawValue
    /// Dice: 200 + die index
    static func gamePieceID(for piece: CantStop.Piece) -> Int {
        switch piece {
        case .white(let whitePiece): return whitePiece.rawValue  // 1, 2, 3
        case .placeholder(let player, let col):
            let playerIndex: Int
            switch player {
            case .player1: playerIndex = 0
            case .player2: playerIndex = 1
            case .player3: playerIndex = 2
            case .player4: playerIndex = 3
            }
            return 100 + playerIndex * 20 + col.rawValue
        }
    }

    static func playerID(for player: CantStop.Player) -> PlayerID {
        switch player {
        case .player1: return PlayerID(0)
        case .player2: return PlayerID(1)
        case .player3: return PlayerID(2)
        case .player4: return PlayerID(3)
        }
    }

    /// Create the fixed set of GamePiece objects for a CantStop game.
    static func pieces() -> [GamePiece] {
        var result: [GamePiece] = []

        // White pieces (tokens, no owner)
        for whitePiece in CantStop.WhitePiece.allCases {
            result.append(GamePiece(id: whitePiece.rawValue, kind: .token, owner: nil))
        }

        // Player placeholders (tokens, owned)
        for player in CantStop.Player.allCases {
            let pid = playerID(for: player)
            for col in CantStop.Column.allCases where col != .none {
                let piece = CantStop.Piece.placeholder(player, col)
                result.append(GamePiece(id: gamePieceID(for: piece), kind: .token, owner: pid))
            }
        }

        // Dice
        for dieIndex in CantStop.Die.allCases.indices {
            result.append(GamePiece(id: 200 + dieIndex, kind: .die(sides: 6), owner: nil))
        }

        return result
    }

    /// Map current CantStop state to a GameSection.
    static func section(from state: CantStop.State, graph: SiteGraph) -> GameSection {
        var section: GameSection = [:]

        // Map piece positions
        for (piece, pos) in state.position {
            let gpID = gamePieceID(for: piece)
            let owner: PlayerID?
            switch piece {
            case .white: owner = nil
            case .placeholder(let player, _): owner = playerID(for: player)
            }
            let gamePiece = GamePiece(id: gpID, kind: .token, owner: owner)

            if pos.col == .none {
                // Off-board — use tray site
                let trayName: String
                switch piece {
                case .white: trayName = CantStopGraph.whiteTray
                case .placeholder: trayName = CantStopGraph.placeholderTray
                }
                if let traySite = CantStopGraph.traySite(in: graph, named: trayName) {
                    section[gamePiece] = .at(traySite)
                }
            } else {
                if let siteID = CantStopGraph.siteID(in: graph, col: pos.col.rawValue, row: pos.row) {
                    section[gamePiece] = .at(siteID)
                }
            }
        }

        // Map dice
        for (dieIndex, die) in CantStop.Die.allCases.enumerated() {
            let face = state.dice[die]?.rawValue ?? 0
            let diceSite = CantStopGraph.traySite(in: graph, named: CantStopGraph.diceTray)
            let piece = GamePiece(id: 200 + dieIndex, kind: .die(sides: 6), owner: nil)
            section[piece] = .dieShowing(face: face, at: diceSite)
        }

        return section
    }
}
