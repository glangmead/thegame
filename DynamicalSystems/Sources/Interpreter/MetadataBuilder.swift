enum MetadataBuilder {
  static func buildHeuristic(
    _ sexpr: SExpr,
    components: ComponentRegistry,
    defines: DefineExpander,
    schema: StateSchema
  ) -> ((InterpretedState) -> Float)? {
    guard let children = sexpr.children, sexpr.tag == "metadata" else { return nil }
    let compiler = ExpressionCompiler(
      components: components, schema: schema
    )
    for child in children.dropFirst() {
      guard child.tag == "ai", let aiParts = child.children else { continue }
      for aiChild in aiParts.dropFirst() {
        if aiChild.tag == "heuristic",
           let hParts = aiChild.children, hParts.count > 1 {
          let expanded = try? defines.expand(hParts[1])
          guard let hExpr = expanded else { continue }
          let compiled = compiler.expr(hExpr)
          return { state in
            let env = ExpressionCompiler.Env(state: state)
            return (try? compiled(env))?.asFloat ?? 0.0
          }
        }
      }
    }
    return nil
  }
}
