//
//  LoDPieceAdapter.swift
//  DynamicalSystems
//
//  Legions of Darkness — Maps game state to GamePiece/GameSection for rendering.
//

import Foundation
import SpriteKit

struct LoDPieceAdapter {

  // MARK: - Piece ID Ranges
  // Armies: 0-5, Heroes: 10-15, Markers: 20-29

  private static let armyBaseID = 0
  private static let heroBaseID = 10
  private static let moraleID = 20
  private static let timeID = 21
  private static let maaMarkerID = 22
  private static let archerMarkerID = 23
  private static let priestMarkerID = 24
  private static let arcaneMarkerID = 25
  private static let divineMarkerID = 26
  private static let bloodyBattleID = 27
  private static let slowMarkerID = 28
  private static let currentCardID = 30

  // MARK: - Army Slot Ordering

  private static let armySlotOrder: [LoD.ArmySlot] = [
    .east, .west, .gate1, .gate2, .sky, .terror
  ]

  private static let heroOrder: [LoD.HeroType] = [
    .warrior, .wizard, .ranger, .rogue, .paladin, .cleric
  ]

  // MARK: - Pieces

  static func pieces() -> [GamePiece] {
    var result: [GamePiece] = []

    // 6 army tokens
    for (i, slot) in armySlotOrder.enumerated() {
      result.append(GamePiece(
        id: armyBaseID + i,
        kind: .token,
        owner: PlayerID(1),  // Enemy
        label: "army:\(slot.rawValue)"
      ))
    }

    // 6 hero tokens (all possible heroes)
    for (i, hero) in heroOrder.enumerated() {
      result.append(GamePiece(
        id: heroBaseID + i,
        kind: .token,
        owner: PlayerID(0),  // Player
        label: "hero:\(hero.rawValue)"
      ))
    }

    // Markers
    result.append(GamePiece(id: moraleID, kind: .token, label: "morale"))
    result.append(GamePiece(id: timeID, kind: .token, label: "time"))
    result.append(GamePiece(id: maaMarkerID, kind: .token, label: "def:menAtArms"))
    result.append(GamePiece(id: archerMarkerID, kind: .token, label: "def:archers"))
    result.append(GamePiece(id: priestMarkerID, kind: .token, label: "def:priests"))
    result.append(GamePiece(id: arcaneMarkerID, kind: .token, label: "energy:arcane"))
    result.append(GamePiece(id: divineMarkerID, kind: .token, label: "energy:divine"))
    result.append(GamePiece(id: bloodyBattleID, kind: .token, owner: PlayerID(1), label: "bloody"))
    result.append(GamePiece(id: slowMarkerID, kind: .token, owner: PlayerID(1), label: "slow"))

    // Current card
    result.append(GamePiece(id: currentCardID, kind: .card, label: "card"))

    return result
  }

  // MARK: - Section (state → piece positions)

