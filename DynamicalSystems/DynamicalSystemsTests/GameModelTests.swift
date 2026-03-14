//
//  GameModelTests.swift
//  DynamicalSystems
//

import Testing
import Foundation

@MainActor
struct GameModelTests {
  @Test
  func resetClearsStateAndLogs() {
    let graph = CantStopGraph.board(cellSize: 25)
    let game = CantStopPages.game()
    let model = GameModel(game: game, graph: graph)

    model.perform(.rollDice)
    #expect(!model.logs.isEmpty || model.state.phase != .notRolled)

    let newGame = CantStopPages.game()
    model.reset(with: newGame)
    #expect(model.logs.isEmpty)
    #expect(model.state.phase == .notRolled)
  }

  @Test
  func performAccumulatesLogs() {
    let graph = CantStopGraph.board(cellSize: 25)
    let game = CantStopPages.game()
    let model = GameModel(game: game, graph: graph)

    model.perform(.rollDice)
    let firstCount = model.logs.count

    let actions = model.allowedActions
    if let action = actions.first {
      model.perform(action)
      #expect(model.logs.count >= firstCount)
    }
  }

  @Test
  func isTerminalReflectsGameState() {
    let graph = CantStopGraph.board(cellSize: 25)
    let game = CantStopPages.game()
    let model = GameModel(game: game, graph: graph)
    #expect(!model.isTerminal)
  }
}
