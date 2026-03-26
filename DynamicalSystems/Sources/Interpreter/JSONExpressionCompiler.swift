// swiftlint:disable file_length
import Foundation

/// Compiles JSONValue expression trees into Expr/Stmt closures.
/// Called once during GameBuilder.build(); the resulting closures
/// execute at near-native speed during MCTS rollouts.
struct JSONExpressionCompiler {

  let components: ComponentRegistry
  let schema: StateSchema
  let graph: SiteGraph
  let defines: JSONDefineExpander

  typealias Expr = ExpressionCompiler.Expr
  typealias Stmt = ExpressionCompiler.Stmt
  typealias Env = ExpressionCompiler.Env

  // MARK: - Public API

  func expr(_ value: JSONValue) -> Expr {
    switch value {
    case .int(let intVal):
      let val: DSLValue = .int(intVal)
      return { _ in val }
    case .float(let floatVal):
      let val: DSLValue = .float(floatVal)
      return { _ in val }
    case .bool(let boolVal):
      let val: DSLValue = .bool(boolVal)
      return { _ in val }
    case .null:
      return { _ in .nil }
    case .string(let str):
      return resolveString(str)
    case .array(let items):
      let compiled = items.map { expr($0) }
      return { env in .list(try compiled.map { try $0(env) }) }
    case .object(let dict):
      return compileObject(dict)
    }
  }

  func stmt(_ value: JSONValue) -> Stmt {
    guard let (oper, args) = value.asCall else {
      return { _ in
        throw DSLError.malformed("statement must be {\"op\": [args]}")
      }
    }
    return compileStmtCall(oper, args: args)
  }

  // MARK: - String resolution

  private func resolveString(_ str: String) -> Expr {
    // $binding
    if str.hasPrefix("$") {
      let name = String(str.dropFirst())
      return { env in
        if let val = env.bindings[name] { return val }
        throw DSLError.undefinedField("$\(name)")
      }
    }
    // .enumCase — resolve the type via ComponentRegistry
    if str.hasPrefix(".") {
      let caseName = String(str.dropFirst())
      let enumType = components.isEnumCase(caseName) ?? ""
      let val: DSLValue = .enumCase(type: enumType, value: caseName)
      return { _ in val }
    }
    // Schema field
    if schema.field(str) != nil {
      return compileFieldAccess(str)
    }
    // Known enum case
    if let enumType = components.isEnumCase(str) {
      let val: DSLValue = .enumCase(type: enumType, value: str)
      return { _ in val }
    }
    // Bare string literal
    let val: DSLValue = .string(str)
    return { _ in val }
  }
}

// MARK: - Field access compilation

extension JSONExpressionCompiler {

  // swiftlint:disable:next cyclomatic_complexity
  private func compileFieldAccess(_ name: String) -> Expr {
    switch name {
    case "ended": return { env in .bool(env.state.ended) }
    case "victory": return { env in .bool(env.state.victory) }
    case "gameAcknowledged":
      return { env in .bool(env.state.gameAcknowledged) }
    case "phase":
      return { env in
        .enumCase(type: "Phase", value: env.state.phase)
      }
    default: break
    }
    guard let def = schema.field(name) else {
      return { _ in .nil }
    }
    switch def.kind {
    case .counter: return { env in .int(env.state.getCounter(name)) }
    case .flag: return { env in .bool(env.state.getFlag(name)) }
    case .field: return { env in env.state.getField(name) }
    case .optional: return { env in env.state.getOptional(name) }
    default: return { env in env.state.get(name) }
    }
  }
}

// MARK: - Object / call compilation

extension JSONExpressionCompiler {

