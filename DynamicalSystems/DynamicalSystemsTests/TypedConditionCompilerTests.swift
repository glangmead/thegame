import Testing
@testable import DynamicalSystems

@Suite("TypedConditionCompiler")
struct TypedConditionCompilerTests {

  private func makeCompiler(
    counterNames: [String] = [],
    flagNames: [String] = [],
    fieldNames: [String] = [],
    setNames: [String] = [],
    dictNames: [String] = [],
    deckNames: [String] = [],
    optionalNames: [String] = []
  ) throws -> JSONExpressionCompiler {
    var fields: [String: FieldDefinition] = [:]
    for fname in counterNames {
      fields[fname] = FieldDefinition(
        name: fname, kind: .counter(min: 0, max: 100)
      )
    }
    for fname in flagNames {
      fields[fname] = FieldDefinition(name: fname, kind: .flag)
    }
    for fname in fieldNames {
      fields[fname] = FieldDefinition(
        name: fname, kind: .field(type: "String")
      )
    }
    for fname in setNames {
      fields[fname] = FieldDefinition(
        name: fname, kind: .set(elementType: "E")
      )
    }
    for fname in dictNames {
      fields[fname] = FieldDefinition(
        name: fname, kind: .dict(keyType: "K", valueType: "V")
      )
    }
    for fname in deckNames {
      fields[fname] = FieldDefinition(
        name: fname, kind: .deck(cardType: "C")
      )
    }
    for fname in optionalNames {
      fields[fname] = FieldDefinition(
        name: fname, kind: .optional(valueType: "V")
      )
    }
    let schema = StateSchema(fields: fields)
    let components = ComponentRegistry.empty()
    let defines = try JSONDefineExpander(.array([]))
    let interner = StringInterner()
    for name in schema.allFieldNames { interner.intern(name) }
    interner.intern("ended")
    interner.intern("victory")
    interner.intern("gameAcknowledged")
    interner.intern("phase")
    return JSONExpressionCompiler(
      components: components, schema: schema,
      graph: SiteGraph(), defines: defines,
      interner: interner
    )
  }

  private func makeState(
    _ compiler: JSONExpressionCompiler,
    phase: String = "action",
    flags: [String: Bool] = [:],
    counters: [String: Int] = [:]
  ) -> InterpretedState {
    let interner = compiler.interner
    interner.intern(phase)
    var state = InterpretedState(
      schema: compiler.schema, interner: interner
    )
    state.phase = phase
    for (name, val) in flags {
      state.setFlag(interner.intern(name), val)
    }
    for (name, val) in counters {
      state.setCounter(interner.intern(name), val, min: 0, max: 100)
    }
    return state
  }

  // MARK: - tryBool: flags and framework fields

  @Test func flagRead() throws {
    let compiler = try makeCompiler(flagNames: ["noMelee"])
    let cond = compiler.tryCompileCondition(.string("noMelee"))
    #expect(cond != nil)
    let state = makeState(compiler, flags: ["noMelee": true])
    #expect(cond!(state) == true)
  }

  @Test func flagReadFalse() throws {
    let compiler = try makeCompiler(flagNames: ["noMelee"])
    let cond = compiler.tryCompileCondition(.string("noMelee"))
    let state = makeState(compiler, flags: ["noMelee": false])
    #expect(cond!(state) == false)
  }

  @Test func frameworkEnded() throws {
    let compiler = try makeCompiler()
    let cond = compiler.tryCompileCondition(.string("ended"))
    #expect(cond != nil)
    var state = makeState(compiler)
    #expect(cond!(state) == false)
    state.ended = true
    #expect(cond!(state) == true)
  }

  @Test func boolLiteral() throws {
    let compiler = try makeCompiler()
    let cond = compiler.tryCompileCondition(.bool(true))
    #expect(cond != nil)
    let state = makeState(compiler)
    #expect(cond!(state) == true)
  }

