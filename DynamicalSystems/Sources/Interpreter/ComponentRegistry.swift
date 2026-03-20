// MARK: - Component Definitions

struct EnumDefinition: Sendable {
  let name: String
  let cases: [String]
  let associatedTypes: [String: [String]] // case name -> [type names], for sum types
}

struct StructDefinition: Sendable {
  let name: String
  let fields: [(name: String, type: String)]
}

struct EnumFunction: Sendable {
  let name: String
  let domain: String
  let mapping: [String: DSLValue] // case name -> value
}

// MARK: - ComponentRegistry

struct ComponentRegistry: Sendable {
  private(set) var enums: [String: EnumDefinition] = [:]
  private(set) var structs: [String: StructDefinition] = [:]
  private(set) var functions: [String: EnumFunction] = [:]
  private(set) var cards: [DSLValue] = []

  init(_ sexpr: SExpr) throws {
    guard let children = sexpr.children, sexpr.tag == "components" else {
      throw DSLError.expectedForm("components")
    }
    for child in children.dropFirst() {
      guard let tag = child.tag else { continue }
      switch tag {
      case "enum": try parseEnum(child)
      case "struct": try parseStruct(child)
      case "fn": try parseFn(child)
      case "cards": try parseCards(child)
      default: throw DSLError.unknownForm(tag)
      }
    }
  }

  static func empty() -> ComponentRegistry {
    // swiftlint:disable:next force_try
    try! ComponentRegistry(SExpr.list([.atom("components")]))
  }

  // MARK: - Queries

  func enumCases(_ name: String) -> [String]? {
    enums[name]?.cases
  }

  func lookupFn(_ name: String, argument: String) -> DSLValue? {
    functions[name]?.mapping[argument]
  }

  func isEnumCase(_ value: String) -> String? {
    for (name, def) in enums where def.cases.contains(value) {
      return name
    }
    return nil
  }
}

// MARK: - Parsing

extension ComponentRegistry {

  // MARK: Enum

  private mutating func parseEnum(_ sexpr: SExpr) throws {
    guard let children = sexpr.children, children.count >= 3 else {
      throw DSLError.malformed("enum needs name and cases")
    }
    guard let name = children[1].atomValue else {
      throw DSLError.malformed("enum name must be an atom")
    }
    let rest = Array(children.dropFirst(2))

    // Simple enum: (enum Name {case1 case2 ...})
    // A single list child whose elements are all atoms -> brace-enclosed cases.
    if rest.count == 1,
       let inner = rest[0].children,
       inner.allSatisfy({ $0.atomValue != nil }) {
      let cases = inner.compactMap(\.atomValue)
      enums[name] = EnumDefinition(
        name: name, cases: cases, associatedTypes: [:]
      )
      return
    }

    // Sum type: (enum Name simple (onTrack Track) ...)
    var cases: [String] = []
    var associated: [String: [String]] = [:]
    for child in rest {
      if let caseName = child.atomValue {
        cases.append(caseName)
      } else if let parts = child.children, let caseName = parts.first?.atomValue {
        cases.append(caseName)
        associated[caseName] = parts.dropFirst().compactMap(\.atomValue)
      }
    }
    enums[name] = EnumDefinition(
      name: name, cases: cases, associatedTypes: associated
    )
  }

  // MARK: Struct

  private mutating func parseStruct(_ sexpr: SExpr) throws {
    guard let children = sexpr.children, children.count >= 2 else {
      throw DSLError.malformed("struct needs name and fields")
    }
    guard let name = children[1].atomValue else {
      throw DSLError.malformed("struct name must be an atom")
    }
    var fields: [(name: String, type: String)] = []
    for child in children.dropFirst(2) {
      guard child.tag == "field",
            let parts = child.children, parts.count >= 3 else { continue }
      let fieldName = parts[1].atomValue ?? ""
      let fieldType = parts[2].atomValue ?? ""
      fields.append((name: fieldName, type: fieldType))
    }
    structs[name] = StructDefinition(name: name, fields: fields)
  }

  // MARK: Function

  private mutating func parseFn(_ sexpr: SExpr) throws {
    guard let children = sexpr.children, children.count == 4 else {
      throw DSLError.malformed("fn needs name, domain, and mapping")
    }
    guard let name = children[1].atomValue else {
      throw DSLError.malformed("fn name must be an atom")
    }
    guard let domain = children[2].atomValue else {
      throw DSLError.malformed("fn domain must be an atom")
    }
    guard let mappingList = children[3].children else {
      throw DSLError.malformed("fn mapping must be a list")
    }
    var mapping: [String: DSLValue] = [:]
    var idx = 0
    while idx < mappingList.count - 1 {
      let caseName = mappingList[idx].atomValue ?? ""
      let value = parseLiteralValue(mappingList[idx + 1])
      mapping[caseName] = value
      idx += 2
    }
    functions[name] = EnumFunction(name: name, domain: domain, mapping: mapping)
  }

  // MARK: Cards

  private mutating func parseCards(_ sexpr: SExpr) throws {
    guard let children = sexpr.children else {
      throw DSLError.malformed("cards must be a list")
    }
    for child in children.dropFirst() {
      guard child.tag == "card", let parts = child.children else { continue }
      var fields: [String: DSLValue] = [:]
      if parts.count > 1 { fields["number"] = parseLiteralValue(parts[1]) }
      if parts.count > 2 { fields["title"] = parseLiteralValue(parts[2]) }
      if parts.count > 3 { fields["deck"] = parseLiteralValue(parts[3]) }
      var idx = 4
      while idx < parts.count {
        let item = parts[idx].atomValue ?? ""
        if item.hasSuffix(":") && idx + 1 < parts.count {
          let fieldName = String(item.dropLast())
          fields[fieldName] = parseLiteralValue(parts[idx + 1])
          idx += 2
        } else {
          idx += 1
        }
      }
      cards.append(.structValue(type: "Card", fields: fields))
    }
  }

  // MARK: Literal values

  private func parseLiteralValue(_ sexpr: SExpr) -> DSLValue {
    if let str = sexpr.atomValue {
      if let num = Int(str) { return .int(num) }
      if str == "true" { return .bool(true) }
      if str == "false" { return .bool(false) }
      if str == "nil" { return .nil }
      if str.hasPrefix("\"") && str.hasSuffix("\"") && str.count >= 2 {
        return .string(String(str.dropFirst().dropLast()))
      }
      return .string(str)
    }
    if let children = sexpr.children {
      return .list(children.map(parseLiteralValue))
    }
    return .nil
  }
}
