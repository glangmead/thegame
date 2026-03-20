import Foundation
import Testing
@testable import DynamicalSystems

@Suite("BattleCard .game")
struct BattleCardDotGameTests {

  private static func loadGameSource(_ name: String) throws -> String {
    let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    let projDir = testDir.deletingLastPathComponent()
    let gameURL = projDir.appendingPathComponent("Resources/\(name).game")
    return try String(contentsOf: gameURL, encoding: .utf8)
  }

  private static func playOneMCTSGame(
    _ game: ComposedGame<InterpretedState>, iters: Int
  ) throws -> InterpretedState {
    var state = game.newState()
    var turns = 0
    while !game.isTerminal(state: state) {
      let actions = game.allowedActions(state: state)
      guard !actions.isEmpty else { break }
      let action: ActionValue
      if actions.count == 1 {
        action = actions[0]
      } else {
        let mcts = OpenLoopMCTS(state: state, reducer: game)
        let recs = try mcts.recommendation(iters: iters)
        let best = recs.max { lhs, rhs in
          let lhsRatio = lhs.value.0 / max(lhs.value.1, 1)
          let rhsRatio = rhs.value.0 / max(rhs.value.1, 1)
          return lhsRatio < rhsRatio
        }
        action = best?.key ?? actions[0]
      }
      _ = game.reduce(into: &state, action: action)
      turns += 1
      if turns > 500 { break }
    }
    return state
  }

  @Test func loadsAndValidates() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.buildValidated(from: source)
    let state = game.newState()
    #expect(state.phase == "setup")
    let actions = game.allowedActions(state: state)
    #expect(actions.count == 1)
    #expect(actions.first?.name == "initialize")
  }

  @Test func battlePhaseHasActions() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.buildValidated(from: source)
    var state = game.newState()
    // Setup
    let setupActions = game.allowedActions(state: state)
    _ = game.reduce(into: &state, action: setupActions[0])
    #expect(state.phase == "airdrop")
    // Airdrop all three allies
    while state.phase == "airdrop" {
      let actions = game.allowedActions(state: state)
      guard !actions.isEmpty else { break }
      _ = game.reduce(into: &state, action: actions[0])
    }
    #expect(state.phase == "battle", "Expected battle phase, got \(state.phase)")
    let battleActions = game.allowedActions(state: state)
    #expect(!battleActions.isEmpty, "Battle phase should have actions")
    let battleNames = Set(battleActions.map(\.name))
    #expect(
      battleNames.contains("rollForAttack") || battleNames.contains("rollForDefend"),
      "Battle actions should include attack or defend, got: \(battleNames)"
    )
  }

  @Test func randomPlaythrough() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.buildValidated(from: source)
    for _ in 0..<20 {
      var state = game.newState()
      var turns = 0
      while !game.isTerminal(state: state) {
        let actions = game.allowedActions(state: state)
        guard !actions.isEmpty else { break }
        _ = game.reduce(into: &state, action: actions.randomElement()!)
        turns += 1
        if turns > 200 { break }
      }
      #expect(state.ended, "Game stuck after \(turns) turns, phase=\(state.phase)")
    }
  }

  @Test func mctsPlaythrough() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.buildValidated(from: source)
    var wins = 0
    var ended = 0
    let trials = 5
    for _ in 0..<trials {
      let finalState = try Self.playOneMCTSGame(game, iters: 30)
      if finalState.ended { ended += 1 }
      if finalState.victory { wins += 1 }
    }
    #expect(ended == trials,
            "Non-terminating games: \(trials - ended)/\(trials)")
  }
}
