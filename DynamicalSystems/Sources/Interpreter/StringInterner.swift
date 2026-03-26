/// A compact integer identifier for an interned string.
/// Hashing and equality are integer operations — no string overhead.
struct FieldID: Hashable, Sendable, Comparable {
  let rawValue: Int

  static func < (lhs: FieldID, rhs: FieldID) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

/// Maps strings to unique integer IDs for O(1) hashing and comparison.
/// Populated during game construction; read-only thereafter.
final class StringInterner: @unchecked Sendable {
  private var table: [String: FieldID] = [:]
  private var strings: [String] = []

  /// Intern a string, returning its unique ID.
  /// Idempotent: repeated calls with the same string return the same ID.
  @discardableResult
  func intern(_ string: String) -> FieldID {
    if let existing = table[string] { return existing }
    let fieldID = FieldID(rawValue: strings.count)
    strings.append(string)
    table[string] = fieldID
    return fieldID
  }

  /// Resolve a FieldID back to its string. O(1).
  func resolve(_ fieldID: FieldID) -> String {
    strings[fieldID.rawValue]
  }

  /// Look up the ID for a string without creating one.
  func lookup(_ string: String) -> FieldID? {
    table[string]
  }

  var count: Int { strings.count }
}