  private func compileObject(_ dict: [String: JSONValue]) -> Expr {
    guard dict.count == 1,
          let (oper, value) = dict.first else {
      return { _ in
        throw DSLError.malformed("expression object must have one key")
      }
    }
    guard case .array(let args) = value else {
      return { _ in
        throw DSLError.malformed(
          "operator '\(oper)' value must be an array"
        )
      }
    }
    return compileCall(oper, args: args)
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func compileCall(
    _ oper: String, args: [JSONValue]
  ) -> Expr {
    switch oper {
    // Arithmetic
    case "+": return binaryNumeric(args, intOp: +, floatOp: +)
    case "-": return binaryNumeric(args, intOp: -, floatOp: -)
    case "*": return binaryNumeric(args, intOp: *, floatOp: *)
    case "/": return compileDivision(args)
    case "%": return binaryInt(args) { $1 == 0 ? 0 : $0 % $1 }
    case "min": return binaryInt(args, combine: Swift.min)
    case "max": return binaryInt(args, combine: Swift.max)
    case "abs":
      let operand = expr(args[0])
      return { env in .int(abs(try operand(env).asInt ?? 0)) }

    // Comparison
    case "==": return dslComparison(args, negate: false)
    case "!=": return dslComparison(args, negate: true)
    case ">": return intComparison(args, compare: >)
    case "<": return intComparison(args, compare: <)
    case ">=": return intComparison(args, compare: >=)
    case "<=": return intComparison(args, compare: <=)

    // Boolean
    case "and":
      let compiled = args.map { expr($0) }
      return { env in
        for item in compiled {
          guard try item(env).asBool == true else {
            return .bool(false)
          }
        }
        return .bool(true)
      }
    case "or":
      let compiled = args.map { expr($0) }
      return { env in
        // swiftlint:disable for_where
        for item in compiled {
          if try item(env).asBool == true { return .bool(true) }
        }
        // swiftlint:enable for_where
        return .bool(false)
      }
    case "not":
      let operand = expr(args[0])
      return { env in .bool(!(try operand(env).asBool ?? false)) }

    // Collections
    case "contains": return compileContains(args)
    case "lookup": return compileLookup(args)
    case "count":
      if let name = args[0].stringValue,
        !name.hasPrefix("$"), !name.hasPrefix(".") {
        // Literal deck name — fast path
        return { env in .int(env.state.deckCount(name)) }
      }
      let compiled = expr(args[0])
      return { env in
        let val = try compiled(env)
        if let list = val.asList { return .int(list.count) }
        return .int(0)
      }
    case "isEmpty":
      if let name = args[0].stringValue,
        !name.hasPrefix("$"), !name.hasPrefix(".") {
        // Literal deck name — fast path
        return { env in .bool(env.state.isDeckEmpty(name)) }
      }
      let compiled = expr(args[0])
      return { env in
        let val = try compiled(env)
        if let list = val.asList { return .bool(list.isEmpty) }
        return .bool(true)
      }

    // Binding & access
    case "let": return compileLet(args)
    case "get": return compileGet(args)
    case "field":
      let fieldName = args[0].stringValue ?? ""
      return compileFieldAccess(fieldName)
    case "param":
      let paramName = args[0].stringValue ?? ""
      return { env in env.actionParams[paramName] ?? .nil }
    case "rollDie": return compileRollDie(args)
    case "list":
      let compiled = args.map { expr($0) }
      return { env in .list(try compiled.map { try $0(env) }) }
    case "format": return compileFormat(args)
    case "if" where args.count >= 2: return compileIf(args)
    case "nth": return compileNth(args)
    case "filter": return compileFilter(args)
    case "map": return compileMap(args)
    case "fn": return compileFn(args)
    case "randomElement": return compileRandomElement(args)
    case "historyCount": return compileHistoryCount(args)

    // Site operations
    case "site": return compileSiteExpr(args)
    case "pos": return compilePos(args)
    case "advance": return compileAdvance(args)
    case "trackOf": return compileTrackOf(args)
    case "indexOf": return compileIndexOf(args)
    case "adjacent": return compileAdjacent(args)
    case "parallel": return compileParallel(args)
    case "pieceAt": return compilePieceAt(args)

    default:
      if components.crts[oper] != nil {
        return compileCrtCall(oper, args: args)
      }
      if components.functions[oper] != nil {
        return compileFnCall(oper, args: args)
      }
      // Expand user-defined functions (defines)
      if defines.lookup(oper) != nil,
         let expanded = try? defines.expand(
           .object([oper: .array(args)])
         ) {
        return expr(expanded)
      }
      return { _ in throw DSLError.unknownForm(oper) }
    }
  }
}

// MARK: - Expression helpers

extension JSONExpressionCompiler {

  private func binaryInt(
    _ args: [JSONValue],
    combine: @escaping (Int, Int) -> Int
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      .int(combine(try lhs(env).asInt ?? 0, try rhs(env).asInt ?? 0))
    }
  }

