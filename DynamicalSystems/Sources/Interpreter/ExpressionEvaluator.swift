// MARK: - ExpressionEvaluator

/// Pure evaluator: reads SExpr trees against InterpretedState + ComponentRegistry,
/// producing DSLValue results. No mutations.
enum ExpressionEvaluator {

  // MARK: - RandomSource

  /// Randomness source: nil means use real randomness, non-nil pops from list.
  final class RandomSource {
    var values: [Int]
    init(_ values: [Int]) { self.values = values }
    func next(sides: Int) -> Int {
      if values.isEmpty { return Int.random(in: 1...sides) }
      return values.removeFirst()
    }
  }

  // MARK: - Context

  struct Context {
    let state: InterpretedState
    let components: ComponentRegistry
    var bindings: [String: DSLValue]
    var actionParams: [String: DSLValue]
    var randomSource: RandomSource?
  }

  // MARK: - Public API

  static func eval(_ expr: SExpr, context: Context) throws -> DSLValue {
    switch expr {
    case .atom(let atomStr):
      return try evalAtom(atomStr, context: context)
    case .list(let children):
      guard let first = children.first, let tag = first.atomValue else {
        throw DSLError.malformed("empty list in expression")
      }
      return try evalForm(tag, args: Array(children.dropFirst()), context: context)
    }
  }

  // MARK: - Atom evaluation

  private static func evalAtom(_ atomStr: String, context: Context) throws -> DSLValue {
    if atomStr.hasPrefix("$") {
      let name = String(atomStr.dropFirst())
      if let val = context.bindings[name] { return val }
      throw DSLError.undefinedField("$\(name)")
    }
    if let intVal = Int(atomStr) { return .int(intVal) }
    if let floatVal = Float(atomStr), atomStr.contains(".") { return .float(floatVal) }
    if atomStr == "true" { return .bool(true) }
    if atomStr == "false" { return .bool(false) }
    if atomStr == "nil" { return .nil }
    if atomStr.hasPrefix("\"") && atomStr.hasSuffix("\"") {
      return .string(String(atomStr.dropFirst().dropLast()))
    }
    if context.state.schema.field(atomStr) != nil {
      return context.state.get(atomStr)
    }
    if let enumType = context.components.isEnumCase(atomStr) {
      return .enumCase(type: enumType, value: atomStr)
    }
    return .string(atomStr)
  }

  // MARK: - Form evaluation

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private static func evalForm(
    _ tag: String, args: [SExpr], context: Context
  ) throws -> DSLValue {
    switch tag {
    case "+": return try binaryNumeric(args, context: context, intOp: +, floatOp: +)
    case "-": return try binaryNumeric(args, context: context, intOp: -, floatOp: -)
    case "*": return try binaryNumeric(args, context: context, intOp: *, floatOp: *)
    case "/": return try evalDivision(args, context: context)
    case "%": return try binaryInt(args, context: context, combine: %)
    case "min": return try binaryInt(args, context: context, combine: Swift.min)
    case "max": return try binaryInt(args, context: context, combine: Swift.max)
    case "abs":
      let val = try eval(args[0], context: context)
      return .int(abs(val.asInt ?? 0))
    case "==": return try comparison(args, context: context, compare: ==)
    case "!=": return try comparison(args, context: context, compare: !=)
    case ">": return try intComparison(args, context: context, compare: >)
    case "<": return try intComparison(args, context: context, compare: <)
    case ">=": return try intComparison(args, context: context, compare: >=)
    case "<=": return try intComparison(args, context: context, compare: <=)
    case "and":
      let lhs = try eval(args[0], context: context)
      guard lhs.asBool == true else { return .bool(false) }
      return try eval(args[1], context: context)
    case "or":
      let lhs = try eval(args[0], context: context)
      if lhs.asBool == true { return .bool(true) }
      return try eval(args[1], context: context)
    case "not":
      let val = try eval(args[0], context: context)
      return .bool(!(val.asBool ?? false))
    case "contains": return try evalContains(args, context: context)
    case "lookup": return try evalLookup(args, context: context)
    case "count":
      return .int(context.state.getDeck(args[0].atomValue ?? "").count)
    case "isEmpty":
      return .bool(context.state.getDeck(args[0].atomValue ?? "").isEmpty)
    case "let": return try evalLet(args, context: context)
    case "field": return context.state.get(args[0].atomValue ?? "")
    case "param": return context.actionParams[args[0].atomValue ?? ""] ?? .nil
    case ".": return try evalDot(args, context: context)
    case "rollDie": return try evalRollDie(args, context: context)
    case "list":
      return .list(try args.map { try eval($0, context: context) })
    case "format": return try evalFormat(args, context: context)
    case "if" where args.count >= 2: return try evalIf(args, context: context)
    case "nth": return try evalNth(args, context: context)
    case "filter": return try evalFilter(args, context: context)
    case "map": return try evalMap(args, context: context)
    case "randomElement": return try evalRandomElement(args, context: context)
    case "historyCount": return try evalHistoryCount(args, context: context)
    case _ where context.components.functions[tag] != nil:
      return try evalFnCall(tag, args: args, context: context)
    default:
      throw DSLError.unknownForm(tag)
    }
  }
}