  @Test func unsupportedReturnsNil() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(
      ["historyCount": .array([.object(["matching": .string("x")])])]
    )
    let cond = compiler.tryCompileCondition(json)
    #expect(cond == nil)
  }

  // MARK: - tryBool: and/or/not

  @Test func andCondition() throws {
    let compiler = try makeCompiler(flagNames: ["a", "b"])
    let json = JSONValue.object(["and": .array([
      .string("a"), .string("b")
    ])])
    let cond = compiler.tryCompileCondition(json)!
    let stateFF = makeState(compiler, flags: ["a": false, "b": false])
    let stateTF = makeState(compiler, flags: ["a": true, "b": false])
    let stateTT = makeState(compiler, flags: ["a": true, "b": true])
    #expect(cond(stateFF) == false)
    #expect(cond(stateTF) == false)
    #expect(cond(stateTT) == true)
  }

  @Test func orCondition() throws {
    let compiler = try makeCompiler(flagNames: ["a", "b"])
    let json = JSONValue.object(["or": .array([
      .string("a"), .string("b")
    ])])
    let cond = compiler.tryCompileCondition(json)!
    let stateFF = makeState(compiler, flags: ["a": false, "b": false])
    let stateTF = makeState(compiler, flags: ["a": true, "b": false])
    #expect(cond(stateFF) == false)
    #expect(cond(stateTF) == true)
  }

  @Test func notCondition() throws {
    let compiler = try makeCompiler(flagNames: ["a"])
    let json = JSONValue.object(["not": .array([.string("a")])])
    let cond = compiler.tryCompileCondition(json)!
    let stateT = makeState(compiler, flags: ["a": true])
    let stateF = makeState(compiler, flags: ["a": false])
    #expect(cond(stateT) == false)
    #expect(cond(stateF) == true)
  }

  // MARK: - tryInt

  @Test func intLiteral() throws {
    let compiler = try makeCompiler()
    let intC = compiler.tryInt(.int(42))
    #expect(intC != nil)
    #expect(intC!(makeState(compiler)) == 42)
  }

  @Test func counterRead() throws {
    let compiler = try makeCompiler(counterNames: ["energy"])
    let intC = compiler.tryInt(.string("energy"))
    #expect(intC != nil)
    let state = makeState(compiler, counters: ["energy": 5])
    #expect(intC!(state) == 5)
  }

  @Test func arithmeticAdd() throws {
    let compiler = try makeCompiler(counterNames: ["a", "b"])
    let json = JSONValue.object(["+": .array([.string("a"), .string("b")])])
    let intC = compiler.tryInt(json)!
    let state = makeState(compiler, counters: ["a": 3, "b": 7])
    #expect(intC(state) == 10)
  }

  @Test func arithmeticMax() throws {
    let compiler = try makeCompiler(counterNames: ["x"])
    let json = JSONValue.object(
      ["max": .array([.int(0), .string("x")])]
    )
    let intC = compiler.tryInt(json)!
    let state = makeState(compiler, counters: ["x": -5])
    #expect(intC(state) == 0)
  }

  // MARK: - tryValue

  @Test func valueSymbolLiteral() throws {
    let compiler = try makeCompiler()
    let valC = compiler.tryValue(.string(".faceUp"))
    #expect(valC != nil)
    let result = valC!(makeState(compiler))
    #expect(result == .symbol(compiler.interner.intern("faceUp")))
  }

  @Test func valueNullLiteral() throws {
    let compiler = try makeCompiler()
    let valC = compiler.tryValue(.null)
    #expect(valC != nil)
    #expect(valC!(makeState(compiler)) == .nil)
  }

  @Test func valueCounterWrapped() throws {
    let compiler = try makeCompiler(counterNames: ["hp"])
    let valC = compiler.tryValue(.string("hp"))
    #expect(valC != nil)
    let state = makeState(compiler, counters: ["hp": 3])
    #expect(valC!(state) == .int(3))
  }

  @Test func valueFlagWrapped() throws {
    let compiler = try makeCompiler(flagNames: ["active"])
    let valC = compiler.tryValue(.string("active"))
    #expect(valC != nil)
    let state = makeState(compiler, flags: ["active": true])
    #expect(valC!(state) == .bool(true))
  }

  // MARK: - Comparisons, contains, isEmpty

  @Test func phaseEquality() throws {
    let compiler = try makeCompiler()
    let json = JSONValue.object(
      ["==": .array([.string("phase"), .string(".action")])]
    )
    let cond = compiler.tryCompileCondition(json)!
    let yes = makeState(compiler, phase: "action")
    let stateNo = makeState(compiler, phase: "event")
    #expect(cond(yes) == true)
    #expect(cond(stateNo) == false)
  }

  @Test func counterGreaterThan() throws {
    let compiler = try makeCompiler(counterNames: ["hp"])
    let json = JSONValue.object(
      [">": .array([.string("hp"), .int(0)])]
    )
    let cond = compiler.tryCompileCondition(json)!
    let yes = makeState(compiler, counters: ["hp": 5])
    let stateNo = makeState(compiler, counters: ["hp": 0])
    #expect(cond(yes) == true)
    #expect(cond(stateNo) == false)
  }

  @Test func notEqual() throws {
    let compiler = try makeCompiler()
    compiler.interner.intern("setup")
    let json = JSONValue.object(
      ["!=": .array([.string("phase"), .string(".setup")])]
    )
    let cond = compiler.tryCompileCondition(json)!
    let yes = makeState(compiler, phase: "action")
    let stateNo = makeState(compiler, phase: "setup")
    #expect(cond(yes) == true)
    #expect(cond(stateNo) == false)
  }

  @Test func containsSet() throws {
    let compiler = try makeCompiler(setNames: ["wounds"])
    let interner = compiler.interner
    interner.intern("warrior")
    let json = JSONValue.object(
      ["contains": .array([.string("wounds"), .string(".warrior")])]
    )
    let cond = compiler.tryCompileCondition(json)!
    var state = makeState(compiler)
    #expect(cond(state) == false)
    state.insertIntoSet(
      interner.intern("wounds"), interner.intern("warrior")
    )
    #expect(cond(state) == true)
  }

  @Test func isEmptyDeck() throws {
    let compiler = try makeCompiler(deckNames: ["cards"])
    let json = JSONValue.object(
      ["isEmpty": .array([.string("cards")])]
    )
    let cond = compiler.tryCompileCondition(json)!
    let state = makeState(compiler)
    #expect(cond(state) == true)
  }

  @Test func ifBoolCondition() throws {
    let compiler = try makeCompiler(flagNames: ["a", "b", "c"])
    let json = JSONValue.object(["if": .array([
      .string("a"), .string("b"), .string("c")
    ])])
    let cond = compiler.tryCompileCondition(json)!
    let state = makeState(
      compiler, flags: ["a": true, "b": true, "c": false]
    )
    #expect(cond(state) == true)
    let state2 = makeState(
      compiler, flags: ["a": false, "b": true, "c": false]
    )
    #expect(cond(state2) == false)
  }

  @Test func valueLookup() throws {
    let compiler = try makeCompiler(dictNames: ["spells"])
    let interner = compiler.interner
    interner.intern("fireball")
    interner.intern("ready")
    let json = JSONValue.object(
      ["lookup": .array([.string("spells"), .string(".fireball")])]
    )
    let valC = compiler.tryValue(json)
    #expect(valC != nil)
    var state = makeState(compiler)
    state.setDictEntry(
      interner.intern("spells"),
      key: interner.intern("fireball"),
      value: .symbol(interner.intern("ready"))
    )
    #expect(valC!(state) == .symbol(interner.intern("ready")))
  }
}
