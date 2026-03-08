import Foundation
import CoreGraphics

enum Direction: String, Codable, Equatable, Hashable, CaseIterable {
    case next, previous, top, bottom
    case north, south, east, west
    case northeast, northwest, southeast, southwest

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
}

struct SiteGraph: Codable, Equatable {
    var sites: [SiteID: Site] = [:]
    var tracks: [String: [SiteID]] = [:]
    private var nextID: Int = 0

    @discardableResult
    mutating func addSite(
        id: SiteID? = nil,
        position: CGPoint,
        tags: Set<String> = []
    ) -> SiteID {
        let siteID = id ?? SiteID(nextID)
        sites[siteID] = Site(id: siteID, position: position, tags: tags)
        nextID = max(nextID, siteID.raw + 1)
        return siteID
    }

    mutating func connect(_ from: SiteID, to: SiteID, direction: Direction) {
        sites[from]?.adjacency[direction] = to
        sites[to]?.adjacency[direction.opposite] = from
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

            for i in 0..<(trackSites.count - 1) {
                graph.connect(trackSites[i], to: trackSites[i + 1], direction: .next)
            }

            if let first = trackSites.first, let last = trackSites.last, trackSites.count > 1 {
                graph.sites[first]?.adjacency[.top] = last
                graph.sites[last]?.adjacency[.bottom] = first
            }

            graph.tracks["col\(colIndex)"] = trackSites
        }

        return graph
    }
}
