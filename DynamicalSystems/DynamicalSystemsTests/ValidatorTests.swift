import Testing
@testable import DynamicalSystems

@Suite("Validator")
struct ValidatorTests {
  @Test func undefinedFieldInReduce() throws {
    let gameFile = """
    (game "Bad"
      (players 1)
      (components (enum Phase {play}))
      (state (field phase Phase) (flag gameAcknowledged))
      (actions (action go))
      (rules
        (terminal (field gameAcknowledged))
        (page "Play"
          (rule (when (== phase play)) (offer go))
          (reduce go (set nonexistent true)))))
    """
    #expect(throws: DSLError.self) {
      try GameBuilder.buildValidated(from: gameFile)
    }
  }

  @Test func validFieldPasses() throws {
    let gameFile = """
    (game "Good"
      (players 1)
      (components (enum Phase {play}))
      (state (field phase Phase) (flag gameAcknowledged))
      (actions (action go))
      (rules
        (terminal (field gameAcknowledged))
        (page "Play"
          (rule (when (== phase play)) (offer go))
          (reduce go (set gameAcknowledged true)))))
    """
    let game = try GameBuilder.buildValidated(from: gameFile)
    #expect(game.gameName == "Good")
  }

  @Test func builtinFieldsAreAllowed() throws {
    let gameFile = """
    (game "Builtins"
      (players 1)
      (components (enum Phase {play}))
      (state (field phase Phase) (flag gameAcknowledged))
      (actions (action go))
      (rules
        (terminal (field gameAcknowledged))
        (page "Play"
          (rule (when (== phase play)) (offer go))
          (reduce go (do (set ended true) (set victory true))))))
    """
    let game = try GameBuilder.buildValidated(from: gameFile)
    #expect(game.gameName == "Builtins")
  }
}
