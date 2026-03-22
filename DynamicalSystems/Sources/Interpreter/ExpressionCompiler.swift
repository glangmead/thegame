// swiftlint:disable file_length
import Foundation

/// Randomness source: nil means use real randomness, non-nil pops from list.
final class RandomSource {
  var values: [Int]
  init(_ values: [Int]) { self.values = values }
  func next(sides: Int) -> Int {
    if values.isEmpty { return Int.random(in: 1...sides) }
    return values.removeFirst()
  }
}

struct ReduceResult {
  var logs: [Log]
  var followUps: [ActionValue]
}

/// Thrown by (guard) to abort a (seq) branch.
struct GuardAbort: Error {}

/// Compiles SExpr trees into Swift closures at game-build time,
/// eliminating runtime tree walking and string-based tag dispatch.
/// Called once during `GameBuilder.build()`; the resulting closures
/// execute at near-native speed during MCTS rollouts.
struct ExpressionCompiler {

  let components: ComponentRegistry
  let schema: StateSchema
  let graph: SiteGraph

  init(
    components: ComponentRegistry,
    schema: StateSchema,
    graph: SiteGraph = SiteGraph()
  ) {
    self.components = components
    self.schema = schema
    self.graph = graph
  }

  // MARK: - Closure types

  typealias Expr = (Env) throws -> DSLValue
  typealias Stmt = (Env) throws -> ReduceResult

  // MARK: - Runtime environment

  /// Lightweight runtime environment for compiled closures.
  /// One allocation per top-level condition/reduce call.
  final class Env {
    var state: InterpretedState
    let actionParams: [String: DSLValue]
    var bindings: [String: DSLValue]
    let randomSource: RandomSource?

    init(
      state: InterpretedState,
      actionParams: [String: DSLValue] = [:],
      bindings: [String: DSLValue] = [:],
      randomSource: RandomSource? = nil
    ) {
      self.state = state
      self.actionParams = actionParams
      self.randomSource = randomSource
      // Seed locals from action params so $piece etc. work without
      // an explicit (let piece (param piece)) wrapper.
      var merged = actionParams
      for (key, value) in bindings { merged[key] = value }
      self.bindings = merged
    }

    /// Temporarily bind `name` to `value`, execute `body`, then restore.
    func withBinding<T>(
      _ name: String, _ value: DSLValue,
      body: () throws -> T
    ) rethrows -> T {
      let saved = bindings[name]
      bindings[name] = value
      defer {
        if let saved {
          bindings[name] = saved
        } else {
          bindings.removeValue(forKey: name)
        }
      }
      return try body()
    }
  }

  // MARK: - Public API

  func expr(_ sexpr: SExpr) -> Expr {
    switch sexpr {
    case .atom(let str):
      return compileAtom(str)
    case .list(let children):
      guard let first = children.first, let tag = first.atomValue else {
        return { _ in throw DSLError.malformed("empty list in expression") }
      }
      let args = Array(children.dropFirst())
      return compileForm(tag, args: args)
    }
  }

  func stmt(_ sexpr: SExpr) -> Stmt {
    guard case .list(let children) = sexpr,
          let tag = children.first?.atomValue else {
      return { _ in throw DSLError.malformed("reduce expression must be a list") }
    }
    let args = Array(children.dropFirst())
    return compileStmtForm(tag, args: args)
  }
}

// MARK: - Atom compilation

extension ExpressionCompiler {

  private func compileAtom(_ str: String) -> Expr {
    // $binding
    if str.hasPrefix("$") {
      let name = String(str.dropFirst())
      return { env in
        if let val = env.bindings[name] { return val }
        throw DSLError.undefinedField("$\(name)")
      }
    }
    // Integer literal
    if let intVal = Int(str) {
      let val: DSLValue = .int(intVal)
      return { _ in val }
    }
    // Float literal
    if str.contains("."), let floatVal = Float(str) {
      let val: DSLValue = .float(floatVal)
      return { _ in val }
    }
    // Boolean / nil
    if str == "true" { return { _ in .bool(true) } }
    if str == "false" { return { _ in .bool(false) } }
    if str == "nil" { return { _ in .nil } }
    // Quoted string
    if str.hasPrefix("\""), str.hasSuffix("\""), str.count >= 2 {
      let val: DSLValue = .string(String(str.dropFirst().dropLast()))
      return { _ in val }
    }
    // Schema field (mirrors evalAtom: gate on schema, then state.get handles framework)
    if schema.field(str) != nil {
      return compileFieldAccess(str)
    }
    // Enum case
    if let enumType = components.isEnumCase(str) {
      let val: DSLValue = .enumCase(type: enumType, value: str)
      return { _ in val }
    }
    // Fallback: treat as string
    let val: DSLValue = .string(str)
    return { _ in val }
  }

