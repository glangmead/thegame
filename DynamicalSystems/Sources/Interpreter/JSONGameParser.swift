import Foundation

enum JSONGameParser {

  static func parse(_ source: String) throws -> JSONValue {
    let stripped = stripJSONCComments(source)
    guard let data = stripped.data(using: .utf8),
          let raw = try? JSONSerialization.jsonObject(
            with: data, options: [.fragmentsAllowed]
          ) else {
      throw JSONValueError.invalidJSON("Failed to parse JSON")
    }
    return try convertToJSONValue(raw)
  }
}
