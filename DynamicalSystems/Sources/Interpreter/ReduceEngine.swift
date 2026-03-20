import Foundation

struct ReduceResult {
  var logs: [Log]
  var followUps: [ActionValue]
}

struct ReduceEngine {
  let components: ComponentRegistry
  let defines: DefineExpander
  var randomSource: ExpressionEvaluator.RandomSource?

  func execute(
    _ expr: SExpr,
    state: InterpretedState,
    actionParams: [String: DSLValue],
    bindings: [String: DSLValue] = [:]
  ) throws -> ReduceResult {
    let ctx = ExpressionEvaluator.Context(
      state: state, components: components,
      bindings: bindings, actionParams: actionParams,
      randomSource: randomSource
    )
    return try exec(expr, state: state, context: ctx)
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func exec(
    _ expr: SExpr,
    state: InterpretedState,
    context: ExpressionEvaluator.Context
  ) throws -> ReduceResult {
    let expanded = try defines.expand(expr)

    guard let children = expanded.children,
          let tag = children.first?.atomValue else {
      throw DSLError.malformed("reduce expression must be a list")
    }
    let args = Array(children.dropFirst())

    switch tag {
    // MARK: - Mutations

    case "set":
      let fieldName = args[0].atomValue ?? ""
      let value = try ExpressionEvaluator.eval(args[1], context: context)
      applySet(state: state, field: fieldName, value: value)
      return ReduceResult(logs: [], followUps: [])

    case "increment":
      let fieldName = args[0].atomValue ?? ""
      let amount = try ExpressionEvaluator.eval(args[1], context: context).asInt ?? 1
      state.incrementCounter(fieldName, by: amount)
      return ReduceResult(logs: [], followUps: [])

    case "decrement":
      let fieldName = args[0].atomValue ?? ""
      let amount = try ExpressionEvaluator.eval(args[1], context: context).asInt ?? 1
      state.decrementCounter(fieldName, by: amount)
      return ReduceResult(logs: [], followUps: [])

    case "insertInto":
      let setName = args[0].atomValue ?? ""
      let element = try ExpressionEvaluator.eval(args[1], context: context)
      state.insertIntoSet(setName, element.asEnumValue ?? element.displayString)
      return ReduceResult(logs: [], followUps: [])

    case "removeFrom":
      let setName = args[0].atomValue ?? ""
      let element = try ExpressionEvaluator.eval(args[1], context: context)
      state.removeFromSet(setName, element.asEnumValue ?? element.displayString)
      return ReduceResult(logs: [], followUps: [])

    case "setEntry":
      let dictName = args[0].atomValue ?? ""
      let key = try ExpressionEvaluator.eval(args[1], context: context)
      let value = try ExpressionEvaluator.eval(args[2], context: context)
      state.setDictEntry(dictName, key: key.asEnumValue ?? key.displayString, value: value)
      return ReduceResult(logs: [], followUps: [])

    case "removeEntry":
      let dictName = args[0].atomValue ?? ""
      let key = try ExpressionEvaluator.eval(args[1], context: context)
      state.removeDictEntry(dictName, key: key.asEnumValue ?? key.displayString)
      return ReduceResult(logs: [], followUps: [])

    case "draw":
      let deckName = parseKeywordArg(args, keyword: "from:")
      let optName = parseKeywordArg(args, keyword: "to:")
      if let card = state.drawFromDeck(deckName) {
        state.setOptional(optName, card)
      }
      return ReduceResult(logs: [], followUps: [])

    case "shuffle":
      let deckName = args[0].atomValue ?? ""
      state.shuffleDeck(deckName)
      return ReduceResult(logs: [], followUps: [])

    case "discard":
      let optName = parseKeywordArg(args, keyword: "from:")
      let deckName = parseKeywordArg(args, keyword: "to:")
      let card = state.getOptional(optName)
      if !card.isNil {
        state.appendToDeck(deckName, card)
        state.setOptional(optName, .nil)
      }
      return ReduceResult(logs: [], followUps: [])

    case "appendTo":
      let listName = args[0].atomValue ?? ""
      let element = try ExpressionEvaluator.eval(args[1], context: context)
      state.appendToDeck(listName, element)
      return ReduceResult(logs: [], followUps: [])

    case "removeAt":
      let listName = args[0].atomValue ?? ""
      let index = try ExpressionEvaluator.eval(args[1], context: context).asInt ?? 0
      state.removeDeckItem(listName, at: index)
      return ReduceResult(logs: [], followUps: [])

    case "clearList":
      let listName = args[0].atomValue ?? ""
      state.clearDeck(listName)
      return ReduceResult(logs: [], followUps: [])

    case "setPhase":
      let phase = try ExpressionEvaluator.eval(args[0], context: context)
      state.phase = phase.asEnumValue ?? phase.displayString
      return ReduceResult(logs: [], followUps: [])

    case "endGame":
      let outcome = args[0].atomValue ?? ""
      state.ended = true
      state.victory = outcome == "victory"
      return ReduceResult(logs: [], followUps: [])

    // MARK: - Control Flow

    case "seq":
      var logs: [Log] = []
      var followUps: [ActionValue] = []
      var seqContext = context
      for arg in args {
        do {
          // Handle (let name value) without body inside seq
          if let letChildren = arg.children,
             letChildren.first?.atomValue == "let",
             letChildren.count == 3 {
            let letName = letChildren[1].atomValue ?? ""
            let letVal = try ExpressionEvaluator.eval(letChildren[2], context: seqContext)
            seqContext.bindings[letName] = letVal
            continue
          }
          let result = try exec(arg, state: state, context: seqContext)
          logs.append(contentsOf: result.logs)
          followUps.append(contentsOf: result.followUps)
        } catch is GuardAbort {
          break
        }
      }
      return ReduceResult(logs: logs, followUps: followUps)

    case "if":
      let cond = try ExpressionEvaluator.eval(args[0], context: context)
      if cond.asBool == true {
        return try exec(args[1], state: state, context: context)
      } else if args.count >= 3 {
        return try exec(args[2], state: state, context: context)
      }
      return ReduceResult(logs: [], followUps: [])

    case "guard":
      let cond = try ExpressionEvaluator.eval(args[0], context: context)
      if cond.asBool != true {
        throw GuardAbort()
      }
      return ReduceResult(logs: [], followUps: [])

    case "chain":
      let actionName = args[0].atomValue ?? ""
      var params: [String: DSLValue] = [:]
      for arg in args.dropFirst() {
        if let parts = arg.children, parts.count >= 2 {
          let key = parts[0].atomValue ?? ""
          let value = try ExpressionEvaluator.eval(parts[1], context: context)
          params[key] = value
        }
      }
      return ReduceResult(logs: [], followUps: [ActionValue(actionName, params)])

    case "log":
      let message = try ExpressionEvaluator.eval(args[0], context: context)
      return ReduceResult(logs: [Log(msg: message.displayString)], followUps: [])

    case "let":
      guard args.count >= 3 else {
        throw DSLError.malformed("let needs name, value, body")
      }
      let name = args[0].atomValue ?? ""
      let value = try ExpressionEvaluator.eval(args[1], context: context)
      var innerContext = context
      innerContext.bindings[name] = value
      return try exec(args[2], state: state, context: innerContext)

    case "forEach":
      let collection = try ExpressionEvaluator.eval(args[0], context: context)
      guard let items = collection.asList else {
        throw DSLError.typeError("forEach requires a list")
      }
      guard let lambdaChildren = args[1].children,
            lambdaChildren.first?.atomValue == "\\" else {
        throw DSLError.malformed("forEach needs a lambda")
      }
      let paramName = lambdaChildren[1].children?.first?.atomValue ?? ""
      let body = lambdaChildren[2]
      var logs: [Log] = []
      var followUps: [ActionValue] = []
      for item in items {
        var innerContext = context
        innerContext.bindings[paramName] = item
        let result = try exec(body, state: state, context: innerContext)
        logs.append(contentsOf: result.logs)
        followUps.append(contentsOf: result.followUps)
      }
      return ReduceResult(logs: logs, followUps: followUps)

    default:
      throw DSLError.unknownForm(tag)
    }
  }

  private func applySet(state: InterpretedState, field: String, value: DSLValue) {
    guard let def = state.schema.field(field) else { return }
    switch def.kind {
    case .counter:
      state.setCounter(field, value.asInt ?? 0)
    case .flag:
      state.setFlag(field, value.asBool ?? false)
    case .field:
      state.setField(field, value)
    case .optional:
      state.setOptional(field, value.isNil ? nil : value)
    default:
      break
    }
  }

  private func parseKeywordArg(_ args: [SExpr], keyword: String) -> String {
    for (idx, arg) in args.enumerated() {
      if arg.atomValue == keyword && idx + 1 < args.count {
        return args[idx + 1].atomValue ?? ""
      }
    }
    return ""
  }
}

/// Thrown by (guard) to abort a (seq) branch.
struct GuardAbort: Error {}
