// MARK: - FieldKind

/// The kind of a state field declared in the DSL state section.
enum FieldKind: Equatable, Sendable {
  case counter(min: Int, max: Int)
  case flag
  case field(type: String)
  case dict(keyType: String, valueType: String)
  case set(elementType: String)
  case deck(cardType: String)
  case optional(valueType: String)
}

extension FieldKind {
  var isCounter: Bool { if case .counter = self { return true }; return false }
  var isFlag: Bool { if case .flag = self { return true }; return false }
  var isField: Bool { if case .field = self { return true }; return false }
  var isDict: Bool { if case .dict = self { return true }; return false }
  var isSet: Bool { if case .set = self { return true }; return false }
  var isDeck: Bool { if case .deck = self { return true }; return false }
  var isOptional: Bool { if case .optional = self { return true }; return false }
}

// MARK: - FieldDefinition

/// A single named field inside a `StateSchema`.
struct FieldDefinition: Equatable, Sendable {
  let name: String
  let kind: FieldKind
}

// MARK: - StateSchema

/// Schema for the mutable game state, parsed from a JSONC game definition.
struct StateSchema: Sendable {
  private(set) var fields: [String: FieldDefinition] = [:]

  var allFieldNames: [String] { Array(fields.keys) }

  func field(_ name: String) -> FieldDefinition? {
    fields[name]
  }

  static func empty() -> StateSchema {
    StateSchema(fields: [:])
  }

  init(fields: [String: FieldDefinition]) {
    self.fields = fields
  }
}