  private func binaryNumeric(
    _ args: [JSONValue],
    intOp: @escaping (Int, Int) -> Int,
    floatOp: @escaping (Float, Float) -> Float
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      let left = try lhs(env)
      let right = try rhs(env)
      if case .float = left {
        return .float(
          floatOp(left.asFloat ?? 0, right.asFloat ?? 0)
        )
      }
      if case .float = right {
        return .float(
          floatOp(left.asFloat ?? 0, right.asFloat ?? 0)
        )
      }
      return .int(intOp(left.asInt ?? 0, right.asInt ?? 0))
    }
  }

  /// Compare with cross-type coercion: `.string("x")` equals
  /// `.enumCase(_, "x")` so card-stored strings match enum literals.
  /// Hand-written to avoid the synthesized == which compares enum type
  /// strings unnecessarily (dslEqual ignores type on enumCase).
  static func dslEqual(_ lhs: DSLValue, _ rhs: DSLValue) -> Bool {
    switch (lhs, rhs) {
    case (.int(let left), .int(let right)): return left == right
    case (.float(let left), .float(let right)): return left == right
    case (.bool(let left), .bool(let right)): return left == right
    case (.nil, .nil): return true
    // enumCase: compare value only, ignore type
    case (.enumCase(_, let left), .enumCase(_, let right)):
      return left == right
    // Cross-type: string ↔ enumCase
    case (.string(let str), .enumCase(_, let val)),
      (.enumCase(_, let val), .string(let str)):
      return str == val
    case (.string(let left), .string(let right)): return left == right
    case (.site(let track1, let idx1), .site(let track2, let idx2)):
      return idx1 == idx2 && track1 == track2
    case (.list(let left), .list(let right)): return left == right
    case (.structValue(let type1, let flds1),
          .structValue(let type2, let flds2)):
      return type1 == type2 && flds1 == flds2
    default: return false
    }
  }

  private func dslComparison(
    _ args: [JSONValue],
    negate: Bool
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      let result = Self.dslEqual(try lhs(env), try rhs(env))
      return .bool(negate ? !result : result)
    }
  }

  private func intComparison(
    _ args: [JSONValue],
    compare: @escaping (Int, Int) -> Bool
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      .bool(
        compare(try lhs(env).asInt ?? 0, try rhs(env).asInt ?? 0)
      )
    }
  }

  private func compileDivision(_ args: [JSONValue]) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      let leftFloat = try lhs(env).asFloat ?? 0
      let rightFloat = try rhs(env).asFloat ?? 1
      return .float(rightFloat == 0 ? 0 : leftFloat / rightFloat)
    }
  }

  private func compileContains(_ args: [JSONValue]) -> Expr {
    let setName = args[0].stringValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      return .bool(
        env.state.containsInSet(
          setName, element.asEnumValue ?? element.displayString
        )
      )
    }
  }

  private func compileLookup(_ args: [JSONValue]) -> Expr {
    let dictName = args[0].stringValue ?? ""
    let keyExpr = expr(args[1])
    return { env in
      let keyVal = try keyExpr(env)
      return env.state.lookupInDict(
        dictName, key: keyVal.asEnumValue ?? keyVal.displayString
      )
    }
  }

  // Flattened let: {"let": ["x", val, "y", val, body]}
  private func compileLet(_ args: [JSONValue]) -> Expr {
    guard args.count >= 3, args.count.isMultiple(of: 2) == false else {
      return { _ in
        throw DSLError.malformed("let needs pairs + body")
      }
    }
    let body = args.last!
    let pairCount = (args.count - 1) / 2
    var names: [String] = []
    var valueExprs: [Expr] = []
    for idx in 0..<pairCount {
      names.append(args[idx * 2].stringValue ?? "")
      valueExprs.append(expr(args[idx * 2 + 1]))
    }
    let bodyExpr = expr(body)
    // Desugar to nested single-binding lets
    return { env in
      try self.nestedLet(
        env: env, names: names, valueExprs: valueExprs,
        bodyExpr: bodyExpr, index: 0
      )
    }
  }

  private func nestedLet(
    env: Env, names: [String], valueExprs: [Expr],
    bodyExpr: Expr, index: Int
  ) throws -> DSLValue {
    if index >= names.count {
      return try bodyExpr(env)
    }
    let value = try valueExprs[index](env)
    return try env.withBinding(names[index], value) {
      try nestedLet(
        env: env, names: names, valueExprs: valueExprs,
        bodyExpr: bodyExpr, index: index + 1
      )
    }
  }

  // {"get": ["$result", "fieldName"]}
  private func compileGet(_ args: [JSONValue]) -> Expr {
    let structExpr = expr(args[0])
    let fieldName = args[1].stringValue ?? ""
    return { env in
      let structVal = try structExpr(env)
      if let structData = structVal.asStruct {
        return structData.fields[fieldName] ?? .nil
      }
      if structVal.isNil { return .nil }
      throw DSLError.typeError("expected struct for get accessor")
    }
  }

  private func compileRollDie(_ args: [JSONValue]) -> Expr {
    let sidesExpr = expr(args[0])
    return { env in
      let sides = try sidesExpr(env).asInt ?? 6
      if let source = env.randomSource {
        return .int(source.next(sides: sides))
      }
      return .int(GameRNG.next(in: 1...sides))
    }
  }

  private func compileFormat(_ args: [JSONValue]) -> Expr {
    let template = args[0].stringValue ?? ""
    let compiled = args.dropFirst().map { expr($0) }
    return { env in
      var result = template
      for item in compiled {
        let val = try item(env)
        if let range = result.range(of: "{}") {
          result.replaceSubrange(range, with: val.displayString)
        }
      }
      return .string(result)
    }
  }

  private func compileIf(_ args: [JSONValue]) -> Expr {
    let condExpr = expr(args[0])
    let thenExpr = expr(args[1])
    let elseExpr = args.count >= 3 ? expr(args[2]) : nil
    return { env in
      if try condExpr(env).asBool == true {
        return try thenExpr(env)
      } else if let elseExpr {
        return try elseExpr(env)
      }
      return .nil
    }
  }

  private func compileNth(_ args: [JSONValue]) -> Expr {
    let listExpr = expr(args[0])
    let indexExpr = expr(args[1])
    return { env in
      let listVal = try listExpr(env)
      let index = try indexExpr(env).asInt ?? 0
      guard let items = listVal.asList,
            index >= 0, index < items.count else { return .nil }
      return items[index]
    }
  }

  private func compileFilter(_ args: [JSONValue]) -> Expr {
    let listExpr = expr(args[0])
    guard let (paramName, bodyExpr) = parseLambda(args[1]) else {
      return { _ in .list([]) }
    }
    return { env in
      let listVal = try listExpr(env)
      guard let items = listVal.asList else { return .list([]) }
      var result: [DSLValue] = []
      for item in items {
        let cond = try env.withBinding(paramName, item) {
          try bodyExpr(env)
        }
        if cond.asBool == true { result.append(item) }
      }
      return .list(result)
    }
  }

  private func compileMap(_ args: [JSONValue]) -> Expr {
    let listExpr = expr(args[0])
    guard let (paramName, bodyExpr) = parseLambda(args[1]) else {
      return { _ in .list([]) }
    }
    return { env in
      let listVal = try listExpr(env)
      guard let items = listVal.asList else { return .list([]) }
      var result: [DSLValue] = []
      for item in items {
        result.append(
          try env.withBinding(paramName, item) { try bodyExpr(env) }
        )
      }
      return .list(result)
    }
  }

  // {"fn": ["paramName", bodyExpr]} -> a closure that can be used
  // as a lambda. When used standalone, returns the body expression
  // (it's meant to be consumed by filter/map/forEach).
  private func compileFn(_ args: [JSONValue]) -> Expr {
    guard args.count >= 2 else {
      return { _ in throw DSLError.malformed("fn needs param and body") }
    }
    // When fn appears in expression position directly, just compile
    // the body. It will be used via parseLambda by filter/map/forEach.
    let bodyExpr = expr(args[1])
    return bodyExpr
  }

  /// Parse a lambda form: {"fn": ["param", body]}
  private func parseLambda(
    _ value: JSONValue
  ) -> (String, Expr)? {
    guard let (oper, fnArgs) = value.asCall,
          oper == "fn",
          fnArgs.count >= 2,
          let paramName = fnArgs[0].stringValue else {
      return nil
    }
    return (paramName, expr(fnArgs[1]))
  }

  private func compileRandomElement(
    _ args: [JSONValue]
  ) -> Expr {
    let listExpr = expr(args[0])
    return { env in
      let listVal = try listExpr(env)
      guard let items = listVal.asList,
            !items.isEmpty else { return .nil }
      if let source = env.randomSource {
        let idx = source.next(sides: items.count) - 1
        return items[idx]
      }
      return GameRNG.pickRandom(from: items) ?? .nil
    }
  }

  private func compileHistoryCount(
    _ args: [JSONValue]
  ) -> Expr {
    // Args are objects like {"since": expr} and {"matching": expr}
    var compiledSince: Expr?
    var compiledMatch: Expr?
    for arg in args {
      if let dict = arg.objectValue {
        if let sinceVal = dict["since"] {
          compiledSince = expr(sinceVal)
        }
        if let matchVal = dict["matching"] {
          compiledMatch = expr(matchVal)
        }
      }
    }
    let since = compiledSince
    let match = compiledMatch
    return { env in
      var count = 0
      let saved = env.bindings["a"]
      defer {
        if let saved {
          env.bindings["a"] = saved
        } else {
          env.bindings.removeValue(forKey: "a")
        }
      }
      for action in env.state.history.reversed() {
        env.bindings["a"] = .string(action.name)
        if let since {
          let isBoundary = try since(env)
          if isBoundary.asBool == true { break }
        }
        if let match {
          let isMatch = try match(env)
          if isMatch.asBool == true { count += 1 }
        }
      }
      return .int(count)
    }
  }
}

