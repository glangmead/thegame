// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
enum PageBuilder {
  struct BuildContext {
    let components: ComponentRegistry
    let schema: StateSchema
    let randomSource: RandomSource?
    let actionSchema: ActionSchema
    let defines: DefineExpander
    let graph: SiteGraph
  }

  struct RulesResult {
    var pages: [RulePage<InterpretedState, ActionValue>] = []
    var priorities: [RulePage<InterpretedState, ActionValue>] = []
    var reactions: [AutoRule<InterpretedState>] = []
    var phases: [String] = []
    var phaseMap: [String: String] = [:]
    var terminalExpr: SExpr?
    var rolloutTerminalExpr: SExpr?
    var redeterminize: [String] = []
  }

  // Build a simple RulePage from `(page ...)` or `(priority ...)` form.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  static func buildPage(
    _ sexpr: SExpr,
    context: BuildContext
  ) throws -> RulePage<InterpretedState, ActionValue> {
    guard let children = sexpr.children else {
      throw DSLError.malformed("page must be a list")
    }
    let name = children[1].stringValue ?? children[1].atomValue ?? ""
    var rules: [GameRule<InterpretedState, ActionValue>] = []
    var reducers: [String: SExpr] = [:]

    for child in children.dropFirst(2) {
      guard let tag = child.tag else { continue }
      switch tag {
      case "rule":
        let rule = try buildRule(child, context: context)
        rules.append(rule)
      case "reduce":
        guard let parts = child.children, parts.count >= 3 else {
          throw DSLError.malformed("reduce needs action name and body")
        }
        let actionName = parts[1].atomValue ?? ""
        if parts.count > 3 {
          reducers[actionName] = .list([.atom("seq")] + Array(parts.dropFirst(2)))
        } else {
          reducers[actionName] = parts[2]
        }
      default:
        continue
      }
    }

    let compiler = ExpressionCompiler(
      components: context.components, schema: context.schema, graph: context.graph
    )
    let randomSource = context.randomSource
    var compiledReducers: [String: ExpressionCompiler.Stmt] = [:]
    for (key, value) in reducers {
      let expanded = try context.defines.expand(value)
      compiledReducers[key] = compiler.stmt(expanded)
    }
    let capturedReducers = compiledReducers
    return RulePage(
      name: name,
      rules: rules,
      reduce: { state, action in
        guard let body = capturedReducers[action.name] else { return nil }
        do {
          let env = ExpressionCompiler.Env(
            state: state, actionParams: action.parameters,
            randomSource: randomSource
          )
          let result = try body(env)
          state = env.state
          return (result.logs, result.followUps)
        } catch {
          return nil
        }
      }
    )
  }

  // Build a GameRule from `(rule (when cond) (offer action1 action2 ...))`.
  // swiftlint:disable:next cyclomatic_complexity
  static func buildRule(
    _ sexpr: SExpr,
    context: BuildContext
  ) throws -> GameRule<InterpretedState, ActionValue> {
    guard let children = sexpr.children else {
      throw DSLError.malformed("rule must be a list")
    }
    var conditionExpr: SExpr?
    var offerExprs: [SExpr] = []

    for child in children.dropFirst() {
      guard let tag = child.tag, let parts = child.children else { continue }
      switch tag {
      case "when":
        conditionExpr = parts.count > 1 ? parts[1] : nil
      case "offer":
        offerExprs = Array(parts.dropFirst())
      default:
        continue
      }
    }

    let compiler = ExpressionCompiler(
      components: context.components, schema: context.schema, graph: context.graph
    )
    let compiledCondition: ExpressionCompiler.Expr? = try conditionExpr.map {
      compiler.expr(try context.defines.expand($0))
    }
    let precomputedActions: [ActionValue] = offerExprs.map { offerExpr in
      if let name = offerExpr.atomValue {
        return ActionValue(name)
      }
      if let parts = offerExpr.children, let name = parts.first?.atomValue {
        var params: [String: DSLValue] = [:]
        for paramExpr in parts.dropFirst() {
          if let pair = paramExpr.children, pair.count >= 2 {
            params[pair[0].atomValue ?? ""] = .string(pair[1].atomValue ?? "")
          }
        }
        return ActionValue(name, params)
      }
      return ActionValue(offerExpr.atomValue ?? "")
    }
    return GameRule(
      condition: { state in
        guard let check = compiledCondition else { return true }
        let env = ExpressionCompiler.Env(state: state)
        return (try? check(env))?.asBool ?? false
      },
      actions: { _ in precomputedActions }
    )
  }

  // Build an AutoRule from `(reaction ...)` form.
  static func buildReaction(
    _ sexpr: SExpr,
    context: BuildContext
  ) throws -> AutoRule<InterpretedState> {
    guard let children = sexpr.children, children.count >= 3 else {
      throw DSLError.malformed("reaction needs name, when, apply")
    }
    let name = children[1].stringValue ?? children[1].atomValue ?? ""
    var conditionExpr: SExpr?
    var applyExpr: SExpr?

    for child in children.dropFirst(2) {
      guard let tag = child.tag, let parts = child.children else { continue }
      switch tag {
      case "when": conditionExpr = parts.count > 1 ? parts[1] : nil
      case "apply": applyExpr = parts.count > 1 ? parts[1] : nil
      default: continue
      }
    }

    let compiler = ExpressionCompiler(
      components: context.components, schema: context.schema, graph: context.graph
    )
    let randomSource = context.randomSource
    let compiledCondition: ExpressionCompiler.Expr? = try conditionExpr.map {
      compiler.expr(try context.defines.expand($0))
    }
    let compiledApply: ExpressionCompiler.Stmt? = try applyExpr.map {
      compiler.stmt(try context.defines.expand($0))
    }

    return AutoRule(
      name: name,
      when: { state in
        guard let check = compiledCondition else { return false }
        let env = ExpressionCompiler.Env(state: state)
        return (try? check(env))?.asBool ?? false
      },
      apply: { state in
        guard let body = compiledApply else { return [] }
        let env = ExpressionCompiler.Env(
          state: state, randomSource: randomSource
        )
        let logs = (try? body(env))?.logs ?? []
        state = env.state
        return logs
      }
    )
  }

  // Build a ForEachPage from `(forEachPage ...)` form.
  // swiftlint:disable:next function_body_length cyclomatic_complexity
  static func buildForEachPage(
    _ sexpr: SExpr,
    context: BuildContext
  ) throws -> ForEachPage<InterpretedState, String> {
    guard let children = sexpr.children else {
      throw DSLError.malformed("forEachPage must be a list")
    }
    let name = children[1].stringValue ?? children[1].atomValue ?? ""
    var conditionExpr: SExpr?
    var itemsExpr: SExpr?
    var transitionName = ""
    var reducers: [String: SExpr] = [:]

    for child in children.dropFirst(2) {
      guard let tag = child.tag, let parts = child.children else { continue }
      switch tag {
      case "when": conditionExpr = parts.count > 1 ? parts[1] : nil
      case "items": itemsExpr = parts.count > 1 ? parts[1] : nil
      case "transition":
        transitionName = parts.count > 1 ? (parts[1].atomValue ?? "") : ""
      case "reduce":
        let actionName = parts.count > 1 ? (parts[1].atomValue ?? "") : ""
        if parts.count > 3 {
          reducers[actionName] = .list([.atom("seq")] + Array(parts.dropFirst(2)))
        } else if parts.count > 2 {
          reducers[actionName] = parts[2]
        }
      default: continue
      }
    }

    let compiler = ExpressionCompiler(
      components: context.components, schema: context.schema, graph: context.graph
    )
    let randomSource = context.randomSource
    let actionSchema = context.actionSchema
    let capturedComponents = context.components
    let compiledCondition: ExpressionCompiler.Expr? = try conditionExpr.map {
      compiler.expr(try context.defines.expand($0))
    }
    let compiledItems: ExpressionCompiler.Expr? = try itemsExpr.map {
      compiler.expr(try context.defines.expand($0))
    }
    var compiledReducers: [String: ExpressionCompiler.Stmt] = [:]
    for (key, value) in reducers {
      let expanded = try context.defines.expand(value)
      compiledReducers[key] = compiler.stmt(expanded)
    }
    let capturedReducers = compiledReducers
    let transition = ActionValue(transitionName)

    return ForEachPage(
      name: name,
      isActive: { state in
        guard let check = compiledCondition else { return true }
        let env = ExpressionCompiler.Env(state: state)
        return (try? check(env))?.asBool ?? false
      },
      items: { state in
        guard let check = compiledItems else { return [] }
        let env = ExpressionCompiler.Env(state: state)
        let result = try? check(env)
        return result?.asList?.compactMap(\.displayString) ?? []
      },
      actionsFor: { _, item in
        capturedReducers.keys.map { actionName in
          let paramName = actionSchema.action(actionName)?
            .parameters.first?.name ?? "item"
          let value: DSLValue
          if let enumType = capturedComponents.isEnumCase(item) {
            value = .enumCase(type: enumType, value: item)
          } else {
            value = .string(item)
          }
          return ActionValue(actionName, [paramName: value])
        }
      },
      itemFrom: { action in
        guard capturedReducers.keys.contains(action.name) else { return nil }
        let val = action.parameters.values.first
        return val?.asEnumValue ?? val?.asString
      },
      transitionAction: transition,
      isPhaseEntry: { action in
        action.name == transitionName
      },
      reduce: { state, action in
        guard let body = capturedReducers[action.name] else { return nil }
        do {
          let env = ExpressionCompiler.Env(
            state: state, actionParams: action.parameters,
            randomSource: randomSource
          )
          let result = try body(env)
          state = env.state
          return (result.logs, result.followUps)
        } catch {
          return nil
        }
      }
    )
  }

  // Build a BudgetedPhasePage from `(budgetedPage ...)` form.
  // swiftlint:disable:next function_body_length cyclomatic_complexity
  static func buildBudgetedPage(
    _ sexpr: SExpr,
    context: BuildContext
  ) throws -> BudgetedPhasePage<InterpretedState, String> {
    guard let children = sexpr.children else {
      throw DSLError.malformed("budgetedPage must be a list")
    }
    let name = children[1].stringValue ?? children[1].atomValue ?? ""
    var conditionExpr: SExpr?
    var itemsExpr: SExpr?
    var transitionName = ""
    var passName: String?
    var reducers: [String: SExpr] = [:]

    for child in children.dropFirst(2) {
      guard let tag = child.tag, let parts = child.children else { continue }
      switch tag {
      case "when": conditionExpr = parts.count > 1 ? parts[1] : nil
      case "items": itemsExpr = parts.count > 1 ? parts[1] : nil
      case "pass": passName = parts.count > 1 ? parts[1].atomValue : nil
      case "transition":
        transitionName = parts.count > 1 ? (parts[1].atomValue ?? "") : ""
      case "reduce":
        let actionName = parts.count > 1 ? (parts[1].atomValue ?? "") : ""
        if parts.count > 3 {
          reducers[actionName] = .list([.atom("seq")] + Array(parts.dropFirst(2)))
        } else if parts.count > 2 {
          reducers[actionName] = parts[2]
        }
      default: continue
      }
    }

    let compiler = ExpressionCompiler(
      components: context.components, schema: context.schema, graph: context.graph
    )
    let randomSource = context.randomSource
    let actionSchema = context.actionSchema
    let capturedComponents = context.components
    let compiledCondition: ExpressionCompiler.Expr? = try conditionExpr.map {
      compiler.expr(try context.defines.expand($0))
    }
    let compiledItems: ExpressionCompiler.Expr? = try itemsExpr.map {
      compiler.expr(try context.defines.expand($0))
    }
    var compiledReducers: [String: ExpressionCompiler.Stmt] = [:]
    for (key, value) in reducers {
      let expanded = try context.defines.expand(value)
      compiledReducers[key] = compiler.stmt(expanded)
    }
    let capturedReducers = compiledReducers
    let transition = ActionValue(transitionName)
    let pass = passName.map { ActionValue($0) }
    let budget: Budget = .atMost(99)

    return BudgetedPhasePage(
      name: name,
      budget: budget,
      isActive: { state in
        guard let check = compiledCondition else { return true }
        let env = ExpressionCompiler.Env(state: state)
        return (try? check(env))?.asBool ?? false
      },
      items: { state in
        guard let check = compiledItems else { return [] }
        let env = ExpressionCompiler.Env(state: state)
        let result = try? check(env)
        return result?.asList?.compactMap(\.displayString) ?? []
      },
      actionsFor: { _, item in
        capturedReducers.keys.map { actionName in
          let paramName = actionSchema.action(actionName)?
            .parameters.first?.name ?? "item"
          let value: DSLValue
          if let enumType = capturedComponents.isEnumCase(item) {
            value = .enumCase(type: enumType, value: item)
          } else {
            value = .string(item)
          }
          return ActionValue(actionName, [paramName: value])
        }
      },
      itemFrom: { action in
        guard capturedReducers.keys.contains(action.name) else { return nil }
        let val = action.parameters.values.first
        return val?.asEnumValue ?? val?.asString
      },
      transitionAction: transition,
      passAction: pass,
      isPhaseEntry: { action in
        action.name == transitionName
      },
      reduce: { state, action in
        guard let body = capturedReducers[action.name] else { return nil }
        do {
          let env = ExpressionCompiler.Env(
            state: state, actionParams: action.parameters,
            randomSource: randomSource
          )
          let result = try body(env)
          state = env.state
          return (result.logs, result.followUps)
        } catch {
          return nil
        }
      }
    )
  }

  // Parse the full `(rules ...)` section.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  static func buildRules(
    _ sexpr: SExpr,
    context: BuildContext
  ) throws -> RulesResult {
    guard let children = sexpr.children, sexpr.tag == "rules" else {
      throw DSLError.expectedForm("rules")
    }
    var result = RulesResult()

    for child in children.dropFirst() {
      guard let tag = child.tag else { continue }
      switch tag {
      case "phases":
        if let parts = child.children, parts.count > 1,
           let phaseList = parts[1].children {
          result.phases = phaseList.compactMap(\.atomValue)
        }
      case "page":
        result.pages.append(try buildPage(child, context: context))
      case "priority":
        result.priorities.append(try buildPage(child, context: context))
      case "reaction":
        result.reactions.append(try buildReaction(child, context: context))
      case "phaseMap":
        if let parts = child.children {
          for entry in parts.dropFirst() {
            if let entryParts = entry.children, entryParts.count >= 3 {
              let actionName = entryParts[0].atomValue ?? ""
              let phase = entryParts[2].atomValue ?? ""
              result.phaseMap[actionName] = phase
            }
          }
        }
      case "terminal":
        if let parts = child.children, parts.count > 1 {
          result.terminalExpr = try context.defines.expand(parts[1])
        }
      case "rolloutTerminal":
        if let parts = child.children, parts.count > 1 {
          result.rolloutTerminalExpr = try context.defines.expand(parts[1])
        }
      case "redeterminize":
        if let parts = child.children {
          for part in parts.dropFirst() {
            if let shuffle = part.children, shuffle.first?.atomValue == "shuffle" {
              result.redeterminize.append(shuffle[1].atomValue ?? "")
            }
          }
        }
      case "forEachPage":
        let forEachPage = try buildForEachPage(child, context: context)
        result.pages.append(forEachPage.asRulePage())
      case "budgetedPage":
        let budgetedPage = try buildBudgetedPage(child, context: context)
        result.pages.append(budgetedPage.asRulePage())
      default:
        continue
      }
    }

    return result
  }
}