// MARK: - Form helpers

extension ExpressionEvaluator {

  private static func evalDivision(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let lhs = try eval(args[0], context: context)
    let rhs = try eval(args[1], context: context)
    let leftFloat = lhs.asFloat ?? 0
    let rightFloat = rhs.asFloat ?? 1
    return .float(rightFloat == 0 ? 0 : leftFloat / rightFloat)
  }

  private static func evalContains(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let setName = args[0].atomValue ?? ""
    let element = try eval(args[1], context: context)
    let set = context.state.getSet(setName)
    return .bool(set.contains(element.asEnumValue ?? element.displayString))
  }

  private static func evalLookup(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let dictName = args[0].atomValue ?? ""
    let keyVal = try eval(args[1], context: context)
    let dict = context.state.getDict(dictName)
    return dict[keyVal.asEnumValue ?? keyVal.displayString] ?? .nil
  }

  private static func evalLet(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    guard args.count >= 3 else {
      throw DSLError.malformed("let needs name, value, body")
    }
    let name = args[0].atomValue ?? ""
    let value = try eval(args[1], context: context)
    var innerContext = context
    innerContext.bindings[name] = value
    return try eval(args[2], context: innerContext)
  }

  private static func evalDot(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let structVal = try eval(args[0], context: context)
    let fieldName = args[1].atomValue ?? ""
    if let structData = structVal.asStruct {
      return structData.fields[fieldName] ?? .nil
    }
    if structVal.isNil { return .nil }
    throw DSLError.typeError("expected struct for . accessor")
  }

  private static func evalRollDie(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let sides = try eval(args[0], context: context).asInt ?? 6
    if let source = context.randomSource {
      return .int(source.next(sides: sides))
    }
    return .int(Int.random(in: 1...sides))
  }

  private static func evalFormat(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let template = args[0].stringValue ?? args[0].atomValue ?? ""
    var result = template
    for arg in args.dropFirst() {
      let val = try eval(arg, context: context)
      if let range = result.range(of: "{}") {
        result.replaceSubrange(range, with: val.displayString)
      }
    }
    return .string(result)
  }

  private static func evalIf(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let cond = try eval(args[0], context: context)
    if cond.asBool == true {
      return try eval(args[1], context: context)
    } else if args.count >= 3 {
      return try eval(args[2], context: context)
    }
    return .nil
  }

  private static func evalNth(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let listVal = try eval(args[0], context: context)
    let index = try eval(args[1], context: context).asInt ?? 0
    guard let items = listVal.asList, index >= 0, index < items.count else { return .nil }
    return items[index]
  }

  private static func evalFilter(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let listVal = try eval(args[0], context: context)
    guard let items = listVal.asList,
          let lambdaChildren = args[1].children,
          lambdaChildren.first?.atomValue == "\\" else {
      return .list([])
    }
    let paramName = lambdaChildren[1].children?.first?.atomValue ?? ""
    let body = lambdaChildren[2]
    var result: [DSLValue] = []
    for item in items {
      var innerCtx = context
      innerCtx.bindings[paramName] = item
      let cond = try eval(body, context: innerCtx)
      if cond.asBool == true { result.append(item) }
    }
    return .list(result)
  }

