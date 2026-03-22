//
//  MCGraph.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation
import CoreGraphics
import SpriteKit

struct MCGraph {
  typealias Location = MalayanCampaignComponents.Location

  // Layout: Two converging roads
  // Trunk (left):   Jitra(0) -> Kampar(1) -> KL(2) -> Kluang(3) -> Singapore(4)
  // Eastern (right): KB(0) -> Kuantan(1) -> Endau(2) -> Kluang(3) -> Singapore(4)
  // Kluang and Singapore are shared (same row)

  /// Row position for each location on the allied track.
  private static let alliedLocationRow: [Location: CGFloat] = [
    .jitra: 0, .kotaBharu: 0,
    .kampar: 1, .kuantan: 1,
    .kualaLumpur: 2, .endau: 2,
    .kluang: 3, .singapore: 4
  ]

  static func board(cellSize: CGFloat = 75) -> SiteGraph {
    var graph = SiteGraph()

    graph.tracks["trunk"] = buildTrackSites(
      &graph, locations: [.jitra, .kampar, .kualaLumpur, .kluang, .singapore],
      column: 0, cellSize: cellSize, tag: "trunk"
    )
    graph.tracks["eastern"] = buildTrackSites(
      &graph, locations: [.kotaBharu, .kuantan, .endau, .kluang, .singapore],
      column: 2, cellSize: cellSize, tag: "eastern"
    )
    graph.tracks["allied"] = buildAlliedTrackSites(&graph, cellSize: cellSize)

    return graph
  }

  /// Build sites for a road track (trunk or eastern) at the given column.
  private static func buildTrackSites(
    _ graph: inout SiteGraph, locations: [Location],
    column: CGFloat, cellSize: CGFloat, tag: String
  ) -> [SiteID] {
    var sites: [SiteID] = []
    for (row, loc) in locations.enumerated() {
      let pos = CGPoint(x: column * cellSize, y: CGFloat(row) * cellSize)
      let siteID = graph.addSite(position: pos, tags: [tag, loc.description.lowercased()])
      graph.sites[siteID]?.displayName = loc.description
      sites.append(siteID)
    }
    connectTrack(&graph, sites: sites)
    return sites
  }

  /// Build allied track sites using the row lookup table.
  private static func buildAlliedTrackSites(_ graph: inout SiteGraph, cellSize: CGFloat) -> [SiteID] {
    let alliedLocations: [Location] = [.jitra, .kotaBharu, .kampar, .kuantan, .kualaLumpur, .endau, .kluang, .singapore]
    var sites: [SiteID] = []
    for loc in alliedLocations {
      let row = alliedLocationRow[loc] ?? 0
      let pos = CGPoint(x: 1 * cellSize, y: row * cellSize)
      let siteID = graph.addSite(position: pos, tags: ["allied", loc.description.lowercased()])
      sites.append(siteID)
    }
    return sites
  }

  private static func connectTrack(_ graph: inout SiteGraph, sites: [SiteID]) {
    for index in 0..<(sites.count - 1) {
      graph.connect(sites[index], to: sites[index + 1], direction: .next)
    }
    if let first = sites.first, let last = sites.last, sites.count > 1 {
      graph.sites[first]?.adjacency[.top] = last
      graph.sites[last]?.adjacency[.bottom] = first
    }
  }

  /// Map Location to allied track index
  static func alliedTrackIndex(for loc: MalayanCampaignComponents.Location) -> Int? {
    let order: [Location] = [.jitra, .kotaBharu, .kampar, .kuantan, .kualaLumpur, .endau, .kluang, .singapore]
    return order.firstIndex(of: loc)
  }

  /// Map Location to trunk track index (nil if not on trunk road)
  static func trunkTrackIndex(for loc: MalayanCampaignComponents.Location) -> Int? {
    MalayanCampaignComponents.trunkRoad.firstIndex(of: loc)
  }

  /// Map Location to eastern track index (nil if not on eastern road)
  static func easternTrackIndex(for loc: MalayanCampaignComponents.Location) -> Int? {
    MalayanCampaignComponents.easternRoad.firstIndex(of: loc)
  }
}

// MARK: - MCPieceAdapter

struct MCPieceAdapter {
  static func pieces() -> [GamePiece] {
    MalayanCampaignComponents.Piece.allCases.map { piece in
      let owner: PlayerID?
      if MalayanCampaignComponents.Piece.allies().contains(piece) {
        owner = PlayerID(0) // allies
      } else {
        owner = PlayerID(1) // japanese
      }
      return GamePiece(id: piece.rawValue, kind: .die(sides: 6), owner: owner, displayName: piece.shortName)
    }
  }

  static func section(from state: MalayanCampaign.State, graph: SiteGraph) -> GameSection {
    var section: GameSection = [:]
    let pieces = pieces()

    for mcPiece in MalayanCampaignComponents.Piece.allCases {
      guard let piece = pieces.first(where: { $0.id == mcPiece.rawValue }) else { continue }
      let face = state.strength[mcPiece]?.rawValue ?? 0

      guard let pos = state.position[mcPiece] else { continue }

      switch pos {
      case .offBoard:
        continue
      case .at(let loc):
        let siteID: SiteID?
        if MalayanCampaignComponents.Piece.allies().contains(mcPiece) {
          siteID = graph.tracks["allied"]?[safe: MCGraph.alliedTrackIndex(for: loc) ?? -1]
        } else if mcPiece == .japTrunk {
          siteID = graph.tracks["trunk"]?[safe: MCGraph.trunkTrackIndex(for: loc) ?? -1]
        } else {
          siteID = graph.tracks["eastern"]?[safe: MCGraph.easternTrackIndex(for: loc) ?? -1]
        }
        section[piece] = .dieShowing(face: face, at: siteID)
      }
    }

    return section
  }

  static func siteHighlights(from state: MalayanCampaign.State, graph: SiteGraph) -> [SiteID: SKColor] {
    // No control tracking in Malayan Campaign - return empty
    [:]
  }
}
