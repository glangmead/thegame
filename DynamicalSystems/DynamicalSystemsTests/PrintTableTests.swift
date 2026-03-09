//
//  PrintTableTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/9/26.
//

import Testing
import Foundation
import TextTable

private struct StringOutput: TextOutputStream {
  var value = ""
  mutating func write(_ string: String) {
    value += string
  }
}

@MainActor
struct PrintTableTests {

  // MARK: - Battle Card: Market Garden

  @Test
  func testBCPrintTableEmptyState() {
    let state = BattleCard.State()
    var out = StringOutput()
    state.printTable(to: &out)
    #expect(!out.value.isEmpty)
  }

  @Test
  func testBCPrintTableAfterSetup() {
    let game = BCPages.game()
    var state = game.newState()
    _ = game.reduce(into: &state, action: .initialize)
    var out = StringOutput()
    state.printTable(to: &out)
    #expect(out.value.contains("Turn"))
    #expect(out.value.contains("Arnhem"))
  }

  // MARK: - Can't Stop

  @Test
  func testCantStopPrintTableEmptyState() {
    let state = CantStop.State()
    var out = StringOutput()
    state.printTable(to: &out)
    #expect(!out.value.isEmpty)
  }

  // MARK: - Malayan Campaign

  @Test
  func testMCPrintTableEmptyState() {
    let state = MalayanCampaign.State()
    var out = StringOutput()
    state.printTable(to: &out)
    #expect(!out.value.isEmpty)
    #expect(out.value.contains("Turn"))
    #expect(out.value.contains("Singapore"))
  }

  @Test
  func testMCPrintTableAfterSetup() {
    let game = MCPages.game()
    var state = game.newState()
    _ = game.reduce(into: &state, action: .initialize)
    var out = StringOutput()
    state.printTable(to: &out)
    #expect(out.value.contains("Jitra"))
    #expect(out.value.contains("JpT"))
  }

  @Test
  func testMCInitialActions() {
    let game = MCPages.game()
    let state = game.newState()
    let actions = game.allowedActions(state: state)
    #expect(actions == [.initialize])
  }
}
