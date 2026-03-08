//
//  CantStopTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/17/25.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct CantStopPagesTests {

  /// Helper: create a state with specific dice values, in .rolled phase.
  private static func stateWithDice(
    _ d1: DSix, _ d2: DSix, _ d3: DSix, _ d4: DSix
  ) -> CantStop.State {
    var state = CantStop.State()
    state.phase = .rolled
    state.dice[.die1] = d1
    state.dice[.die2] = d2
    state.dice[.die3] = d3
    state.dice[.die4] = d4
    state.rolledThisTurn = true
    state.history = [.setPhase(.rolled)]
    return state
  }

  // MARK: - Roll Page

  @Test
  func testRollPageOffersRollDice() {
    let state = CantStop.State() // phase = .notRolled
    let page = CantStopPages.rollPage()
    #expect(page.allowedActions(state: state) == [.rollDice])
  }

  @Test
  func testRollPageInactiveWhenRolled() {
    var state = CantStop.State()
    state.phase = .rolled
    let page = CantStopPages.rollPage()
    #expect(page.allowedActions(state: state).isEmpty)
  }

  @Test
  func testRollPageSetsRolledThisTurn() {
    var state = CantStop.State()
    let page = CantStopPages.rollPage()
    _ = page.reduce(&state, .rollDice)
    #expect(state.rolledThisTurn)
    #expect(state.rolledDice().count == 4)
  }

  // MARK: - Move Page

  @Test
  func testMovePageBasicActions() {
    // Roll: 3,4,2,5 → splits: (7,7), (5,9), (8,6)
    let state = Self.stateWithDice(.three, .four, .two, .five)
    let page = CantStopPages.movePage()
    let actions = page.allowedActions(state: state)
    #expect(!actions.isEmpty)
    // All actions should be .progressColumns
    for action in actions {
      guard case .progressColumns = action else {
        Issue.record("Expected .progressColumns, got \(action)")
        return
      }
    }
  }

  @Test
  func testMovePageBothPairs() {
    // Roll: 3,4,2,5 → splits: (7,7), (5,9), (8,6)
    let state = Self.stateWithDice(.three, .four, .two, .five)
    let page = CantStopPages.movePage()
    let actions = page.allowedActions(state: state)
    #expect(actions.contains(.progressColumns([.seven, .seven])))
    #expect(actions.contains(.progressColumns([.five, .nine])))
    #expect(actions.contains(.progressColumns([.eight, .six])))
  }

  @Test
  func testMovePageSinglePairWhenWhitesExhausted() {
    // Place all 3 white pieces in different columns
    var state = Self.stateWithDice(.three, .four, .two, .five)
    state.position[.white(.white1)] = CantStop.Position(col: .five, row: 1)
    state.position[.white(.white2)] = CantStop.Position(col: .six, row: 1)
    state.position[.white(.white3)] = CantStop.Position(col: .seven, row: 1)
    // Splits: (7,7) can do both (white already in 7). (5,9) can do 5 (white in 5) but not 9 (no spare).
    // (8,6) can do 6 (white in 6) but not 8 (no spare).
    let page = CantStopPages.movePage()
    let actions = page.allowedActions(state: state)
    // (7,7) should work: white in 7 advances twice
    #expect(actions.contains(.progressColumns([.seven, .seven])))
    // (5,9) should split: only 5 is available
    #expect(actions.contains(.progressColumns([.five])))
    // (8,6) should split: only 6 is available
    #expect(actions.contains(.progressColumns([.six])))
  }

  @Test
  func testMovePageDedup() {
    // Roll: 6,6,6,5 → splits:
    //   (die1+die2=12, die3+die4=11)
    //   (die1+die3=12, die2+die4=11)
    //   (die1+die4=11, die2+die3=12)
    // All three produce the same columns {12, 11} → should dedup to one action
    let state = Self.stateWithDice(.six, .six, .six, .five)
    let page = CantStopPages.movePage()
    let actions = page.allowedActions(state: state)
    // Verify no two actions lead to the same state
    var seen = Set<CantStop.State>()
    for action in actions {
      var testState = state
      _ = CantStopPages.progressColumnsOrFail(state: &testState, action: action)
      let isNew = seen.insert(testState).inserted
      #expect(isNew, "Duplicate state found for action \(action)")
    }
  }

  @Test
  func testMovePageNoDiceNoActions() {
    var state = CantStop.State()
    state.phase = .rolled
    state.history = [.setPhase(.rolled)]
    let page = CantStopPages.movePage()
    #expect(page.allowedActions(state: state).isEmpty)
  }

  @Test
  func testMovePageProgressEffect() {
    var state = Self.stateWithDice(.three, .four, .two, .five)
    let page = CantStopPages.movePage()

    // Progress in columns 5 and 9
    state.history.append(.progressColumns([.five, .nine]))
    let result = page.reduce(&state, .progressColumns([.five, .nine]))
    #expect(result != nil)

    // White pieces should be placed
    #expect(state.whiteIn(col: .five) != nil)
    #expect(state.whiteIn(col: .nine) != nil)

    // Dice should be cleared
    #expect(state.rolledDice().isEmpty)
  }

  @Test
  func testMovePageDoubleColumnProgress() {
    // Roll: 3,4,3,4 → all splits give (7, 7)
    var state = Self.stateWithDice(.three, .four, .three, .four)
    let page = CantStopPages.movePage()
    let actions = page.allowedActions(state: state)
    #expect(actions.contains(.progressColumns([.seven, .seven])))

    // Apply the action
    state.history.append(.progressColumns([.seven, .seven]))
    _ = page.reduce(&state, .progressColumns([.seven, .seven]))

    // White piece should be at row 2 in column 7 (advanced twice)
    let white = state.whiteIn(col: .seven)!
    #expect(state.position[white]!.row == 2)
  }

  // MARK: - Bust

  @Test
  func testBustCondition() {
    // All 3 white pieces occupied in different columns, roll dice that
    // only produce columns not matching any whites → bust
    var state = Self.stateWithDice(.one, .one, .one, .one)
    state.position[.white(.white1)] = CantStop.Position(col: .six, row: 1)
    state.position[.white(.white2)] = CantStop.Position(col: .seven, row: 1)
    state.position[.white(.white3)] = CantStop.Position(col: .eight, row: 1)
    // All splits: (1+1=2, 1+1=2). Column 2 has no white and no spare white → bust
    let bustPage = CantStopPages.bustPage()
    #expect(bustPage.allowedActions(state: state) == [.bust])
  }

  @Test
  func testBustEffect() {
    var state = Self.stateWithDice(.one, .one, .one, .one)
    state.position[.white(.white1)] = CantStop.Position(col: .six, row: 1)
    state.position[.white(.white2)] = CantStop.Position(col: .seven, row: 1)
    state.position[.white(.white3)] = CantStop.Position(col: .eight, row: 1)

    let result = CantStopPages.bustPage().reduce(&state, .bust)
    #expect(result != nil)

    // White pieces should be cleared
    #expect(state.whiteIn(col: .six) == nil)
    #expect(state.whiteIn(col: .seven) == nil)
    #expect(state.whiteIn(col: .eight) == nil)

    // Player should advance
    #expect(state.player == .player2)

    // Should transition to notRolled
    #expect(result!.1 == [.setPhase(.notRolled)])
  }

  @Test
  func testNoBustWhenMovesAvailable() {
    // Fresh state with dice that have legal moves
    let state = Self.stateWithDice(.three, .four, .two, .five)
    let bustPage = CantStopPages.bustPage()
    #expect(bustPage.allowedActions(state: state).isEmpty)
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
    // phase = .notRolled, rolledThisTurn = false → no pass
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
      col: .two, row: CantStop.colHeights()[.two]!)
    state.position[.placeholder(.player1, .three)] = CantStop.Position(
      col: .three, row: CantStop.colHeights()[.three]!)
    state.position[.placeholder(.player1, .four)] = CantStop.Position(
      col: .four, row: CantStop.colHeights()[.four]!)

    let victoryPage = CantStopPages.victoryPage()
    #expect(victoryPage.allowedActions(state: state) == [.claimVictory])
  }

  @Test
  func testVictoryEffect() {
    var state = CantStop.State()
    state.phase = .rolled
    state.rolledThisTurn = true
    state.position[.placeholder(.player1, .two)] = CantStop.Position(
      col: .two, row: CantStop.colHeights()[.two]!)
    state.position[.placeholder(.player1, .three)] = CantStop.Position(
      col: .three, row: CantStop.colHeights()[.three]!)
    state.position[.placeholder(.player1, .four)] = CantStop.Position(
      col: .four, row: CantStop.colHeights()[.four]!)

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
      col: .two, row: CantStop.colHeights()[.two]!)
    state.position[.placeholder(.player1, .three)] = CantStop.Position(
      col: .three, row: CantStop.colHeights()[.three]!)

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

    // Should have sites for all columns plus 3 off-board trays
    let totalBoardSites = heights.reduce(0, +)
    #expect(graph.sites.count == totalBoardSites + 3)

    // Column 7 should have 13 sites
    let col7Track = graph.tracks["col7"]!
    #expect(col7Track.count == 13)

    // Navigation works
    let bottom = col7Track[0]
    let top = col7Track[12]
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
}
