// swiftlint:disable:next type_body_length
enum JSONPageBuilder {

  // MARK: - Public entry point

  // swiftlint:disable:next function_parameter_count
  static func buildRules(
    _ json: JSONValue,
    components: ComponentRegistry,
    schema: StateSchema,
    actionSchema: ActionSchema,
    defines: JSONDefineExpander,
    graph: SiteGraph,
    compiler: JSONExpressionCompiler
  ) throws -> PageBuilder.RulesResult {
    guard case .object(let root) = json else {
      throw DSLError.expectedForm("rules object")
    }
    var result = PageBuilder.RulesResult()

    // Phases: derive from the Phase enum declaration order
    if let phases = components.enumCases("Phase") {
      result.phases = phases
    }

    // Pages
    if let pagesArray = root["pages"]?.arrayValue {
      for pageJSON in pagesArray {
        guard case .object(let pageDict) = pageJSON else { continue }
        if pageDict["forEachPage"] != nil {
          let forEachPage = try buildForEachPage(
            pageJSON, actionSchema: actionSchema,
            components: components, compiler: compiler
          )
          result.pages.append(forEachPage.asRulePage())
        } else {
          let page = try buildPage(
            pageJSON, compiler: compiler,
            actionSchema: actionSchema,
            components: components
          )
          result.pages.append(page)
        }
      }
    }

    // Priorities
    if let prioritiesArray = root["priorities"]?.arrayValue {
      for prioJSON in prioritiesArray {
        let page = try buildPriority(
          prioJSON, compiler: compiler,
          actionSchema: actionSchema,
          components: components
        )
        result.priorities.append(page)
      }
    }

    // Reactions
    if let reactionsArray = root["reactions"]?.arrayValue {
      for reactionJSON in reactionsArray {
        let rule = try buildReaction(reactionJSON, compiler: compiler)
        result.reactions.append(rule)
      }
    }

    // Phase map: for each reduce action in each page, map action -> phase
    result.phaseMap = buildPhaseMap(root, components: components)

    return result
  }

  // MARK: - Page building

  private static func buildPage(
    _ json: JSONValue,
    compiler: JSONExpressionCompiler,
    actionSchema: ActionSchema,
    components: ComponentRegistry
  ) throws -> RulePage<InterpretedState, ActionValue> {
    guard case .object(let dict) = json else {
      throw DSLError.malformed("page must be an object")
    }
    let name = dict["page"]?.stringValue ?? ""
    let rules = try buildRuleArray(
      dict["rules"], compiler: compiler,
      actionSchema: actionSchema,
      components: components
    )
    let compiledReducers = try compileReduceMap(
      dict["reduce"], compiler: compiler
    )
    return RulePage(
      name: name,
      rules: rules,
      reduce: makeReducer(compiledReducers)
    )
  }

  private static func buildPriority(
    _ json: JSONValue,
    compiler: JSONExpressionCompiler,
    actionSchema: ActionSchema,
    components: ComponentRegistry
  ) throws -> RulePage<InterpretedState, ActionValue> {
    guard case .object(let dict) = json else {
      throw DSLError.malformed("priority must be an object")
    }
    let name = dict["priority"]?.stringValue ?? ""
    let rules = try buildRuleArray(
      dict["rules"], compiler: compiler,
      actionSchema: actionSchema,
      components: components
    )
    let compiledReducers = try compileReduceMap(
      dict["reduce"], compiler: compiler
    )
    return RulePage(
      name: name,
      rules: rules,
      reduce: makeReducer(compiledReducers)
    )
  }

  // MARK: - Rule building

  private static func buildRuleArray(
    _ json: JSONValue?,
    compiler: JSONExpressionCompiler,
    actionSchema: ActionSchema,
    components: ComponentRegistry
  ) throws -> [GameRule<InterpretedState, ActionValue>] {
    guard let arr = json?.arrayValue else { return [] }
    return try arr.map {
      try buildRule(
        $0, compiler: compiler,
        actionSchema: actionSchema, components: components
      )
    }
  }

