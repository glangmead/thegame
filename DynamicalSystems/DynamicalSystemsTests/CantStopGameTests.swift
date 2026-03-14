//
//  CantStopGameTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/17/25.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct CantStopGameTests {

  /// Helper: create a state with specific dice values, in .rolled phase.
  private static func stateWithDice(
    _ die1: DSix, _ die2: DSix, _ die3: DSix, _ die4: DSix
  ) -> CantStop.State {
    var state = CantStop.State()
    state.phase = .rolled
    state.dice[.die1] = die1
    state.dice[.die2] = die2
    state.dice[.die3] = die3
    state.dice[.die4] = die4
    state.rolledThisTurn = true
    state.history = [.setPhase(.rolled)]
    return state
  }

  // MARK: - Pass

  @Test
  func testPassCondition() {
    // After a move: dice cleared, rolledThisTurn = true, phase = .rolled
    var state = CantStop.State()
    state.phase = .rolled
    state.rolledThisTurn = true
    state.history = [.setPhase(.rolled)]

    let passPage = CantStopPages.passPage()
    let actions = passPage.allowedActions(state: state)
    #expect(actions.contains(.rollDice))
    #expect(actions.contains(.pass))
  }

  @Test
  func testPassEffect() {
    var state = CantStop.State()
    state.phase = .rolled
    state.rolledThisTurn = true
    // Place a white piece to verify it gets committed
    state.position[.white(.white1)] = CantStop.Position(col: .seven, row: 3)

    let result = CantStopPages.passPage().reduce(&state, .pass)
    #expect(result != nil)

    // White cleared, placeholder committed at row 3
    #expect(state.position[.placeholder(.player1, .seven)]?.row == 3)
    #expect(state.whiteIn(col: .seven) == nil)

    // Player advanced
    #expect(state.player == .player2)

    // Transition
    #expect(result!.1 == [.setPhase(.notRolled)])
  }

  @Test
  func testNoPassBeforeRolling() {
    // phase = .notRolled, rolledThisTurn = false -> no pass
    let state = CantStop.State()
    let passPage = CantStopPages.passPage()
    #expect(passPage.allowedActions(state: state).isEmpty)
  }

  // MARK: - Victory

  @Test
  func testVictoryCondition() {
    var state = CantStop.State()
    state.phase = .rolled
    state.rolledThisTurn = true
    // Player 1 has 3 columns topped
    state.position[.placeholder(.player1, .two)] = CantStop.Position(
      col: .two, row: CantStop.colHeights[.two]!)
    state.position[.placeholder(.player1, .three)] = CantStop.Position(
      col: .three, row: CantStop.colHeights[.three]!)
    state.position[.placeholder(.player1, .four)] = CantStop.Position(
      col: .four, row: CantStop.colHeights[.four]!)

    let victoryPage = CantStopPages.victoryPage()
    #expect(victoryPage.allowedActions(state: state) == [.claimVictory])
  }

  @Test
  func testVictoryEffect() {
    var state = CantStop.State()
    state.phase = .rolled
    state.rolledThisTurn = true
    state.position[.placeholder(.player1, .two)] = CantStop.Position(
      col: .two, row: CantStop.colHeights[.two]!)
    state.position[.placeholder(.player1, .three)] = CantStop.Position(
      col: .three, row: CantStop.colHeights[.three]!)
    state.position[.placeholder(.player1, .four)] = CantStop.Position(
      col: .four, row: CantStop.colHeights[.four]!)

    let result = CantStopPages.victoryPage().reduce(&state, .claimVictory)
    #expect(result != nil)
    #expect(state.ended)
    #expect(state.endedInVictoryFor == [.player1])
    #expect(state.endedInDefeatFor == [.player2])
  }

  @Test
  func testNoVictoryWithoutThreeColumns() {
    var state = CantStop.State()
    state.phase = .rolled
    state.rolledThisTurn = true
    // Only 2 columns topped
    state.position[.placeholder(.player1, .two)] = CantStop.Position(
      col: .two, row: CantStop.colHeights[.two]!)
    state.position[.placeholder(.player1, .three)] = CantStop.Position(
      col: .three, row: CantStop.colHeights[.three]!)

    let victoryPage = CantStopPages.victoryPage()
    #expect(victoryPage.allowedActions(state: state).isEmpty)
  }

  // MARK: - Composed Game

  @Test
  func testComposedGameInitialActions() {
    let game = CantStopPages.game()
    let state = game.newState()
    let actions = game.allowedActions(state: state)
    #expect(actions == [.rollDice])
  }

  @Test
  func testComposedGameRollThenMove() {
    let game = CantStopPages.game()
    var state = game.newState()
    // Manually set dice instead of using random rollDice
    state.phase = .rolled
    state.history = [.setPhase(.rolled)]
    state.rolledThisTurn = true
    state.dice[.die1] = .three
    state.dice[.die2] = .four
    state.dice[.die3] = .two
    state.dice[.die4] = .five

    let actions = game.allowedActions(state: state)
    #expect(!actions.isEmpty)
    // Pick the first move
    let move = actions[0]
    _ = game.reduce(into: &state, action: move)

    // After move, dice are cleared, pass/roll should be available
    #expect(state.rolledDice().isEmpty)
    let postActions = game.allowedActions(state: state)
    #expect(postActions.contains(.pass))
    #expect(postActions.contains(.rollDice))
  }

  @Test
  func testComposedGamePassAdvancesPlayer() {
    let game = CantStopPages.game()
    var state = game.newState()
    // Set up: rolled, made a move, now choosing pass
    state.phase = .rolled
    state.history = [.setPhase(.rolled)]
    state.rolledThisTurn = true
    // dice cleared (post-move)
    #expect(state.player == .player1)

    _ = game.reduce(into: &state, action: .pass)
    #expect(state.player == .player2)
    #expect(state.phase == .notRolled)
  }

  // MARK: - Graph

  @Test
  func testCantStopGraph() {
    let graph = CantStopGraph.board()
    let heights = [3, 5, 7, 9, 11, 13, 11, 9, 7, 5, 3]

    // Each column has height+1 sites (extra crown site at top) plus 3 off-board trays
    let totalBoardSites = heights.map { $0 + 1 }.reduce(0, +)
    #expect(graph.sites.count == totalBoardSites + 3)

    // Column 7 should have 14 sites (13 track + 1 crown)
    let col7Track = graph.tracks["col7"]!
    #expect(col7Track.count == 14)

    // Navigation works
    let bottom = col7Track[0]
    let top = col7Track[13]
    #expect(graph.site(bottom).top?.id == top)
    #expect(graph.site(bottom).next?.next?.id == col7Track[2])
  }

  @Test
  func testCantStopGraphSiteIDLookup() {
    let graph = CantStopGraph.board()
    let site = CantStopGraph.siteID(in: graph, col: 7, row: 0)
    #expect(site == graph.tracks["col7"]![0])

    let tray = CantStopGraph.traySite(in: graph, named: CantStopGraph.whiteTray)
    #expect(tray != nil)
  }

  @Test
  func testCantStopSceneConfig() throws {
    let config = CantStopSceneConfig.config()
    guard case .container("cantstop", let children) = config else {
      Issue.record("Expected root container")
      return
    }
    #expect(children.count >= 2)

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(SceneConfig.self, from: data)
    #expect(decoded == config)
  }

  // MARK: - Parameterized init

  @Test
  func threePlayerInit() {
    let state = CantStop.State(
      players: [.player1, .player2, .player3])
    #expect(state.players == [.player1, .player2, .player3])
    #expect(state.player == .player1)
    let p4placeholder = CantStop.Piece.placeholder(.player4, .seven)
    #expect(state.position[p4placeholder]?.col == .none)
    let p3placeholder = CantStop.Piece.placeholder(.player3, .seven)
    #expect(state.position[p3placeholder]?.col == .seven)
  }

  @Test
  func fourPlayerInit() {
    let state = CantStop.State(
      players: [.player1, .player2, .player3, .player4])
    #expect(state.players.count == 4)
  }

  @Test
  func defaultInitStillTwoPlayers() {
    let state = CantStop.State()
    #expect(state.players == [.player1, .player2])
  }
}
