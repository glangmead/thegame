import Foundation
import Testing
@testable import DynamicalSystems

@Suite("InterpretedGame")
struct InterpretedGameTests {
  @Test func trivialGamePlaythrough() throws {
    let gameFile = """
    (game "Coin Flip"
      (players 1)
      (components
        (enum Phase {play done}))
      (state
        (counter score 0 10)
        (flag ended)
        (flag victory)
        (flag gameAcknowledged)
        (field phase Phase))
      (graph)
      (actions
        (action flipHeads)
        (action flipTails)
        (action acknowledge))
      (rules
        (phases {play done})
        (terminal (field gameAcknowledged))
        (page "Play"
          (rule (when (== phase play))
                (offer flipHeads flipTails))
          (reduce flipHeads
            (seq (increment score 1)
                 (if (>= score 3)
                   (seq (endGame victory) (setPhase done))
                   (log "tails, no points"))))
          (reduce flipTails
            (log "tails, no points")))
        (priority "Victory"
          (rule (when (and victory (not gameAcknowledged)))
                (offer acknowledge))
          (reduce acknowledge
            (set gameAcknowledged true)))))
    """
    let game = try GameBuilder.build(from: gameFile)
    var state = game.newState()
    #expect(!game.isTerminal(state: state))
    // Play 3 heads to win
    for _ in 0..<3 {
      let actions = game.allowedActions(state: state)
      let heads = actions.first { $0.name == "flipHeads" }!
      _ = game.reduce(into: &state, action: heads)
    }
    // Should see victory acknowledge
    let actions = game.allowedActions(state: state)
    #expect(actions.count == 1)
    #expect(actions[0].name == "acknowledge")
    _ = game.reduce(into: &state, action: actions[0])
    #expect(game.isTerminal(state: state))
  }

  @Test func heuristicFromMetadata() throws {
    let gameFile = """
    (game "WithAI"
      (players 1)
      (components (enum Phase {play}))
      (state
        (counter score 0 10)
        (field phase Phase)
        (flag gameAcknowledged))
      (actions (action go))
      (rules
        (terminal (field gameAcknowledged))
        (page "Play"
          (rule (when (== phase play)) (offer go))
          (reduce go (increment score 1)))))

    (metadata
      (ai
        (heuristic (/ score 10))))
    """
    let game = try GameBuilder.build(from: gameFile)
    var state = game.newState()
    state.setCounter("score", 5)
    let eval = game.stateEvaluator?(state)
    #expect(eval == 0.5)
  }

  @Test func mctsPlaysSimpleGame() throws {
    let gameFile = """
    (game "Race to 5"
      (players 1)
      (components (enum Phase {play}))
      (state
        (counter score 0 5)
        (field phase Phase)
        (flag ended)
        (flag victory)
        (flag gameAcknowledged))
      (actions
        (action step)
        (action acknowledge))
      (rules
        (phases {play})
        (terminal (field gameAcknowledged))
        (rolloutTerminal (field ended))
        (page "Play"
          (rule (when (and (== phase play) (not ended)))
                (offer step))
          (reduce step
            (seq
              (increment score 1)
              (if (>= score 5)
                (endGame victory)
                (log "stepped")))))
        (priority "Victory"
          (rule (when (and ended (not gameAcknowledged)))
                (offer acknowledge))
          (reduce acknowledge
            (set gameAcknowledged true)))))
    """
    let game = try GameBuilder.build(from: gameFile)
    var state = game.newState()

    // MCTS should find that "step" is the only move and win
    let mcts = OpenLoopMCTS(state: state, reducer: game)
    let recs = try mcts.recommendation(iters: 100)
    // With only one possible action, MCTS should recommend "step"
    #expect(!recs.isEmpty)
    // Play the game manually to verify end-to-end
    while !game.isTerminal(state: state) {
      let actions = game.allowedActions(state: state)
      guard let action = actions.first else { break }
      _ = game.reduce(into: &state, action: action)
    }
    #expect(state.victory)
  }

  @Test func initialPhaseSet() throws {
    let gameFile = """
    (game "Phase Test"
      (players 1)
      (components (enum Phase {alpha beta}))
      (state (field phase Phase) (flag gameAcknowledged))
      (actions (action doSomething))
      (rules
        (phases {alpha beta})
        (terminal (field gameAcknowledged))
        (page "Alpha"
          (rule (when (== phase alpha))
                (offer doSomething))
          (reduce doSomething
            (set gameAcknowledged true)))))
    """
    let game = try GameBuilder.build(from: gameFile)
    let state = game.newState()
    #expect(state.phase == "alpha")
  }

  @Test func sampleGameLoadsAndPlays() throws {
    let source = """
    (game "Coin Collector"
      (players 1)
      (components
        (enum Phase {flip done})
        (enum Outcome {heads tails}))
      (state
        (counter heads 0 10)
        (counter tails 0 3)
        (field phase Phase)
        (flag ended)
        (flag victory)
        (flag gameAcknowledged))
      (actions
        (action flip)
        (action acknowledge))
      (rules
        (phases {flip done})
        (terminal (field gameAcknowledged))
        (rolloutTerminal (field ended))
        (page "Flip"
          (rule (when (and (== phase flip) (not ended)))
                (offer flip))
          (reduce flip
            (seq
              (let coin (rollDie 2))
              (if (== $coin 1)
                (seq
                  (increment heads 1)
                  (set tails 0)
                  (if (>= heads 10)
                    (endGame victory)
                    (log "Heads!")))
                (seq
                  (increment tails 1)
                  (if (>= tails 3)
                    (endGame defeat)
                    (log "Tails...")))))))
        (priority "End"
          (rule (when (and ended (not gameAcknowledged)))
                (offer acknowledge))
          (reduce acknowledge
            (set gameAcknowledged true)))))

    (metadata
      (ai
        (heuristic (- (* 0.1 heads) (* 0.3 tails)))))
    """
    let game = try GameBuilder.build(from: source)
    let state = game.newState()
    #expect(state.phase == "flip")
    let actions = game.allowedActions(state: state)
    #expect(!actions.isEmpty)
    #expect(actions.first?.name == "flip")
    // Verify heuristic
    #expect(game.stateEvaluator != nil)
    let eval = game.stateEvaluator?(state)
    #expect(eval == 0.0) // heads=0, tails=0 → 0.0
  }
}