  private static func buildRule(
    _ json: JSONValue,
    compiler: JSONExpressionCompiler,
    actionSchema: ActionSchema,
    components: ComponentRegistry
  ) throws -> GameRule<InterpretedState, ActionValue> {
    guard case .object(let dict) = json else {
      throw DSLError.malformed("rule must be an object")
    }
    let compiledCondition: JSONExpressionCompiler.Expr? = dict["when"].map {
      compiler.expr($0)
    }
    let precomputedActions: [ActionValue] =
      (dict["offer"]?.arrayValue ?? []).flatMap { offerItem -> [ActionValue] in
        let name = offerItem.stringValue ?? ""
        guard let def = actionSchema.action(name),
              !def.parameters.isEmpty else {
          return [ActionValue(name)]
        }
        return expandParameters(
          actionName: name, params: def.parameters,
          components: components
        )
      }

    // Optional per-combo filter for parameterized actions.
    // Evaluated at runtime with action params bound so $param references work.
    let compiledParamFilter: JSONExpressionCompiler.Expr? =
      dict["paramFilter"].map { compiler.expr($0) }

    return GameRule(
      condition: { state in
        guard let check = compiledCondition else { return true }
        let env = ExpressionCompiler.Env(state: state)
        return (try? check(env))?.asBool ?? false
      },
      actions: { state in
        guard let filter = compiledParamFilter else {
          return precomputedActions
        }
        return precomputedActions.filter { action in
          let env = ExpressionCompiler.Env(
            state: state, actionParams: action.parameters
          )
          return (try? filter(env))?.asBool ?? false
        }
      }
    )
  }

  /// Expand a parameterized action into all combinations of enum cases.
  private static func expandParameters(
    actionName: String,
    params: [ActionParameter],
    components: ComponentRegistry
  ) -> [ActionValue] {
    // Build list of (paramName, [(caseName, DSLValue)]) for each param
    var paramOptions: [(String, [(String, DSLValue)])] = []
    for param in params {
      guard let cases = components.enumCases(param.type) else {
        // Not an enum type — cannot expand; fall back to unexpanded
        return [ActionValue(actionName)]
      }
      let options = cases.map { caseName in
        (caseName, DSLValue.enumCase(type: param.type, value: caseName))
      }
      paramOptions.append((param.name, options))
    }
    // Compute cartesian product
    var combos: [[String: DSLValue]] = [[:]]
    for (paramName, options) in paramOptions {
      var next: [[String: DSLValue]] = []
      for combo in combos {
        for (_, value) in options {
          var updated = combo
          updated[paramName] = value
          next.append(updated)
        }
      }
      combos = next
    }
    return combos.map { ActionValue(actionName, $0) }
  }

  // MARK: - Reduce map compilation

  private static func compileReduceMap(
    _ json: JSONValue?,
    compiler: JSONExpressionCompiler
  ) throws -> [String: JSONExpressionCompiler.Stmt] {
    guard case .object(let dict) = json else { return [:] }
    var result: [String: JSONExpressionCompiler.Stmt] = [:]
    for (actionName, body) in dict {
      result[actionName] = compiler.stmt(body)
    }
    return result
  }

  private static func makeReducer(
    _ compiledReducers: [String: JSONExpressionCompiler.Stmt]
  ) -> (inout InterpretedState, ActionValue) -> ([Log], [ActionValue])? {
    { state, action in
      guard let body = compiledReducers[action.name] else { return nil }
      do {
        let env = ExpressionCompiler.Env(
          state: state, actionParams: action.parameters
        )
        let result = try body(env)
        state = env.state
        return (result.logs, result.followUps)
      } catch {
        return nil
      }
    }
  }

  // MARK: - ForEachPage building

