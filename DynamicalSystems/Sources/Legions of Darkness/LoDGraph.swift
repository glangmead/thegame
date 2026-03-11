//
//  LoDGraph.swift
//  DynamicalSystems
//
//  Legions of Darkness — SiteGraph board layout.
//

import Foundation
import CoreGraphics

struct LoDGraph {

  // MARK: - Well-Known Site IDs (fixed for stable lookups)

  // Breach sites (space 0 on wall tracks)
  // IDs start at 500 to avoid colliding with auto-generated IDs (0–~80)
  static let eastBreach = SiteID(500)
  static let westBreach = SiteID(501)
  static let gateBreach = SiteID(502)

  // Upgrade circles
  static let eastUpgrade = SiteID(510)
  static let westUpgrade = SiteID(511)
  static let gateUpgrade = SiteID(512)

  // Card areas
  static let dayDraw = SiteID(520)
  static let nightDraw = SiteID(521)
  static let currentCard = SiteID(522)
  static let dayDiscard = SiteID(523)
  static let nightDiscard = SiteID(524)

  // Items
  static let sword = SiteID(530)
  static let bow = SiteID(531)

  // Reserves
  static let reserves = SiteID(540)

  // MARK: - Board Builder

  static func board(cellSize: CGFloat = 40) -> SiteGraph {
    var graph = SiteGraph()
    let cell = cellSize
    func yPos(_ row: CGFloat) -> CGFloat { (14 - row) * cell }

    registerWellKnownSites(&graph, cell: cell, yPos: yPos)
    addArmyTracks(&graph, cell: cell, yPos: yPos)
    addStatusTracks(&graph, cell: cell, yPos: yPos)
    addTimeTracks(&graph, cell: cell, yPos: yPos)
    addHeaderLabels(&graph, cell: cell, yPos: yPos)
    return graph
  }

  // MARK: - Board Builder Helpers

  private static func registerWellKnownSites(
    _ graph: inout SiteGraph,
    cell: CGFloat,
    yPos: (CGFloat) -> CGFloat
  ) {
    graph.addSite(id: eastBreach, position: CGPoint(x: cell, y: yPos(0)), tags: ["breach"])
    graph.addSite(id: westBreach, position: CGPoint(x: cell, y: yPos(1)), tags: ["breach"])
    graph.addSite(id: gateBreach, position: CGPoint(x: cell, y: yPos(2)), tags: ["breach"])
    graph.addSite(id: eastUpgrade, position: CGPoint(x: 0, y: yPos(0)), tags: ["upgrade"])
    graph.addSite(id: westUpgrade, position: CGPoint(x: 0, y: yPos(1)), tags: ["upgrade"])
    graph.addSite(id: gateUpgrade, position: CGPoint(x: 0, y: yPos(2)), tags: ["upgrade"])
    let cardRow: CGFloat = 12
    graph.addSite(id: dayDraw, position: CGPoint(x: 0, y: yPos(cardRow)), tags: ["card"])
    graph.addSite(id: nightDraw, position: CGPoint(x: cell, y: yPos(cardRow)), tags: ["card"])
    graph.addSite(id: currentCard, position: CGPoint(x: 3 * cell, y: yPos(cardRow)), tags: ["card"])
    graph.addSite(id: dayDiscard, position: CGPoint(x: 5 * cell, y: yPos(cardRow)), tags: ["card"])
    graph.addSite(id: nightDiscard, position: CGPoint(x: 6 * cell, y: yPos(cardRow)), tags: ["card"])
    let itemRow: CGFloat = 14
    graph.addSite(id: sword, position: CGPoint(x: 0, y: yPos(itemRow)), tags: ["item"])
    graph.addSite(id: bow, position: CGPoint(x: cell, y: yPos(itemRow)), tags: ["item"])
    let statusRow: CGFloat = 6
    graph.addSite(id: reserves, position: CGPoint(x: 4 * cell, y: yPos(statusRow)), tags: ["reserves"])

    let labels: [(SiteID, String)] = [
      (eastBreach, "E 0"), (westBreach, "W 0"), (gateBreach, "G 0"),
      (eastUpgrade, "E Up"), (westUpgrade, "W Up"), (gateUpgrade, "G Up"),
      (dayDraw, "Day"), (nightDraw, "Night"), (currentCard, "Card"),
      (dayDiscard, "D Dis"), (nightDiscard, "N Dis"),
      (sword, "Sword"), (bow, "Bow"), (reserves, "Rsv")
    ]
    for (siteID, label) in labels { graph.sites[siteID]?.label = label }
  }

