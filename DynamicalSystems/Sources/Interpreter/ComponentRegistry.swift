// MARK: - Component Definitions

struct EnumDefinition: Sendable {
  let name: String
  let cases: [String]
  let associatedTypes: [String: [String]] // case name -> [type names], for sum types
  let displayNames: [String: String] // case name -> human-readable name
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

// MARK: - CRT Definitions

struct CRTEntry: Sendable {
  let low: Int
  let high: Int
  let values: [DSLValue]
}

struct CRTDefinition: Sendable {
  let name: String
  let rowEnumName: String?
  let resultFields: [String]
  let rows: [String: [CRTEntry]]

  func lookup(row: String?, dieRoll: Int) -> [DSLValue]? {
    let key = row ?? ""
    guard let entries = rows[key] else { return nil }
    for entry in entries where dieRoll >= entry.low && dieRoll <= entry.high {
      return entry.values
    }
    return nil
  }
}

// MARK: - ComponentRegistry

struct ComponentRegistry: Sendable {
  private(set) var enums: [String: EnumDefinition] = [:]
  private(set) var structs: [String: StructDefinition] = [:]
  private(set) var functions: [String: EnumFunction] = [:]
  private(set) var cards: [DSLValue] = []
  private(set) var crts: [String: CRTDefinition] = [:]
  private(set) var playerIndex: [String: Int] = [:]

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
      case "crt": try parseCrt(child)
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

