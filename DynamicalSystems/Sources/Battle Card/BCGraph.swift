//
//  BCGraph.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation
import CoreGraphics
import SpriteKit

struct BCGraph {
  // City names
  static let alliedCities = ["Eindhoven", "Grave", "Nijmegen", "Arnhem"]
  static let roadCities = ["Belgium", "Eindhoven", "Grave", "Nijmegen", "Arnhem"]
  static let germanCities = ["Eindhoven", "Grave", "Nijmegen", "Arnhem"]

  static func board(cellSize: CGFloat = 60) -> SiteGraph {
    var graph = SiteGraph()

    // Road track (5 cities including Belgium)
    var roadSites: [SiteID] = []
    for (cityIndex, city) in roadCities.enumerated() {
      let pos = CGPoint(x: 1 * cellSize, y: CGFloat(cityIndex) * cellSize)
      let siteID = graph.addSite(position: pos, tags: ["road", city.lowercased()])
      graph.sites[siteID]?.displayName = city
      roadSites.append(siteID)
    }
    connectTrack(&graph, sites: roadSites)
    graph.addTrack("road", sites: roadSites)

    // Allied track (4 cities, no Belgium)
    var alliedSites: [SiteID] = []
    for (cityIndex, city) in alliedCities.enumerated() {
      let pos = CGPoint(x: 0 * cellSize, y: CGFloat(cityIndex + 1) * cellSize)
      let id = graph.addSite(position: pos, tags: ["allied", city.lowercased()])
      alliedSites.append(id)
    }
    connectTrack(&graph, sites: alliedSites)
    graph.addTrack("allied", sites: alliedSites)

    // German track (4 cities, no Belgium)
    var germanSites: [SiteID] = []
    for (cityIndex, city) in germanCities.enumerated() {
      let pos = CGPoint(x: 2 * cellSize, y: CGFloat(cityIndex + 1) * cellSize)
      let id = graph.addSite(position: pos, tags: ["german", city.lowercased()])
      germanSites.append(id)
    }
    connectTrack(&graph, sites: germanSites)
    graph.addTrack("german", sites: germanSites)

    // Cross-track adjacency at each shared city (Eindhoven, Grave, Nijmegen, Arnhem)
    for cityIndex in 0..<4 {
      let roadIndex = cityIndex + 1  // skip Belgium on road track
      // Allied <-> Road
      graph.sites[alliedSites[cityIndex]]?.adjacency[.custom("road")] = roadSites[roadIndex]
      graph.sites[roadSites[roadIndex]]?.adjacency[.custom("allied")] = alliedSites[cityIndex]
      // Allied <-> German
      graph.sites[alliedSites[cityIndex]]?.adjacency[.custom("german")] = germanSites[cityIndex]
      graph.sites[germanSites[cityIndex]]?.adjacency[.custom("allied")] = alliedSites[cityIndex]
      // Road <-> German
      graph.sites[roadSites[roadIndex]]?.adjacency[.custom("german")] = germanSites[cityIndex]
      graph.sites[germanSites[cityIndex]]?.adjacency[.custom("road")] = roadSites[roadIndex]
    }

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
      let kind: GamePiece.PieceKind = piece == .thirtycorps ? .token : .die(sides: 6)
      return GamePiece(id: piece.rawValue, kind: kind, owner: owner, displayName: piece.shortName)
    }
  }

  /// Map BattleCard state to a GameSection.
  static func section(from state: BattleCard.State, graph: SiteGraph) -> GameSection {
    var section: GameSection = [:]
    let pieces = pieces()

    for bcPiece in BattleCardComponents.Piece.allCases {
      guard let piece = pieces.first(where: { $0.id == bcPiece.rawValue }) else { continue }
      let face = state.strength[bcPiece]?.rawValue ?? 0

      guard let pos = state.position[bcPiece] else { continue }

      switch pos {
      case .offBoard:
        continue

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
        if bcPiece == .thirtycorps {
          if let siteID { section[piece] = .at(siteID) }
        } else {
          section[piece] = .dieShowing(face: face, at: siteID)
        }
      }
    }

    return section
  }

  /// Map control state to site highlight colors for the road track.
  static func siteHighlights(from state: BattleCard.State, graph: SiteGraph) -> [SiteID: SKColor] {
    var highlights: [SiteID: SKColor] = [:]
    guard let roadTrack = graph.tracks["road"] else { return highlights }
    for (trackPos, control) in state.control {
      guard let siteID = roadTrack[safe: trackPos] else { continue }
      switch control {
      case .allies:
        highlights[siteID] = SKColor.blue.withAlphaComponent(0.2)
      case .germans:
        highlights[siteID] = SKColor.red.withAlphaComponent(0.2)
      }
    }
    return highlights
  }
}