  private static func addArmyTracks(
    _ graph: inout SiteGraph,
    cell: CGFloat,
    yPos: (CGFloat) -> CGFloat
  ) {
    addSingleTrack(&graph, key: "east", prefix: "E", row: 0, count: 6, cell: cell, yPos: yPos)
    addSingleTrack(&graph, key: "west", prefix: "W", row: 1, count: 6, cell: cell, yPos: yPos)
    addSingleTrack(&graph, key: "gate", prefix: "G", row: 2, count: 4, cell: cell, yPos: yPos)
    addSingleTrack(&graph, key: "sky", prefix: "S", row: 3, count: 6, cell: cell, yPos: yPos)
    addSingleTrack(&graph, key: "terror", prefix: "T", row: 4, count: 3, cell: cell, yPos: yPos)
  }

  private static func addStatusTracks(
    _ graph: inout SiteGraph,
    cell: CGFloat,
    yPos: (CGFloat) -> CGFloat
  ) {
    let statusRow: CGFloat = 6

    // Morale: Low, Normal, High
    graph.tracks["morale"] = addLabeledTrack(
      &graph, labels: ["Low", "Norm", "High"],
      xStart: 0, cell: cell, yVal: yPos(statusRow), tag: "morale"
    )

    // Defenders (row 7) — track values from board (rule 8.2)
    // Fighters (Max Melee Attacks): 6 spaces [3, 2, 2, 2, 1, 0]
    graph.tracks["menAtArms"] = addLabeledTrack(
      &graph, labels: ["F0:3", "F1:2", "F2:2", "F3:2", "F4:1", "F5:0"],
      xStart: 0, cell: cell, yVal: yPos(7), tag: "defender"
    )
    // Archers (Max Ranged Attacks): 5 spaces [2, 2, 1, 1, 0]
    graph.tracks["archers"] = addLabeledTrack(
      &graph, labels: ["A0:2", "A1:2", "A2:1", "A3:1", "A4:0"],
      xStart: 7, cell: cell, yVal: yPos(7), tag: "defender"
    )
    // Priests (Chant DRM): 4 spaces [2, 2, 1, 0]
    graph.tracks["priests"] = addLabeledTrack(
      &graph, labels: ["P0:2", "P1:2", "P2:1", "P3:0"],
      xStart: 13, cell: cell, yVal: yPos(7), tag: "defender"
    )

    // Energy (row 8)
    graph.tracks["arcane"] = addIndexedTrack(
      &graph, prefix: "a", range: 0...6,
      xStart: 0, cell: cell, yVal: yPos(8), tag: "energy"
    )
    graph.tracks["divine"] = addIndexedTrack(
      &graph, prefix: "d", range: 0...6,
      xStart: 8, cell: cell, yVal: yPos(8), tag: "energy"
    )
  }

  private static func addTimeTracks(
    _ graph: inout SiteGraph,
    cell: CGFloat,
    yPos: (CGFloat) -> CGFloat
  ) {
    let timeLabels = ["D0", "d1", "d2", "T3", "n4", "n5",
                      "D6", "d7", "d8", "T9", "n10", "n11",
                      "D12", "d13", "d14", "T15"]
    let timeSites = addLabeledTrack(
      &graph, labels: timeLabels,
      xStart: 0, cell: cell, yVal: yPos(10), tag: "time"
    )
    connectTrack(&graph, sites: timeSites)
    graph.tracks["time"] = timeSites

    let spellLabels = ["FB", "Sl", "CL", "Fo", "CW", "MH", "DW", "In", "RD"]
    graph.tracks["spells"] = addLabeledTrack(
      &graph, labels: spellLabels,
      xStart: 0, cell: cell, yVal: yPos(13), tag: "spell"
    )
  }

