import Testing
@testable import DynamicalSystems

// swiftlint:disable file_length type_body_length

@Suite("ExpressionCompiler")
struct ExpressionCompilerTests {

  // MARK: - Test helpers

  private func makeCompiler(
    components compInput: String = "(components (enum Track {east west}))",
    state stateInput: String = "(state (counter energy 0 6))"
  ) throws -> (ExpressionCompiler, StateSchema) {
    let registry = try ComponentRegistry(try SExprParser.parse(compInput))
    let schema = try StateSchema(try SExprParser.parse(stateInput))
    return (ExpressionCompiler(components: registry, schema: schema), schema)
  }

  private func makeEnv(
    schema: StateSchema,
    setup: (InterpretedState) -> Void = { _ in },
    actionParams: [String: DSLValue] = [:],
    randomSource: RandomSource? = nil
  ) -> ExpressionCompiler.Env {
    let state = InterpretedState(schema: schema)
    setup(state)
    return ExpressionCompiler.Env(
      state: state, actionParams: actionParams,
      randomSource: randomSource
    )
  }

  private func evalExpr(
    _ source: String,
    components: String = "(components (enum Track {east west}))",
    state: String = "(state (counter energy 0 6))",
    setup: (InterpretedState) -> Void = { _ in },
    actionParams: [String: DSLValue] = [:],
    randomSource: RandomSource? = nil
  ) throws -> DSLValue {
    let (compiler, schema) = try makeCompiler(
      components: components, state: state
    )
    let sexpr = try SExprParser.parse(source)
    let compiled = compiler.expr(sexpr)
    let env = makeEnv(
      schema: schema, setup: setup,
      actionParams: actionParams, randomSource: randomSource
    )
    return try compiled(env)
  }

  private func evalStmt(
    _ source: String,
    components: String = "(components (enum Track {east west}))",
    state: String = "(state (counter energy 0 6))",
    setup: (InterpretedState) -> Void = { _ in },
    actionParams: [String: DSLValue] = [:],
    randomSource: RandomSource? = nil
  ) throws -> (ReduceResult, InterpretedState) {
    let (compiler, schema) = try makeCompiler(
      components: components, state: state
    )
    let sexpr = try SExprParser.parse(source)
    let compiled = compiler.stmt(sexpr)
    let state = InterpretedState(schema: schema)
    setup(state)
    let env = ExpressionCompiler.Env(
      state: state, actionParams: actionParams,
      randomSource: randomSource
    )
    let result = try compiled(env)
    return (result, state)
  }

  // MARK: - Atom compilation

  @Test func integerLiteral() throws {
    let result = try evalExpr("42")
    #expect(result == .int(42))
  }

  @Test func floatLiteral() throws {
    let result = try evalExpr("3.14")
    #expect(result == .float(3.14))
  }

  @Test func booleanLiterals() throws {
    #expect(try evalExpr("true") == .bool(true))
    #expect(try evalExpr("false") == .bool(false))
  }

  @Test func nilLiteral() throws {
    #expect(try evalExpr("nil") == .nil)
  }

  @Test func enumCase() throws {
    let result = try evalExpr("east")
    #expect(result == .enumCase(type: "Track", value: "east"))
  }

  @Test func counterFieldAccess() throws {
    let result = try evalExpr("energy", setup: { state in
      state.setCounter("energy", 3)
    })
    #expect(result == .int(3))
  }

  @Test func flagFieldAccess() throws {
    let result = try evalExpr(
      "ended",
      state: "(state (flag ended))",
      setup: { $0.setFlag("ended", true) }
    )
    #expect(result == .bool(true))
  }

  @Test func frameworkFieldEnded() throws {
    let result = try evalExpr(
      "ended",
      state: "(state (flag ended))",
      setup: { $0.ended = true }
    )
    #expect(result == .bool(true))
  }

  @Test func frameworkFieldPhase() throws {
    let result = try evalExpr(
      "phase",
      components: "(components (enum Phase {card army}))",
      state: "(state (field phase Phase))",
      setup: { $0.phase = "army" }
    )
    #expect(result == .enumCase(type: "Phase", value: "army"))
  }

