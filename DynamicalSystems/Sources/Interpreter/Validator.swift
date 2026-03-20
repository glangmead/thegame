enum Validator {

  // MARK: - Public API

  /// Walk all reduce bodies and check field references against the schema.
  static func validate(
    components: ComponentRegistry,
    schema: StateSchema,
    actions: ActionSchema,
    rulesExpr: SExpr
  ) throws {
    guard let children = rulesExpr.children else { return }
    for child in children.dropFirst() {
      guard let tag = child.tag else { continue }
      if tag == "page" || tag == "priority" {
        try validatePage(child, components: components, schema: schema)
      }
    }
  }

  // MARK: - Page validation

  private static func validatePage(
    _ sexpr: SExpr,
    components: ComponentRegistry,
    schema: StateSchema
  ) throws {
    guard let children = sexpr.children else { return }
    for child in children {
      if child.tag == "reduce",
         let parts = child.children,
         parts.count >= 3 {
        try validateExpr(parts[2], components: components, schema: schema)
      }
    }
  }

  // MARK: - Expression validation

  /// Recursively walk an expression tree checking that mutation targets exist.
  private static func validateExpr(
    _ expr: SExpr,
    components: ComponentRegistry,
    schema: StateSchema
  ) throws {
    guard let children = expr.children,
          let tag = children.first?.atomValue else {
      return
    }
    let mutationTargets = [
      "set", "increment", "decrement", "insertInto", "removeFrom",
      "setEntry", "removeEntry"
    ]
    if mutationTargets.contains(tag) {
      let fieldName = children.count > 1
        ? (children[1].atomValue ?? "") : ""
      let builtins: Set<String> = ["ended", "victory", "gameAcknowledged"]
      if schema.field(fieldName) == nil && !builtins.contains(fieldName) {
        throw DSLError.undefinedField(fieldName)
      }
    }
    for child in children {
      try validateExpr(child, components: components, schema: schema)
    }
  }
}
