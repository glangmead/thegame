struct ActionParameter: Sendable {
  let name: String
  let type: String
  let isOptional: Bool
  /// For Int-typed params: inclusive range to enumerate.
  let min: Int?
  let max: Int?
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
    ActionSchema(actions: [:], groups: [])
  }

  init(actions: [String: ActionDefinition], groups: [DSLActionGroup]) {
    self.actions = actions
    self.groups = groups
  }
}
