import Testing
@testable import DynamicalSystems

@Suite("InterpretedState")
struct InterpretedStateTests {
  @Test func constructFromSchema() throws {
    let input = """
    (state
      (counter energy 0 6)
      (flag ended)
      (set breaches Track))
    """
    let schema = try StateSchema(try SExprParser.parse(input))
    let state = InterpretedState(schema: schema)
    #expect(state.getCounter("energy") == 0)
    #expect(state.getFlag("ended") == false)
    #expect(state.getSet("breaches").isEmpty)
  }

  @Test func counterClamping() throws {
    let input = "(state (counter energy 0 6))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.setCounter("energy", 10)
    #expect(state.getCounter("energy") == 6)
    state.setCounter("energy", -5)
    #expect(state.getCounter("energy") == 0)
  }

  @Test func setOperations() throws {
    let input = "(state (set breaches Track))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.insertIntoSet("breaches", "east")
    #expect(state.getSet("breaches").contains("east"))
    state.removeFromSet("breaches", "east")
    #expect(state.getSet("breaches").isEmpty)
  }

  @Test func dictOperations() throws {
    let input = "(state (dict armyPosition ArmySlot Int))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.setDictEntry("armyPosition", key: "east", value: .int(5))
    #expect(state.getDict("armyPosition")["east"] == .int(5))
    state.removeDictEntry("armyPosition", key: "east")
    #expect(state.getDict("armyPosition")["east"] == nil)
  }

  @Test func historyTracking() throws {
    let input = "(state (counter energy 0 6))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.history.append(ActionValue("drawCard"))
    state.phase = "card"
    #expect(state.history.count == 1)
    #expect(state.phase == "card")
  }
}
