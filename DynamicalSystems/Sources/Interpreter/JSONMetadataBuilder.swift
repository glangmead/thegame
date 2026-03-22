enum JSONMetadataBuilder {
  static func buildHeuristic(
    _ json: JSONValue,
    components: ComponentRegistry,
    defines: JSONDefineExpander,
    schema: StateSchema,
    graph: SiteGraph
  ) -> ((InterpretedState) -> Float)? {
    guard case .object(let dict) = json,
          case .object(let aiDict) = dict["ai"],
          let heurExpr = aiDict["heuristic"] else { return nil }
    let compiler = JSONExpressionCompiler(
      components: components, schema: schema,
      graph: graph, defines: defines
    )
    let compiled = compiler.expr(heurExpr)
    return { state in
      let env = ExpressionCompiler.Env(state: state)
      return (try? compiled(env))?.asFloat ?? 0.0
    }
  }
}
