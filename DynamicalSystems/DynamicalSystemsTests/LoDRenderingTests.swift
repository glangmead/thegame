//
//  LoDRenderingTests.swift
//  DynamicalSystems
//
//  Tests for LoD rendering: Graph (SiteGraph), Piece Adapter, Victory/Defeat Priority Pages, Full Game Loop Integration.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDRenderingTests {

  // MARK: - Graph (SiteGraph)

  @Test
  func graphHasArmyTracks() {
    let layout = LoDGraph.board()
    #expect(layout.tracks["east"]?.count == 6)
    #expect(layout.tracks["west"]?.count == 6)
    #expect(layout.tracks["gate"]?.count == 4)
    #expect(layout.tracks["sky"]?.count == 6)
    #expect(layout.tracks["terror"]?.count == 3)
  }

  @Test
  func graphHasStatusTracks() {
    let layout = LoDGraph.board()
    #expect(layout.tracks["time"]?.count == 16)
    #expect(layout.tracks["morale"]?.count == 3)
    #expect(layout.tracks["menAtArms"]?.count == 4)
    #expect(layout.tracks["archers"]?.count == 3)
    #expect(layout.tracks["priests"]?.count == 3)
    #expect(layout.tracks["arcane"]?.count == 7)
    #expect(layout.tracks["divine"]?.count == 7)
    #expect(layout.tracks["spells"]?.count == 9)
  }

  @Test
  func graphHasSpecialSites() {
    let layout = LoDGraph.board()
    // Breach sites, upgrade sites, card areas, reserves, items
    #expect(layout.sites[LoDGraph.eastBreach] != nil)
    #expect(layout.sites[LoDGraph.westBreach] != nil)
    #expect(layout.sites[LoDGraph.gateBreach] != nil)
    #expect(layout.sites[LoDGraph.reserves] != nil)
    #expect(layout.sites[LoDGraph.currentCard] != nil)
    #expect(layout.sites[LoDGraph.dayDraw] != nil)
    #expect(layout.sites[LoDGraph.nightDraw] != nil)
    #expect(layout.sites[LoDGraph.sword] != nil)
    #expect(layout.sites[LoDGraph.bow] != nil)
  }

  @Test
  func graphMiniAdjacency() {
    var miniGraph = SiteGraph()
    let a = miniGraph.addSite(position: .zero)
    let b = miniGraph.addSite(position: CGPoint(x: 1, y: 0))
    miniGraph.connect(a, to: b, direction: .next)
    #expect(miniGraph.sites[a]!.adjacency[.next] == b)
  }

  @Test
  func graphTrackAdjacency() {
    let layout = LoDGraph.board()
    let east = layout.tracks["east"]!
    #expect(east.count == 6)
    let site0 = layout.sites[east[0]]!
    #expect(site0.adjacency[.next] == east[1])
  }

  // MARK: - Piece Adapter

  @Test
  func adapterCreatesAllPieces() {
    let pieces = LoDPieceAdapter.pieces()
    // 6 armies + 3 heroes (greenskin default) + morale + time + 3 defenders + 2 energy + 1 card
    // Actually: 6 armies, up to 6 heroes, morale, time, 3 defenders, 2 energy = 18+
    let armyLabels: Set = ["Gob", "Orc", "G1", "G2", "Sky", "Ter"]
    let armyPieces = pieces.filter { armyLabels.contains($0.label ?? "") }
    #expect(armyPieces.count == 6)
  }

  @Test
  func adapterMapsArmyPositions() {
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let graph = LoDGraph.board()
    let section = LoDPieceAdapter.section(from: state, graph: graph)
    // East army at space 6 → east track index 5
    let eastPiece = LoDPieceAdapter.pieces().first { $0.label == "Gob" }!
    let eastValue = section[eastPiece]
    let expectedSite = graph.tracks["east"]![5]  // index 5 = space 6
    #expect(eastValue?.site == expectedSite)
  }

  @Test
  func adapterMapsMorale() {
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let graph = LoDGraph.board()
    let section = LoDPieceAdapter.section(from: state, graph: graph)
    let moralePiece = LoDPieceAdapter.pieces().first { $0.label == "Mor" }!
    let moraleValue = section[moralePiece]
    let normalSite = graph.tracks["morale"]![1]  // index 1 = normal
    #expect(moraleValue?.site == normalSite)
  }

  @Test
  func adapterMapsTimePosition() {
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let graph = LoDGraph.board()
    let section = LoDPieceAdapter.section(from: state, graph: graph)
    let timePiece = LoDPieceAdapter.pieces().first { $0.label == "T" }!
    let timeValue = section[timePiece]
    let startSite = graph.tracks["time"]![0]  // position 0
    #expect(timeValue?.site == startSite)
  }

  // MARK: - Victory/Defeat Priority Pages (rule 11.0)

  @Test
  func victoryPriorityPageOffersClaimVictory() {
    // Rule 11.0: When game reaches Final Twilight and housekeeping triggers victory,
    // the composed game should offer .claimVictory via priority page.
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    var state = game.newState()
    state.ended = true
    state.victory = true
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(LoD.Action.claimVictory))
  }

  @Test
  func defeatPriorityPageOffersDeclareLoss() {
    // Rule 11.1: When game ends in defeat (breach, all defenders lost),
    // the composed game should offer .declareLoss via priority page.
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    var state = game.newState()
    state.ended = true
    state.victory = false
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(LoD.Action.declareLoss))
  }

  @Test
  func noVictoryOrDefeatWhileGameOngoing() {
    // Victory/defeat pages should not fire while game is ongoing.
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    let state = game.newState()
    let actions = game.allowedActions(state: state)
    #expect(!actions.contains(LoD.Action.claimVictory))
    #expect(!actions.contains(LoD.Action.declareLoss))
  }

  @Test
  func composedGameTerminalAfterVictoryAcknowledged() {
    // After acknowledging victory, the game should be terminal (no more actions).
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    var state = game.newState()
    state.ended = true
    state.victory = true
    state.gameAcknowledged = true
    #expect(game.isTerminal(state))
  }

  @Test
  func composedGameTerminalAfterDefeatAcknowledged() {
    // After acknowledging defeat, the game should be terminal.
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    var state = game.newState()
    state.ended = true
    state.victory = false
    state.gameAcknowledged = true
    #expect(game.isTerminal(state))
  }

  @Test
  func composedGameNotTerminalBeforeAcknowledgment() {
    // Game ended but not yet acknowledged — not terminal, priority pages should fire.
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    var state = game.newState()
    state.ended = true
    state.victory = true
    #expect(!game.isTerminal(state))
  }

  // MARK: - Full Game Loop Integration

  @Test
  func fullGameVictoryPlaythrough() {
    // Play through all 16 time positions using a safe card (no event, time: 1)
    // to reach Final Twilight and trigger victory.
    let card3 = LoD.dayCards.first { $0.number == 3 }!  // "All is Quiet", time: 1, no event
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 20),
      shuffledNightCards: Array(repeating: card3, count: 20)
    )
    var state = game.newState()
    #expect(state.phase == .card)
    #expect(state.outcome == .ongoing)

    // Play 15 turns (time advances from 0 to 15)
    for turn in 0..<15 {
      let actions = game.allowedActions(state: state)
      #expect(actions.contains(.drawCard), "Turn \(turn): expected drawCard in \(state.phase)")
      _ = game.reduce(into: &state, action: .drawCard)
      _ = game.reduce(into: &state, action: .passActions)
      _ = game.reduce(into: &state, action: .passHeroics)
    }

    // After 15 turns with time: 1 each, we should be at Final Twilight
    #expect(state.timePosition == 15)
    #expect(state.ended == true)
    #expect(state.victory == true)
    #expect(state.outcome == .victory)

    // Priority page should offer claimVictory
    let actions = game.allowedActions(state: state)
    #expect(actions == [LoD.Action.claimVictory])

    // Acknowledge victory → terminal
    _ = game.reduce(into: &state, action: .claimVictory)
    #expect(state.gameAcknowledged == true)
    #expect(game.isTerminal(state))
    #expect(game.allowedActions(state: state).isEmpty)
  }

  @Test
  func fullGameDefeatByBreach() {
    // Use a card that advances East army until it breaches and enters castle.
    // Card #6 advances East only, time: 1, no event.
    let card6 = LoD.dayCards.first { $0.number == 6 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card6, count: 20),
      shuffledNightCards: Array(repeating: card6, count: 20)
    )
    var state = game.newState()

    // Play turns until defeat
    var turnCount = 0
    while !state.ended && turnCount < 20 {
      _ = game.reduce(into: &state, action: .drawCard)
      _ = game.reduce(into: &state, action: .passActions)
      _ = game.reduce(into: &state, action: .passHeroics)
      turnCount += 1
    }

    // Game should have ended in defeat (East army breached)
    #expect(state.ended == true)
    #expect(state.victory == false)
    #expect(state.outcome == .defeatBreached)

    // Priority page should offer declareLoss
    let actions = game.allowedActions(state: state)
    #expect(actions == [LoD.Action.declareLoss])

    // Acknowledge defeat → terminal
    _ = game.reduce(into: &state, action: .declareLoss)
    #expect(state.gameAcknowledged == true)
    #expect(game.isTerminal(state))
    #expect(game.allowedActions(state: state).isEmpty)
  }
}
