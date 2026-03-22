//
//  OpenLoopMCTSTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Testing

@MainActor
struct OpenLoopMCTSTests {

  // MARK: - CantStop MCTS

  @Test
  func testCantStopMCTSRecommendation() throws {
    let game = CantStopPages.game()
    var state = game.newState()
    // Roll dice so MCTS has something to think about
    _ = game.reduce(into: &state, action: .rollDice)

    let mcts = OpenLoopMCTS(state: state, reducer: game)
    let results = try mcts.recommendation(iters: 10, numRollouts: 1)
    #expect(!results.isEmpty)
    // Every recommended action should have been visited
    for (_, valCount) in results {
      #expect(valCount.1 > 0)
    }
  }

  @Test
  func testCantStopMCTSRecommendationOnTerminalState() throws {
    let game = CantStopPages.game()
    var state = game.newState()
    state.ended = true
    state.endedInVictoryFor = [.player1]

    let mcts = OpenLoopMCTS(state: state, reducer: game)
    let results = try mcts.recommendation(iters: 10, numRollouts: 1)
    #expect(results.isEmpty)
  }

  @Test(.timeLimit(.minutes(1)))
  func testCantStopFullGameMCTS() throws {
    let game = CantStopPages.game()
    #expect(!game.newState().ended)
    var state = game.newState()
    let maxTurns = 5000

    var turns = 0
    while !state.ended && turns < maxTurns {
      let actions = game.allowedActions(state: state)
      guard !actions.isEmpty else {
        Issue.record("No action available at turn \(turns)")
        return
      }

      let action: CantStop.Action
      if actions.count == 1 {
        action = actions[0]
      } else {
        let mcts = OpenLoopMCTS(state: state, reducer: game)
        let results = try mcts.recommendation(iters: 2, numRollouts: 1)

        let ratio: ((Float, Float)) -> Float = { valCount in
          valCount.0 / (valCount.1 > 0 ? valCount.1 : 1)
        }
        let bestValue = results.values.map({ ratio($0) }).max() ?? 0
        let bestAction = results.keys.filter { action in
          ratio(results[action]!).near(bestValue)
        }.randomElement()

        guard let best = bestAction else {
          Issue.record("MCTS returned no action at turn \(turns)")
          return
        }
        action = best
      }

      _ = game.reduce(into: &state, action: action)
      turns += 1
    }

    #expect(state.ended, "Game should have ended within \(maxTurns) turns")
    #expect(!state.endedInVictoryFor.isEmpty || !state.endedInDefeatFor.isEmpty)
  }

  // MARK: - BattleCard MCTS

  @Test
  func testBattleCardMCTSRecommendation() throws {
    let game = BCPages.game()
    let state = game.newState()

    let mcts = OpenLoopMCTS(state: state, reducer: game)
    let results = try mcts.recommendation(iters: 10, numRollouts: 1)
    #expect(!results.isEmpty)
    // Initial state should recommend .initialize
    #expect(results.keys.contains(.initialize))
  }

  @Test
  func testBattleCardFullGameMCTS() throws {
    let game = BCPages.game()
    var state = game.newState()
    let maxTurns = 5000

    var turns = 0
    while !state.ended && turns < maxTurns {
      let mcts = OpenLoopMCTS(state: state, reducer: game)
      let results = try mcts.recommendation(iters: 5, numRollouts: 1)

      let ratio: ((Float, Float)) -> Float = { valCount in
        valCount.0 / (valCount.1 > 0 ? valCount.1 : 1)
      }
      let bestValue = results.values.map({ ratio($0) }).max() ?? 0
      let bestAction = results.keys.filter { action in
        ratio(results[action]!).near(bestValue)
      }.randomElement()

      guard let action = bestAction else {
        Issue.record("No action available at turn \(turns), state: \(state)")
        return
      }

      _ = game.reduce(into: &state, action: action)
      turns += 1
    }

    #expect(state.ended, "Game should have ended within \(maxTurns) turns")
    #expect(!state.endedInVictoryFor.isEmpty || !state.endedInDefeatFor.isEmpty)
  }
}
