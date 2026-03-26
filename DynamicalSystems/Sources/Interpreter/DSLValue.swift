// MARK: - DSLValue

/// Runtime value type for the S-expression DSL interpreter.
enum DSLValue: Hashable, Sendable {
  case int(Int)
  case float(Float)
  case bool(Bool)
  case string(String)
  /// Interned identifier — integer equality, no heap allocation.
  case symbol(FieldID)
  case list([DSLValue])
  case structValue(type: String, fields: [String: DSLValue])
  case site(track: String, index: Int)
  case `nil`
}

// MARK: - Accessors

extension DSLValue {

  var asInt: Int? {
    switch self {
    case .int(let intVal): return intVal
    case .float(let floatVal): return Int(exactly: floatVal)
    default: return nil
    }
  }

  var asFloat: Float? {
    switch self {
    case .float(let floatVal): return floatVal
    case .int(let intVal): return Float(intVal)
    default: return nil
    }
  }

  var asBool: Bool? {
    guard case .bool(let boolVal) = self else { return nil }
    return boolVal
  }

  var asString: String? {
    guard case .string(let strVal) = self else { return nil }
    return strVal
  }

  /// Extract the interned FieldID from .symbol.
  var symbolID: FieldID? {
    guard case .symbol(let fid) = self else { return nil }
    return fid
  }

  /// Obtain a FieldID, interning on the fly if not already a symbol.
  func toFieldID(_ interner: StringInterner) -> FieldID {
    switch self {
    case .symbol(let fid): return fid
    case .string(let str): return interner.intern(str)
    case .int(let num): return interner.intern(String(num))
    default: return interner.intern(displayString)
    }
  }

  var asList: [DSLValue]? {
    guard case .list(let items) = self else { return nil }
    return items
  }

  var asStruct: (type: String, fields: [String: DSLValue])? {
    guard case .structValue(let typeName, let fields) = self else {
      return nil
    }
    return (type: typeName, fields: fields)
  }

  var asSite: (track: String, index: Int)? {
    guard case .site(let track, let index) = self else { return nil }
    return (track, index)
  }

  var isNil: Bool {
    if case .nil = self { return true }
    return false
  }

  /// Human-readable representation. For .symbol, shows placeholder.
  /// Use displayString(interner:) for resolved text.
  var displayString: String {
    switch self {
    case .int(let intVal): return "\(intVal)"
    case .float(let floatVal): return "\(floatVal)"
    case .bool(let boolVal): return boolVal ? "true" : "false"
    case .string(let strVal): return strVal
    case .symbol(let fid): return "#\(fid.rawValue)"
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

  /// Resolved human-readable representation.
  func displayString(interner: StringInterner) -> String {
    if case .symbol(let fid) = self {
      return interner.resolve(fid)
    }
    return displayString
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