  func displayName(forCase caseName: String) -> String? {
    for def in enums.values {
      if let name = def.displayNames[caseName] {
        return name
      }
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

    // Simple enum: (enum Name {case1 case2 ...} [player: N])
    // Must have exactly one list child and no bare non-keyword atoms.
    let listChildren = rest.enumerated().filter { $0.element.children != nil }
    let bareAtoms = rest.enumerated().filter { (offset, element) in
      guard let atom = element.atomValue else { return false }
      if atom.hasSuffix(":") { return false }
      // Skip values that follow a keyword atom (e.g. "0" after "player:")
      if offset > 0,
         let prev = rest[offset - 1].atomValue,
         prev.hasSuffix(":") { return false }
      return true
    }
    if listChildren.count >= 1, bareAtoms.isEmpty,
       let inner = listChildren[0].element.children,
       inner.allSatisfy({ $0.atomValue != nil }) {
      let braceIdx = listChildren[0].offset
      let cases = inner.compactMap(\.atomValue)
      let displayNames = scanDisplayNames(cases: cases, rest: rest)
      enums[name] = EnumDefinition(
        name: name, cases: cases, associatedTypes: [:],
        displayNames: displayNames
      )
      scanPlayerKeyword(name: name, rest: rest, skipIndex: braceIdx)
      return
    }

    // Sum type: (enum Name simple (onTrack Track) ...)
    var cases: [String] = []
    var associated: [String: [String]] = [:]
    var idx = 0
    while idx < rest.count {
      let child = rest[idx]
      // Skip player: keyword and its value
      if child.atomValue == "player:" {
        idx += 2
        continue
      }
      if let caseName = child.atomValue {
        cases.append(caseName)
      } else if let parts = child.children, let caseName = parts.first?.atomValue {
        cases.append(caseName)
        associated[caseName] = parts.dropFirst().compactMap(\.atomValue)
      }
      idx += 1
    }
    let displayNames = scanDisplayNames(cases: cases, rest: rest)
    enums[name] = EnumDefinition(
      name: name, cases: cases, associatedTypes: associated,
      displayNames: displayNames
    )
    scanPlayerKeyword(name: name, rest: rest)
  }

  private mutating func scanPlayerKeyword(
    name: String, rest: [SExpr], skipIndex: Int? = nil
  ) {
    for (idx, child) in rest.enumerated() {
      if idx == skipIndex { continue }
      if child.atomValue == "player:", idx + 1 < rest.count,
         let val = rest[idx + 1].intValue {
        playerIndex[name] = val
        return
      }
    }
  }

  private func scanDisplayNames(
    cases: [String], rest: [SExpr]
  ) -> [String: String] {
    for (idx, child) in rest.enumerated() {
      if child.atomValue == "displayNames:", idx + 1 < rest.count,
         let list = rest[idx + 1].children {
        let names = list.compactMap { $0.stringValue ?? $0.atomValue }
        var result: [String: String] = [:]
        for (idx, caseName) in cases.enumerated() where idx < names.count {
          result[caseName] = names[idx]
        }
        return result
      }
    }
    return [:]
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

  // MARK: CRT

  private mutating func parseCrt(_ sexpr: SExpr) throws {
    guard let children = sexpr.children, children.count >= 3 else {
      throw DSLError.malformed("crt needs name and data")
    }
    guard let name = children[1].atomValue else {
      throw DSLError.malformed("crt name must be an atom")
    }
    let (rowEnumName, resultFields, dataChildren) =
      classifyCrtChildren(Array(children.dropFirst(2)))
    let rows = try buildCrtRows(
      dataChildren, rowEnumName: rowEnumName,
      multiResult: !resultFields.isEmpty
    )
    crts[name] = CRTDefinition(
      name: name, rowEnumName: rowEnumName,
      resultFields: resultFields, rows: rows
    )
  }

  private func classifyCrtChildren(
    _ children: [SExpr]
  ) -> (rowEnum: String?, results: [String], data: [SExpr]) { // swiftlint:disable:this large_tuple
    var rowEnumName: String?
    var resultFields: [String] = []
    var dataChildren: [SExpr] = []
    for child in children {
      switch child.tag {
      case "row":
        if let parts = child.children, parts.count >= 2 {
          rowEnumName = parts[1].atomValue
        }
      case "col":
        continue
      case "results":
        resultFields = child.children?.dropFirst().compactMap(\.atomValue) ?? []
      default:
        dataChildren.append(child)
      }
    }
    return (rowEnumName, resultFields, dataChildren)
  }

  private func buildCrtRows(
    _ dataChildren: [SExpr], rowEnumName: String?, multiResult: Bool
  ) throws -> [String: [CRTEntry]] {
    var rows: [String: [CRTEntry]] = [:]
    if rowEnumName != nil {
      for dataChild in dataChildren {
        guard let parts = dataChild.children,
              let caseName = parts.first?.atomValue,
              parts.count >= 2,
              let columnData = parts[1].children else {
          throw DSLError.malformed("CRT row needs case name and data")
        }
        rows[caseName] = try parseCrtColumns(
          columnData, multiResult: multiResult
        )
      }
    } else if let dataChild = dataChildren.first,
              let columnData = dataChild.children {
      rows[""] = try parseCrtColumns(columnData, multiResult: false)
    }
    return rows
  }

  private func parseCrtColumns(
    _ data: [SExpr], multiResult: Bool
  ) throws -> [CRTEntry] {
    var entries: [CRTEntry] = []
    var idx = 0
    while idx < data.count - 1 {
      let (low, high) = try parseCrtRange(data[idx])
      let valueExpr = data[idx + 1]
      let values: [DSLValue]
      if multiResult, let parts = valueExpr.children {
        values = parts.map(parseLiteralValue)
      } else {
        values = [parseLiteralValue(valueExpr)]
      }
      entries.append(CRTEntry(low: low, high: high, values: values))
      idx += 2
    }
    return entries
  }

  private func parseCrtRange(_ expr: SExpr) throws -> (Int, Int) {
    guard let atom = expr.atomValue else {
      throw DSLError.malformed("CRT range must be an atom")
    }
    if let single = Int(atom) { return (single, single) }
    let parts = atom.split(separator: "-")
    guard parts.count == 2,
          let low = Int(parts[0]),
          let high = Int(parts[1]) else {
      throw DSLError.malformed("Invalid CRT range: \(atom)")
    }
    return (low, high)
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
      if let enumType = isEnumCase(str) {
        return .enumCase(type: enumType, value: str)
      }
      return .string(str)
    }
    if let children = sexpr.children {
      return .list(children.map(parseLiteralValue))
    }
    return .nil
  }
}
