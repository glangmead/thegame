// MARK: - FieldKind

/// The kind of a state field declared in the DSL `(state ...)` form.
enum FieldKind: Equatable, Sendable {
  case counter(min: Int, max: Int)
  case flag
  case field(type: String)
  case dict(keyType: String, valueType: String)
  case set(elementType: String)
  case deck(cardType: String)
  case optional(valueType: String)
}

// MARK: - FieldDefinition

/// A single named field inside a `StateSchema`.
struct FieldDefinition: Equatable, Sendable {
  let name: String
  let kind: FieldKind
}

// MARK: - StateSchema

/// Schema for the mutable game state, parsed from a `(state ...)` S-expression.
struct StateSchema: Sendable {
  private(set) var fields: [String: FieldDefinition] = [:]

  var allFieldNames: [String] { Array(fields.keys) }

  func field(_ name: String) -> FieldDefinition? {
    fields[name]
  }

  static func empty() -> StateSchema {
    // swiftlint:disable:next force_try
    try! StateSchema(SExpr.list([.atom("state")]))
  }

  // swiftlint:disable:next cyclomatic_complexity
  init(_ sexpr: SExpr) throws {
    guard let children = sexpr.children, sexpr.tag == "state" else {
      throw DSLError.expectedForm("state")
    }
    for child in children.dropFirst() {
      guard let tag = child.tag, let parts = child.children else { continue }
      let name = parts.count > 1 ? (parts[1].atomValue ?? "") : ""
      switch tag {
      case "counter":
        let minimum = parts.count > 2 ? (parts[2].intValue ?? 0) : 0
        let hiAtom = parts.count > 3 ? (parts[3].atomValue ?? "0") : "0"
        let maximum = hiAtom == "inf" ? Int.max : (Int(hiAtom) ?? 0)
        fields[name] = FieldDefinition(name: name, kind: .counter(min: minimum, max: maximum))
      case "flag":
        fields[name] = FieldDefinition(name: name, kind: .flag)
      case "field":
        let type = parts.count > 2 ? (parts[2].atomValue ?? "") : ""
        fields[name] = FieldDefinition(name: name, kind: .field(type: type))
      case "dict":
        let keyType = parts.count > 2 ? (parts[2].atomValue ?? "") : ""
        let valueType = parts.count > 3 ? (parts[3].atomValue ?? "") : ""
        fields[name] = FieldDefinition(name: name, kind: .dict(keyType: keyType, valueType: valueType))
      case "set":
        let elementType = parts.count > 2 ? (parts[2].atomValue ?? "") : ""
        fields[name] = FieldDefinition(name: name, kind: .set(elementType: elementType))
      case "deck":
        let cardType = parts.count > 2 ? (parts[2].atomValue ?? "") : ""
        fields[name] = FieldDefinition(name: name, kind: .deck(cardType: cardType))
      case "optional":
        let valueType = parts.count > 2 ? (parts[2].atomValue ?? "") : ""
        fields[name] = FieldDefinition(name: name, kind: .optional(valueType: valueType))
      default:
        throw DSLError.unknownForm(tag)
      }
    }
  }
}
