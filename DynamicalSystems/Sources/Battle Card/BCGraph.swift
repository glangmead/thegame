//
//  BCGraph.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation
import CoreGraphics

struct BCGraph {
    // City names
    static let alliedCities = ["Eindhoven", "Grave", "Nijmegen", "Arnhem"]
    static let roadCities = ["Belgium", "Eindhoven", "Grave", "Nijmegen", "Arnhem"]
    static let germanCities = ["Eindhoven", "Grave", "Nijmegen", "Arnhem"]

    // Off-board site tags
    static let removed = "removed"
    static let weatherTrack = "weather"

    static func board(cellSize: CGFloat = 60) -> SiteGraph {
        var graph = SiteGraph()

        // Road track (5 cities including Belgium)
        var roadSites: [SiteID] = []
        for (i, city) in roadCities.enumerated() {
            let pos = CGPoint(x: 1 * cellSize, y: CGFloat(i) * cellSize)
            let id = graph.addSite(position: pos, tags: ["road", city.lowercased()])
            roadSites.append(id)
        }
        connectTrack(&graph, sites: roadSites)
        graph.tracks["road"] = roadSites

        // Allied track (4 cities, no Belgium)
        var alliedSites: [SiteID] = []
        for (i, city) in alliedCities.enumerated() {
            let pos = CGPoint(x: 0 * cellSize, y: CGFloat(i + 1) * cellSize)
            let id = graph.addSite(position: pos, tags: ["allied", city.lowercased()])
            alliedSites.append(id)
        }
        connectTrack(&graph, sites: alliedSites)
        graph.tracks["allied"] = alliedSites

        // German track (4 cities, no Belgium)
        var germanSites: [SiteID] = []
        for (i, city) in germanCities.enumerated() {
            let pos = CGPoint(x: 2 * cellSize, y: CGFloat(i + 1) * cellSize)
            let id = graph.addSite(position: pos, tags: ["german", city.lowercased()])
            germanSites.append(id)
        }
        connectTrack(&graph, sites: germanSites)
        graph.tracks["german"] = germanSites

        // Cross-track adjacency at each shared city (Eindhoven, Grave, Nijmegen, Arnhem)
        for i in 0..<4 {
            let roadIndex = i + 1  // skip Belgium on road track
            // Allied <-> Road
            graph.sites[alliedSites[i]]?.adjacency[.custom("road")] = roadSites[roadIndex]
            graph.sites[roadSites[roadIndex]]?.adjacency[.custom("allied")] = alliedSites[i]
            // Allied <-> German
            graph.sites[alliedSites[i]]?.adjacency[.custom("german")] = germanSites[i]
            graph.sites[germanSites[i]]?.adjacency[.custom("allied")] = alliedSites[i]
            // Road <-> German
            graph.sites[roadSites[roadIndex]]?.adjacency[.custom("german")] = germanSites[i]
            graph.sites[germanSites[i]]?.adjacency[.custom("road")] = roadSites[roadIndex]
        }

        // Off-board sites
        _ = graph.addSite(position: CGPoint(x: -cellSize, y: 0), tags: [removed])
        _ = graph.addSite(position: CGPoint(x: 3 * cellSize, y: 0), tags: [weatherTrack, "fog"])
        _ = graph.addSite(position: CGPoint(x: 3 * cellSize, y: cellSize), tags: [weatherTrack, "clear"])

        return graph
    }

    private static func connectTrack(_ graph: inout SiteGraph, sites: [SiteID]) {
        for i in 0..<(sites.count - 1) {
            graph.connect(sites[i], to: sites[i + 1], direction: .next)
        }
        if let first = sites.first, let last = sites.last, sites.count > 1 {
            graph.sites[first]?.adjacency[.top] = last
            graph.sites[last]?.adjacency[.bottom] = first
        }
    }
}

// MARK: - BCPieceAdapter

struct BCPieceAdapter {
    /// GamePiece IDs match BattleCardComponents.Piece.rawValue
    static func pieces() -> [GamePiece] {
        BattleCardComponents.Piece.allCases.map { piece in
            let owner: PlayerID?
            if BattleCardComponents.Piece.allies().contains(piece) || piece == .thirtycorps {
                owner = PlayerID(0)  // allies
            } else {
                owner = PlayerID(1)  // germans
            }
            return GamePiece(id: piece.rawValue, kind: .die(sides: 6), owner: owner)
        }
    }

    /// Map BattleCard state to a GameSection.
    static func section(from state: BattleCard.State, graph: SiteGraph) -> GameSection {
        var section: GameSection = [:]
        let pieces = pieces()

        for bcPiece in BattleCardComponents.Piece.allCases {
            guard let gp = pieces.first(where: { $0.id == bcPiece.rawValue }) else { continue }
            let face = state.strength[bcPiece]?.rawValue ?? 0

            guard let pos = state.position[bcPiece] else { continue }

            switch pos {
            case .offBoard:
                let removedSite = graph.sites.values.first { $0.tags.contains(BCGraph.removed) }?.id
                section[gp] = .dieShowing(face: face, at: removedSite)

            case .onTrack(let cityIndex):
                let siteID: SiteID?
                if BattleCardComponents.Piece.allies().contains(bcPiece) {
                    // Allied pieces on allied track (no Belgium, so index = cityIndex - 1)
                    let trackIndex = cityIndex - 1
                    siteID = graph.tracks["allied"]?[safe: trackIndex]
                } else if bcPiece == .thirtycorps {
                    // 30 Corps on road track (direct index)
                    siteID = graph.tracks["road"]?[safe: cityIndex]
                } else {
                    // German pieces on german track (no Belgium, so index = cityIndex - 1)
                    let trackIndex = cityIndex - 1
                    siteID = graph.tracks["german"]?[safe: trackIndex]
                }
                section[gp] = .dieShowing(face: face, at: siteID)
            }
        }

        return section
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
