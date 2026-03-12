//
//  HeartsGraph.swift
//  DynamicalSystems
//
//  Hearts — SiteGraph with 12 sites for card rendering positions.
//

import Foundation
import CoreGraphics

struct HeartsGraph {
  // Well-known IDs at 500+ per project convention
  static let northHand = SiteID(500)
  static let eastHand = SiteID(501)
  static let southHand = SiteID(502)
  static let westHand = SiteID(503)

  static let northTrick = SiteID(504)
  static let eastTrick = SiteID(505)
  static let southTrick = SiteID(506)
  static let westTrick = SiteID(507)

  static let northPile = SiteID(508)
  static let eastPile = SiteID(509)
  static let southPile = SiteID(510)
  static let westPile = SiteID(511)

  static func board(cellSize: CGFloat = 40) -> SiteGraph {
    var graph = SiteGraph()
    let center = CGPoint(x: 6 * cellSize, y: 6 * cellSize)

    // Hand zones — SpriteKit y-up: north=top, south=bottom
    _ = graph.addSite(
      id: northHand, position: CGPoint(x: center.x, y: 11 * cellSize), tags: ["hand", "north"])
    _ = graph.addSite(
      id: eastHand, position: CGPoint(x: 11 * cellSize, y: center.y), tags: ["hand", "east"])
    _ = graph.addSite(
      id: southHand, position: CGPoint(x: center.x, y: 1 * cellSize), tags: ["hand", "south"])
    _ = graph.addSite(
      id: westHand, position: CGPoint(x: 1 * cellSize, y: center.y), tags: ["hand", "west"])

    // Trick positions (center cross, offset toward each player)
    _ = graph.addSite(
      id: northTrick, position: CGPoint(x: center.x, y: center.y + cellSize),
      tags: ["trick", "north"])
    _ = graph.addSite(
      id: eastTrick, position: CGPoint(x: center.x + cellSize, y: center.y),
      tags: ["trick", "east"])
    _ = graph.addSite(
      id: southTrick, position: CGPoint(x: center.x, y: center.y - cellSize),
      tags: ["trick", "south"])
    _ = graph.addSite(
      id: westTrick, position: CGPoint(x: center.x - cellSize, y: center.y),
      tags: ["trick", "west"])

    // Won-tricks pile positions (in each player's corner)
    _ = graph.addSite(
      id: northPile, position: CGPoint(x: center.x + 3 * cellSize, y: 11 * cellSize),
      tags: ["pile", "north"])
    _ = graph.addSite(
      id: eastPile, position: CGPoint(x: 11 * cellSize, y: center.y - 3 * cellSize),
      tags: ["pile", "east"])
    _ = graph.addSite(
      id: southPile, position: CGPoint(x: center.x - 3 * cellSize, y: 1 * cellSize),
      tags: ["pile", "south"])
    _ = graph.addSite(
      id: westPile, position: CGPoint(x: 1 * cellSize, y: center.y + 3 * cellSize),
      tags: ["pile", "west"])

    return graph
  }
}
