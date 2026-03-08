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
            for i in 0..<(trackSites.count - 1) {
                graph.connect(trackSites[i], to: trackSites[i + 1], direction: .next)
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
