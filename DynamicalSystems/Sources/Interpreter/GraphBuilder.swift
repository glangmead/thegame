import CoreGraphics

enum GraphBuilder {
  struct TrackInfo {
    let name: String
    let length: Int
    let isWall: Bool
    let labels: [String]
    let tags: Set<String>
  }

  struct CrossConnect {
    let trackA: String
    let trackB: String
    let offset: Int
  }

  static func build(_ sexpr: SExpr) throws -> SiteGraph {
    guard let children = sexpr.children, sexpr.tag == "graph" else {
      throw DSLError.expectedForm("graph")
    }
    var graph = SiteGraph()
    var tracks: [TrackInfo] = []
    var crossConnects: [CrossConnect] = []
    var namedSiteNames: [String] = []

    for child in children.dropFirst() {
      guard let tag = child.tag, let parts = child.children else { continue }
      switch tag {
      case "track":
        tracks.append(parseTrack(parts))
      case "site":
        let name = parts[1].stringValue ?? parts[1].atomValue ?? ""
        namedSiteNames.append(name)
      case "crossConnect":
        crossConnects.append(parseCrossConnect(parts))
      default:
        continue
      }
    }

    materializeTracks(tracks, into: &graph)
    applyCrossConnects(crossConnects, in: &graph)
    addNamedSites(namedSiteNames, to: &graph)
    return graph
  }

  // MARK: - Private helpers

  private static func parseTrack(_ parts: [SExpr]) -> TrackInfo {
    let name = parts[1].stringValue ?? parts[1].atomValue ?? ""
    var length = 6
    var isWall = false
    var labels: [String] = []
    var tags: Set<String> = []
    var idx = 2
    while idx < parts.count {
      let atomKey = parts[idx].atomValue ?? ""
      if atomKey == "length:" && idx + 1 < parts.count {
        length = parts[idx + 1].intValue ?? 6
        idx += 2
      } else if atomKey == "wall:" && idx + 1 < parts.count {
        isWall = parts[idx + 1].atomValue == "true"
        idx += 2
      } else if atomKey == "labels:" && idx + 1 < parts.count,
                let list = parts[idx + 1].children {
        labels = list.compactMap { $0.stringValue ?? $0.atomValue }
        idx += 2
      } else if atomKey == "tags:" && idx + 1 < parts.count,
                let list = parts[idx + 1].children {
        tags = Set(list.compactMap { $0.stringValue ?? $0.atomValue })
        idx += 2
      } else {
        idx += 1
      }
    }
    return TrackInfo(
      name: name, length: length, isWall: isWall,
      labels: labels, tags: tags
    )
  }

  private static func parseCrossConnect(_ parts: [SExpr]) -> CrossConnect {
    let trackA = parts[1].stringValue ?? parts[1].atomValue ?? ""
    let trackB = parts[2].stringValue ?? parts[2].atomValue ?? ""
    var offset = 0
    var idx = 3
    while idx < parts.count {
      let atomKey = parts[idx].atomValue ?? ""
      if atomKey == "offset:" && idx + 1 < parts.count {
        offset = parts[idx + 1].intValue ?? 0
        idx += 2
      } else {
        idx += 1
      }
    }
    return CrossConnect(trackA: trackA, trackB: trackB, offset: offset)
  }

  private static func addNamedSites(
    _ names: [String],
    to graph: inout SiteGraph
  ) {
    let spacing: CGFloat = 80
    let maxY = graph.sites.values.map(\.position.y).max() ?? 0
    let baseY = maxY + 2 * spacing
    for (index, name) in names.enumerated() {
      graph.addSite(
        position: CGPoint(x: CGFloat(index) * spacing, y: baseY),
        tags: ["named:\(name)"],
        label: name
      )
    }
  }

  private static func materializeTracks(
    _ tracks: [TrackInfo],
    into graph: inout SiteGraph
  ) {
    let spacing: CGFloat = 80
    let maxHeight = tracks.map(\.length).max() ?? 0
    for (trackIndex, track) in tracks.enumerated() {
      var siteIDs: [SiteID] = []
      var prevID: SiteID?
      let yOffset = maxHeight - track.length
      for siteIndex in 0..<track.length {
        var tags: Set<String> = [
          "track:\(track.name)", "space:\(siteIndex + 1)"
        ]
        if track.isWall { tags.insert("wall") }
        tags.formUnion(track.tags)
        let position = CGPoint(
          x: CGFloat(trackIndex) * spacing,
          y: CGFloat(siteIndex + yOffset) * spacing
        )
        let label: String
        if siteIndex < track.labels.count {
          label = track.labels[siteIndex]
        } else {
          label = "\(track.name)_\(siteIndex + 1)"
        }
        let siteID = graph.addSite(
          position: position,
          tags: tags,
          label: label
        )
        siteIDs.append(siteID)
        if let prev = prevID {
          graph.connect(prev, to: siteID, direction: .next)
        }
        prevID = siteID
      }
      var trackTags = track.tags
      if track.isWall { trackTags.insert("wall") }
      graph.addTrack(track.name, sites: siteIDs, tags: trackTags)
    }
  }

  private static func applyCrossConnects(
    _ crossConnects: [CrossConnect],
    in graph: inout SiteGraph
  ) {
    for conn in crossConnects {
      guard let sitesA = graph.tracks[conn.trackA],
            let sitesB = graph.tracks[conn.trackB] else { continue }
      for idx in sitesA.indices {
        let target = idx + conn.offset
        guard target >= 0, target < sitesB.count else { continue }
        graph.sites[sitesA[idx]]?.adjacency[.custom(conn.trackB)] = sitesB[target]
        graph.sites[sitesB[target]]?.adjacency[.custom(conn.trackA)] = sitesA[idx]
      }
    }
  }
}
