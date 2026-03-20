import Testing
@testable import DynamicalSystems

@Suite("ReduceEngine")
struct ReduceEngineTests {
  func makeEngine() throws -> (ReduceEngine, InterpretedState) {
    let compInput = "(components (enum Track {east west}))"
    let stateInput = """
    (state
      (counter energy 0 6)
      (flag ended)
      (set breaches Track))
    """
    let registry = try ComponentRegistry(try SExprParser.parse(compInput))
    let schema = try StateSchema(try SExprParser.parse(stateInput))
    let state = InterpretedState(schema: schema)
    let engine = ReduceEngine(components: registry, defines: try DefineExpander([]))
    return (engine, state)
  }

  @Test func setAndIncrement() throws {
    let (engine, state) = try makeEngine()
    state.setCounter("energy", 2)
    let setExpr = try SExprParser.parse("(increment energy 3)")
    let result = try engine.execute(setExpr, state: state, actionParams: [:])
    #expect(state.getCounter("energy") == 5)
    #expect(result.followUps.isEmpty)
  }

  @Test func seqAndLog() throws {
    let (engine, state) = try makeEngine()
    let expr = try SExprParser.parse("""
    (seq
      (set energy 4)
      (log "energy set"))
    """)
    let result = try engine.execute(expr, state: state, actionParams: [:])
    #expect(state.getCounter("energy") == 4)
    #expect(result.logs.count == 1)
  }

  @Test func ifBranch() throws {
    let (engine, state) = try makeEngine()
    state.setCounter("energy", 3)
    let expr = try SExprParser.parse("""
    (if (> energy 2)
      (set energy 6)
      (set energy 0))
    """)
    _ = try engine.execute(expr, state: state, actionParams: [:])
    #expect(state.getCounter("energy") == 6)
  }

  @Test func chainFollowUp() throws {
    let (engine, state) = try makeEngine()
    let expr = try SExprParser.parse("(chain advanceArmies)")
    let result = try engine.execute(expr, state: state, actionParams: [:])
    #expect(result.followUps.count == 1)
    #expect(result.followUps[0].name == "advanceArmies")
  }

  @Test func guardAbort() throws {
    let (engine, state) = try makeEngine()
    state.setCounter("energy", 0)
    let expr = try SExprParser.parse("""
    (seq
      (guard (> energy 2))
      (set energy 6))
    """)
    _ = try engine.execute(expr, state: state, actionParams: [:])
    #expect(state.getCounter("energy") == 0)
  }
}
