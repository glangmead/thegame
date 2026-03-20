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

  init(_ name: String, _ parameters: [String: DSLValue] = [:]) {
    self.name = name
    self.parameters = parameters
  }
}