  @Test func bindingAccess() throws {
    let (compiler, schema) = try makeCompiler()
    let sexpr = try SExprParser.parse("$x")
    let compiled = compiler.expr(sexpr)
    let env = makeEnv(schema: schema)
    env.bindings["x"] = .int(99)
    let result = try compiled(env)
    #expect(result == .int(99))
  }

  @Test func undefinedBindingThrows() throws {
    let (compiler, schema) = try makeCompiler()
    let sexpr = try SExprParser.parse("$missing")
    let compiled = compiler.expr(sexpr)
    let env = makeEnv(schema: schema)
    #expect(throws: (any Error).self) { try compiled(env) }
  }

  @Test func fallbackStringAtom() throws {
    let result = try evalExpr(
      "\"hello\"",
      state: "(state (counter x 0 1))"
    )
    #expect(result == .string("hello"))
  }

  // MARK: - Arithmetic

  @Test func addition() throws {
    #expect(try evalExpr("(+ 3 4)") == .int(7))
  }

  @Test func subtraction() throws {
    #expect(try evalExpr("(- 10 3)") == .int(7))
  }

  @Test func multiplication() throws {
    #expect(try evalExpr("(* 3 4)") == .int(12))
  }

  @Test func division() throws {
    let result = try evalExpr("(/ 10 4)")
    #expect(result == .float(2.5))
  }

  @Test func divisionByZero() throws {
    #expect(try evalExpr("(/ 5 0)") == .float(0))
  }

  @Test func modulo() throws {
    #expect(try evalExpr("(% 7 3)") == .int(1))
  }

  @Test func minMax() throws {
    #expect(try evalExpr("(min 3 7)") == .int(3))
    #expect(try evalExpr("(max 3 7)") == .int(7))
  }

  @Test func abs() throws {
    #expect(try evalExpr("(abs -5)") == .int(5))
  }

  @Test func floatArithmetic() throws {
    let result = try evalExpr("(+ 1.5 2.5)")
    #expect(result == .float(4.0))
  }

  @Test func mixedIntFloatPromotes() throws {
    let result = try evalExpr("(+ 1 2.5)")
    #expect(result == .float(3.5))
  }

  // MARK: - Comparison

  @Test func equality() throws {
    #expect(try evalExpr("(== 3 3)") == .bool(true))
    #expect(try evalExpr("(== 3 4)") == .bool(false))
  }

  @Test func inequality() throws {
    #expect(try evalExpr("(!= 3 4)") == .bool(true))
  }

  @Test func ordering() throws {
    #expect(try evalExpr("(> 5 3)") == .bool(true))
    #expect(try evalExpr("(< 5 3)") == .bool(false))
    #expect(try evalExpr("(>= 3 3)") == .bool(true))
    #expect(try evalExpr("(<= 2 3)") == .bool(true))
  }

  // MARK: - Boolean logic

  @Test func andShortCircuit() throws {
    let result = try evalExpr("(and false (/ 1 0))")
    #expect(result == .bool(false))
  }

  @Test func andAllTrue() throws {
    #expect(try evalExpr("(and true true true)") == .bool(true))
  }

  @Test func orShortCircuit() throws {
    let result = try evalExpr("(or true (/ 1 0))")
    #expect(result == .bool(true))
  }

  @Test func orAllFalse() throws {
    #expect(try evalExpr("(or false false)") == .bool(false))
  }

  @Test func not() throws {
    #expect(try evalExpr("(not true)") == .bool(false))
    #expect(try evalExpr("(not false)") == .bool(true))
  }

  // MARK: - Collections

  @Test func list() throws {
    let result = try evalExpr("(list 1 2 3)")
    #expect(result == .list([.int(1), .int(2), .int(3)]))
  }

  @Test func nth() throws {
    #expect(try evalExpr("(nth (list 10 20 30) 1)") == .int(20))
  }