// MARK: - Site operations

extension JSONExpressionCompiler {

  private func compileSiteExpr(_ args: [JSONValue]) -> Expr {
    let trackName = args[0].stringValue ?? ""

    if args.count == 1 {
      // Named site: {"site": ["reserves"]}
      if let site = graph.sites.values.first(where: {
        $0.displayName == trackName
      }) {
        let val = DSLValue.site(track: "", index: site.id.raw)
        return { _ in val }
      }
      return { _ in .nil }
    }

    let indexArg = args[1]

    // Integer literal: {"site": ["road", 0]}
    if let intVal = indexArg.intValue {
      let val = DSLValue.site(track: trackName, index: intVal)
      return { _ in val }
    }

    // String label: {"site": ["road", "Belgium"]}
    if let label = indexArg.stringValue,
       !label.hasPrefix("$") {
      if let trackSites = graph.tracks[trackName] {
        for (idx, siteID) in trackSites.enumerated()
        where graph.sites[siteID]?.displayName == label {
          let val = DSLValue.site(track: trackName, index: idx)
          return { _ in val }
        }
      }
      return { _ in .nil }
    }

    // Runtime expression
    let idxExpr = expr(indexArg)
    return { env in
      let idx = try idxExpr(env).asInt ?? 0
      return .site(track: trackName, index: idx)
    }
  }