  // Compile a field read, specializing on the field kind at compile time.
  // swiftlint:disable:next cyclomatic_complexity
  private func compileFieldAccess(_ name: String) -> Expr {
    // Framework fields checked by state.get() first
    switch name {
    case "ended": return { env in .bool(env.state.ended) }
    case "victory": return { env in .bool(env.state.victory) }
    case "gameAcknowledged": return { env in .bool(env.state.gameAcknowledged) }
    case "phase": return { env in .enumCase(type: "Phase", value: env.state.phase) }
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

// MARK: - Expression form compilation

extension ExpressionCompiler {

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func compileForm(_ tag: String, args: [SExpr]) -> Expr {
    switch tag {
    // Arithmetic
    case "+": return binaryNumeric(args, intOp: +, floatOp: +)
    case "-": return binaryNumeric(args, intOp: -, floatOp: -)
    case "*": return binaryNumeric(args, intOp: *, floatOp: *)
    case "/": return compileDivision(args)
    case "%": return binaryInt(args, combine: %)
    case "min": return binaryInt(args, combine: Swift.min)
    case "max": return binaryInt(args, combine: Swift.max)
    case "abs":
      let operand = expr(args[0])
      return { env in .int(abs(try operand(env).asInt ?? 0)) }

    // Comparison
    case "==": return dslComparison(args, compare: ==)
    case "!=": return dslComparison(args, compare: !=)
    case ">": return intComparison(args, compare: >)
    case "<": return intComparison(args, compare: <)
    case ">=": return intComparison(args, compare: >=)
    case "<=": return intComparison(args, compare: <=)

    // Boolean
    case "and":
      let compiled = args.map { expr($0) }
      return { env in
        for item in compiled {
          guard try item(env).asBool == true else { return .bool(false) }
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
      let deckName = args[0].atomValue ?? ""
      return { env in .int(env.state.getDeck(deckName).count) }
    case "isEmpty":
      let deckName = args[0].atomValue ?? ""
      return { env in .bool(env.state.getDeck(deckName).isEmpty) }

    // Binding & access
    case "let": return compileLet(args)
    case "field":
      let fieldName = args[0].atomValue ?? ""
      return compileFieldAccess(fieldName)
    case "param":
      let paramName = args[0].atomValue ?? ""
      return { env in env.actionParams[paramName] ?? .nil }
    case ".": return compileDot(args)
    case "rollDie": return compileRollDie(args)
    case "list":
      let compiled = args.map { expr($0) }
      return { env in .list(try compiled.map { try $0(env) }) }
    case "format": return compileFormat(args)
    case "if" where args.count >= 2: return compileIf(args)
    case "nth": return compileNth(args)
    case "filter": return compileFilter(args)
    case "map": return compileMap(args)
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
      if components.crts[tag] != nil {
        return compileCrtCall(tag, args: args)
      }
      if components.functions[tag] != nil {
        return compileFnCall(tag, args: args)
      }
      return { _ in throw DSLError.unknownForm(tag) }
    }
  }
}

// MARK: - Expression helpers

extension ExpressionCompiler {

  private func binaryInt(
    _ args: [SExpr], combine: @escaping (Int, Int) -> Int
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      .int(combine(try lhs(env).asInt ?? 0, try rhs(env).asInt ?? 0))
    }
  }

  private func binaryNumeric(
    _ args: [SExpr],
    intOp: @escaping (Int, Int) -> Int,
    floatOp: @escaping (Float, Float) -> Float
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      let left = try lhs(env)
      let right = try rhs(env)
      if case .float = left {
        return .float(floatOp(left.asFloat ?? 0, right.asFloat ?? 0))
      }
      if case .float = right {
        return .float(floatOp(left.asFloat ?? 0, right.asFloat ?? 0))
      }
      return .int(intOp(left.asInt ?? 0, right.asInt ?? 0))
    }
  }

  private func dslComparison(
    _ args: [SExpr], compare: @escaping (DSLValue, DSLValue) -> Bool
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in .bool(compare(try lhs(env), try rhs(env))) }
  }

  private func intComparison(
    _ args: [SExpr], compare: @escaping (Int, Int) -> Bool
  ) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      .bool(compare(try lhs(env).asInt ?? 0, try rhs(env).asInt ?? 0))
    }
  }

