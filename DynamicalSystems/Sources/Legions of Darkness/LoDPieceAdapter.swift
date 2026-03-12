//
//  LoDPieceAdapter.swift
//  DynamicalSystems
//
//  Legions of Darkness — Maps game state to GamePiece/GameSection for rendering.
//

import Foundation
import SpriteKit

// swiftlint:disable:next type_body_length
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

  private static let armyLabels: [LoD.ArmySlot: String] = [
    .east: "G2", .west: "O3", .gate1: "G2", .gate2: "G2", .sky: "D4", .terror: "T4"
  ]

  private static let heroLabels: [LoD.HeroType: String] = [
    .warrior: "War", .wizard: "Wiz", .ranger: "Ran",
    .rogue: "Rog", .paladin: "Pal", .cleric: "Clr"
  ]

  static func pieces() -> [GamePiece] {
    var result: [GamePiece] = []

    // 6 army tokens
    for (idx, slot) in armySlotOrder.enumerated() {
      result.append(GamePiece(
        id: armyBaseID + idx,
        kind: .token,
        owner: PlayerID(1),  // Enemy
        label: armyLabels[slot] ?? slot.rawValue
      ))
    }

    // 6 hero tokens (all possible heroes)
    for (idx, hero) in heroOrder.enumerated() {
      result.append(GamePiece(
        id: heroBaseID + idx,
        kind: .token,
        owner: PlayerID(0),  // Player
        label: heroLabels[hero] ?? hero.rawValue
      ))
    }

    // Markers
    result.append(GamePiece(id: moraleID, kind: .token, label: "Mor"))
    result.append(GamePiece(id: timeID, kind: .token, label: "T"))
    result.append(GamePiece(id: maaMarkerID, kind: .token, label: "MaA"))
    result.append(GamePiece(id: archerMarkerID, kind: .token, label: "Arc"))
    result.append(GamePiece(id: priestMarkerID, kind: .token, label: "Pri"))
    result.append(GamePiece(id: arcaneMarkerID, kind: .token, label: "Ark"))
    result.append(GamePiece(id: divineMarkerID, kind: .token, label: "Div"))
    result.append(GamePiece(id: bloodyBattleID, kind: .token, owner: PlayerID(1), label: "Bld"))
    result.append(GamePiece(id: slowMarkerID, kind: .token, owner: PlayerID(1), label: "Slw"))

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

    sectionForArmies(state: state, graph: graph, piece: piece, section: &section)
    sectionForHeroes(state: state, graph: graph, piece: piece, section: &section)
    sectionForMorale(state: state, graph: graph, piece: piece, section: &section)
    sectionForTime(state: state, graph: graph, piece: piece, section: &section)
    sectionForDefenders(state: state, graph: graph, piece: piece, section: &section)
    sectionForEnergy(state: state, graph: graph, piece: piece, section: &section)
    sectionForBloodyBattle(state: state, graph: graph, piece: piece, section: &section)
    sectionForSlowMarker(state: state, graph: graph, piece: piece, section: &section)
    sectionForCurrentCard(state: state, piece: piece, section: &section)

    return section
  }

  // MARK: - Section Helpers

  private static func sectionForArmies(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    for (idx, slot) in armySlotOrder.enumerated() {
      let armyPiece = piece(armyBaseID + idx)
      if let space = state.armyPosition[slot] {
        let trackKey = LoDGraph.trackKey(for: slot.track)
        if let siteID = graph.tracks[trackKey]?[safe: LoDGraph.trackIndex(space: space)] {
          section[armyPiece] = .at(siteID)
        }
      }
      // If army not on board, piece absent from section (hidden)
    }
  }

  private static func sectionForHeroes(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    for (idx, hero) in heroOrder.enumerated() {
      let heroPiece = piece(heroBaseID + idx)
      guard let loc = state.heroLocation[hero], !state.heroDead.contains(hero) else { continue }
      switch loc {
      case .reserves:
        section[heroPiece] = .at(LoDGraph.reserves)
      case .onTrack(let track):
        let trackKey = LoDGraph.trackKey(for: track)
        if let siteID = graph.tracks[trackKey]?.first {
          section[heroPiece] = .at(siteID)
        }
      }
    }
  }

  private static func sectionForMorale(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    let moraleIndex: Int
    switch state.morale {
    case .low: moraleIndex = 0
    case .normal: moraleIndex = 1
    case .high: moraleIndex = 2
    }
    if let siteID = graph.tracks["morale"]?[moraleIndex] {
      section[piece(moraleID)] = .at(siteID)
    }
  }

  private static func sectionForTime(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    if let siteID = graph.tracks["time"]?[safe: state.timePosition] {
      section[piece(timeID)] = .at(siteID)
    }
  }

  private static func sectionForDefenders(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    let maaPos = state.defenderPosition[.menAtArms] ?? LoD.DefenderType.menAtArms.lastPosition
    if let siteID = graph.tracks["menAtArms"]?[safe: maaPos] {
      section[piece(maaMarkerID)] = .at(siteID)
    }
    let archerPos = state.defenderPosition[.archers] ?? LoD.DefenderType.archers.lastPosition
    if let siteID = graph.tracks["archers"]?[safe: archerPos] {
      section[piece(archerMarkerID)] = .at(siteID)
    }
    let priestPos = state.defenderPosition[.priests] ?? LoD.DefenderType.priests.lastPosition
    if let siteID = graph.tracks["priests"]?[safe: priestPos] {
      section[piece(priestMarkerID)] = .at(siteID)
    }
  }

  private static func sectionForEnergy(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    if let siteID = graph.tracks["arcane"]?[safe: state.arcaneEnergy] {
      section[piece(arcaneMarkerID)] = .at(siteID)
    }
    if let siteID = graph.tracks["divine"]?[safe: state.divineEnergy] {
      section[piece(divineMarkerID)] = .at(siteID)
    }
  }

  private static func sectionForBloodyBattle(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    if let bbSlot = state.bloodyBattleArmy {
      let bbPiece = piece(bloodyBattleID)
      if let space = state.armyPosition[bbSlot] {
        let trackKey = LoDGraph.trackKey(for: bbSlot.track)
        if let siteID = graph.tracks[trackKey]?[safe: LoDGraph.trackIndex(space: space)] {
          section[bbPiece] = .at(siteID)
        }
      }
    }
  }

  private static func sectionForSlowMarker(
    state: LoD.State, graph: SiteGraph,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    if let slowSlot = state.slowedArmy {
      let slowPiece = piece(slowMarkerID)
      if let space = state.armyPosition[slowSlot] {
        let trackKey = LoDGraph.trackKey(for: slowSlot.track)
        if let siteID = graph.tracks[trackKey]?[safe: LoDGraph.trackIndex(space: space)] {
          section[slowPiece] = .at(siteID)
        }
      }
    }
  }

  private static func sectionForCurrentCard(
    state: LoD.State,
    piece: (Int) -> GamePiece, section: inout GameSection
  ) {
    if let card = state.currentCard {
      section[piece(currentCardID)] = .cardState(
        name: card.title,
        faceUp: true,
        isRed: false,
        rotation: 0,
        at: LoDGraph.currentCard
      )
    }
  }

  // MARK: - Site Highlights

  static func siteHighlights(from state: LoD.State, graph: SiteGraph) -> [SiteID: SKColor] {
    var highlights: [SiteID: SKColor] = [:]

    highlightBreachesAndBarricades(state: state, highlights: &highlights)
    highlightUpgrades(state: state, graph: graph, highlights: &highlights)
    highlightSpells(state: state, graph: graph, highlights: &highlights)
    highlightItems(state: state, highlights: &highlights)

    return highlights
  }

  // MARK: - Highlight Helpers

  /// Map a wall track to its breach site ID, returning nil for non-wall tracks.
  private static func breachSiteID(for track: LoD.Track) -> SiteID? {
    switch track {
    case .east: return LoDGraph.eastBreach
    case .west: return LoDGraph.westBreach
    case .gate: return LoDGraph.gateBreach
    default: return nil
    }
  }

  /// Map a wall track to its upgrade site ID, returning nil for non-wall tracks.
  private static func upgradeSiteID(for track: LoD.Track) -> SiteID? {
    switch track {
    case .east: return LoDGraph.eastUpgrade
    case .west: return LoDGraph.westUpgrade
    case .gate: return LoDGraph.gateUpgrade
    default: return nil
    }
  }

  private static func highlightBreachesAndBarricades(
    state: LoD.State, highlights: inout [SiteID: SKColor]
  ) {
    for track in LoD.Track.walls {
      guard let siteID = breachSiteID(for: track) else { continue }
      if state.breaches.contains(track) {
        highlights[siteID] = SKColor.red.withAlphaComponent(0.3)
      }
      if state.barricades.contains(track) {
        highlights[siteID] = SKColor.orange.withAlphaComponent(0.3)
      }
    }
  }

  private static func highlightUpgrades(
    state: LoD.State, graph: SiteGraph, highlights: inout [SiteID: SKColor]
  ) {
    for (track, upgrade) in state.upgrades {
      guard let siteID = upgradeSiteID(for: track) else { continue }
      highlights[siteID] = SKColor.green.withAlphaComponent(0.3)
      _ = upgrade  // Upgrade type could be shown as label in future
    }
  }

  private static func highlightSpells(
    state: LoD.State, graph: SiteGraph, highlights: inout [SiteID: SKColor]
  ) {
    for (idx, spell) in LoDGraph.spellOrder.enumerated() {
      guard let siteID = graph.tracks["spells"]?[safe: idx] else { continue }
      switch state.spellStatus[spell] {
      case .known:
        highlights[siteID] = SKColor.cyan.withAlphaComponent(0.3)
      case .cast:
        highlights[siteID] = SKColor.gray.withAlphaComponent(0.3)
      default:
        break  // face-down = no highlight
      }
    }
  }

  private static func highlightItems(
    state: LoD.State, highlights: inout [SiteID: SKColor]
  ) {
    if state.magicSwordState != nil {
      highlights[LoDGraph.sword] = SKColor.yellow.withAlphaComponent(0.3)
    }
    if state.magicBowState != nil {
      highlights[LoDGraph.bow] = SKColor.yellow.withAlphaComponent(0.3)
    }
  }
}

// Array safe subscript is defined in BCGraph.swift