  private func compilePos(_ args: [JSONValue]) -> Expr {
    let pieceExpr = expr(args[0])
    return { env in
      let piece = try pieceExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      return env.state.getPosition(name)
    }
  }

  private func compileAdvance(_ args: [JSONValue]) -> Expr {
    let siteExpr = expr(args[0])
    let trackName = args[1].stringValue ?? ""
    let nExpr = expr(args[2])
    let capturedGraph = graph
    return { env in
      let siteVal = try siteExpr(env)
      guard case .site(let curTrack, let curIndex) = siteVal else {
        return .nil
      }
      let steps = try nExpr(env).asInt ?? 0
      let effectiveTrack = trackName.isEmpty ? curTrack : trackName
      guard let trackSites = capturedGraph.tracks[effectiveTrack]
      else {
        return .nil
      }
      let startIdx = (effectiveTrack == curTrack) ? curIndex : 0
      let newIdx = max(
        0, min(startIdx + steps, trackSites.count - 1)
      )
      return .site(track: effectiveTrack, index: newIdx)
    }
  }

  private func compileTrackOf(_ args: [JSONValue]) -> Expr {
    let siteExpr = expr(args[0])
    return { env in
      guard case .site(let track, _) = try siteExpr(env) else {
        return .nil
      }
      return .string(track)
    }
  }

  private func compileIndexOf(_ args: [JSONValue]) -> Expr {
    let siteExpr = expr(args[0])
    return { env in
      guard case .site(_, let index) = try siteExpr(env) else {
        return .nil
      }
      return .int(index)
    }
  }

  private func compileAdjacent(_ args: [JSONValue]) -> Expr {
    let siteExpr = expr(args[0])
    let dirName = args[1].stringValue ?? ""
    let capturedGraph = graph
    return { env in
      let siteVal = try siteExpr(env)
      guard let siteID = capturedGraph.resolve(siteVal),
            let dest = capturedGraph.sites[siteID]?
              .adjacency[.custom(dirName)] else {
        return .nil
      }
      for (trackName, trackSites) in capturedGraph.tracks {
        if let idx = trackSites.firstIndex(of: dest) {
          return .site(track: trackName, index: idx)
        }
      }
      return .site(track: "", index: dest.raw)
    }
  }

  private func compileParallel(_ args: [JSONValue]) -> Expr {
    let siteExpr = expr(args[0])
    let otherTrack = args[1].stringValue ?? ""
    let capturedGraph = graph
    return { env in
      let siteVal = try siteExpr(env)
      guard case .site(let curTrack, let curIndex) = siteVal else {
        return .nil
      }
      if let siteID = capturedGraph.resolve(siteVal),
         let dest = capturedGraph.sites[siteID]?
           .adjacency[.custom(otherTrack)] {
        for (trackName, trackSites) in capturedGraph.tracks
        where trackName == otherTrack {
          if let idx = trackSites.firstIndex(of: dest) {
            return .site(track: otherTrack, index: idx)
          }
        }
      }
      guard let otherSites = capturedGraph.tracks[otherTrack],
            curIndex >= 0, curIndex < otherSites.count else {
        return .nil
      }
      return .site(track: otherTrack, index: curIndex)
    }
  }

  private func compilePieceAt(_ args: [JSONValue]) -> Expr {
    let siteExpr = expr(args[0])
    return { env in
      let targetSite = try siteExpr(env)
      if targetSite.isNil { return .nil }
      for (name, pos) in env.state.positions
      where pos == targetSite {
        if let enumType = env.state.pieceTypes[name] {
          return .enumCase(type: enumType, value: name)
        }
        return .string(name)
      }
      return .nil
    }
  }

  private func compileFnCall(
    _ tag: String, args: [JSONValue]
  ) -> Expr {
    let argExpr = expr(args[0])
    let capturedComponents = components
    return { env in
      let arg = try argExpr(env)
      let argKey = arg.asEnumValue ?? arg.displayString
      if let result = capturedComponents.lookupFn(
        tag, argument: argKey
      ) {
        return result
      }
      throw DSLError.undefinedFunction("\(tag)(\(argKey))")
    }
  }

