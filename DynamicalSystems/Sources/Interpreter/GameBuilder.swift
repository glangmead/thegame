enum GameBuilder {

  // MARK: - Extracted sections from the (game ...) form

  private struct GameSections {
    let gameName: String
    var componentsExpr: SExpr?
    var stateExpr: SExpr?
    var actionsExpr: SExpr?
    var rulesExpr: SExpr?
    var metadataExpr: SExpr?
  }

  // MARK: - Public API

  static func build(from source: String) throws -> ComposedGame<InterpretedState> {
    let forms = try SExprParser.parseMultiple(source)
    let (sections, defineExprs) = try extractSections(forms)
    return try assembleGame(sections, defineExprs: defineExprs)
  }

  /// Build with static validation: checks field references before assembly.
  static func buildValidated(
    from source: String
  ) throws -> ComposedGame<InterpretedState> {
    let forms = try SExprParser.parseMultiple(source)
    let (sections, defineExprs) = try extractSections(forms)

    let components = try sections.componentsExpr.map { try ComponentRegistry($0) }
      ?? ComponentRegistry.empty()
    let schema = try sections.stateExpr.map { try StateSchema($0) }
      ?? StateSchema.empty()
    let actions = try sections.actionsExpr.map { try ActionSchema($0) }
      ?? ActionSchema.empty()

    if let rulesExpr = sections.rulesExpr {
      try Validator.validate(
        components: components, schema: schema,
        actions: actions, rulesExpr: rulesExpr
      )
    }

    return try assembleGame(sections, defineExprs: defineExprs)
  }

  // MARK: - Top-level form classification

  private static func classifyForms(
    _ forms: [SExpr]
  ) -> (gameForm: SExpr?, defines: [SExpr], metadataForm: SExpr?) { // swiftlint:disable:this large_tuple
    var gameForm: SExpr?
    var defineExprs: [SExpr] = []
    var metadataForm: SExpr?
    for form in forms {
      switch form.tag {
      case "game": gameForm = form
      case "define": defineExprs.append(form)
      case "metadata": metadataForm = form
      default: continue
      }
    }
    return (gameForm, defineExprs, metadataForm)
  }

  // MARK: - Section extraction

  private static func extractSections(
    _ forms: [SExpr]
  ) throws -> (GameSections, [SExpr]) {
    let (gameForm, defineExprs, metadataForm) = classifyForms(forms)

    guard let game = gameForm, let children = game.children else {
      throw DSLError.expectedForm("game")
    }

    let name = children[1].stringValue
      ?? children[1].atomValue ?? "Untitled"
    var sections = GameSections(gameName: name)
    sections.metadataExpr = metadataForm

    for child in children.dropFirst(2) {
      switch child.tag {
      case "components": sections.componentsExpr = child
      case "state": sections.stateExpr = child
      case "actions": sections.actionsExpr = child
      case "rules": sections.rulesExpr = child
      default: continue
      }
    }

    return (sections, defineExprs)
  }

  // MARK: - Game assembly

  private static func assembleGame(
    _ sections: GameSections,
    defineExprs: [SExpr]
  ) throws -> ComposedGame<InterpretedState> {
    let components = try sections.componentsExpr.map { try ComponentRegistry($0) }
      ?? ComponentRegistry.empty()
    let schema = try sections.stateExpr.map { try StateSchema($0) }
      ?? StateSchema.empty()
    _ = try sections.actionsExpr.map { try ActionSchema($0) }
      ?? ActionSchema.empty()
    let defines = try DefineExpander(defineExprs)
    let engine = ReduceEngine(components: components, defines: defines)

    let buildContext = PageBuilder.BuildContext(
      components: components, schema: schema, engine: engine
    )
    let rulesResult = try sections.rulesExpr.map {
      try PageBuilder.buildRules($0, context: buildContext)
    }

    let capturedPhaseMap = rulesResult?.phaseMap ?? [:]
    let capturedTerminalExpr = rulesResult?.terminalExpr
    let capturedRolloutExpr = rulesResult?.rolloutTerminalExpr
    let capturedPhases = rulesResult?.phases ?? []

    var game = ComposedGame(
      gameName: sections.gameName,
      pages: rulesResult?.pages ?? [],
      priorities: rulesResult?.priorities ?? [],
      makeInitialState: {
        let state = InterpretedState(schema: schema)
        if let first = capturedPhases.first {
          state.phase = first
        }
        return state
      },
      terminalCheck: makeTerminalCheck(
        capturedTerminalExpr, components: components
      ),
      rolloutTerminalCheck: capturedRolloutExpr.map {
        makeExprCheck($0, components: components)
      },
      phaseForAction: { action in capturedPhaseMap[action.name] },
      autoRules: rulesResult?.reactions ?? []
    )
    game.stateEvaluator = sections.metadataExpr.flatMap {
      MetadataBuilder.buildHeuristic($0, components: components)
    }
    return game
  }

  // MARK: - Terminal check helpers

  private static func makeTerminalCheck(
    _ expr: SExpr?,
    components: ComponentRegistry
  ) -> (InterpretedState) -> Bool {
    guard let expr else {
      return { state in state.gameAcknowledged }
    }
    return makeExprCheck(expr, components: components)
  }

  private static func makeExprCheck(
    _ expr: SExpr,
    components: ComponentRegistry
  ) -> (InterpretedState) -> Bool {
    { state in
      let ctx = ExpressionEvaluator.Context(
        state: state, components: components,
        bindings: [:], actionParams: [:], randomSource: nil
      )
      return (try? ExpressionEvaluator.eval(expr, context: ctx))?.asBool ?? false
    }
  }
}
