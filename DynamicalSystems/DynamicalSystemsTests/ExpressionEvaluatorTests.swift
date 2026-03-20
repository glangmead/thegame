import Testing
@testable import DynamicalSystems

@Suite("ExpressionEvaluator")
struct ExpressionEvaluatorTests {

  private func makeContext() throws -> ExpressionEvaluator.Context {
    let stateInput = "(state (counter energy 0 6))"
    let schema = try StateSchema(try SExprParser.parse(stateInput))
    let state = InterpretedState(schema: schema)
    state.setCounter("energy", 3)
    let compInput = "(components (enum Track {east west}))"
    let registry = try ComponentRegistry(try SExprParser.parse(compInput))
    return ExpressionEvaluator.Context(
      state: state, components: registry, bindings: [:],
      actionParams: [:], randomSource: nil
    )
  }

  @Test func arithmetic() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("(+ 3 4)")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .int(7))
  }

  @Test func comparison() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("(> 5 3)")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .bool(true))
  }

  @Test func stateFieldAccess() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("energy")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .int(3))
  }

  @Test func booleanShortCircuit() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("(and false (/ 1 0))")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .bool(false))
  }

  @Test func fnCall() throws {
    let compInput = """
    (components
      (enum Track {east west sky})
      (fn isWall Track {east true west true sky false}))
    """
    let stateInput = "(state (counter x 0 1))"
    let registry = try ComponentRegistry(try SExprParser.parse(compInput))
    let schema = try StateSchema(try SExprParser.parse(stateInput))
    let state = InterpretedState(schema: schema)
    let ctx = ExpressionEvaluator.Context(
      state: state, components: registry, bindings: [:],
      actionParams: [:], randomSource: nil
    )
    let expr = try SExprParser.parse("(isWall east)")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .bool(true))
  }

  @Test func letBinding() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("(let x 5 (+ $x 3))")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .int(8))
  }

  @Test func nthExpression() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("(nth (list 10 20 30) 1)")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .int(20))
  }

  @Test func filterExpression() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("(filter (list 1 2 3 4 5) (\\ (x) (> $x 3)))")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .list([.int(4), .int(5)]))
  }

  @Test func mapExpression() throws {
    let ctx = try makeContext()
    let expr = try SExprParser.parse("(map (list 1 2 3) (\\ (x) (* $x 2)))")
    let result = try ExpressionEvaluator.eval(expr, context: ctx)
    #expect(result == .list([.int(2), .int(4), .int(6)]))
  }
}