  // swiftlint:disable:next function_body_length
  private func compileCrtCall(
    _ name: String, args: [JSONValue]
  ) -> Expr {
    guard let crt = components.crts[name] else {
      return { _ in throw DSLError.undefinedFunction(name) }
    }
    if crt.rowEnumName != nil {
      guard args.count >= 2 else {
        return { _ in
          throw DSLError.malformed(
            "2D CRT requires row and die roll"
          )
        }
      }
      let rowExpr = expr(args[0])
      let dieExpr = expr(args[1])
      let resultFields = crt.resultFields
      return { env in
        let rowVal = try rowExpr(env)
        let dieRoll = try dieExpr(env).asInt ?? 0
        let rowKey = rowVal.asEnumValue ?? rowVal.displayString
        guard let values = crt.lookup(
          row: rowKey, dieRoll: dieRoll
        ) else {
          throw DSLError.typeError(
            "CRT lookup failed: \(name)(\(rowKey), \(dieRoll))"
          )
        }
        if !resultFields.isEmpty {
          var fields: [String: DSLValue] = [:]
          for (idx, fieldName) in resultFields.enumerated() {
            fields[fieldName] =
              idx < values.count ? values[idx] : .nil
          }
          return .structValue(
            type: "\(name)Result", fields: fields
          )
        }
        return values.first ?? .nil
      }
    }
    guard !args.isEmpty else {
      return { _ in
        throw DSLError.malformed("1D CRT requires die roll")
      }
    }
    let dieExpr = expr(args[0])
    return { env in
      let dieRoll = try dieExpr(env).asInt ?? 0
      guard let values = crt.lookup(
        row: nil, dieRoll: dieRoll
      ) else {
        throw DSLError.typeError(
          "CRT lookup failed: \(name)(\(dieRoll))"
        )
      }
      return values.first ?? .nil
    }
  }
}

// MARK: - Statement compilation

extension JSONExpressionCompiler {

  // swiftlint:disable:next cyclomatic_complexity
  private func compileStmtCall(
    _ oper: String, args: [JSONValue]
  ) -> Stmt {
    switch oper {
    // Mutations
    case "set": return compileSet(args)
    case "increment": return compileIncDec(args, increment: true)
    case "decrement": return compileIncDec(args, increment: false)
    case "insertInto": return compileInsertInto(args)
    case "removeFrom": return compileRemoveFrom(args)
    case "setEntry": return compileSetEntry(args)
    case "removeEntry": return compileRemoveEntry(args)
    // Deck
    case "draw": return compileDraw(args)
    case "shuffle": return compileShuffle(args)
    case "discard": return compileDiscard(args)
    case "appendTo": return compileAppendTo(args)
    case "removeAt": return compileRemoveAt(args)
    case "clearList": return compileClearList(args)
    // State
    case "setPhase": return compileSetPhase(args)
    case "endGame": return compileEndGame(args)
    // Control flow
    case "seq": return compileSeq(args)
    case "if": return compileStmtIf(args)
    case "guard": return compileGuard(args)
    case "chain": return compileChain(args)
    case "log": return compileLog(args)
    case "let": return compileStmtLet(args)
    case "forEach": return compileForEach(args)
    case "place": return compilePlace(args)
    case "move": return compileMove(args)
    case "remove": return compileRemove(args)
    default:
      // Expand user-defined functions (defines) as statements
      if let expanded = try? defines.expand(
        .object([oper: .array(args)])
      ) {
        return stmt(expanded)
      }
      return { _ in throw DSLError.unknownForm(oper) }
    }
  }
}

// MARK: - Statement helpers

extension JSONExpressionCompiler {

  private func compileSet(_ args: [JSONValue]) -> Stmt {
    let fieldName = args[0].stringValue ?? ""
    let valueExpr = expr(args[1])
    guard let def = schema.field(fieldName) else {
      return { _ in ReduceResult(logs: [], followUps: []) }
    }
    switch def.kind {
    case .counter:
      return { env in
        env.state.setCounter(
          fieldName, try valueExpr(env).asInt ?? 0
        )
        return ReduceResult(logs: [], followUps: [])
      }
    case .flag:
      return { env in
        env.state.setFlag(
          fieldName, try valueExpr(env).asBool ?? false
        )
        return ReduceResult(logs: [], followUps: [])
      }
    case .field:
      return { env in
        env.state.setField(fieldName, try valueExpr(env))
        return ReduceResult(logs: [], followUps: [])
      }
    case .optional:
      return { env in
        let value = try valueExpr(env)
        env.state.setOptional(
          fieldName, value.isNil ? nil : value
        )
        return ReduceResult(logs: [], followUps: [])
      }
    default:
      return { _ in ReduceResult(logs: [], followUps: []) }
    }
  }

