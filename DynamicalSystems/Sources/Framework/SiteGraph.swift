//
//  SiteGraph.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation
import CoreGraphics

enum Direction: Codable, Equatable, Hashable {
  case next, previous, top, bottom
  case north, south, east, west
  case northeast, northwest, southeast, southwest
  case custom(String)

  var opposite: Direction {
    switch self {
    case .next: return .previous
    case .previous: return .next
    case .top: return .bottom
    case .bottom: return .top
    case .north: return .south
    case .south: return .north
    case .east: return .west
    case .west: return .east
    case .northeast: return .southwest
    case .southwest: return .northeast
    case .northwest: return .southeast
    case .southeast: return .northwest
    case .custom(let name): return .custom(name)
    }
  }
}

struct SiteID: Hashable, Codable, Equatable, CustomStringConvertible {
  let raw: Int
  init(_ raw: Int) { self.raw = raw }
  var description: String { "site(\(raw))" }
}

struct Site: Codable, Equatable {
  let id: SiteID
  var position: CGPoint
  var adjacency: [Direction: SiteID] = [:]
  var tags: Set<String> = []
  var label: String?
}

struct SiteGraph: Codable, Equatable {
  var sites: [SiteID: Site] = [:]
  var tracks: [String: [SiteID]] = [:]
  var trackTags: [String: Set<String>] = [:]
  private var nextID: Int = 0

  @discardableResult
  mutating func addSite(
    id: SiteID? = nil,
    position: CGPoint,
    tags: Set<String> = [],
    label: String? = nil
  ) -> SiteID {
    let siteID = id ?? SiteID(nextID)
    sites[siteID] = Site(id: siteID, position: position, tags: tags, label: label)
    nextID = max(nextID, siteID.raw + 1)
    return siteID
  }

  // swiftlint:disable:next identifier_name
  mutating func connect(_ from: SiteID, to: SiteID, direction: Direction) {
    sites[from]?.adjacency[direction] = to
    sites[to]?.adjacency[direction.opposite] = from
  }

  mutating func addTrack(_ name: String, sites trackSites: [SiteID], tags: Set<String> = []) {
    tracks[name] = trackSites
    if !tags.isEmpty { trackTags[name] = tags }
  }
}

struct SiteCursor {
  let graph: SiteGraph
  let id: SiteID

  var site: Site? { graph.sites[id] }
  var position: CGPoint? { site?.position }

  var next: SiteCursor? { navigate(.next) }
  var previous: SiteCursor? { navigate(.previous) }
  var top: SiteCursor? { navigate(.top) }
  var bottom: SiteCursor? { navigate(.bottom) }

  func adjacent(_ dir: Direction) -> SiteCursor? { navigate(dir) }

  private func navigate(_ dir: Direction) -> SiteCursor? {
    guard let dest = graph.sites[id]?.adjacency[dir] else { return nil }
    return SiteCursor(graph: graph, id: dest)
  }
}

extension SiteGraph {
  func site(_ id: SiteID) -> SiteCursor {
    SiteCursor(graph: self, id: id)
  }

  /// Creates a columnar board with variable-height columns.
  /// Each column becomes a named track ("col0", "col1", ...).
  /// Sites have .next/.previous along the column and .top/.bottom to endpoints.
  static func columnar(heights: [Int], spacing: CGFloat = 40) -> SiteGraph {
    var graph = SiteGraph()

    for (colIndex, height) in heights.enumerated() {
      var trackSites: [SiteID] = []
      for row in 0..<height {
        let pos = CGPoint(x: CGFloat(colIndex) * spacing, y: CGFloat(row) * spacing)
        let id = graph.addSite(position: pos, tags: ["col\(colIndex)"])
        trackSites.append(id)
      }

      for index in 0..<(trackSites.count - 1) {
        graph.connect(trackSites[index], to: trackSites[index + 1], direction: .next)
      }

      if let first = trackSites.first, let last = trackSites.last, trackSites.count > 1 {
        graph.sites[first]?.adjacency[.top] = last
        graph.sites[last]?.adjacency[.bottom] = first
      }

      graph.tracks["col\(colIndex)"] = trackSites
    }

    return graph
  }

  /// Creates parallel named tracks of equal length with optional cross-track adjacency.
  /// When `crossDirections` is true, each site gets `.custom(trackName)` adjacency
  /// to the corresponding site on every other track.
  static func parallelTracks(
    names: [String],
    length: Int,
    crossDirections: Bool = false,
    spacing: CGFloat = 40,
    trackSpacing: CGFloat = 40
  ) -> SiteGraph {
    var graph = SiteGraph()
    var trackSites: [[SiteID]] = []

    for (trackIndex, name) in names.enumerated() {
      var sites: [SiteID] = []
      for row in 0..<length {
        let pos = CGPoint(
          x: CGFloat(trackIndex) * trackSpacing,
          y: CGFloat(row) * spacing
        )
        let id = graph.addSite(position: pos, tags: [name])
        sites.append(id)
      }

      for index in 0..<(sites.count - 1) {
        graph.connect(sites[index], to: sites[index + 1], direction: .next)
      }

      if let first = sites.first, let last = sites.last, sites.count > 1 {
        graph.sites[first]?.adjacency[.top] = last
        graph.sites[last]?.adjacency[.bottom] = first
      }

      graph.tracks[name] = sites
      trackSites.append(sites)
    }

    if crossDirections {
      for row in 0..<length {
        for fromTrack in names.indices {
          for (toTrack, toName) in names.enumerated() where fromTrack != toTrack {
            let from = trackSites[fromTrack][row]
            let target = trackSites[toTrack][row]
            graph.sites[from]?.adjacency[.custom(toName)] = target
          }
        }
      }
    }

    return graph
  }
}
