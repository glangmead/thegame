import CoreGraphics

// MARK: - Shared graph types

enum GraphBuilder {
  struct TrackInfo {
    let name: String
    let length: Int
    let isWall: Bool
    let displayNames: [String]
    let tags: Set<String>
  }

  struct CrossConnect {
    let trackA: String
    let trackB: String
    let offset: Int
  }
}

// MARK: - JSONGraphBuilder

enum JSONGraphBuilder {

  static func build(_ json: JSONValue) throws -> SiteGraph {
    var graph = SiteGraph()
    let dict = json.objectValue ?? [:]
    var tracks: [GraphBuilder.TrackInfo] = []
    var crossConnects: [GraphBuilder.CrossConnect] = []

    // Parse tracks
    if let tracksArray = dict["tracks"]?.arrayValue {
      for item in tracksArray {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue else {
          throw DSLError.malformed("track entry missing name")
        }
        let length = obj["length"]?.intValue ?? 6
        let isWall = obj["wall"]?.boolValue ?? false
        let displayNames = obj["displayNames"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let tags: Set<String> = Set(obj["tags"]?.arrayValue?.compactMap(\.stringValue) ?? [])
        tracks.append(GraphBuilder.TrackInfo(
          name: name,
          length: length,
          isWall: isWall,
          displayNames: displayNames,
          tags: tags
        ))
      }
    }

    // Parse connections
    if let connectionsArray = dict["connections"]?.arrayValue {
      for item in connectionsArray {
        guard let obj = item.objectValue,
              let fromTrack = obj["from"]?.stringValue,
              let toTrack = obj["to"]?.stringValue else {
          throw DSLError.malformed("connection entry missing from or to")
        }
        let offset = obj["offset"]?.intValue ?? 0
        crossConnects.append(GraphBuilder.CrossConnect(trackA: fromTrack, trackB: toTrack, offset: offset))
      }
    }

    materializeTracks(tracks, into: &graph)
    applyCrossConnects(crossConnects, in: &graph)
    return graph
  }

  // MARK: - Private helpers

  private static func materializeTracks(
    _ tracks: [GraphBuilder.TrackInfo],
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
        let displayName: String? = siteIndex < track.displayNames.count
          ? track.displayNames[siteIndex]
          : nil
        let siteID = graph.addSite(
          position: position,
          tags: tags,
          displayName: displayName
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
    _ crossConnects: [GraphBuilder.CrossConnect],
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
