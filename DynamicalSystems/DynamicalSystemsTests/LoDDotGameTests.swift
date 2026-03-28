import Foundation
import Testing
@testable import DynamicalSystems

@Suite("LoD JSONC")
struct LoDDotGameTests {

  private static func loadGameSource(_ name: String) throws -> String {
    guard let url = Bundle.main.url(
      forResource: "\(name).game", withExtension: "jsonc"
    ) else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try String(contentsOf: url, encoding: .utf8)
  }

  @Test func loadsAndValidates() throws {
    let source = try Self.loadGameSource("Legions of Darkness")
    let game = try GameBuilder.build(fromJSONC: source)
    let state = game.newState()
    #expect(state.phase == "setup")
    let actions = game.allowedActions(state: state)
    #expect(actions.count == 1)
    #expect(actions.first?.name == "initialize")
  }

  @Test func initializeSetsState() throws {
    let source = try Self.loadGameSource("Legions of Darkness")
    let game = try GameBuilder.build(fromJSONC: source)
    var state = game.newState()
    let actions = game.allowedActions(state: state)
    _ = game.reduce(into: &state, action: actions[0])
    #expect(state.phase == "card")
    // Armies should be placed
    #expect(state.getDict("armyPosition")["east"] != nil)
    #expect(state.getDict("armyPosition")["west"] != nil)
    // Heroes should be in reserves
    #expect(
      state.getDict("heroLocationDict")["warrior"]?
        .displayString(interner: state.interner) == "reserves"
    )
  }

  @Test func drawCardAndAdvance() throws {
    let source = try Self.loadGameSource("Legions of Darkness")
    let game = try GameBuilder.build(fromJSONC: source)
    var state = game.newState()
    // Initialize
    let initActions = game.allowedActions(state: state)
    _ = game.reduce(into: &state, action: initActions[0])
    // Draw card
    let cardActions = game.allowedActions(state: state)
    let drawAction = cardActions.first { $0.name == "drawCard" }
    #expect(drawAction != nil)
    _ = game.reduce(into: &state, action: drawAction!)
    // Should have advanced to event or action phase
    #expect(state.phase == "event" || state.phase == "action")
  }

  @Test func playMultipleTurnsRandomly() throws {
    let source = try Self.loadGameSource("Legions of Darkness")
    let game = try GameBuilder.build(fromJSONC: source)
    var state = game.newState()
    var turns = 0
    while !game.isTerminal(state: state) {
      let actions = game.allowedActions(state: state)
      guard !actions.isEmpty else {
        Issue.record("No actions at turn \(turns), phase=\(state.phase)")
        break
      }
      let action = actions.randomElement()!
      _ = game.reduce(into: &state, action: action)
      turns += 1
      if turns > 500 { break }
    }
    // Game should have ended one way or another (victory or defeat)
    #expect(turns > 5, "Game too short: only \(turns) turns")
    #expect(turns <= 500, "Game did not terminate in 500 turns")
  }

  @Test func typedConditionsProduceSameResults() throws {
    let source = try Self.loadGameSource("Legions of Darkness")
    let game = try GameBuilder.build(fromJSONC: source)
    var state = game.newState()
    var steps = 0
    for _ in 0..<80 {
      let actions = game.allowedActions(state: state)
      if actions.isEmpty { break }
      _ = game.reduce(into: &state, action: actions[0])
      steps += 1
    }
    #expect(steps > 20, "Should play at least 20 steps")
  }

  @Test func typedConditionsMCTS() throws {
    let source = try Self.loadGameSource("Legions of Darkness")
    let game = try GameBuilder.build(fromJSONC: source)
    var state = game.newState()
    let initActions = game.allowedActions(state: state)
    _ = game.reduce(into: &state, action: initActions[0])
    let cardActions = game.allowedActions(state: state)
    let drawAction = cardActions.first { $0.name == "drawCard" }!
    _ = game.reduce(into: &state, action: drawAction)
    let mcts = OpenLoopMCTS(state: state, reducer: game)
    let rec = try mcts.recommendation(iters: 20)
    #expect(!rec.isEmpty)
  }
}
