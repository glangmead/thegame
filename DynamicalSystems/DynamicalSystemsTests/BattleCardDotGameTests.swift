import Foundation
import Testing
@testable import DynamicalSystems

@Suite("BattleCard .game")
struct BattleCardDotGameTests {

  private static func loadGameSource(_ name: String) throws -> String {
    guard let url = Bundle.main.url(
      forResource: name, withExtension: "game"
    ) else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try String(contentsOf: url, encoding: .utf8)
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

  @Test func pieceAdapterAfterInitialize() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.buildValidated(from: source)
    var state = game.newState()
    let actions = game.allowedActions(state: state)
    _ = game.reduce(into: &state, action: actions[0]) // initialize

    // Verify pieceTypes are set
    #expect(state.pieceTypes["corps"] == "CorpsPiece",
            "corps type: \(state.pieceTypes["corps"] ?? "nil")")
    #expect(state.pieceTypes["germanGrave"] == "GermanPiece",
            "germanGrave type: \(state.pieceTypes["germanGrave"] ?? "nil")")
    #expect(state.pieceTypes["allied82nd"] == "AllyPiece",
            "allied82nd type: \(state.pieceTypes["allied82nd"] ?? "nil")")

    // Verify playerIndex
    #expect(game.playerIndex["CorpsPiece"] == 0,
            "playerIndex: \(game.playerIndex)")
    #expect(game.playerIndex["AllyPiece"] == 0)
    #expect(game.playerIndex["GermanPiece"] == 1)

    // Build adapter and verify owners
    let adapter = InterpretedPieceAdapter(
      state: state,
      schema: state.schema,
      graph: game.graph,
      playerIndex: game.playerIndex
    )
    let nilOwnerPieces = adapter.pieces
      .filter { $0.owner == nil }
      .map { "\($0.label ?? "?") (type=\(state.pieceTypes[$0.label ?? ""] ?? "nil"))" }
    #expect(nilOwnerPieces.isEmpty,
            Comment(rawValue: "Nil-owner pieces: \(nilOwnerPieces)"))
    // Check every piece has correct owner and display values
    let expected: [(String, Int, String, Int)] = [
      ("corps", 0, "", 0),
      ("allied101st", 0, "allyStrength", 6),
      ("allied82nd", 0, "allyStrength", 6),
      ("allied1st", 0, "allyStrength", 5),
      ("germanEindhoven", 1, "germanStrength", 2),
      ("germanGrave", 1, "germanStrength", 2),
      ("germanNijmegen", 1, "germanStrength", 1),
      ("germanArnhem", 1, "germanStrength", 2)
    ]
    for (name, player, dvKey, dvVal) in expected {
      let piece = adapter.pieces.first { $0.label == name }
      #expect(piece != nil,
              Comment(rawValue: "Missing piece: \(name)"))
      #expect(piece?.owner == PlayerID(player),
              Comment(rawValue: "\(name) owner=\(String(describing: piece?.owner))"))
      if !dvKey.isEmpty {
        #expect(piece?.displayValues[dvKey] == dvVal,
                Comment(rawValue: "\(name) dv=\(piece?.displayValues.description ?? "nil")"))
      }
    }
    // Check for hash collisions in piece IDs
    let ids = adapter.pieces.map(\.id)
    let labels = adapter.pieces.map { "\($0.label ?? "?")=\($0.id)" }
    #expect(Set(ids).count == ids.count,
            Comment(rawValue: "Hash collision! \(labels)"))
  }

  @Test func existentialReducePreservesPieceTypes() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.buildValidated(from: source)
    let anyGame: any PlayableGame<InterpretedState, ActionValue> = game
    var state = anyGame.newState()
    let actions = anyGame.allowedActions(state: state)
    _ = anyGame.reduce(into: &state, action: actions[0])
    #expect(state.pieceTypes.count == 8,
            Comment(rawValue: "Expected 8, got \(state.pieceTypes.count): \(state.pieceTypes)"))
    for name in ["allied101st", "allied82nd", "allied1st", "corps",
                  "germanEindhoven", "germanGrave", "germanNijmegen", "germanArnhem"] {
      #expect(state.pieceTypes[name] != nil && !state.pieceTypes[name]!.isEmpty,
              Comment(rawValue: "\(name) type=\(state.pieceTypes[name] ?? "nil")"))
    }
  }

  @MainActor
  @Test func gameModelReducePreservesPieceTypes() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.buildValidated(from: source)
    let graph = game.graph
    let model = GameModel(game: game, graph: graph)
    let actions = model.allowedActions
    model.perform(actions[0]) // initialize
    let state = model.state
    #expect(state.pieceTypes.count == 8,
            Comment(rawValue: "Expected 8, got \(state.pieceTypes.count): \(state.pieceTypes)"))
    for name in ["allied101st", "allied82nd", "allied1st", "corps",
                  "germanEindhoven", "germanGrave", "germanNijmegen", "germanArnhem"] {
      #expect(state.pieceTypes[name] != nil && !state.pieceTypes[name]!.isEmpty,
              Comment(rawValue: "\(name) type=\(state.pieceTypes[name] ?? "nil")"))
    }
  }

  /// Same as gameModelReducePreservesPieceTypes but uses GameBuilder.build
  /// (the same function the app uses, not buildValidated)
  @MainActor
  @Test func gameModelWithBuildPreservesPieceTypes() throws {
    let source = try Self.loadGameSource("BattleCard")
    let game = try GameBuilder.build(from: source)
    let graph = game.graph
    let model = GameModel(game: game, graph: graph)
    let actions = model.allowedActions
    model.perform(actions[0]) // initialize
    let state = model.state
    #expect(state.pieceTypes.count == 8,
            Comment(rawValue: "build(): Expected 8, got \(state.pieceTypes.count): \(state.pieceTypes)"))
    // Also build the adapter exactly like InterpretedGameView.syncScene does
    let adapter = InterpretedPieceAdapter(
      state: state,
      schema: state.schema,
      graph: graph,
      playerIndex: game.playerIndex
    )
    let nilOwnerPieces = adapter.pieces
      .filter { $0.owner == nil }
      .map { "\($0.label ?? "?") (type=\(state.pieceTypes[$0.label ?? ""] ?? "nil"))" }
    #expect(nilOwnerPieces.isEmpty,
            Comment(rawValue: "build() nil-owner pieces: \(nilOwnerPieces)"))
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
