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
    let cs = cellSize

    // Flip y so row 0 (East) is at the top of the SpriteKit scene.
    // The board has 15 logical rows (0–14). SpriteKit y-axis points up,
    // so we map row r → (14 - r) * cs.
    func y(_ row: CGFloat) -> CGFloat { (14 - row) * cs }

    // Pre-register all well-known sites so nextID starts past them.
    // This prevents auto-generated IDs from colliding with well-known IDs.
    graph.addSite(id: eastBreach, position: CGPoint(x: cs, y: y(0)), tags: ["breach"])
    graph.addSite(id: westBreach, position: CGPoint(x: cs, y: y(1)), tags: ["breach"])
    graph.addSite(id: gateBreach, position: CGPoint(x: cs, y: y(2)), tags: ["breach"])
    graph.addSite(id: eastUpgrade, position: CGPoint(x: 0, y: y(0)), tags: ["upgrade"])
    graph.addSite(id: westUpgrade, position: CGPoint(x: 0, y: y(1)), tags: ["upgrade"])
    graph.addSite(id: gateUpgrade, position: CGPoint(x: 0, y: y(2)), tags: ["upgrade"])
    let cardRow: CGFloat = 12
    graph.addSite(id: dayDraw, position: CGPoint(x: 0, y: y(cardRow)), tags: ["card"])
    graph.addSite(id: nightDraw, position: CGPoint(x: cs, y: y(cardRow)), tags: ["card"])
    graph.addSite(id: currentCard, position: CGPoint(x: 3 * cs, y: y(cardRow)), tags: ["card"])
    graph.addSite(id: dayDiscard, position: CGPoint(x: 5 * cs, y: y(cardRow)), tags: ["card"])
    graph.addSite(id: nightDiscard, position: CGPoint(x: 6 * cs, y: y(cardRow)), tags: ["card"])
    let itemRow: CGFloat = 14
    graph.addSite(id: sword, position: CGPoint(x: 0, y: y(itemRow)), tags: ["item"])
    graph.addSite(id: bow, position: CGPoint(x: cs, y: y(itemRow)), tags: ["item"])
    let statusRow: CGFloat = 6
    graph.addSite(id: reserves, position: CGPoint(x: 4 * cs, y: y(statusRow)), tags: ["reserves"])

    // Set labels for well-known sites
    graph.sites[eastBreach]?.label = "E 0"
    graph.sites[westBreach]?.label = "W 0"
    graph.sites[gateBreach]?.label = "G 0"
    graph.sites[eastUpgrade]?.label = "E Up"
    graph.sites[westUpgrade]?.label = "W Up"
    graph.sites[gateUpgrade]?.label = "G Up"
    graph.sites[dayDraw]?.label = "Day"
    graph.sites[nightDraw]?.label = "Night"
    graph.sites[currentCard]?.label = "Card"
    graph.sites[dayDiscard]?.label = "D Dis"
    graph.sites[nightDiscard]?.label = "N Dis"
    graph.sites[sword]?.label = "Sword"
    graph.sites[bow]?.label = "Bow"
    graph.sites[reserves]?.label = "Rsv"

    // ---- ARMY TRACKS (rows 0–4) ----
    // Layout: [Upgrade] [Breach/Space0] [Space1] [Space2] ... [SpaceMax]
    // Spaces go left (castle) to right (far)

    // East track (row 0): spaces 1-6
    var eastSites: [SiteID] = []
    for space in 1...6 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(space + 1) * cs, y: y(0)), tags: ["east"])
      graph.sites[id]?.label = "E\(space)"
      eastSites.append(id)
    }
    connectTrack(&graph, sites: eastSites)
    graph.tracks["east"] = eastSites

    // West track (row 1): spaces 1-6
    var westSites: [SiteID] = []
    for space in 1...6 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(space + 1) * cs, y: y(1)), tags: ["west"])
      graph.sites[id]?.label = "W\(space)"
      westSites.append(id)
    }
    connectTrack(&graph, sites: westSites)
    graph.tracks["west"] = westSites

    // Gate track (row 2): spaces 1-4
    var gateSites: [SiteID] = []
    for space in 1...4 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(space + 1) * cs, y: y(2)), tags: ["gate"])
      graph.sites[id]?.label = "G\(space)"
      gateSites.append(id)
    }
    connectTrack(&graph, sites: gateSites)
    graph.tracks["gate"] = gateSites

    // Sky track (row 3): no upgrade/breach, spaces 1-6
    var skySites: [SiteID] = []
    for space in 1...6 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(space + 1) * cs, y: y(3)), tags: ["sky"])
      graph.sites[id]?.label = "S\(space)"
      skySites.append(id)
    }
    connectTrack(&graph, sites: skySites)
    graph.tracks["sky"] = skySites

    // Terror track (row 4): no upgrade/breach, spaces 1-3
    var terrorSites: [SiteID] = []
    for space in 1...3 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(space + 1) * cs, y: y(4)), tags: ["terror"])
      graph.sites[id]?.label = "T\(space)"
      terrorSites.append(id)
    }
    connectTrack(&graph, sites: terrorSites)
    graph.tracks["terror"] = terrorSites

    // ---- STATUS SECTION (row 6) ----

    // Morale: Low, Normal, High
    var moraleSites: [SiteID] = []
    for (i, label) in ["Low", "Norm", "High"].enumerated() {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i) * cs, y: y(statusRow)), tags: ["morale"])
      graph.sites[id]?.label = label
      moraleSites.append(id)
    }
    graph.tracks["morale"] = moraleSites

    // ---- DEFENDERS (row 7) ----

    // Men-at-Arms: 0-3
    var maaSites: [SiteID] = []
    for i in 0...3 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i) * cs, y: y(7)), tags: ["defender"])
      graph.sites[id]?.label = "M\(i)"
      maaSites.append(id)
    }
    graph.tracks["menAtArms"] = maaSites

    // Archers: 0-2
    var archerSites: [SiteID] = []
    for i in 0...2 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i + 5) * cs, y: y(7)), tags: ["defender"])
      graph.sites[id]?.label = "A\(i)"
      archerSites.append(id)
    }
    graph.tracks["archers"] = archerSites

    // Priests: 0-2
    var priestSites: [SiteID] = []
    for i in 0...2 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i + 9) * cs, y: y(7)), tags: ["defender"])
      graph.sites[id]?.label = "P\(i)"
      priestSites.append(id)
    }
    graph.tracks["priests"] = priestSites

    // ---- ENERGY (row 8) ----

    // Arcane: 0-6
    var arcaneSites: [SiteID] = []
    for i in 0...6 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i) * cs, y: y(8)), tags: ["energy"])
      graph.sites[id]?.label = "a\(i)"
      arcaneSites.append(id)
    }
    graph.tracks["arcane"] = arcaneSites

    // Divine: 0-6
    var divineSites: [SiteID] = []
    for i in 0...6 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i + 8) * cs, y: y(8)), tags: ["energy"])
      graph.sites[id]?.label = "d\(i)"
      divineSites.append(id)
    }
    graph.tracks["divine"] = divineSites

    // ---- TIME TRACK (row 10) ----
    var timeSites: [SiteID] = []
    let timeLabels = ["D0", "d1", "d2", "T3", "n4", "n5",
                      "D6", "d7", "d8", "T9", "n10", "n11",
                      "D12", "d13", "d14", "T15"]
    for i in 0..<16 {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i) * cs, y: y(10)), tags: ["time"])
      graph.sites[id]?.label = timeLabels[i]
      timeSites.append(id)
    }
    connectTrack(&graph, sites: timeSites)
    graph.tracks["time"] = timeSites

    // ---- SPELLS (row 13) ----
    var spellSites: [SiteID] = []
    let spellLabels = ["FB", "Sl", "CL", "Fo", "CW", "MH", "DW", "In", "RD"]
    for (i, label) in spellLabels.enumerated() {
      let id = graph.addSite(position: CGPoint(x: CGFloat(i) * cs, y: y(13)), tags: ["spell"])
      graph.sites[id]?.label = label
      spellSites.append(id)
    }
    graph.tracks["spells"] = spellSites

    return graph
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