  // swiftlint:disable:next function_body_length
  private static func buildForEachPage(
    _ json: JSONValue,
    actionSchema: ActionSchema,
    components: ComponentRegistry,
    compiler: JSONExpressionCompiler
  ) throws -> ForEachPage<InterpretedState, String> {
    guard case .object(let dict) = json else {
      throw DSLError.malformed("forEachPage must be an object")
    }
    let name = dict["forEachPage"]?.stringValue ?? ""
    let transitionName = dict["transition"]?.stringValue ?? ""
    let transition = ActionValue(transitionName)

    let compiledCondition: JSONExpressionCompiler.Expr? = dict["when"].map {
      compiler.expr($0)
    }
    let compiledItems: JSONExpressionCompiler.Expr? = dict["items"].map {
      compiler.expr($0)
    }
    let compiledReducers = try compileReduceMap(
      dict["reduce"], compiler: compiler
    )
    let capturedActionSchema = actionSchema
    let capturedComponents = components

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
        compiledReducers.keys.map { actionName in
          let paramName = capturedActionSchema.action(actionName)?
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
        guard compiledReducers.keys.contains(action.name) else {
          return nil
        }
        let val = action.parameters.values.first
        return val?.asEnumValue ?? val?.asString
      },
      transitionAction: transition,
      isPhaseEntry: { action in
        action.name == transitionName
      },
      reduce: { state, action in
        guard let body = compiledReducers[action.name] else {
          return nil
        }
        do {
          let env = ExpressionCompiler.Env(
            state: state, actionParams: action.parameters
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

  // MARK: - Reaction building

  private static func buildReaction(
    _ json: JSONValue,
    compiler: JSONExpressionCompiler
  ) throws -> AutoRule<InterpretedState> {
    guard case .object(let dict) = json else {
      throw DSLError.malformed("reaction must be an object")
    }
    let name = dict["name"]?.stringValue ?? ""
    let compiledCondition: JSONExpressionCompiler.Expr? = dict["when"].map {
      compiler.expr($0)
    }
    let compiledApply: JSONExpressionCompiler.Stmt? = dict["apply"].map {
      compiler.stmt($0)
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
        let env = ExpressionCompiler.Env(state: state)
        let logs = (try? body(env))?.logs ?? []
        state = env.state
        return logs
      }
    )
  }

  // MARK: - Phase map derivation

  private static func buildPhaseMap(
    _ root: [String: JSONValue],
    components: ComponentRegistry
  ) -> [String: String] {
    let phases = components.enumCases("Phase") ?? []
    guard !phases.isEmpty else { return [:] }
    var phaseMap: [String: String] = [:]

    // Scan pages: each page's reduce actions map to the phase
    // whose "when" condition checks for that phase.
    if let pagesArray = root["pages"]?.arrayValue {
      for pageJSON in pagesArray {
        guard case .object(let pageDict) = pageJSON else { continue }
        let inferredPhase = inferPhase(
          from: pageDict, phases: phases
        )
        if let phase = inferredPhase,
           let reduceDict = pageDict["reduce"]?.objectValue {
          for actionName in reduceDict.keys {
            phaseMap[actionName] = phase
          }
        }
        // Also map transition actions for forEachPages
        if let transition = pageDict["transition"]?.stringValue,
           let phase = inferredPhase {
          phaseMap[transition] = phase
        }
      }
    }

    return phaseMap
  }

  /// Infer which phase a page operates in by scanning its "when" conditions
  /// and rules for phase comparisons like {"==": ["phase", ".play"]}.
  private static func inferPhase(
    from pageDict: [String: JSONValue],
    phases: [String]
  ) -> String? {
    // Check top-level "when" (forEachPage)
    if let topWhen = pageDict["when"] {
      if let phase = extractPhaseFromCondition(topWhen, phases: phases) {
        return phase
      }
    }
    // Check rules array
    if let rulesArr = pageDict["rules"]?.arrayValue {
      for ruleJSON in rulesArr {
        guard case .object(let ruleDict) = ruleJSON,
              let whenExpr = ruleDict["when"] else { continue }
        if let phase = extractPhaseFromCondition(
          whenExpr, phases: phases
        ) {
          return phase
        }
      }
    }
    return nil
  }

  /// Extract a phase name from a condition like {"==": ["phase", ".play"]}.
  private static func extractPhaseFromCondition(
    _ json: JSONValue,
    phases: [String]
  ) -> String? {
    guard let (oper, args) = json.asCall else { return nil }
    if oper == "==" && args.count == 2 {
      if args[0].stringValue == "phase",
         let dotCase = args[1].stringValue,
         dotCase.hasPrefix(".") {
        let caseName = String(dotCase.dropFirst())
        if phases.contains(caseName) { return caseName }
      }
    }
    // Recurse into "and"
    if oper == "and" {
      for arg in args {
        if let phase = extractPhaseFromCondition(arg, phases: phases) {
          return phase
        }
      }
    }
    return nil
  }
}
