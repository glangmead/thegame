import Foundation

// MARK: - JSONValue

enum JSONValue: Equatable, Sendable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case int(Int)
  case float(Float)
  case bool(Bool)
  case null
}

// MARK: - Convenience accessors

extension JSONValue {

  var objectValue: [String: JSONValue]? {
    guard case .object(let dict) = self else { return nil }
    return dict
  }

  var arrayValue: [JSONValue]? {
    guard case .array(let arr) = self else { return nil }
    return arr
  }

  var stringValue: String? {
    guard case .string(let str) = self else { return nil }
    return str
  }

  var intValue: Int? {
    guard case .int(let val) = self else { return nil }
    return val
  }

  var floatValue: Float? {
    switch self {
    case .float(let val): return val
    case .int(let val): return Float(val)
    default: return nil
    }
  }

  var boolValue: Bool? {
    guard case .bool(let val) = self else { return nil }
    return val
  }

  var isNull: Bool {
    if case .null = self { return true }
    return false
  }

  /// For expressions: is this a single-key object with an array value (i.e., an operator call)?
  /// Returns nil if the value is not an array -- single-key objects with non-array values
  /// (e.g., reduce maps, CRT entries) are NOT operator calls.
  var asCall: (op: String, args: [JSONValue])? {
    guard case .object(let dict) = self, dict.count == 1,
          let (key, value) = dict.first,
          case .array(let args) = value else { return nil }
    return (key, args)
  }
}

// MARK: - JSONC comment stripping

// swiftlint:disable:next cyclomatic_complexity function_body_length
func stripJSONCComments(_ source: String) -> String {
  var result = ""
  result.reserveCapacity(source.count)
  var idx = source.startIndex
  var inString = false

  while idx < source.endIndex {
    let char = source[idx]

    if inString {
      result.append(char)
      if char == "\\" && source.index(after: idx) < source.endIndex {
        idx = source.index(after: idx)
        result.append(source[idx])
      } else if char == "\"" {
        inString = false
      }
      idx = source.index(after: idx)
      continue
    }

    if char == "\"" {
      inString = true
      result.append(char)
      idx = source.index(after: idx)
      continue
    }

    let next = source.index(after: idx)
    if char == "/" && next < source.endIndex {
      let nextChar = source[next]
      if nextChar == "/" {
        // Line comment -- skip to end of line
        idx = source.index(after: next)
        while idx < source.endIndex && source[idx] != "\n" {
          idx = source.index(after: idx)
        }
        result.append(" ")
        continue
      }
      if nextChar == "*" {
        // Block comment -- skip to */
        idx = source.index(after: next)
        while idx < source.endIndex {
          if source[idx] == "*" {
            let afterStar = source.index(after: idx)
            if afterStar < source.endIndex && source[afterStar] == "/" {
              idx = source.index(after: afterStar)
              break
            }
          }
          idx = source.index(after: idx)
        }
        result.append(" ")
        continue
      }
    }

    result.append(char)
    idx = source.index(after: idx)
  }

  return result
}

// MARK: - JSON -> JSONValue conversion

enum JSONValueError: Error {
  case invalidJSON(String)
  case unsupportedType(String)
}

func convertToJSONValue(_ any: Any) throws -> JSONValue {
  switch any {
  case let dict as [String: Any]:
    var result: [String: JSONValue] = [:]
    for (key, val) in dict {
      result[key] = try convertToJSONValue(val)
    }
    return .object(result)
  case let arr as [Any]:
    return .array(try arr.map { try convertToJSONValue($0) })
  case let str as String:
    return .string(str)
  case let num as NSNumber:
    if CFBooleanGetTypeID() == CFGetTypeID(num) {
      return .bool(num.boolValue)
    }
    let typeID = CFNumberGetType(num)
    switch typeID {
    case .sInt8Type, .sInt16Type, .sInt32Type, .sInt64Type,
         .shortType, .intType, .longType, .longLongType,
         .cfIndexType, .nsIntegerType:
      return .int(num.intValue)
    default:
      return .float(num.floatValue)
    }
  case is NSNull:
    return .null
  default:
    throw JSONValueError.unsupportedType("\(type(of: any))")
  }
}