  @Test func nthOutOfBounds() throws {
    #expect(try evalExpr("(nth (list 1 2) 5)") == .nil)
  }

  @Test func containsSet() throws {
    let result = try evalExpr(
      "(contains breaches east)",
      state: "(state (set breaches Track))",
      setup: { $0.insertIntoSet("breaches", "east") }
    )
    #expect(result == .bool(true))
  }

  @Test func lookupDict() throws {
    let result = try evalExpr(
      "(lookup positions east)",
      state: "(state (dict positions Track Int))",
      setup: { $0.setDictEntry("positions", key: "east", value: .int(5)) }
    )
    #expect(result == .int(5))
  }

  @Test func countDeck() throws {
    let result = try evalExpr(
      "(count hand)",
      state: "(state (deck hand))",
      setup: { state in
        state.appendToDeck("hand", .string("cardA"))
        state.appendToDeck("hand", .string("cardB"))
      }
    )
    #expect(result == .int(2))
  }

  @Test func isEmptyDeck() throws {
    #expect(
      try evalExpr(
        "(isEmpty hand)",
        state: "(state (deck hand))"
      ) == .bool(true)
    )
  }

  // MARK: - Bindings and access

  @Test func letBinding() throws {
    let result = try evalExpr("(let x 5 (+ $x 3))")
    #expect(result == .int(8))
  }

  @Test func letBindingRestores() throws {
    let (compiler, schema) = try makeCompiler()
    let env = makeEnv(schema: schema)
    env.bindings["x"] = .int(100)
    let sexpr = try SExprParser.parse("(let x 5 $x)")
    let compiled = compiler.expr(sexpr)
    _ = try compiled(env)
    #expect(env.bindings["x"] == .int(100))
  }

  @Test func paramAccess() throws {
    let result = try evalExpr(
      "(param card)",
      actionParams: ["card": .string("ace")]
    )
    #expect(result == .string("ace"))
  }

  @Test func dotAccess() throws {
    let compInput = """
    (components
      (struct Point (x Int) (y Int)))
    """
    let (compiler, schema) = try makeCompiler(
      components: compInput,
      state: "(state (counter z 0 1))"
    )
    let env = makeEnv(schema: schema)
    env.bindings["p"] = .structValue(
      type: "Point", fields: ["x": .int(3), "y": .int(7)]
    )
    let sexpr = try SExprParser.parse("(. $p x)")
    let compiled = compiler.expr(sexpr)
    let result = try compiled(env)
    #expect(result == .int(3))
  }

  @Test func rollDieWithSource() throws {
    let result = try evalExpr(
      "(rollDie 6)",
      randomSource: RandomSource([4])
    )
    #expect(result == .int(4))
  }

  @Test func format() throws {
    let result = try evalExpr(
      "(format \"Player {} scored {}\" \"Alice\" 42)"
    )
    #expect(result == .string("Player Alice scored 42"))
  }

  // MARK: - If expression

  @Test func ifTrue() throws {
    #expect(try evalExpr("(if true 1 2)") == .int(1))
  }

  @Test func ifFalse() throws {
    #expect(try evalExpr("(if false 1 2)") == .int(2))
  }

  @Test func ifNoElse() throws {
    #expect(try evalExpr("(if false 1)") == .nil)
  }

  // MARK: - Filter and map

  @Test func filterWithLambda() throws {
    let result = try evalExpr(
      "(filter (list 1 2 3 4 5) (\\ (x) (> $x 3)))"
    )
    #expect(result == .list([.int(4), .int(5)]))
  }

  @Test func mapWithLambda() throws {
    let result = try evalExpr(
      "(map (list 1 2 3) (\\ (x) (+ $x 10)))"
    )
    #expect(result == .list([.int(11), .int(12), .int(13)]))
  }

  // MARK: - Fn call

  @Test func fnCall() throws {
    let compInput = """
    (components
      (enum Track {east west sky})
      (fn isWall Track {east true west true sky false}))
    """
    let result = try evalExpr(
      "(isWall east)",
      components: compInput,
      state: "(state (counter x 0 1))"
    )
    #expect(result == .bool(true))
  }

  // MARK: - CRT lookup

  @Test func crt1DLookup() throws {
    let compInput = """
    (components
      (crt airdropPenalty
        (col 1 6)
        {1-2 2  3-4 1  5-6 0}))
    """
    let roll2 = try evalExpr(
      "(airdropPenalty 2)", components: compInput,
      state: "(state (counter x 0 1))"
    )
    #expect(roll2 == .int(2))

    let roll4 = try evalExpr(
      "(airdropPenalty 4)", components: compInput,
      state: "(state (counter x 0 1))"
    )
    #expect(roll4 == .int(1))
  }

  @Test func crt2DLookup() throws {
    let compInput = """
    (components
      (enum Advantage {allies equal germans})
      (crt attackCRT
        (row Advantage) (col 1 6)
        (results allyHits germanHits controlGained)
        (allies  {1 (1 0 false) 2-4 (1 1 true)  5-6 (0 1 true)})
        (equal   {1 (2 0 false) 2-4 (1 1 false) 5-6 (1 1 true)})
        (germans {1 (3 0 false) 2-4 (2 1 false) 5-6 (1 0 true)})))
    """
    let result = try evalExpr(
      "(attackCRT allies 3)", components: compInput,
      state: "(state (counter x 0 1))"
    )
    #expect(result.asStruct?.type == "attackCRTResult")
    #expect(result.asStruct?.fields["allyHits"] == .int(1))
    #expect(result.asStruct?.fields["germanHits"] == .int(1))
    #expect(result.asStruct?.fields["controlGained"] == .bool(true))
  }

  @Test func crt2DDotAccess() throws {
    let compInput = """
    (components
      (enum Advantage {allies equal germans})
      (crt attackCRT
        (row Advantage) (col 1 6)
        (results allyHits germanHits controlGained)
        (allies  {1 (1 0 false) 2-4 (1 1 true)  5-6 (0 1 true)})
        (equal   {1 (2 0 false) 2-4 (1 1 false) 5-6 (1 1 true)})
        (germans {1 (3 0 false) 2-4 (2 1 false) 5-6 (1 0 true)})))
    """
    let result = try evalExpr(
      "(. (attackCRT equal 1) allyHits)", components: compInput,
      state: "(state (counter x 0 1))"
    )
    #expect(result == .int(2))
  }

  @Test func randomElement() throws {
    let result = try evalExpr(
      "(randomElement (list 10 20 30))",
      randomSource: RandomSource([2])
    )
    #expect(result == .int(20))
  }

  // MARK: - Statement: set

  @Test func setCounter() throws {
    let (_, state) = try evalStmt("(set energy 5)")
    #expect(state.getCounter("energy") == 5)
  }

  @Test func setFlag() throws {
    let (_, state) = try evalStmt(
      "(set ended true)",
      state: "(state (flag ended))"
    )
    #expect(state.getFlag("ended") == true)
  }

  @Test func setField() throws {
    let (_, state) = try evalStmt(
      "(set phase card)",
      components: "(components (enum Phase {card army}))",
      state: "(state (field phase Phase))"
    )
    #expect(state.getField("phase") == .enumCase(type: "Phase", value: "card"))
  }

  @Test func setOptional() throws {
    let (_, state) = try evalStmt(
      "(set current nil)",
      state: "(state (optional current))"
    )
    #expect(state.getOptional("current").isNil)
  }

  // MARK: - Statement: increment / decrement

  @Test func increment() throws {
    let (_, state) = try evalStmt(
      "(increment energy 3)",
      setup: { $0.setCounter("energy", 2) }
    )
    #expect(state.getCounter("energy") == 5)
  }

  @Test func decrement() throws {
    let (_, state) = try evalStmt(
      "(decrement energy 2)",
      setup: { $0.setCounter("energy", 5) }
    )
    #expect(state.getCounter("energy") == 3)
  }

  // MARK: - Statement: set/dict operations

  @Test func insertIntoSet() throws {
    let (_, state) = try evalStmt(
      "(insertInto breaches east)",
      state: "(state (set breaches Track))"
    )
    #expect(state.getSet("breaches").contains("east"))
  }

  @Test func removeFromSet() throws {
    let (_, state) = try evalStmt(
      "(removeFrom breaches east)",
      state: "(state (set breaches Track))",
      setup: { $0.insertIntoSet("breaches", "east") }
    )
    #expect(!state.getSet("breaches").contains("east"))
  }

  @Test func setEntry() throws {
    let (_, state) = try evalStmt(
      "(setEntry positions east 5)",
      state: "(state (dict positions Track Int))"
    )
    #expect(state.getDict("positions")["east"] == .int(5))
  }

  @Test func removeEntry() throws {
    let (_, state) = try evalStmt(
      "(removeEntry positions east)",
      state: "(state (dict positions Track Int))",
      setup: { $0.setDictEntry("positions", key: "east", value: .int(5)) }
    )
    #expect(state.getDict("positions")["east"] == nil)
  }

  // MARK: - Statement: deck operations

  @Test func drawFromDeck() throws {
    let (_, state) = try evalStmt(
      "(draw from: hand to: current)",
      state: "(state (deck hand) (optional current))",
      setup: { $0.appendToDeck("hand", .string("cardA")) }
    )
    #expect(state.getOptional("current") == .string("cardA"))
    #expect(state.getDeck("hand").isEmpty)
  }

  @Test func shuffleDeck() throws {
    // Shuffle shouldn't crash on empty or populated decks
    let (_, state) = try evalStmt(
      "(shuffle hand)",
      state: "(state (deck hand))",
      setup: { state in
        state.appendToDeck("hand", .string("a"))
        state.appendToDeck("hand", .string("b"))
      }
    )
    #expect(state.getDeck("hand").count == 2)
  }

  @Test func discardFromOptional() throws {
    let (_, state) = try evalStmt(
      "(discard from: current to: discard)",
      state: "(state (optional current) (deck discard))",
      setup: { $0.setOptional("current", .string("cardA")) }
    )
    #expect(state.getOptional("current").isNil)
    #expect(state.getDeck("discard") == [.string("cardA")])
  }

  @Test func appendToDeck() throws {
    let (_, state) = try evalStmt(
      "(appendTo hand 42)",
      state: "(state (deck hand))"
    )
    #expect(state.getDeck("hand") == [.int(42)])
  }

  @Test func removeAt() throws {
    let (_, state) = try evalStmt(
      "(removeAt hand 1)",
      state: "(state (deck hand))",
      setup: { state in
        state.appendToDeck("hand", .string("a"))
        state.appendToDeck("hand", .string("b"))
        state.appendToDeck("hand", .string("c"))
      }
    )
    #expect(state.getDeck("hand").count == 2)
  }

  @Test func clearList() throws {
    let (_, state) = try evalStmt(
      "(clearList hand)",
      state: "(state (deck hand))",
      setup: { state in
        state.appendToDeck("hand", .string("a"))
        state.appendToDeck("hand", .string("b"))
      }
    )
    #expect(state.getDeck("hand").isEmpty)
  }

  // MARK: - Statement: state

  @Test func setPhase() throws {
    let (_, state) = try evalStmt(
      "(setPhase army)",
      components: "(components (enum Phase {card army}))",
      state: "(state (field phase Phase))"
    )
    #expect(state.phase == "army")
  }

  @Test func endGameVictory() throws {
    let (_, state) = try evalStmt(
      "(endGame victory)",
      state: "(state (flag ended))"
    )
    #expect(state.ended == true)
    #expect(state.victory == true)
  }

  @Test func endGameDefeat() throws {
    let (_, state) = try evalStmt(
      "(endGame defeat)",
      state: "(state (flag ended))"
    )
    #expect(state.ended == true)
    #expect(state.victory == false)
  }

  // MARK: - Statement: control flow

  @Test func seqAndLog() throws {
    let (result, state) = try evalStmt("""
    (seq
      (set energy 4)
      (log "energy set"))
    """)
    #expect(state.getCounter("energy") == 4)
    #expect(result.logs.count == 1)
  }

  @Test func ifBranch() throws {
    let (_, state) = try evalStmt(
      """
      (if (> energy 2)
        (set energy 6)
        (set energy 0))
      """,
      setup: { $0.setCounter("energy", 3) }
    )
    #expect(state.getCounter("energy") == 6)
  }

  @Test func ifElseBranch() throws {
    let (_, state) = try evalStmt(
      """
      (if (> energy 5)
        (set energy 6)
        (set energy 0))
      """,
      setup: { $0.setCounter("energy", 3) }
    )
    #expect(state.getCounter("energy") == 0)
  }

  @Test func guardAbort() throws {
    let (_, state) = try evalStmt(
      """
      (seq
        (guard (> energy 2))
        (set energy 6))
      """,
      setup: { $0.setCounter("energy", 0) }
    )
    #expect(state.getCounter("energy") == 0)
  }

  @Test func guardPass() throws {
    let (_, state) = try evalStmt(
      """
      (seq
        (guard (> energy 2))
        (set energy 6))
      """,
      setup: { $0.setCounter("energy", 3) }
    )
    #expect(state.getCounter("energy") == 6)
  }

  @Test func chainFollowUp() throws {
    let (result, _) = try evalStmt("(chain advanceArmies)")
    #expect(result.followUps.count == 1)
    #expect(result.followUps[0].name == "advanceArmies")
  }

  @Test func chainWithParams() throws {
    let (result, _) = try evalStmt("(chain attack (target east) (bonus 2))")
    #expect(result.followUps[0].name == "attack")
    #expect(result.followUps[0].parameters["target"] == .enumCase(type: "Track", value: "east"))
    #expect(result.followUps[0].parameters["bonus"] == .int(2))
  }

  @Test func log() throws {
    let (result, _) = try evalStmt("(log \"test message\")")
    #expect(result.logs.count == 1)
    #expect(result.logs[0].msg == "test message")
  }

  @Test func stmtLet() throws {
    let (_, state) = try evalStmt(
      """
      (seq
        (let bonus 3
          (increment energy $bonus)))
      """,
      setup: { $0.setCounter("energy", 2) }
    )
    #expect(state.getCounter("energy") == 5)
  }

  @Test func seqLetBindingScope() throws {
    let (_, state) = try evalStmt(
      """
      (seq
        (let x 10 (set energy $x))
        (set energy 0))
      """,
      setup: { $0.setCounter("energy", 0) }
    )
    // Second set should execute, overriding the first
    #expect(state.getCounter("energy") == 0)
  }

  @Test func forEach() throws {
    let (result, _) = try evalStmt(
      """
      (forEach (list 1 2 3)
        (\\ (item) (log $item)))
      """
    )
    #expect(result.logs.count == 3)
  }

  // MARK: - Env.withBinding

  @Test func withBindingRestoresPrevious() throws {
    let (_, schema) = try makeCompiler()
    let env = makeEnv(schema: schema)
    env.bindings["x"] = .int(100)
    let inner = env.withBinding("x", .int(200)) {
      env.bindings["x"]
    }
    #expect(inner == .int(200))
    #expect(env.bindings["x"] == .int(100))
  }

  @Test func withBindingRemovesNew() throws {
    let (_, schema) = try makeCompiler()
    let env = makeEnv(schema: schema)
    _ = env.withBinding("y", .int(5)) {
      env.bindings["y"]
    }
    #expect(env.bindings["y"] == nil)
  }

  // MARK: - Unknown form

  @Test func unknownFormThrows() throws {
    let (compiler, schema) = try makeCompiler()
    let sexpr = try SExprParser.parse("(bogus 1 2)")
    let compiled = compiler.expr(sexpr)
    let env = makeEnv(schema: schema)
    #expect(throws: (any Error).self) { try compiled(env) }
  }
}

// swiftlint:enable file_length type_body_length
