/// Runtime representation of a player action.
struct ActionValue: Hashable, Sendable, CustomStringConvertible {
  let name: String
  let parameters: [String: DSLValue]

  var description: String {
    if parameters.isEmpty { return name }
    let params = parameters.map { "\($0.key):\($0.value.displayString)" }
      .joined(separator: ",")
    return "\(name)(\(params))"
  }

  func description(interner: StringInterner) -> String {
    if parameters.isEmpty { return name }
    let params = parameters.map {
      "\($0.key):\($0.value.displayString(interner: interner))"
    }.joined(separator: ",")
    return "\(name)(\(params))"
  }

  init(_ name: String, _ parameters: [String: DSLValue] = [:]) {
    self.name = name
    self.parameters = parameters
  }

  /// Human-readable display name derived from camelCase splitting.
  /// Parameter values are resolved via the `lookup` closure, which
  /// typically maps enum case names to their `displayNames:` value.
  func displayName(
    interner: StringInterner? = nil,
    lookup: (String) -> String? = { _ in nil }
  ) -> String {
    var words = Self.camelCaseWords(name).map { $0.lowercased() }
    for (_, value) in parameters.sorted(by: { $0.key < $1.key }) {
      let raw: String
      if let interner, let fid = value.symbolID {
        raw = interner.resolve(fid)
      } else {
        raw = value.asString ?? value.displayString
      }
      if let display = lookup(raw) {
        words.append(display)
      } else {
        words.append(
          contentsOf: Self.camelCaseWords(raw).map { $0.lowercased() }
        )
      }
    }
    guard !words.isEmpty else { return name }
    words[0] = words[0].prefix(1).uppercased()
      + words[0].dropFirst()
    return words.joined(separator: " ")
  }

  /// Split a camelCase identifier into words.
  /// Splits before uppercase-after-lowercase, uppercase-after-digit,
  /// and digit-after-letter transitions. `"advance30Corps"` becomes
  /// `["advance", "30", "Corps"]`.
  static func camelCaseWords(_ string: String) -> [String] {
    var words: [String] = []
    var current = ""
    for char in string {
      if let prev = current.last {
        let split: Bool
        if char.isUppercase && (prev.isLowercase || prev.isNumber) {
          split = true
        } else if char.isNumber && prev.isLetter {
          split = true
        } else {
          split = false
        }
        if split {
          words.append(current)
          current = String(char)
          continue
        }
      }
      current.append(char)
    }
    if !current.isEmpty { words.append(current) }
    return words
  }
}