  // swiftlint:disable:next function_parameter_count
  private static func addLabeledTrack(
    _ graph: inout SiteGraph,
    labels: [String],
    xStart: Int,
    cell: CGFloat,
    yVal: CGFloat,
    tag: String
  ) -> [SiteID] {
    var sites: [SiteID] = []
    for (idx, label) in labels.enumerated() {
      let id = graph.addSite(
        position: CGPoint(x: CGFloat(xStart + idx) * cell, y: yVal),
        tags: [tag]
      )
      graph.sites[id]?.label = label
      sites.append(id)
    }
    return sites
  }

  // swiftlint:disable:next function_parameter_count
  private static func addIndexedTrack(
    _ graph: inout SiteGraph,
    prefix: String,
    range: ClosedRange<Int>,
    xStart: Int,
    cell: CGFloat,
    yVal: CGFloat,
    tag: String
  ) -> [SiteID] {
    var sites: [SiteID] = []
    for idx in range {
      let id = graph.addSite(
        position: CGPoint(x: CGFloat(xStart + idx) * cell, y: yVal),
        tags: [tag]
      )
      graph.sites[id]?.label = "\(prefix)\(idx)"
      sites.append(id)
    }
    return sites
  }

  // swiftlint:disable:next function_parameter_count
  private static func addSingleTrack(
    _ graph: inout SiteGraph,
    key: String,
    prefix: String,
    row: CGFloat,
    count: Int,
    cell: CGFloat,
    yPos: (CGFloat) -> CGFloat
  ) {
    var sites: [SiteID] = []
    for space in 1...count {
      let id = graph.addSite(
        position: CGPoint(x: CGFloat(space + 1) * cell, y: yPos(row)),
        tags: [key]
      )
      graph.sites[id]?.label = "\(prefix)\(space)"
      sites.append(id)
    }
    connectTrack(&graph, sites: sites)
    graph.tracks[key] = sites
  }

  // MARK: - Header Labels

  private struct HeaderLabel {
    let col: CGFloat
    let row: CGFloat
    let name: String
  }

  private static func addHeaderLabels(
    _ graph: inout SiteGraph,
    cell: CGFloat,
    yPos: (CGFloat) -> CGFloat
  ) {
    let headers: [HeaderLabel] = [
      HeaderLabel(col: 9, row: 0, name: "East"),
      HeaderLabel(col: 9, row: 1, name: "West"),
      HeaderLabel(col: 9, row: 2, name: "Gate"),
      HeaderLabel(col: 9, row: 3, name: "Sky"),
      HeaderLabel(col: 9, row: 4, name: "Terror"),
      HeaderLabel(col: 3, row: 6, name: "Morale"),
      HeaderLabel(col: 17, row: 7, name: "Defenders"),
      HeaderLabel(col: 7, row: 8, name: "Arcane"),
      HeaderLabel(col: 15, row: 8, name: "Divine"),
      HeaderLabel(col: 0, row: 9, name: "Time"),
      HeaderLabel(col: 8, row: 12, name: "Cards"),
      HeaderLabel(col: 10, row: 13, name: "Spells"),
      HeaderLabel(col: 3, row: 14, name: "Items")
    ]
    for header in headers {
      let id = graph.addSite(
        position: CGPoint(x: header.col * cell, y: yPos(header.row)),
        tags: ["header"]
      )
      graph.sites[id]?.label = header.name
    }
  }

  // MARK: - Helpers

  private static func connectTrack(_ graph: inout SiteGraph, sites: [SiteID]) {
    for index in 0..<(sites.count - 1) {
      graph.connect(sites[index], to: sites[index + 1], direction: .next)
    }
  }

  /// Map an army track name to the graph track key.
  static func trackKey(for track: LoD.Track) -> String {
    track.rawValue  // east, west, gate, sky, terror
  }

  /// Map an army space number (1-based) to track array index (0-based).
  static func trackIndex(space: Int) -> Int {
    space - 1
  }

  /// Spell order in the spells track.
  static let spellOrder: [LoD.SpellType] = [
    .fireball, .slow, .chainLightning, .fortune,
    .cureWounds, .massHeal, .divineWrath, .inspire, .raiseDead
  ]
}