  private func compileDivision(_ args: [SExpr]) -> Expr {
    let lhs = expr(args[0])
    let rhs = expr(args[1])
    return { env in
      let leftFloat = try lhs(env).asFloat ?? 0
      let rightFloat = try rhs(env).asFloat ?? 1
      return .float(rightFloat == 0 ? 0 : leftFloat / rightFloat)
    }
  }

  private func compileContains(_ args: [SExpr]) -> Expr {
    let setName = args[0].atomValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      let set = env.state.getSet(setName)
      return .bool(set.contains(element.asEnumValue ?? element.displayString))
    }
  }

  private func compileLookup(_ args: [SExpr]) -> Expr {
    let dictName = args[0].atomValue ?? ""
    let keyExpr = expr(args[1])
    return { env in
      let keyVal = try keyExpr(env)
      let dict = env.state.getDict(dictName)
      return dict[keyVal.asEnumValue ?? keyVal.displayString] ?? .nil
    }
  }

  private func compileLet(_ args: [SExpr]) -> Expr {
    guard args.count >= 3 else {
      return { _ in throw DSLError.malformed("let needs name, value, body") }
    }
    let name = args[0].atomValue ?? ""
    let valueExpr = expr(args[1])
    let bodyExpr = expr(args[2])
    return { env in
      let value = try valueExpr(env)
      return try env.withBinding(name, value) { try bodyExpr(env) }
    }
  }

  private func compileDot(_ args: [SExpr]) -> Expr {
    let structExpr = expr(args[0])
    let fieldName = args[1].atomValue ?? ""
    return { env in
      let structVal = try structExpr(env)
      if let structData = structVal.asStruct {
        return structData.fields[fieldName] ?? .nil
      }
      if structVal.isNil { return .nil }
      throw DSLError.typeError("expected struct for . accessor")
    }
  }

  private func compileRollDie(_ args: [SExpr]) -> Expr {
    let sidesExpr = expr(args[0])
    return { env in
      let sides = try sidesExpr(env).asInt ?? 6
      if let source = env.randomSource {
        return .int(source.next(sides: sides))
      }
      return .int(Int.random(in: 1...sides))
    }
  }

  private func compileFormat(_ args: [SExpr]) -> Expr {
    let template = args[0].stringValue ?? args[0].atomValue ?? ""
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

  private func compileIf(_ args: [SExpr]) -> Expr {
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

  private func compileNth(_ args: [SExpr]) -> Expr {
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

  private func compileFilter(_ args: [SExpr]) -> Expr {
    let listExpr = expr(args[0])
    guard let lambdaChildren = args[1].children,
          lambdaChildren.first?.atomValue == "\\" else {
      return { _ in .list([]) }
    }
    let paramName = lambdaChildren[1].children?.first?.atomValue ?? ""
    let bodyExpr = expr(lambdaChildren[2])
    return { env in
      let listVal = try listExpr(env)
      guard let items = listVal.asList else { return .list([]) }
      var result: [DSLValue] = []
      for item in items {
        let cond = try env.withBinding(paramName, item) { try bodyExpr(env) }
        if cond.asBool == true { result.append(item) }
      }
      return .list(result)
    }
  }

  private func compileMap(_ args: [SExpr]) -> Expr {
    let listExpr = expr(args[0])
    guard let lambdaChildren = args[1].children,
          lambdaChildren.first?.atomValue == "\\" else {
      return { _ in .list([]) }
    }
    let paramName = lambdaChildren[1].children?.first?.atomValue ?? ""
    let bodyExpr = expr(lambdaChildren[2])
    return { env in
      let listVal = try listExpr(env)
      guard let items = listVal.asList else { return .list([]) }
      var result: [DSLValue] = []
      for item in items {
        result.append(try env.withBinding(paramName, item) { try bodyExpr(env) })
      }
      return .list(result)
    }
  }

  private func compileRandomElement(_ args: [SExpr]) -> Expr {
    let listExpr = expr(args[0])
    return { env in
      let listVal = try listExpr(env)
      guard let items = listVal.asList, !items.isEmpty else { return .nil }
      if let source = env.randomSource {
        let idx = source.next(sides: items.count) - 1
        return items[idx]
      }
      return items.randomElement() ?? .nil
    }
  }

  private func compileHistoryCount(_ args: [SExpr]) -> Expr {
    var compiledSince: Expr?
    var compiledMatch: Expr?
    for arg in args {
      if arg.tag == "since", let parts = arg.children {
        compiledSince = expr(parts[1])
      }
      if arg.tag == "matching", let parts = arg.children {
        compiledMatch = expr(parts[1])
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

  // MARK: - Site operations

  private func compileSiteExpr(_ args: [SExpr]) -> Expr {
    let trackExpr = args[0]
    let trackName = trackExpr.stringValue ?? trackExpr.atomValue ?? ""

    if args.count == 1 {
      // Named site: (site "reserves")
      if let site = graph.sites.values.first(where: {
        $0.displayName == trackName
      }) {
        let val = DSLValue.site(track: "", index: site.id.raw)
        return { _ in val }
      }
      return { _ in .nil }
    }

    let indexArg = args[1]

    // 1. Integer literal: (site "road" 0)
    if let intVal = indexArg.intValue {
      let val = DSLValue.site(track: trackName, index: intVal)
      return { _ in val }
    }

    // 2. Quoted string label: (site "road" "Belgium")
    if let label = indexArg.stringValue {
      if let trackSites = graph.tracks[trackName] {
        for (idx, siteID) in trackSites.enumerated()
        where graph.sites[siteID]?.displayName == label {
          let val = DSLValue.site(track: trackName, index: idx)
          return { _ in val }
        }
      }
      return { _ in .nil }
    }

    // 3. Runtime expression
    let idxExpr = expr(indexArg)
    return { env in
      let idx = try idxExpr(env).asInt ?? 0
      return .site(track: trackName, index: idx)
    }
  }

  private func compilePos(_ args: [SExpr]) -> Expr {
    let pieceExpr = expr(args[0])
    return { env in
      let piece = try pieceExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      return env.state.getPosition(name)
    }
  }

  private func compileAdvance(_ args: [SExpr]) -> Expr {
    let siteExpr = expr(args[0])
    let trackNameExpr = args[1]
    let trackName =
      trackNameExpr.stringValue ?? trackNameExpr.atomValue ?? ""
    let nExpr = expr(args[2])
    let capturedGraph = graph
    return { env in
      let siteVal = try siteExpr(env)
      guard case .site(let curTrack, let curIndex) = siteVal else {
        return .nil
      }
      let steps = try nExpr(env).asInt ?? 0
      let effectiveTrack = trackName.isEmpty ? curTrack : trackName
      guard let trackSites = capturedGraph.tracks[effectiveTrack] else {
        return .nil
      }
      let startIdx = (effectiveTrack == curTrack) ? curIndex : 0
      let newIdx = max(0, min(startIdx + steps, trackSites.count - 1))
      return .site(track: effectiveTrack, index: newIdx)
    }
  }

  private func compileTrackOf(_ args: [SExpr]) -> Expr {
    let siteExpr = expr(args[0])
    return { env in
      guard case .site(let track, _) = try siteExpr(env) else {
        return .nil
      }
      return .string(track)
    }
  }

  private func compileIndexOf(_ args: [SExpr]) -> Expr {
    let siteExpr = expr(args[0])
    return { env in
      guard case .site(_, let index) = try siteExpr(env) else {
        return .nil
      }
      return .int(index)
    }
  }

  private func compileAdjacent(_ args: [SExpr]) -> Expr {
    let siteExpr = expr(args[0])
    let dirName = args[1].stringValue ?? args[1].atomValue ?? ""
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

  private func compileParallel(_ args: [SExpr]) -> Expr {
    let siteExpr = expr(args[0])
    let otherTrack =
      args[1].stringValue ?? args[1].atomValue ?? ""
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

  private func compilePieceAt(_ args: [SExpr]) -> Expr {
    let siteExpr = expr(args[0])
    return { env in
      let targetSite = try siteExpr(env)
      if targetSite.isNil { return .nil }
      for (name, pos) in env.state.positions where pos == targetSite {
        if let enumType = env.state.pieceTypes[name] {
          return .enumCase(type: enumType, value: name)
        }
        return .string(name)
      }
      return .nil
    }
  }

  private func compileFnCall(_ tag: String, args: [SExpr]) -> Expr {
    let argExpr = expr(args[0])
    let capturedComponents = components
    return { env in
      let arg = try argExpr(env)
      let argKey = arg.asEnumValue ?? arg.displayString
      if let result = capturedComponents.lookupFn(tag, argument: argKey) {
        return result
      }
      throw DSLError.undefinedFunction("\(tag)(\(argKey))")
    }
  }

  private func compileCrtCall(_ name: String, args: [SExpr]) -> Expr {
    guard let crt = components.crts[name] else {
      return { _ in throw DSLError.undefinedFunction(name) }
    }
    if crt.rowEnumName != nil {
      guard args.count >= 2 else {
        return { _ in throw DSLError.malformed("2D CRT requires row and die roll") }
      }
      let rowExpr = expr(args[0])
      let dieExpr = expr(args[1])
      let resultFields = crt.resultFields
      return { env in
        let rowVal = try rowExpr(env)
        let dieRoll = try dieExpr(env).asInt ?? 0
        let rowKey = rowVal.asEnumValue ?? rowVal.displayString
        guard let values = crt.lookup(row: rowKey, dieRoll: dieRoll) else {
          throw DSLError.typeError(
            "CRT lookup failed: \(name)(\(rowKey), \(dieRoll))"
          )
        }
        if !resultFields.isEmpty {
          var fields: [String: DSLValue] = [:]
          for (idx, fieldName) in resultFields.enumerated() {
            fields[fieldName] = idx < values.count ? values[idx] : .nil
          }
          return .structValue(type: "\(name)Result", fields: fields)
        }
        return values.first ?? .nil
      }
    }
    guard !args.isEmpty else {
      return { _ in throw DSLError.malformed("1D CRT requires die roll") }
    }
    let dieExpr = expr(args[0])
    return { env in
      let dieRoll = try dieExpr(env).asInt ?? 0
      guard let values = crt.lookup(row: nil, dieRoll: dieRoll) else {
        throw DSLError.typeError("CRT lookup failed: \(name)(\(dieRoll))")
      }
      return values.first ?? .nil
    }
  }
}

// MARK: - Statement form compilation

extension ExpressionCompiler {

  // swiftlint:disable:next cyclomatic_complexity
  private func compileStmtForm(_ tag: String, args: [SExpr]) -> Stmt {
    switch tag {
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
      return { _ in throw DSLError.unknownForm(tag) }
    }
  }

  // MARK: - Place / Move / Remove

  private func compilePlace(_ args: [SExpr]) -> Stmt {
    let pieceExpr = expr(args[0])
    let siteExpr = expr(args[1])
    let staticEnumType = args[0].atomValue.flatMap { components.isEnumCase($0) }
    return { env in
      let piece = try pieceExpr(env)
      let site = try siteExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      let enumType = staticEnumType ?? piece.asEnumType ?? ""
      env.state.place(name, at: site, enumType: enumType)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileMove(_ args: [SExpr]) -> Stmt {
    let pieceExpr = expr(args[0])
    let siteExpr = expr(args[1])
    let staticEnumType = args[0].atomValue.flatMap { components.isEnumCase($0) }
    return { env in
      let piece = try pieceExpr(env)
      let site = try siteExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      let enumType = staticEnumType ?? piece.asEnumType ?? ""
      env.state.place(name, at: site, enumType: enumType)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileRemove(_ args: [SExpr]) -> Stmt {
    let pieceExpr = expr(args[0])
    return { env in
      let piece = try pieceExpr(env)
      let name = piece.asEnumValue ?? piece.displayString
      env.state.removePiece(name)
      return ReduceResult(logs: [], followUps: [])
    }
  }
}

// MARK: - Statement helpers

extension ExpressionCompiler {

  private func compileSet(_ args: [SExpr]) -> Stmt {
    let fieldName = args[0].atomValue ?? ""
    let valueExpr = expr(args[1])
    guard let def = schema.field(fieldName) else {
      return { _ in ReduceResult(logs: [], followUps: []) }
    }
    switch def.kind {
    case .counter:
      return { env in
        env.state.setCounter(fieldName, try valueExpr(env).asInt ?? 0)
        return ReduceResult(logs: [], followUps: [])
      }
    case .flag:
      return { env in
        env.state.setFlag(fieldName, try valueExpr(env).asBool ?? false)
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
        env.state.setOptional(fieldName, value.isNil ? nil : value)
        return ReduceResult(logs: [], followUps: [])
      }
    default:
      return { _ in ReduceResult(logs: [], followUps: []) }
    }
  }

  private func compileIncDec(_ args: [SExpr], increment: Bool) -> Stmt {
    let fieldName = args[0].atomValue ?? ""
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

  private func compileInsertInto(_ args: [SExpr]) -> Stmt {
    let setName = args[0].atomValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      env.state.insertIntoSet(setName, element.asEnumValue ?? element.displayString)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileRemoveFrom(_ args: [SExpr]) -> Stmt {
    let setName = args[0].atomValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      env.state.removeFromSet(setName, element.asEnumValue ?? element.displayString)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileSetEntry(_ args: [SExpr]) -> Stmt {
    let dictName = args[0].atomValue ?? ""
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

  private func compileRemoveEntry(_ args: [SExpr]) -> Stmt {
    let dictName = args[0].atomValue ?? ""
    let keyExpr = expr(args[1])
    return { env in
      let key = try keyExpr(env)
      env.state.removeDictEntry(dictName, key: key.asEnumValue ?? key.displayString)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileDraw(_ args: [SExpr]) -> Stmt {
    let deckName = parseKeywordArg(args, keyword: "from:")
    let optName = parseKeywordArg(args, keyword: "to:")
    return { env in
      if let card = env.state.drawFromDeck(deckName) {
        env.state.setOptional(optName, card)
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileShuffle(_ args: [SExpr]) -> Stmt {
    let deckName = args[0].atomValue ?? ""
    return { env in
      env.state.shuffleDeck(deckName)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileDiscard(_ args: [SExpr]) -> Stmt {
    let optName = parseKeywordArg(args, keyword: "from:")
    let deckName = parseKeywordArg(args, keyword: "to:")
    return { env in
      let card = env.state.getOptional(optName)
      if !card.isNil {
        env.state.appendToDeck(deckName, card)
        env.state.setOptional(optName, .nil)
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileAppendTo(_ args: [SExpr]) -> Stmt {
    let listName = args[0].atomValue ?? ""
    let elementExpr = expr(args[1])
    return { env in
      let element = try elementExpr(env)
      env.state.appendToDeck(listName, element)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileRemoveAt(_ args: [SExpr]) -> Stmt {
    let listName = args[0].atomValue ?? ""
    let indexExpr = expr(args[1])
    return { env in
      let index = try indexExpr(env).asInt ?? 0
      env.state.removeDeckItem(listName, at: index)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileClearList(_ args: [SExpr]) -> Stmt {
    let listName = args[0].atomValue ?? ""
    return { env in
      env.state.clearDeck(listName)
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileSetPhase(_ args: [SExpr]) -> Stmt {
    let phaseExpr = expr(args[0])
    return { env in
      let phase = try phaseExpr(env)
      env.state.phase = phase.asEnumValue ?? phase.displayString
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileEndGame(_ args: [SExpr]) -> Stmt {
    let outcome = args[0].atomValue ?? ""
    let isVictory = outcome == "victory"
    return { env in
      env.state.ended = true
      env.state.victory = isVictory
      return ReduceResult(logs: [], followUps: [])
    }
  }

  // MARK: Control flow

  private func compileSeq(_ args: [SExpr]) -> Stmt {
    enum SeqChild {
      case letBinding(name: String, valueExpr: ExpressionCompiler.Expr)
      case statement(ExpressionCompiler.Stmt)
    }
    var compiled: [SeqChild] = []
    for arg in args {
      if case .list(let letChildren) = arg,
         letChildren.first?.atomValue == "let",
         letChildren.count == 3 {
        let name = letChildren[1].atomValue ?? ""
        let valueExpr = expr(letChildren[2])
        compiled.append(.letBinding(name: name, valueExpr: valueExpr))
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

  private func compileStmtIf(_ args: [SExpr]) -> Stmt {
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

  private func compileGuard(_ args: [SExpr]) -> Stmt {
    let condExpr = expr(args[0])
    return { env in
      if try condExpr(env).asBool != true {
        throw GuardAbort()
      }
      return ReduceResult(logs: [], followUps: [])
    }
  }

  private func compileChain(_ args: [SExpr]) -> Stmt {
    let actionName = args[0].atomValue ?? ""
    let paramPairs: [(String, Expr)] = args.dropFirst().compactMap { arg in
      guard let parts = arg.children, parts.count >= 2 else { return nil }
      let key = parts[0].atomValue ?? ""
      return (key, expr(parts[1]))
    }
    return { env in
      var params: [String: DSLValue] = [:]
      for (key, valueExpr) in paramPairs {
        params[key] = try valueExpr(env)
      }
      return ReduceResult(logs: [], followUps: [ActionValue(actionName, params)])
    }
  }

  private func compileLog(_ args: [SExpr]) -> Stmt {
    let messageExpr = expr(args[0])
    return { env in
      let message = try messageExpr(env)
      return ReduceResult(
        logs: [Log(msg: message.displayString)], followUps: []
      )
    }
  }

  private func compileStmtLet(_ args: [SExpr]) -> Stmt {
    guard args.count >= 3 else {
      return { _ in throw DSLError.malformed("let needs name, value, body") }
    }
    let name = args[0].atomValue ?? ""
    let valueExpr = expr(args[1])
    let bodyStmt = stmt(args[2])
    return { env in
      let value = try valueExpr(env)
      return try env.withBinding(name, value) { try bodyStmt(env) }
    }
  }

  private func compileForEach(_ args: [SExpr]) -> Stmt {
    let collectionExpr = expr(args[0])
    guard let lambdaChildren = args[1].children,
          lambdaChildren.first?.atomValue == "\\" else {
      return { _ in throw DSLError.malformed("forEach needs a lambda") }
    }
    let paramName = lambdaChildren[1].children?.first?.atomValue ?? ""
    let bodyStmt = stmt(lambdaChildren[2])
    return { env in
      let collection = try collectionExpr(env)
      guard let items = collection.asList else {
        throw DSLError.typeError("forEach requires a list")
      }
      var logs: [Log] = []
      var followUps: [ActionValue] = []
      for item in items {
        let result = try env.withBinding(paramName, item) { try bodyStmt(env) }
        logs.append(contentsOf: result.logs)
        followUps.append(contentsOf: result.followUps)
      }
      return ReduceResult(logs: logs, followUps: followUps)
    }
  }

  // MARK: - Compile-time helpers

  private func parseKeywordArg(
    _ args: [SExpr], keyword: String
  ) -> String {
    for (idx, arg) in args.enumerated() {
      if arg.atomValue == keyword, idx + 1 < args.count {
        return args[idx + 1].atomValue ?? ""
      }
    }
    return ""
  }
}
// swiftlint:enable file_length
