enum GameBuilder {

  // MARK: - Public API

  static func build(
    fromJSONC source: String
  ) throws -> ComposedGame<InterpretedState> {
    let json = try JSONGameParser.parse(source)
    return try assembleGameFromJSON(json)
  }

  // MARK: - Assembly

  // swiftlint:disable:next function_body_length
  private static func assembleGameFromJSON(
    _ json: JSONValue
  ) throws -> ComposedGame<InterpretedState> {
    guard case .object(let root) = json else {
      throw DSLError.expectedForm("root object")
    }
    let gameName = root["game"]?.stringValue ?? "Untitled"
    var components = try root["components"].map {
      try JSONComponentRegistry.build($0)
    } ?? ComponentRegistry.empty()
    let schema = try root["state"].map {
      try JSONStateSchema.build($0)
    } ?? StateSchema.empty()
    let actions = try root["actions"].map {
      try JSONActionSchema.build($0)
    } ?? ActionSchema.empty()
    let defines = try JSONDefineExpander(root["defines"] ?? .array([]))
    let graph = try root["graph"].map {
      try JSONGraphBuilder.build($0)
    } ?? SiteGraph()

    let interner = StringInterner()
    for name in schema.allFieldNames { interner.intern(name) }
    for def in components.enums.values {
      for caseName in def.cases { interner.intern(caseName) }
    }
    interner.intern("ended")
    interner.intern("victory")
    interner.intern("gameAcknowledged")
    interner.intern("phase")

    components.populateFIDMappings(interner)

    let compiler = JSONExpressionCompiler(
      components: components, schema: schema,
      graph: graph, defines: defines,
      interner: interner
    )
    let rulesResult = try root["rules"].map {
      try JSONPageBuilder.buildRules(
        $0, components: components, schema: schema,
        actionSchema: actions, defines: defines,
        graph: graph, compiler: compiler
      )
    }

    let capturedPhaseMap = rulesResult?.phaseMap ?? [:]
    let capturedPhases = rulesResult?.phases ?? []

    // Terminal check
    let terminalCheck: (InterpretedState) -> Bool
    if let rulesJSON = root["rules"]?.objectValue,
       let termField = rulesJSON["terminal"]?.stringValue {
      let compiled = compiler.expr(.string(termField))
      terminalCheck = { state in
        let env = ExpressionCompiler.Env(state: state)
        return (try? compiled(env))?.asBool ?? false
      }
    } else {
      terminalCheck = { $0.gameAcknowledged }
    }

    let rolloutCheck: ((InterpretedState) -> Bool)? = {
      guard let rulesJSON = root["rules"]?.objectValue,
            let rolloutField = rulesJSON["rolloutTerminal"]?.stringValue
      else { return nil }
      let compiled = compiler.expr(.string(rolloutField))
      return { state in
        let env = ExpressionCompiler.Env(state: state)
        return (try? compiled(env))?.asBool ?? false
      }
    }()

    var game = ComposedGame(
      gameName: gameName,
      pages: rulesResult?.pages ?? [],
      priorities: rulesResult?.priorities ?? [],
      makeInitialState: {
        var state = InterpretedState(schema: schema, interner: interner)
        if let first = capturedPhases.first {
          state.phase = first
        }
        // Populate decks from card definitions
        for card in components.cards {
          if let deckName = card.asStruct?.fields["deck"]?.displayString {
            state.appendToDeck(deckName, card)
          }
        }
        return state
      },
      terminalCheck: terminalCheck,
      rolloutTerminalCheck: rolloutCheck,
      phaseForAction: { action in capturedPhaseMap[action.name] },
      autoRules: rulesResult?.reactions ?? []
    )
    game.graph = graph

    // Scene style
    if let sceneJSON = root["scene"],
       case .object(let sceneDict) = sceneJSON {
      var config = StyleConfig()
      config.stroke = sceneDict["stroke"]?.stringValue
      config.lineWidth = sceneDict["lineWidth"]?.intValue
        .map { Float($0) }
      config.fill = sceneDict["fill"]?.stringValue
      game.sceneStyle = config
    }

    game.playerIndex = components.playerIndex
    var pieceNames: [String: String] = [:]
    for def in components.enums.values {
      for (caseName, displayName) in def.displayNames {
        pieceNames[caseName] = displayName
      }
    }
    game.pieceDisplayNames = pieceNames
    game.stateEvaluator = root["metadata"].flatMap {
      JSONMetadataBuilder.buildHeuristic(
        $0, components: components, defines: defines,
        schema: schema, graph: graph, interner: interner
      )
    }
    return game
  }
}