  private func compileIncDec(
    _ args: [JSONValue], increment: Bool
  ) -> Stmt {
    let fieldName = args[0].stringValue ?? ""
    let amountExpr = expr(args[1])
    return { env in
      let amount = try amountExpr(env).asInt ?? 1
      if increment {
        env.state.incrementCounter(fieldName, by: amount)
      } else {
        env.state.decrementCounter(fieldName, by: amount)
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileInsertInto(_ args: [JSONValue]) -> Stmt {
    let setName = args[0].stringValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      env.state.insertIntoSet(
        setName, element.asEnumValue ?? element.displayString
      )
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileRemoveFrom(_ args: [JSONValue]) -> Stmt {
    let setName = args[0].stringValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      env.state.removeFromSet(
        setName, element.asEnumValue ?? element.displayString
      )
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileSetEntry(_ args: [JSONValue]) -> Stmt {
    let dictName = args[0].stringValue ?? ""
    let keyExpr = expr(args[1])
    let valueExpr = expr(args[2])
    return { env in
      let key = try keyExpr(env)
      let value = try valueExpr(env)
      env.state.setDictEntry(
        dictName,
        key: key.asEnumValue ?? key.displayString,
        value: value
      )
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileRemoveEntry(_ args: [JSONValue]) -> Stmt {
    let dictName = args[0].stringValue ?? ""
    let keyExpr = expr(args[1])
    return { env in
      let key = try keyExpr(env)
      env.state.removeDictEntry(
        dictName, key: key.asEnumValue ?? key.displayString
      )
      return ReduceResult(logs: [], followUps: [])
    }
  }

  // JSON: {"draw": ["deckName", "optionalName"]}
  // Source first, destination second
  private func compileDraw(_ args: [JSONValue]) -> Stmt {
    let deckName = args[0].stringValue ?? ""
    let optName = args.count > 1 ? (args[1].stringValue ?? "") : ""
    return { env in
      if let card = env.state.drawFromDeck(deckName) {
        env.state.setOptional(optName, card)
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileShuffle(_ args: [JSONValue]) -> Stmt {
    let deckName = args[0].stringValue ?? ""
    return { env in
      env.state.shuffleDeck(deckName)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  // JSON: {"discard": ["optionalName", "deckName"]}
  // Source first, destination second
  private func compileDiscard(_ args: [JSONValue]) -> Stmt {
    let optName = args[0].stringValue ?? ""
    let deckName = args.count > 1
      ? (args[1].stringValue ?? "") : ""
    return { env in
      let card = env.state.getOptional(optName)
      if !card.isNil {
        env.state.appendToDeck(deckName, card)
        env.state.setOptional(optName, .nil)
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileAppendTo(_ args: [JSONValue]) -> Stmt {
    let listName = args[0].stringValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      env.state.appendToDeck(listName, element)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileRemoveAt(_ args: [JSONValue]) -> Stmt {
    let listName = args[0].stringValue ?? ""
    let indexExpr = expr(args[1])
    return { env in
      let index = try indexExpr(env).asInt ?? 0
      env.state.removeDeckItem(listName, at: index)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileClearList(_ args: [JSONValue]) -> Stmt {
    let listName = args[0].stringValue ?? ""
    return { env in
      env.state.clearDeck(listName)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileSetPhase(_ args: [JSONValue]) -> Stmt {
    let phaseExpr = expr(args[0])
    return { env in
      let phase = try phaseExpr(env)
      env.state.phase = phase.asEnumValue ?? phase.displayString
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileEndGame(_ args: [JSONValue]) -> Stmt {
    let outcome = args[0].stringValue ?? ""
    let isVictory = outcome == "victory"
    return { env in
      env.state.ended = true
      env.state.victory = isVictory
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compilePlace(_ args: [JSONValue]) -> Stmt {
    let pieceExpr = expr(args[0])
    let siteExpr = expr(args[1])
    let staticEnumType = args[0].stringValue.flatMap {
      components.isEnumCase($0)
    }
    return { env in
      let piece = try pieceExpr(env)
      let site = try siteExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      let enumType = staticEnumType ?? piece.asEnumType ?? ""
      env.state.place(name, at: site, enumType: enumType)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileMove(_ args: [JSONValue]) -> Stmt {
    let pieceExpr = expr(args[0])
    let siteExpr = expr(args[1])
    let staticEnumType = args[0].stringValue.flatMap {
      components.isEnumCase($0)
    }
    return { env in
      let piece = try pieceExpr(env)
      let site = try siteExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      let enumType = staticEnumType ?? piece.asEnumType ?? ""
      env.state.place(name, at: site, enumType: enumType)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileRemove(_ args: [JSONValue]) -> Stmt {
    let pieceExpr = expr(args[0])
    return { env in
      let piece = try pieceExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      env.state.removePiece(name)
      return ReduceResult(logs: [], followUps: [])
    }
  }
}

// MARK: - Control flow statements

extension JSONExpressionCompiler {

  private func compileSeq(_ args: [JSONValue]) -> Stmt {
    enum SeqChild {
      case letBinding(name: String, valueExpr: Expr)
      case statement(Stmt)
    }
    var compiled: [SeqChild] = []
    for arg in args {
      if let (oper, letArgs) = arg.asCall,
         oper == "let", letArgs.count == 2,
         let name = letArgs[0].stringValue {
        compiled.append(
          .letBinding(name: name, valueExpr: expr(letArgs[1]))
        )
      } else {
        compiled.append(.statement(stmt(arg)))
      }
    }
    return { env in
      var logs: [Log] = []
      var followUps: [ActionValue] = []
      var savedBindings: [(String, DSLValue?)] = []
      defer {
        for (name, saved) in savedBindings.reversed() {
          if let saved {
            env.bindings[name] = saved
          } else {
            env.bindings.removeValue(forKey: name)
          }
        }
      }
      for child in compiled {
        do {
          switch child {
          case .letBinding(let name, let valueExpr):
            savedBindings.append((name, env.bindings[name]))
            env.bindings[name] = try valueExpr(env)
          case .statement(let body):
            let result = try body(env)
            logs.append(contentsOf: result.logs)
            followUps.append(contentsOf: result.followUps)
          }
        } catch is GuardAbort {
          break
        }
      }
      return ReduceResult(logs: logs, followUps: followUps)
    }
  }

  private func compileStmtIf(_ args: [JSONValue]) -> Stmt {
    let condExpr = expr(args[0])
    let thenStmt = stmt(args[1])
    let elseStmt = args.count >= 3 ? stmt(args[2]) : nil
    return { env in
      if try condExpr(env).asBool == true {
        return try thenStmt(env)
      } else if let elseStmt {
        return try elseStmt(env)
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileGuard(_ args: [JSONValue]) -> Stmt {
    let condExpr = expr(args[0])
    return { env in
      if try condExpr(env).asBool != true {
        throw GuardAbort()
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  // {"chain": ["actionName", {"key": value}, ...]}
  private func compileChain(_ args: [JSONValue]) -> Stmt {
    let actionName = args[0].stringValue ?? ""
    let paramPairs: [(String, Expr)] = args.dropFirst().compactMap { arg in
      guard let dict = arg.objectValue, dict.count == 1,
            let (key, val) = dict.first else { return nil }
      return (key, expr(val))
    }
    return { env in
      var params: [String: DSLValue] = [:]
      for (key, valueExpr) in paramPairs {
        params[key] = try valueExpr(env)
      }
      return ReduceResult(
        logs: [], followUps: [ActionValue(actionName, params)]
      )
    }
  }

  private func compileLog(_ args: [JSONValue]) -> Stmt {
    let messageExpr = expr(args[0])
    return { env in
      let message = try messageExpr(env)
      return ReduceResult(
        logs: [Log(msg: message.displayString)], followUps: []
      )
    }
  }

  private func compileStmtLet(_ args: [JSONValue]) -> Stmt {
    guard args.count >= 3, args.count.isMultiple(of: 2) == false else {
      return { _ in
        throw DSLError.malformed("let needs pairs + body")
      }
    }
    let body = args.last!
    let pairCount = (args.count - 1) / 2
    var names: [String] = []
    var valueExprs: [Expr] = []
    for idx in 0..<pairCount {
      names.append(args[idx * 2].stringValue ?? "")
      valueExprs.append(expr(args[idx * 2 + 1]))
    }
    let bodyStmt = stmt(body)
    return { env in
      try self.nestedStmtLet(
        env: env, names: names, valueExprs: valueExprs,
        bodyStmt: bodyStmt, index: 0
      )
    }
  }

  private func nestedStmtLet(
    env: Env, names: [String], valueExprs: [Expr],
    bodyStmt: Stmt, index: Int
  ) throws -> ReduceResult {
    if index >= names.count {
      return try bodyStmt(env)
    }
    let value = try valueExprs[index](env)
    return try env.withBinding(names[index], value) {
      try nestedStmtLet(
        env: env, names: names, valueExprs: valueExprs,
        bodyStmt: bodyStmt, index: index + 1
      )
    }
  }

  private func compileForEach(_ args: [JSONValue]) -> Stmt {
    let collectionExpr = expr(args[0])
    guard let (paramName, bodyExpr) = parseLambdaStmt(args[1])
    else {
      return { _ in
        throw DSLError.malformed("forEach needs a lambda")
      }
    }
    return { env in
      let collection = try collectionExpr(env)
      guard let items = collection.asList else {
        throw DSLError.typeError("forEach requires a list")
      }
      var logs: [Log] = []
      var followUps: [ActionValue] = []
      for item in items {
        let result = try env.withBinding(paramName, item) {
          try bodyExpr(env)
        }
        logs.append(contentsOf: result.logs)
        followUps.append(contentsOf: result.followUps)
      }
      return ReduceResult(logs: logs, followUps: followUps)
    }
  }

  /// Parse a lambda form for statements: {"fn": ["param", body]}
  private func parseLambdaStmt(
    _ value: JSONValue
  ) -> (String, Stmt)? {
    guard let (oper, fnArgs) = value.asCall,
          oper == "fn",
          fnArgs.count >= 2,
          let paramName = fnArgs[0].stringValue else {
      return nil
    }
    return (paramName, stmt(fnArgs[1]))
  }
}
// swiftlint:enable file_length
