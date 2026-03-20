struct ActionParameter: Sendable {
  let name: String
  let type: String
  let isOptional: Bool
}

struct ActionDefinition: Sendable {
  let name: String
  let parameters: [ActionParameter]
}

struct DSLActionGroup: Sendable {
  let name: String
  let actionNames: [String]
}

struct ActionSchema: Sendable {
  private(set) var actions: [String: ActionDefinition] = [:]
  private(set) var groups: [DSLActionGroup] = []

  func action(_ name: String) -> ActionDefinition? {
    actions[name]
  }

  static func empty() -> ActionSchema {
    // swiftlint:disable:next force_try
    try! ActionSchema(SExpr.list([.atom("actions")]))
  }

  init(_ sexpr: SExpr) throws {
    guard let children = sexpr.children, sexpr.tag == "actions" else {
      throw DSLError.expectedForm("actions")
    }
    for child in children.dropFirst() {
      guard let tag = child.tag, let parts = child.children else { continue }
      switch tag {
      case "action":
        guard let name = parts[1].atomValue else {
          throw DSLError.malformed("action name must be an atom")
        }
        var params: [ActionParameter] = []
        for paramExpr in parts.dropFirst(2) {
          guard let paramParts = paramExpr.children, paramParts.count >= 2 else { continue }
          let paramName = paramParts[0].atomValue ?? ""
          let paramType = paramParts[1].atomValue ?? ""
          let isOpt = paramType.hasPrefix("(Optional") ||
            (paramParts.count > 1 && paramParts[1].tag == "Optional")
          let resolvedType: String
          if let inner = paramParts[1].children, inner.first?.atomValue == "Optional" {
            resolvedType = inner.count > 1 ? (inner[1].atomValue ?? "") : ""
          } else {
            resolvedType = paramType
          }
          params.append(ActionParameter(
            name: paramName, type: resolvedType, isOptional: isOpt
          ))
        }
        actions[name] = ActionDefinition(name: name, parameters: params)
      case "group":
        let groupName = parts[1].stringValue ?? parts[1].atomValue ?? ""
        let actionNames = parts.count > 2
          ? (parts[2].children?.compactMap(\.atomValue) ?? [])
          : []
        groups.append(DSLActionGroup(name: groupName, actionNames: actionNames))
      default:
        continue
      }
    }
  }
}
