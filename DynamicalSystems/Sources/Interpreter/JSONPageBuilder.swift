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
    let typedCondition: JSONExpressionCompiler.BoolCondition?
    let compiledCondition: JSONExpressionCompiler.Expr?
    if let whenExpr = dict["when"] {
      typedCondition = compiler.tryCompileCondition(whenExpr)
      compiledCondition = typedCondition == nil
        ? compiler.expr(whenExpr) : nil
    } else {
      typedCondition = nil
      compiledCondition = nil
    }
    let lookup = displayLookup(components)
    let precomputedActions: [ActionValue] =
      (dict["offer"]?.arrayValue ?? []).flatMap { offerItem -> [ActionValue] in
        let name = offerItem.stringValue ?? ""
        guard let def = actionSchema.action(name),
              !def.parameters.isEmpty else {
          return [withDisplay(
            ActionValue(name),
            interner: compiler.interner, lookup: lookup
          )]
        }
        return expandParameters(
          actionName: name, params: def.parameters,
          components: components, interner: compiler.interner
        )
      }

    // Optional per-combo filter for parameterized actions.
    // Evaluated at runtime with action params bound so $param references work.
    let compiledParamFilter: JSONExpressionCompiler.Expr? =
      dict["paramFilter"].map { compiler.expr($0) }

    return GameRule(
      condition: { state in
        if let typed = typedCondition { return typed(state) }
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

  /// Build a display-name lookup from all enum displayNames in the registry.
  private static func displayLookup(
    _ components: ComponentRegistry
  ) -> (String) -> String? {
    var map: [String: String] = [:]
    for def in components.enums.values {
      for (caseName, display) in def.displayNames {
        map[caseName] = display
      }
    }
    return { map[$0] }
  }

  /// Set the display name on an ActionValue using the interner and components.
  private static func withDisplay(
    _ action: ActionValue,
    interner: StringInterner,
    lookup: @escaping (String) -> String?
  ) -> ActionValue {
    var result = action
    result.display = action.displayName(
      interner: interner, lookup: lookup
    )
    return result
  }

  /// Expand a parameterized action into all combinations of enum/int values.
  private static func expandParameters(
    actionName: String,
    params: [ActionParameter],
    components: ComponentRegistry,
    interner: StringInterner
  ) -> [ActionValue] {
    // Build list of (paramName, [(caseName, DSLValue)]) for each param
    var paramOptions: [(String, [(String, DSLValue)])] = []
    for param in params {
      if let cases = components.enumCases(param.type) {
        let options = cases.map { caseName in
          (caseName, DSLValue.symbol(interner.intern(caseName)))
        }
        paramOptions.append((param.name, options))
      } else if param.type == "Int",
                let rangeMin = param.min, let rangeMax = param.max {
        let options = (rangeMin...rangeMax).map { value in
          (String(value), DSLValue.int(value))
        }
        paramOptions.append((param.name, options))
      } else {
        // Unknown type without range — cannot expand
        var fallback = ActionValue(actionName)
        fallback.display = fallback.displayName()
        return [fallback]
      }
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
    let lookup = displayLookup(components)
    return combos.map {
      withDisplay(
        ActionValue(actionName, $0),
        interner: interner, lookup: lookup
      )
    }
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
  ) throws -> ForEachPage<InterpretedState, FieldID> {
    guard case .object(let dict) = json else {
      throw DSLError.malformed("forEachPage must be an object")
    }
    let name = dict["forEachPage"]?.stringValue ?? ""
    let transitionName = dict["transition"]?.stringValue ?? ""
    var transition = ActionValue(transitionName)
    transition.display = transition.displayName()

    let typedFECondition: JSONExpressionCompiler.BoolCondition?
    let compiledCondition: JSONExpressionCompiler.Expr?
    if let whenExpr = dict["when"] {
      typedFECondition = compiler.tryCompileCondition(whenExpr)
      compiledCondition = typedFECondition == nil
        ? compiler.expr(whenExpr) : nil
    } else {
      typedFECondition = nil
      compiledCondition = nil
    }
    let compiledItems: JSONExpressionCompiler.Expr? = dict["items"].map {
      compiler.expr($0)
    }
    let compiledReducers = try compileReduceMap(
      dict["reduce"], compiler: compiler
    )
    let capturedActionSchema = actionSchema
    let feLookup = displayLookup(components)
    let feInterner = compiler.interner

    return ForEachPage(
      name: name,
      isActive: { state in
        if let typed = typedFECondition { return typed(state) }
        guard let check = compiledCondition else { return true }
        let env = ExpressionCompiler.Env(state: state)
        return (try? check(env))?.asBool ?? false
      },
      items: { state in
        guard let check = compiledItems else { return [] }
        let env = ExpressionCompiler.Env(state: state)
        let result = try? check(env)
        return result?.asList?.compactMap(\.symbolID) ?? []
      },
      actionsFor: { _, item in
        compiledReducers.keys.map { actionName in
          let paramName = capturedActionSchema.action(actionName)?
            .parameters.first?.name ?? "item"
          return withDisplay(
            ActionValue(actionName, [paramName: .symbol(item)]),
            interner: feInterner, lookup: feLookup
          )
        }
      },
      itemFrom: { action in
        guard compiledReducers.keys.contains(action.name) else {
          return nil
        }
        let val = action.parameters.values.first
        return val?.symbolID
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
    let typedReactionCond: JSONExpressionCompiler.BoolCondition?
    let compiledCondition: JSONExpressionCompiler.Expr?
    if let whenExpr = dict["when"] {
      typedReactionCond = compiler.tryCompileCondition(whenExpr)
      compiledCondition = typedReactionCond == nil
        ? compiler.expr(whenExpr) : nil
    } else {
      typedReactionCond = nil
      compiledCondition = nil
    }
    let compiledApply: JSONExpressionCompiler.Stmt? = dict["apply"].map {
      compiler.stmt($0)
    }

    return AutoRule(
      name: name,
      when: { state in
        if let typed = typedReactionCond { return typed(state) }
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
