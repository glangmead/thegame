import CoreGraphics

enum GraphBuilder {
  struct TrackInfo {
    let name: String
    let length: Int
    let isWall: Bool
  }

  static func build(_ sexpr: SExpr) throws -> SiteGraph {
    guard let children = sexpr.children, sexpr.tag == "graph" else {
      throw DSLError.expectedForm("graph")
    }
    var graph = SiteGraph()
    var tracks: [TrackInfo] = []

    for child in children.dropFirst() {
      guard let tag = child.tag, let parts = child.children else { continue }
      switch tag {
      case "track":
        tracks.append(parseTrack(parts))
      case "site":
        addNamedSite(parts, to: &graph)
      default:
        continue
      }
    }

    materializeTracks(tracks, into: &graph)
    return graph
  }

  // MARK: - Private helpers

  private static func parseTrack(_ parts: [SExpr]) -> TrackInfo {
    let name = parts[1].stringValue ?? parts[1].atomValue ?? ""
    var length = 6
    var isWall = false
    var idx = 2
    while idx < parts.count {
      let atomKey = parts[idx].atomValue ?? ""
      if atomKey == "length:" && idx + 1 < parts.count {
        length = parts[idx + 1].intValue ?? 6
        idx += 2
      } else if atomKey == "wall:" && idx + 1 < parts.count {
        isWall = parts[idx + 1].atomValue == "true"
        idx += 2
      } else {
        idx += 1
      }
    }
    return TrackInfo(name: name, length: length, isWall: isWall)
  }

  private static func addNamedSite(_ parts: [SExpr], to graph: inout SiteGraph) {
    let name = parts[1].stringValue ?? parts[1].atomValue ?? ""
    graph.addSite(
      position: .zero,
      tags: ["named:\(name)"],
      label: name
    )
  }

  private static func materializeTracks(_ tracks: [TrackInfo], into graph: inout SiteGraph) {
    for (row, track) in tracks.enumerated() {
      var siteIDs: [SiteID] = []
      var prevID: SiteID?
      for space in 1...track.length {
        var tags: Set<String> = ["track:\(track.name)", "space:\(space)"]
        if track.isWall { tags.insert("wall") }
        let position = CGPoint(
          x: CGFloat(space * 40),
          y: CGFloat(row * 40)
        )
        let siteID = graph.addSite(
          position: position,
          tags: tags,
          label: "\(track.name)_\(space)"
        )
        siteIDs.append(siteID)
        if let prev = prevID {
          graph.connect(prev, to: siteID, direction: .next)
        }
        prevID = siteID
      }
      var trackTags: Set<String> = []
      if track.isWall { trackTags.insert("wall") }
      graph.addTrack(track.name, sites: siteIDs, tags: trackTags)
    }
  }
}
