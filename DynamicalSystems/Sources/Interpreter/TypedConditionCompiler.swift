// TypedConditionCompiler.swift
//
// Compiles JSONC condition expressions to typed closures that
// bypass Env, DSLValue boxing, and nested closure calls.
// Falls back to nil for unsupported expressions.

extension JSONExpressionCompiler {

  typealias BoolCondition = (InterpretedState) -> Bool
  typealias IntCondition = (InterpretedState) -> Int
  typealias ValueCondition = (InterpretedState) -> DSLValue

  /// Try to compile a condition expression to a typed
  /// (InterpretedState) -> Bool closure. Returns nil if the
  /// expression contains unsupported operators — caller falls
  /// back to the generic Expr + Env path.
  func tryCompileCondition(_ json: JSONValue) -> BoolCondition? {
    tryBool(json)
  }

  // MARK: - Bool path

  private func tryBool(_ json: JSONValue) -> BoolCondition? {
    switch json {
    case .bool(let val):
      return { _ in val }
    case .string(let str):
      return tryBoolString(str)
    case .object(let dict):
      guard dict.count == 1,
            let (oper, value) = dict.first,
            case .array(let args) = value else { return nil }
      return tryBoolCall(oper, args: args)
    default:
      return nil
    }
  }

  private func tryBoolString(_ str: String) -> BoolCondition? {
    if str.hasPrefix("$") || str.hasPrefix(".") { return nil }
    switch str {
    case "ended": return { state in state.ended }
    case "victory": return { state in state.victory }
    case "gameAcknowledged": return { state in state.gameAcknowledged }
    default: break
    }
    guard let def = schema.field(str) else { return nil }
    let fid = interner.intern(str)
    switch def.kind {
    case .flag:
      return { state in state.getFlag(fid) }
    default:
      return nil
    }
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func tryBoolCall(
    _ oper: String, args: [JSONValue]
  ) -> BoolCondition? {
    switch oper {
    case "and":
      let compiled = args.compactMap { tryBool($0) }
      guard compiled.count == args.count else { return nil }
      return { state in compiled.allSatisfy { $0(state) } }

    case "or":
      let compiled = args.compactMap { tryBool($0) }
      guard compiled.count == args.count else { return nil }
      return { state in compiled.contains { $0(state) } }

    case "not":
      guard let inner = tryBool(args[0]) else { return nil }
      return { state in !inner(state) }

    case "==":
      return tryEquality(args, negate: false)
    case "!=":
      return tryEquality(args, negate: true)
    case ">":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in lhs(state) > rhs(state) }
    case "<":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in lhs(state) < rhs(state) }
    case ">=":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in lhs(state) >= rhs(state) }
    case "<=":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in lhs(state) <= rhs(state) }

    case "contains":
      guard let setName = args[0].stringValue,
            schema.field(setName) != nil else { return nil }
      let setFID = interner.intern(setName)
      if let elemStr = args[1].stringValue {
        let elemName = elemStr.hasPrefix(".")
          ? String(elemStr.dropFirst()) : elemStr
        let elemFID = interner.intern(elemName)
        return { state in state.containsInSet(setFID, elemFID) }
      }
      guard let elemExpr = tryValue(args[1]) else { return nil }
      let capturedInterner = interner
      return { state in
        state.containsInSet(
          setFID, elemExpr(state).toFieldID(capturedInterner)
        )
      }

    case "isEmpty":
      if let name = args[0].stringValue,
         !name.hasPrefix("$"), !name.hasPrefix("."),
         schema.field(name) != nil {
        let fid = interner.intern(name)
        return { state in state.isDeckEmpty(fid) }
      }
      return nil

    case "if" where args.count >= 3:
      guard let cond = tryBool(args[0]),
            let then = tryBool(args[1]),
            let els = tryBool(args[2]) else { return nil }
      return { state in cond(state) ? then(state) : els(state) }

    default:
      // Expand user-defined functions
      if defines.lookup(oper) != nil,
         let expanded = try? defines.expand(
           .object([oper: .array(args)])
         ) {
        return tryBool(expanded)
      }
      return nil
    }
  }

  private func tryEquality(
    _ args: [JSONValue], negate: Bool
  ) -> BoolCondition? {
    // Try int == int first
    if let lhs = tryInt(args[0]), let rhs = tryInt(args[1]) {
      return negate
        ? { state in lhs(state) != rhs(state) }
        : { state in lhs(state) == rhs(state) }
    }
    // Fall back to value == value
    guard let lhs = tryValue(args[0]),
          let rhs = tryValue(args[1]) else { return nil }
    let capturedInterner = interner
    return { state in
      let result = JSONExpressionCompiler.dslEqual(
        lhs(state), rhs(state), interner: capturedInterner
      )
      return negate ? !result : result
    }
  }

  // MARK: - Int path

  func tryInt(_ json: JSONValue) -> IntCondition? {
    switch json {
    case .int(let val):
      return { _ in val }
    case .string(let str):
      return tryIntString(str)
    case .object(let dict):
      guard dict.count == 1,
            let (oper, value) = dict.first,
            case .array(let args) = value else { return nil }
      return tryIntCall(oper, args: args)
    default:
      return nil
    }
  }

  private func tryIntString(_ str: String) -> IntCondition? {
    if str.hasPrefix("$") || str.hasPrefix(".") { return nil }
    guard let def = schema.field(str) else { return nil }
    let fid = interner.intern(str)
    switch def.kind {
    case .counter:
      return { state in state.getCounter(fid) }
    default:
      return nil
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func tryIntCall(
    _ oper: String, args: [JSONValue]
  ) -> IntCondition? {
    switch oper {
    case "+":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in lhs(state) + rhs(state) }
    case "-":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in lhs(state) - rhs(state) }
    case "*":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in lhs(state) * rhs(state) }
    case "max":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in Swift.max(lhs(state), rhs(state)) }
    case "min":
      guard let lhs = tryInt(args[0]),
            let rhs = tryInt(args[1]) else { return nil }
      return { state in Swift.min(lhs(state), rhs(state)) }
    case "abs":
      guard let inner = tryInt(args[0]) else { return nil }
      return { state in Swift.abs(inner(state)) }
    case "count":
      if let name = args[0].stringValue,
         !name.hasPrefix("$"), !name.hasPrefix("."),
         schema.field(name) != nil {
        let fid = interner.intern(name)
        return { state in state.deckCount(fid) }
      }
      return nil
    case "if" where args.count >= 3:
      guard let cond = tryBool(args[0]),
            let then = tryInt(args[1]),
            let els = tryInt(args[2]) else { return nil }
      return { state in cond(state) ? then(state) : els(state) }
    default:
      if defines.lookup(oper) != nil,
         let expanded = try? defines.expand(
           .object([oper: .array(args)])
         ) {
        return tryInt(expanded)
      }
      return nil
    }
  }

  // MARK: - Value path

  func tryValue(_ json: JSONValue) -> ValueCondition? {
    switch json {
    case .int(let intVal):
      let dsl: DSLValue = .int(intVal)
      return { _ in dsl }
    case .bool(let boolVal):
      let dsl: DSLValue = .bool(boolVal)
      return { _ in dsl }
    case .null:
      return { _ in .nil }
    case .string(let str):
      return tryValueString(str)
    case .object(let dict):
      guard dict.count == 1,
            let (oper, value) = dict.first,
            case .array(let args) = value else { return nil }
      return tryValueCall(oper, args: args)
    default:
      return nil
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func tryValueString(_ str: String) -> ValueCondition? {
    if str.hasPrefix("$") { return nil }
    if str.hasPrefix(".") {
      let caseName = String(str.dropFirst())
      let val: DSLValue = .symbol(interner.intern(caseName))
      return { _ in val }
    }
    switch str {
    case "phase":
      let capturedInterner = interner
      return { state in
        if let fid = state.phaseFID { return .symbol(fid) }
        return .symbol(capturedInterner.intern(state.phase))
      }
    case "ended":
      return { state in .bool(state.ended) }
    case "victory":
      return { state in .bool(state.victory) }
    case "gameAcknowledged":
      return { state in .bool(state.gameAcknowledged) }
    default: break
    }
    guard let def = schema.field(str) else {
      if components.isEnumCase(str) != nil {
        let val: DSLValue = .symbol(interner.intern(str))
        return { _ in val }
      }
      return nil
    }
    let fid = interner.intern(str)
    switch def.kind {
    case .counter:
      return { state in .int(state.getCounter(fid)) }
    case .flag:
      return { state in .bool(state.getFlag(fid)) }
    case .field:
      return { state in state.getField(fid) }
    case .optional:
      return { state in state.getOptional(fid) }
    default:
      return { state in state.getField(fid) }
    }
  }

  private func tryValueCall(
    _ oper: String, args: [JSONValue]
  ) -> ValueCondition? {
    switch oper {
    case "lookup":
      guard let dictName = args[0].stringValue,
            schema.field(dictName) != nil else { return nil }
      let dictFID = interner.intern(dictName)
      guard let keyExpr = tryValue(args[1]) else { return nil }
      let capturedInterner = interner
      return { state in
        let key = keyExpr(state).toFieldID(capturedInterner)
        return state.lookupInDict(dictFID, key: key)
      }
    case "get":
      guard let structExpr = tryValue(args[0]),
            let fieldName = args[1].stringValue else { return nil }
      return { state in
        structExpr(state).asStruct?.fields[fieldName] ?? .nil
      }
    case "if" where args.count >= 3:
      guard let cond = tryBool(args[0]),
            let then = tryValue(args[1]),
            let els = tryValue(args[2]) else { return nil }
      return { state in cond(state) ? then(state) : els(state) }
    default:
      if defines.lookup(oper) != nil,
         let expanded = try? defines.expand(
           .object([oper: .array(args)])
         ) {
        return tryValue(expanded)
      }
      return nil
    }
  }
}
