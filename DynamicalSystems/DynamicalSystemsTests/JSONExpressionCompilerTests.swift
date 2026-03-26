import Testing
@testable import DynamicalSystems

// swiftlint:disable type_body_length file_length
@Suite("JSONExpressionCompiler")
struct JSONExpressionCompilerTests {

  let interner = StringInterner()

  private func makeCompiler() throws -> JSONExpressionCompiler {
    let components = ComponentRegistry.empty()
    let schema = StateSchema.empty()
    let defines = try JSONDefineExpander(.array([]))
    return JSONExpressionCompiler(
      components: components, schema: schema,
      graph: SiteGraph(), defines: defines,
      interner: interner
    )
  }

  private func makeEnv() -> ExpressionCompiler.Env {
    let state = InterpretedState(
      schema: StateSchema.empty(), interner: interner
    )
    return ExpressionCompiler.Env(state: state)
  }

  @Test func compileIntLiteral() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.int(42))
    let result = try compiled(makeEnv())
    #expect(result == .int(42))
  }

  @Test func compileFloatLiteral() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.float(1.5))
    let result = try compiled(makeEnv())
    #expect(result == .float(1.5))
  }

  @Test func compileBoolLiteral() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.bool(true))
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func compileNull() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.null)
    let result = try compiled(makeEnv())
    #expect(result == .nil)
  }

  @Test func compileAddition() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["+": .array([.int(1), .int(2)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(3))
  }

  @Test func compileSubtraction() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["-": .array([.int(10), .int(3)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(7))
  }

  @Test func compileMultiplication() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["*": .array([.int(4), .int(5)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(20))
  }

  @Test func compileDivision() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["/": .array([.int(10), .int(4)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .float(2.5))
  }

  @Test func compileModulo() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["%": .array([.int(7), .int(3)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(1))
  }

  @Test func compileMin() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["min": .array([.int(3), .int(7)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(3))
  }

  @Test func compileMax() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["max": .array([.int(3), .int(7)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(7))
  }

  @Test func compileAbs() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["abs": .array([.int(-5)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(5))
  }

  @Test func compileEquality() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["==": .array([.int(3), .int(3)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func compileInequality() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["!=": .array([.int(3), .int(4)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func compileGreaterThan() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([">": .array([.int(5), .int(3)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func compileLessThan() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["<": .array([.int(2), .int(3)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func compileAnd() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["and": .array([.bool(true), .bool(false)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(false))
  }

  @Test func compileOr() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["or": .array([.bool(false), .bool(true)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func compileNot() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["not": .array([.bool(true)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(false))
  }

  @Test func compileEnumCaseDotPrefix() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.string(".fog"))
    let result = try compiled(makeEnv())
    #expect(result.displayString(interner: interner) == "fog")
  }

  @Test func compileVariableReference() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.string("$myVar"))
    let env = makeEnv()
    let result = try env.withBinding("myVar", .int(99)) {
      try compiled(env)
    }
    #expect(result == .int(99))
  }

  @Test func compileLet() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "let": .array([
        .string("x"), .int(10),
        .string("y"), .int(20),
        .object(["+": .array([.string("$x"), .string("$y")])])
      ])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(30))
  }

  @Test func compileLetSingleBinding() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "let": .array([
        .string("x"), .int(10),
        .object(["+": .array([.string("$x"), .int(5)])])
      ])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(15))
  }

  @Test func compileIf() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "if": .array([.bool(true), .int(1), .int(2)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(1))
  }

  @Test func compileIfFalse() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "if": .array([.bool(false), .int(1), .int(2)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(2))
  }

  @Test func compileGetField() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "get": .array([.string("$result"), .string("hits")])
    ])
    let compiled = compiler.expr(json)
    let env = makeEnv()
    let result = try env.withBinding(
      "result",
      .structValue(type: "CRT", fields: ["hits": .int(3)])
    ) {
      try compiled(env)
    }
    #expect(result == .int(3))
  }

  @Test func compileListLiteral() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.array([.int(1), .int(2), .int(3)])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .list([.int(1), .int(2), .int(3)]))
  }

  @Test func compileListOp() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "list": .array([.int(10), .int(20)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .list([.int(10), .int(20)]))
  }

  @Test func compileNthOp() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "nth": .array([
        .array([.int(10), .int(20), .int(30)]),
        .int(1)
      ])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(20))
  }

  @Test func compileFnLambda() throws {
    let compiler = try makeCompiler()
    // {"filter": [["a", "b", "c"], {"fn": ["x", {"==": ["$x", "b"]}]}]}
    let json = JSONValue.object([
      "filter": .array([
        .array([.string("a"), .string("b"), .string("c")]),
        .object(["fn": .array([
          .string("x"),
          .object(["==": .array([.string("$x"), .string("b")])])
        ])])
      ])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .list([.string("b")]))
  }

  @Test func compileMapLambda() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "map": .array([
        .array([.int(1), .int(2), .int(3)]),
        .object(["fn": .array([
          .string("x"),
          .object(["+": .array([.string("$x"), .int(10)])])
        ])])
      ])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .list([.int(11), .int(12), .int(13)]))
  }

  @Test func compileFormatString() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "format": .array([.string("Hello {} world {}"), .int(42), .bool(true)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .string("Hello 42 world true"))
  }

  @Test func compileBareStringAsLiteral() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.string("hello"))
    let result = try compiled(makeEnv())
    #expect(result == .string("hello"))
  }

  // MARK: - Statement helpers

  private func makeSchema(
    _ fields: [FieldDefinition]
  ) -> StateSchema {
    var dict: [String: FieldDefinition] = [:]
    for field in fields {
      dict[field.name] = field
    }
    return StateSchema(fields: dict)
  }

  private func makeStmtCompiler(
    schema: StateSchema
  ) throws -> JSONExpressionCompiler {
    let components = ComponentRegistry.empty()
    let defines = try JSONDefineExpander(.array([]))
    return JSONExpressionCompiler(
      components: components, schema: schema,
      graph: SiteGraph(), defines: defines,
      interner: interner
    )
  }

  private func makeStmtEnv(
    schema: StateSchema
  ) -> ExpressionCompiler.Env {
    ExpressionCompiler.Env(
      state: InterpretedState(schema: schema, interner: interner)
    )
  }

  // MARK: - Statements

  @Test func stmtSetCounter() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["set": .array([.string("hp"), .int(5)])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 5)
  }

  @Test func stmtSetFlag() throws {
    let schema = makeSchema([
      FieldDefinition(name: "ended", kind: .flag)
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["set": .array([.string("ended"), .bool(true)])])
    )
    _ = try compiled(env)
    #expect(env.state.getFlag("ended") == true)
  }

  @Test func stmtSetField() throws {
    let schema = makeSchema([
      FieldDefinition(name: "weather", kind: .field(type: "Weather"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["set": .array([.string("weather"), .string(".sunny")])])
    )
    _ = try compiled(env)
    let value = env.state.getField("weather")
    #expect(value.displayString(interner: interner) == "sunny")
  }

  @Test func stmtIncrement() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    #expect(env.state.getCounter("hp") == 0)
    let compiled = compiler.stmt(
      .object(["increment": .array([.string("hp"), .int(2)])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 2)
  }

  @Test func stmtDecrement() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.setCounter("hp", 5)
    let compiled = compiler.stmt(
      .object(["decrement": .array([.string("hp"), .int(1)])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 4)
  }

  @Test func stmtSetPhase() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["setPhase": .array([.string(".play")])])
    )
    _ = try compiled(env)
    #expect(env.state.phase == "play")
  }

  @Test func stmtEndGameVictory() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["endGame": .array([.string("victory")])])
    )
    _ = try compiled(env)
    #expect(env.state.ended == true)
    #expect(env.state.victory == true)
  }

  @Test func stmtEndGameDefeat() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["endGame": .array([.string("defeat")])])
    )
    _ = try compiled(env)
    #expect(env.state.ended == true)
    #expect(env.state.victory == false)
  }

  // MARK: - Set operations

  @Test func stmtInsertIntoSet() throws {
    let schema = makeSchema([
      FieldDefinition(name: "breaches", kind: .set(elementType: "String"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["insertInto": .array([.string("breaches"), .string("east")])])
    )
    _ = try compiled(env)
    #expect(env.state.getSet("breaches").contains("east"))
  }

  @Test func stmtRemoveFromSet() throws {
    let schema = makeSchema([
      FieldDefinition(name: "breaches", kind: .set(elementType: "String"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.insertIntoSet("breaches", "east")
    #expect(env.state.getSet("breaches").contains("east"))
    let compiled = compiler.stmt(
      .object([
        "removeFrom": .array([.string("breaches"), .string("east")])
      ])
    )
    _ = try compiled(env)
    #expect(env.state.getSet("breaches").isEmpty)
  }

  // MARK: - Dict operations

  @Test func stmtSetEntry() throws {
    let schema = makeSchema([
      FieldDefinition(
        name: "scores", kind: .dict(keyType: "String", valueType: "Int")
      )
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object([
        "setEntry": .array([
          .string("scores"), .string("alice"), .int(10)
        ])
      ])
    )
    _ = try compiled(env)
    #expect(env.state.getDict("scores")["alice"] == .int(10))
  }

  @Test func stmtRemoveEntry() throws {
    let schema = makeSchema([
      FieldDefinition(
        name: "scores", kind: .dict(keyType: "String", valueType: "Int")
      )
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.setDictEntry("scores", key: "alice", value: .int(10))
    let compiled = compiler.stmt(
      .object([
        "removeEntry": .array([.string("scores"), .string("alice")])
      ])
    )
    _ = try compiled(env)
    #expect(env.state.getDict("scores")["alice"] == nil)
  }

  // MARK: - Deck/list operations

  @Test func stmtAppendToDeck() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hand", kind: .deck(cardType: "Card"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["appendTo": .array([.string("hand"), .int(42)])])
    )
    _ = try compiled(env)
    #expect(env.state.getDeck("hand") == [.int(42)])
  }

  @Test func stmtClearList() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hand", kind: .deck(cardType: "Card"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.appendToDeck("hand", .int(1))
    env.state.appendToDeck("hand", .int(2))
    #expect(env.state.getDeck("hand").count == 2)
    let compiled = compiler.stmt(
      .object(["clearList": .array([.string("hand")])])
    )
    _ = try compiled(env)
    #expect(env.state.getDeck("hand").isEmpty)
  }

  // MARK: - Control flow

  @Test func stmtSeqAndLog() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["seq": .array([
        .object(["set": .array([.string("hp"), .int(3)])]),
        .object(["log": .array([.string("damage dealt")])])
      ])])
    )
    let result = try compiled(env)
    #expect(env.state.getCounter("hp") == 3)
    #expect(result.logs.contains(Log(msg: "damage dealt")))
  }

  @Test func stmtIfTrue() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["if": .array([
        .bool(true),
        .object(["set": .array([.string("hp"), .int(1)])]),
        .object(["set": .array([.string("hp"), .int(2)])])
      ])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 1)
  }

  @Test func stmtIfFalse() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["if": .array([
        .bool(false),
        .object(["set": .array([.string("hp"), .int(1)])]),
        .object(["set": .array([.string("hp"), .int(2)])])
      ])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 2)
  }

  @Test func stmtGuardPass() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["seq": .array([
        .object(["guard": .array([.bool(true)])]),
        .object(["set": .array([.string("hp"), .int(5)])])
      ])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 5)
  }

  @Test func stmtGuardAbort() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["seq": .array([
        .object(["guard": .array([.bool(false)])]),
        .object(["set": .array([.string("hp"), .int(5)])])
      ])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 0)
  }

  @Test func stmtForEach() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["forEach": .array([
        .object(["list": .array([.int(1), .int(2), .int(3)])]),
        .object(["fn": .array([
          .string("item"),
          .object(["increment": .array([.string("hp"), .int(1)])])
        ])])
      ])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 3)
  }

  @Test func stmtLetBinding() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["let": .array([
        .string("x"), .int(5),
        .object(["set": .array([.string("hp"), .string("$x")])])
      ])])
    )
    _ = try compiled(env)
    #expect(env.state.getCounter("hp") == 5)
  }

  // MARK: - Chain / follow-up

  @Test func stmtChain() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["chain": .array([.string("attack")])])
    )
    let result = try compiled(env)
    #expect(result.followUps.count == 1)
    #expect(result.followUps[0].name == "attack")
  }

  @Test func stmtChainWithParams() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["chain": .array([
        .string("attack"),
        .object(["target": .string("goblin")])
      ])])
    )
    let result = try compiled(env)
    #expect(result.followUps.count == 1)
    #expect(result.followUps[0].name == "attack")
    #expect(result.followUps[0].parameters["target"] == .string("goblin"))
  }

  // MARK: - Logging

  @Test func stmtLog() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let compiled = compiler.stmt(
      .object(["log": .array([.string("hello world")])])
    )
    let result = try compiled(env)
    #expect(result.logs.count == 1)
    #expect(result.logs[0].msg == "hello world")
  }

  // MARK: - Expression edge cases

  // -- Arithmetic edge cases --

  @Test func divisionByZeroReturnsZero() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["/": .array([.int(10), .int(0)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    // compileDivision always returns .float; guard against /0
    #expect(result == .float(0))
  }

  @Test func mixedIntFloatPromotion() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["+": .array([.int(1), .float(1.5)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .float(2.5))
  }

  @Test func moduloByZeroReturnsZero() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(["%": .array([.int(10), .int(0)])])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .int(0))
  }

  // -- Boolean logic edge cases --

  @Test func andShortCircuitsFalseTrue() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "and": .array([.bool(false), .bool(true)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(false))
  }

  @Test func andAllTrue() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "and": .array([.bool(true), .bool(true), .bool(true)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func orShortCircuitsTrueFalse() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "or": .array([.bool(true), .bool(false)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(true))
  }

  @Test func orAllFalse() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "or": .array([.bool(false), .bool(false)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .bool(false))
  }

  // -- Collection edge cases --

  @Test func nthOutOfBoundsReturnsNil() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "nth": .array([
        .object(["list": .array([.int(1), .int(2), .int(3)])]),
        .int(10)
      ])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .nil)
  }

  @Test func containsInSet() throws {
    let schema = makeSchema([
      FieldDefinition(
        name: "breaches", kind: .set(elementType: "String")
      )
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.insertIntoSet("breaches", "east")
    let json = JSONValue.object([
      "contains": .array([.string("breaches"), .string("east")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .bool(true))
  }

  @Test func containsNotInSet() throws {
    let schema = makeSchema([
      FieldDefinition(
        name: "breaches", kind: .set(elementType: "String")
      )
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let json = JSONValue.object([
      "contains": .array([.string("breaches"), .string("west")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .bool(false))
  }

  @Test func lookupDict() throws {
    let schema = makeSchema([
      FieldDefinition(
        name: "scores",
        kind: .dict(keyType: "String", valueType: "Int")
      )
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.setDictEntry("scores", key: "alice", value: .int(10))
    let json = JSONValue.object([
      "lookup": .array([.string("scores"), .string("alice")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .int(10))
  }

  @Test func countCollection() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hand", kind: .deck(cardType: "Card"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.appendToDeck("hand", .int(1))
    env.state.appendToDeck("hand", .int(2))
    env.state.appendToDeck("hand", .int(3))
    let json = JSONValue.object([
      "count": .array([.string("hand")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .int(3))
  }

  @Test func isEmptyOnEmptyCollection() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hand", kind: .deck(cardType: "Card"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    let json = JSONValue.object([
      "isEmpty": .array([.string("hand")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .bool(true))
  }

  @Test func isEmptyOnNonEmpty() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hand", kind: .deck(cardType: "Card"))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.appendToDeck("hand", .int(42))
    let json = JSONValue.object([
      "isEmpty": .array([.string("hand")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .bool(false))
  }

  // -- Field access --

  @Test func counterFieldAccess() throws {
    let schema = makeSchema([
      FieldDefinition(name: "hp", kind: .counter(min: 0, max: 100))
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.setCounter("hp", 5)
    let compiled = compiler.expr(.string("hp"))
    let result = try compiled(env)
    #expect(result == .int(5))
  }

  @Test func flagFieldAccess() throws {
    let schema = makeSchema([
      FieldDefinition(name: "ended", kind: .flag)
    ])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.ended = true
    let compiled = compiler.expr(.string("ended"))
    let result = try compiled(env)
    #expect(result == .bool(true))
  }

  @Test func phaseFieldAccess() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = makeStmtEnv(schema: schema)
    env.state.phase = "combat"
    // Use the "field" operator to access built-in phase property
    let json = JSONValue.object([
      "field": .array([.string("phase")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result.displayString(interner: interner) == "combat")
  }

  @Test func paramAccess() throws {
    let schema = makeSchema([])
    let compiler = try makeStmtCompiler(schema: schema)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema, interner: interner),
      actionParams: ["target": .string("goblin")]
    )
    let json = JSONValue.object([
      "param": .array([.string("target")])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .string("goblin"))
  }

  // -- Error handling --

  @Test func undefinedVariableThrows() throws {
    let compiler = try makeCompiler()
    let compiled = compiler.expr(.string("$nonexistent"))
    #expect(throws: DSLError.self) {
      try compiled(makeEnv())
    }
  }

  @Test func unknownOperatorThrows() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "totallyBogus": .array([.int(1), .int(2)])
    ])
    let compiled = compiler.expr(json)
    #expect(throws: DSLError.self) {
      try compiled(makeEnv())
    }
  }

  // -- Die rolling --

  @Test func rollDieWithRandomSource() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "rollDie": .array([.int(6)])
    ])
    let compiled = compiler.expr(json)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: StateSchema.empty(), interner: interner),
      randomSource: RandomSource([3])
    )
    let result = try compiled(env)
    #expect(result == .int(3))
  }

  // -- CRT lookup --

  @Test func crtLookupExpression() throws {
    let crt = CRTDefinition(
      name: "combat",
      rowEnumName: nil,
      resultFields: [],
      rows: [
        "": [
          CRTEntry(low: 1, high: 3, values: [.int(0)]),
          CRTEntry(low: 4, high: 6, values: [.int(1)])
        ]
      ]
    )
    let components = ComponentRegistry(
      enums: [:], structs: [:], functions: [:],
      cards: [], crts: ["combat": crt], playerIndex: [:]
    )
    let schema = StateSchema.empty()
    let defines = try JSONDefineExpander(.array([]))
    let compiler = JSONExpressionCompiler(
      components: components, schema: schema,
      graph: SiteGraph(), defines: defines,
      interner: interner
    )
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema, interner: interner),
      randomSource: RandomSource([5])
    )
    // 1D CRT: {"combat": [dieRoll]}
    let json = JSONValue.object([
      "combat": .array([.int(5)])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(env)
    #expect(result == .int(1))
  }

  // -- Random element --

  @Test func randomElementFromList() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "randomElement": .array([
        .object(["list": .array([.int(1), .int(2), .int(3)])])
      ])
    ])
    let compiled = compiler.expr(json)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: StateSchema.empty(), interner: interner),
      randomSource: RandomSource([2])
    )
    let result = try compiled(env)
    // RandomSource returns 2, index = 2-1 = 1, so items[1] = .int(2)
    #expect(result == .int(2))
  }

  // -- String/format --

  @Test func formatInterpolation() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object([
      "format": .array([
        .string("Score: {}"),
        .int(42)
      ])
    ])
    let compiled = compiler.expr(json)
    let result = try compiled(makeEnv())
    #expect(result == .string("Score: 42"))
  }
}
// swiftlint:enable type_body_length file_length
