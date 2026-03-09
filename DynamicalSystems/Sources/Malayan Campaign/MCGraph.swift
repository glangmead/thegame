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

  static func board(cellSize: CGFloat = 75) -> SiteGraph {
    var graph = SiteGraph()

    // Trunk road sites (left column): Jitra, Kampar, KL, Kluang, Singapore
    let trunkLocations: [Location] = [.jitra, .kampar, .kualaLumpur, .kluang, .singapore]
    var trunkSites: [SiteID] = []
    for (row, loc) in trunkLocations.enumerated() {
      let pos = CGPoint(x: 0 * cellSize, y: CGFloat(row) * cellSize)
      let siteID = graph.addSite(position: pos, tags: ["trunk", loc.description.lowercased()])
      graph.sites[siteID]?.label = loc.description
      trunkSites.append(siteID)
    }
    connectTrack(&graph, sites: trunkSites)
    graph.tracks["trunk"] = trunkSites

    // Eastern road sites (right column): Kota Bharu, Kuantan, Endau, Kluang, Singapore
    let easternLocations: [Location] = [.kotaBharu, .kuantan, .endau, .kluang, .singapore]
    var easternSites: [SiteID] = []
    for (row, loc) in easternLocations.enumerated() {
      let pos = CGPoint(x: 2 * cellSize, y: CGFloat(row) * cellSize)
      let siteID = graph.addSite(position: pos, tags: ["eastern", loc.description.lowercased()])
      graph.sites[siteID]?.label = loc.description
      easternSites.append(siteID)
    }
    connectTrack(&graph, sites: easternSites)
    graph.tracks["eastern"] = easternSites

    // Allied track (center column) - one site per location that has allied units
    // All 7 locations + Singapore
    let alliedLocations: [Location] = [.jitra, .kotaBharu, .kampar, .kuantan, .kualaLumpur, .endau, .kluang, .singapore]
    var alliedSites: [SiteID] = []
    for loc in alliedLocations {
      // Position allied track in the center column
      let row: CGFloat
      switch loc {
      case .jitra:       row = 0
      case .kotaBharu:   row = 0  // same row as Jitra
      case .kampar:      row = 1
      case .kuantan:     row = 1  // same row as Kampar
      case .kualaLumpur: row = 2
      case .endau:       row = 2  // same row as KL
      case .kluang:      row = 3
      case .singapore:   row = 4
      }
      let pos = CGPoint(x: 1 * cellSize, y: row * cellSize)
      let siteID = graph.addSite(position: pos, tags: ["allied", loc.description.lowercased()])
      alliedSites.append(siteID)
    }
    graph.tracks["allied"] = alliedSites

    return graph
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
      return GamePiece(id: piece.rawValue, kind: .die(sides: 6), owner: owner, label: piece.shortName)
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
