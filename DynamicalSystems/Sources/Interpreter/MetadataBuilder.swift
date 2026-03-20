enum MetadataBuilder {
  static func buildHeuristic(
    _ sexpr: SExpr,
    components: ComponentRegistry,
    defines: DefineExpander
  ) -> ((InterpretedState) -> Float)? {
    guard let children = sexpr.children, sexpr.tag == "metadata" else { return nil }
    for child in children.dropFirst() {
      guard child.tag == "ai", let aiParts = child.children else { continue }
      for aiChild in aiParts.dropFirst() {
        if aiChild.tag == "heuristic",
           let hParts = aiChild.children, hParts.count > 1 {
          let expanded = try? defines.expand(hParts[1])
          guard let expr = expanded else { continue }
          let capturedComponents = components
          return { state in
            let ctx = ExpressionEvaluator.Context(
              state: state, components: capturedComponents,
              bindings: [:], actionParams: [:], randomSource: nil
            )
            let result = try? ExpressionEvaluator.eval(expr, context: ctx)
            return result?.asFloat ?? 0.0
          }
        }
      }
    }
    return nil
  }
}