  private static func evalMap(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let listVal = try eval(args[0], context: context)
    guard let items = listVal.asList,
          let lambdaChildren = args[1].children,
          lambdaChildren.first?.atomValue == "\\" else {
      return .list([])
    }
    let paramName = lambdaChildren[1].children?.first?.atomValue ?? ""
    let body = lambdaChildren[2]
    var result: [DSLValue] = []
    for item in items {
      var innerCtx = context
      innerCtx.bindings[paramName] = item
      result.append(try eval(body, context: innerCtx))
    }
    return .list(result)
  }

  private static func evalRandomElement(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    let listVal = try eval(args[0], context: context)
    guard let items = listVal.asList, !items.isEmpty else { return .nil }
    if let source = context.randomSource {
      let idx = source.next(sides: items.count) - 1
      return items[idx]
    }
    return items.randomElement() ?? .nil
  }

  private static func evalHistoryCount(
    _ args: [SExpr], context: Context
  ) throws -> DSLValue {
    var sinceExpr: SExpr?
    var matchExpr: SExpr?
    for arg in args {
      if arg.tag == "since", let parts = arg.children { sinceExpr = parts[1] }
      if arg.tag == "matching", let parts = arg.children { matchExpr = parts[1] }
    }
    var count = 0
    for action in context.state.history.reversed() {
      if let since = sinceExpr {
        var checkCtx = context
        checkCtx.bindings["a"] = .string(action.name)
        let isBoundary = try eval(since, context: checkCtx)
        if isBoundary.asBool == true { break }
      }
      if let match = matchExpr {
        var checkCtx = context
        checkCtx.bindings["a"] = .string(action.name)
        let isMatch = try eval(match, context: checkCtx)
        if isMatch.asBool == true { count += 1 }
      }
    }
    return .int(count)
  }

  private static func evalFnCall(
    _ tag: String, args: [SExpr], context: Context
  ) throws -> DSLValue {
    let arg = try eval(args[0], context: context)
    let argKey = arg.asEnumValue ?? arg.displayString
    if let result = context.components.lookupFn(tag, argument: argKey) {
      return result
    }
    throw DSLError.undefinedFunction("\(tag)(\(argKey))")
  }
}

// MARK: - Arithmetic & comparison helpers

extension ExpressionEvaluator {

  private static func binaryInt(
    _ args: [SExpr], context: Context, combine: (Int, Int) -> Int
  ) throws -> DSLValue {
    let lhs = try eval(args[0], context: context).asInt ?? 0
    let rhs = try eval(args[1], context: context).asInt ?? 0
    return .int(combine(lhs, rhs))
  }

  private static func binaryNumeric(
    _ args: [SExpr], context: Context,
    intOp: (Int, Int) -> Int, floatOp: (Float, Float) -> Float
  ) throws -> DSLValue {
    let lhs = try eval(args[0], context: context)
    let rhs = try eval(args[1], context: context)
    if case .float = lhs {
      return .float(floatOp(lhs.asFloat ?? 0, rhs.asFloat ?? 0))
    }
    if case .float = rhs {
      return .float(floatOp(lhs.asFloat ?? 0, rhs.asFloat ?? 0))
    }
    return .int(intOp(lhs.asInt ?? 0, rhs.asInt ?? 0))
  }

  private static func comparison(
    _ args: [SExpr], context: Context, compare: (DSLValue, DSLValue) -> Bool
  ) throws -> DSLValue {
    let lhs = try eval(args[0], context: context)
    let rhs = try eval(args[1], context: context)
    return .bool(compare(lhs, rhs))
  }

  private static func intComparison(
    _ args: [SExpr], context: Context, compare: (Int, Int) -> Bool
  ) throws -> DSLValue {
    let lhs = try eval(args[0], context: context).asInt ?? 0
    let rhs = try eval(args[1], context: context).asInt ?? 0
    return .bool(compare(lhs, rhs))
  }
}
