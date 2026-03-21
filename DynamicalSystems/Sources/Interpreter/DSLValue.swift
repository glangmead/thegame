// MARK: - DSLValue

/// Runtime value type for the S-expression DSL interpreter.
enum DSLValue: Hashable, Sendable {
  case int(Int)
  case float(Float)
  case bool(Bool)
  case string(String)
  case enumCase(type: String, value: String)
  case list([DSLValue])
  case structValue(type: String, fields: [String: DSLValue])
  case site(track: String, index: Int)
  case `nil`
}

// MARK: - Accessors

extension DSLValue {

  /// Extract Int. Also converts from float if the value is whole.
  var asInt: Int? {
    switch self {
    case .int(let intVal): return intVal
    case .float(let floatVal): return Int(exactly: floatVal)
    default: return nil
    }
  }

  /// Extract Float. Also converts from int.
  var asFloat: Float? {
    switch self {
    case .float(let floatVal): return floatVal
    case .int(let intVal): return Float(intVal)
    default: return nil
    }
  }

  /// Extract Bool.
  var asBool: Bool? {
    guard case .bool(let boolVal) = self else { return nil }
    return boolVal
  }

  /// Extract String.
  var asString: String? {
    guard case .string(let strVal) = self else { return nil }
    return strVal
  }

  /// Extract enum case value string.
  var asEnumValue: String? {
    guard case .enumCase(_, let caseVal) = self else { return nil }
    return caseVal
  }

  /// Extract enum type name.
  var asEnumType: String? {
    guard case .enumCase(let typeName, _) = self else { return nil }
    return typeName
  }

  /// Extract list.
  var asList: [DSLValue]? {
    guard case .list(let items) = self else { return nil }
    return items
  }

  /// Extract struct type and fields.
  var asStruct: (type: String, fields: [String: DSLValue])? {
    guard case .structValue(let typeName, let fields) = self else { return nil }
    return (type: typeName, fields: fields)
  }

  /// Extract site track and index.
  var asSite: (track: String, index: Int)? {
    guard case .site(let track, let index) = self else { return nil }
    return (track, index)
  }

  /// True only for the `.nil` case.
  var isNil: Bool {
    if case .nil = self { return true }
    return false
  }

  /// Human-readable representation for logging.
  var displayString: String {
    switch self {
    case .int(let intVal): return "\(intVal)"
    case .float(let floatVal): return "\(floatVal)"
    case .bool(let boolVal): return boolVal ? "true" : "false"
    case .string(let strVal): return strVal
    case .enumCase(_, let caseVal): return caseVal
    case .list(let items):
      let inner = items.map(\.displayString).joined(separator: ", ")
      return "[\(inner)]"
    case .structValue(let typeName, let fields):
      let inner = fields.map { "\($0.key): \($0.value.displayString)" }
        .sorted()
        .joined(separator: ", ")
      return "\(typeName){\(inner)}"
    case .site(let track, let index):
      return track.isEmpty ? ":\(index)" : "\(track):\(index)"
    case .nil:
      return "nil"
    }
  }
}

// MARK: - DSLError

/// Shared error type for all phases of the DSL interpreter.
enum DSLError: Error {
  case expectedForm(String)
  case unknownForm(String)
  case malformed(String)
  case typeError(String)
  case undefinedField(String)
  case undefinedEnum(String)
  case undefinedFunction(String)
  case undefinedAction(String)
  case undefinedDefine(String)
  case cyclicDefine(String)
  case validationError(String)
}
