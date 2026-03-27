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
  /// FieldID-keyed mapping for O(1) integer-hashed lookup at runtime.
  let fidMapping: [FieldID: DSLValue]
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

  static func empty() -> ComponentRegistry {
    ComponentRegistry(
      enums: [:], structs: [:], functions: [:],
      cards: [], crts: [:], playerIndex: [:]
    )
  }

  init(
    enums: [String: EnumDefinition],
    structs: [String: StructDefinition],
    functions: [String: EnumFunction],
    cards: [DSLValue],
    crts: [String: CRTDefinition],
    playerIndex: [String: Int]
  ) {
    self.enums = enums
    self.structs = structs
    self.functions = functions
    self.cards = cards
    self.crts = crts
    self.playerIndex = playerIndex
  }

  /// Populate FieldID-keyed function mappings after interner is ready.
  mutating func populateFIDMappings(_ interner: StringInterner) {
    for (name, enumFn) in functions {
      var fidMap = [FieldID: DSLValue](
        minimumCapacity: enumFn.mapping.count
      )
      for (key, value) in enumFn.mapping {
        fidMap[interner.intern(key)] = value
      }
      functions[name] = EnumFunction(
        name: enumFn.name, domain: enumFn.domain,
        mapping: enumFn.mapping, fidMapping: fidMap
      )
    }
  }

  // MARK: - Queries

  func enumCases(_ name: String) -> [String]? {
    enums[name]?.cases
  }

  func crt(_ name: String) -> CRTDefinition? {
    crts[name]
  }

  func lookupFn(_ name: String, argument: String) -> DSLValue? {
    functions[name]?.mapping[argument]
  }

  func lookupFn(_ name: String, argumentFID: FieldID) -> DSLValue? {
    functions[name]?.fidMapping[argumentFID]
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
