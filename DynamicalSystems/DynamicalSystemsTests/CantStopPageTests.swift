//
//  CantStopPageTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/17/25.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct CantStopPageTests {

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
    // Roll: 3,4,2,5 -> splits: (7,7), (5,9), (8,6)
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
    // Roll: 3,4,2,5 -> splits: (7,7), (5,9), (8,6)
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
    // Roll: 6,6,6,5 -> splits:
    //   (die1+die2=12, die3+die4=11)
    //   (die1+die3=12, die2+die4=11)
    //   (die1+die4=11, die2+die3=12)
    // All three produce the same columns {12, 11} -> should dedup to one action
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
    // Roll: 3,4,3,4 -> all splits give (7, 7)
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
    // only produce columns not matching any whites -> bust
    var state = Self.stateWithDice(.one, .one, .one, .one)
    state.position[.white(.white1)] = CantStop.Position(col: .six, row: 1)
    state.position[.white(.white2)] = CantStop.Position(col: .seven, row: 1)
    state.position[.white(.white3)] = CantStop.Position(col: .eight, row: 1)
    // All splits: (1+1=2, 1+1=2). Column 2 has no white and no spare white -> bust
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
}