  static func section(from state: LoD.State, graph: SiteGraph) -> GameSection {
    var section: GameSection = [:]
    let allPieces = pieces()

    func piece(id: Int) -> GamePiece {
      allPieces.first { $0.id == id }!
    }

    // -- Armies --
    for (i, slot) in armySlotOrder.enumerated() {
      let p = piece(id: armyBaseID + i)
      if let space = state.armyPosition[slot] {
        let trackKey = LoDGraph.trackKey(for: slot.track)
        if let siteID = graph.tracks[trackKey]?[safe: LoDGraph.trackIndex(space: space)] {
          section[p] = .at(siteID)
        }
      }
      // If army not on board, piece absent from section (hidden)
    }

    // -- Heroes --
    for (i, hero) in heroOrder.enumerated() {
      let p = piece(id: heroBaseID + i)
      guard let loc = state.heroLocation[hero], !state.heroDead.contains(hero) else { continue }
      switch loc {
      case .reserves:
        section[p] = .at(LoDGraph.reserves)
      case .onTrack(let track):
        // Heroes go to space 1 of their track visually
        let trackKey = LoDGraph.trackKey(for: track)
        if let siteID = graph.tracks[trackKey]?.first {
          section[p] = .at(siteID)
        }
      }
    }

    // -- Morale --
    let moraleIndex: Int
    switch state.morale {
    case .low: moraleIndex = 0
    case .normal: moraleIndex = 1
    case .high: moraleIndex = 2
    }
    if let siteID = graph.tracks["morale"]?[moraleIndex] {
      section[piece(id: moraleID)] = .at(siteID)
    }

    // -- Time --
    if let siteID = graph.tracks["time"]?[safe: state.timePosition] {
      section[piece(id: timeID)] = .at(siteID)
    }

    // -- Defenders --
    let maaValue = state.defenders[.menAtArms] ?? 0
    if let siteID = graph.tracks["menAtArms"]?[safe: maaValue] {
      section[piece(id: maaMarkerID)] = .at(siteID)
    }
    let archerValue = state.defenders[.archers] ?? 0
    if let siteID = graph.tracks["archers"]?[safe: archerValue] {
      section[piece(id: archerMarkerID)] = .at(siteID)
    }
    let priestValue = state.defenders[.priests] ?? 0
    if let siteID = graph.tracks["priests"]?[safe: priestValue] {
      section[piece(id: priestMarkerID)] = .at(siteID)
    }

    // -- Energy --
    if let siteID = graph.tracks["arcane"]?[safe: state.arcaneEnergy] {
      section[piece(id: arcaneMarkerID)] = .at(siteID)
    }
    if let siteID = graph.tracks["divine"]?[safe: state.divineEnergy] {
      section[piece(id: divineMarkerID)] = .at(siteID)
    }

    // -- Bloody Battle marker --
    if let bbSlot = state.bloodyBattleArmy {
      let bbPiece = piece(id: bloodyBattleID)
      if let space = state.armyPosition[bbSlot] {
        let trackKey = LoDGraph.trackKey(for: bbSlot.track)
        if let siteID = graph.tracks[trackKey]?[safe: LoDGraph.trackIndex(space: space)] {
          section[bbPiece] = .at(siteID)
        }
      }
    }

    // -- Slow marker --
    if let slowSlot = state.slowedArmy {
      let slowPiece = piece(id: slowMarkerID)
      if let space = state.armyPosition[slowSlot] {
        let trackKey = LoDGraph.trackKey(for: slowSlot.track)
        if let siteID = graph.tracks[trackKey]?[safe: LoDGraph.trackIndex(space: space)] {
          section[slowPiece] = .at(siteID)
        }
      }
    }

    // -- Current card --
    if let card = state.currentCard {
      section[piece(id: currentCardID)] = .cardState(
        name: card.title,
        faceUp: true,
        at: LoDGraph.currentCard
      )
    }

    return section
  }

  // MARK: - Site Highlights

  static func siteHighlights(from state: LoD.State, graph: SiteGraph) -> [SiteID: SKColor] {
    var highlights: [SiteID: SKColor] = [:]

    // Highlight breached walls in red
    for track in LoD.Track.walls {
      if state.breaches.contains(track) {
        let breachSite: SiteID
        switch track {
        case .east: breachSite = LoDGraph.eastBreach
        case .west: breachSite = LoDGraph.westBreach
        case .gate: breachSite = LoDGraph.gateBreach
        default: continue
        }
        highlights[breachSite] = SKColor.red.withAlphaComponent(0.3)
      }
      // Highlight barricaded walls in orange
      if state.barricades.contains(track) {
        let breachSite: SiteID
        switch track {
        case .east: breachSite = LoDGraph.eastBreach
        case .west: breachSite = LoDGraph.westBreach
        case .gate: breachSite = LoDGraph.gateBreach
        default: continue
        }
        highlights[breachSite] = SKColor.orange.withAlphaComponent(0.3)
      }
    }

    // Highlight upgrade sites
    for (track, upgrade) in state.upgrades {
      let upgradeSite: SiteID
      switch track {
      case .east: upgradeSite = LoDGraph.eastUpgrade
      case .west: upgradeSite = LoDGraph.westUpgrade
      case .gate: upgradeSite = LoDGraph.gateUpgrade
      default: continue
      }
      highlights[upgradeSite] = SKColor.green.withAlphaComponent(0.3)
      graph.sites[upgradeSite]  // Just accessing to silence unused warning for upgrade
      _ = upgrade  // Upgrade type could be shown as label in future
    }

    // Highlight spell statuses
    for (i, spell) in LoDGraph.spellOrder.enumerated() {
      guard let siteID = graph.tracks["spells"]?[safe: i] else { continue }
      switch state.spellStatus[spell] {
      case .known:
        highlights[siteID] = SKColor.cyan.withAlphaComponent(0.3)
      case .cast:
        highlights[siteID] = SKColor.gray.withAlphaComponent(0.3)
      default:
        break  // face-down = no highlight
      }
    }

    // Highlight items
    if state.hasMagicSword {
      highlights[LoDGraph.sword] = SKColor.yellow.withAlphaComponent(0.3)
    }
    if state.hasMagicBow {
      highlights[LoDGraph.bow] = SKColor.yellow.withAlphaComponent(0.3)
    }

    return highlights
  }
}

// Array safe subscript is defined in BCGraph.swift
