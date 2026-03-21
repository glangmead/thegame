struct InterpretedState: Sendable {
  let schema: StateSchema
  private(set) var counters: [String: Int] = [:]
  private(set) var flags: [String: Bool] = [:]
  private(set) var fields: [String: DSLValue] = [:]
  private(set) var dicts: [String: [String: DSLValue]] = [:]
  private(set) var sets: [String: Set<String>] = [:]
  private(set) var decks: [String: [DSLValue]] = [:]
  private(set) var optionals: [String: DSLValue?] = [:]
  private(set) var positions: [String: DSLValue] = [:]
  private(set) var pieceTypes: [String: String] = [:]
  var history: [ActionValue] = []
  var phase: String = ""

  // Framework fields
  var ended: Bool = false
  var victory: Bool = false
  var gameAcknowledged: Bool = false

  // Centralized framework field access.
  // Add new framework flags/fields here only.

  private func getFrameworkFlag(_ name: String) -> Bool? {
    switch name {
    case "ended": return ended
    case "victory": return victory
    case "gameAcknowledged": return gameAcknowledged
    default: return nil
    }
  }

  @discardableResult
  private mutating func setFrameworkFlag(_ name: String, _ value: Bool) -> Bool {
    switch name {
    case "ended": ended = value; return true
    case "victory": victory = value; return true
    case "gameAcknowledged": gameAcknowledged = value; return true
    default: return false
    }
  }

  private func getFrameworkField(_ name: String) -> DSLValue? {
    switch name {
    case "phase": return .enumCase(type: "Phase", value: phase)
    default: return nil
    }
  }

  @discardableResult
  private mutating func setFrameworkField(_ name: String, _ value: DSLValue) -> Bool {
    switch name {
    case "phase":
      phase = value.asEnumValue ?? value.displayString
      return true
    default: return false
    }
  }

  init(schema: StateSchema) {
    self.schema = schema
    for (name, field) in schema.fields {
      switch field.kind {
      case .counter(let min, _):
        counters[name] = min
      case .flag:
        flags[name] = false
      case .field:
        fields[name] = .nil
      case .dict:
        dicts[name] = [:]
      case .set:
        sets[name] = []
      case .deck:
        decks[name] = []
      case .optional:
        optionals[name] = .some(.nil)
      }
    }
  }

  // MARK: - Getters

  func getCounter(_ name: String) -> Int {
    counters[name] ?? 0
  }

  func getFlag(_ name: String) -> Bool {
    if let fwk = getFrameworkFlag(name) { return fwk }
    return flags[name] ?? false
  }

  func getField(_ name: String) -> DSLValue {
    if let fwk = getFrameworkField(name) { return fwk }
    return fields[name] ?? .nil
  }

  func getDict(_ name: String) -> [String: DSLValue] {
    dicts[name] ?? [:]
  }

  func getSet(_ name: String) -> Set<String> {
    sets[name] ?? []
  }

  func getDeck(_ name: String) -> [DSLValue] {
    decks[name] ?? []
  }

  func getOptional(_ name: String) -> DSLValue {
    if let value = optionals[name] { return value ?? .nil }
    return .nil
  }

  /// Generic get: looks across all field types.
  /// Framework fields (ended, victory, gameAcknowledged, phase) are checked
  /// before the schema dicts so that direct property mutations stay visible.
  func get(_ name: String) -> DSLValue {
    if let fwk = getFrameworkFlag(name) { return .bool(fwk) }
    if let fwk = getFrameworkField(name) { return fwk }
    if let value = counters[name] { return .int(value) }
    if let value = flags[name] { return .bool(value) }
    if let value = fields[name] { return value }
    if let value = optionals[name] { return value ?? .nil }
    return .nil
  }

  // MARK: - Mutators

  mutating func setCounter(_ name: String, _ value: Int) {
    guard let field = schema.field(name),
          case .counter(let min, let max) = field.kind else { return }
    counters[name] = Swift.min(Swift.max(value, min), max)
  }

  mutating func incrementCounter(_ name: String, by amount: Int) {
    let current = counters[name] ?? 0
    setCounter(name, current + amount)
  }

  mutating func decrementCounter(_ name: String, by amount: Int) {
    let current = counters[name] ?? 0
    setCounter(name, current - amount)
  }

  mutating func setFlag(_ name: String, _ value: Bool) {
    if setFrameworkFlag(name, value) { return }
    flags[name] = value
  }

  mutating func setField(_ name: String, _ value: DSLValue) {
    if setFrameworkField(name, value) { return }
    fields[name] = value
  }

  mutating func setDictEntry(_ dictName: String, key: String, value: DSLValue) {
    dicts[dictName, default: [:]][key] = value
  }

  mutating func removeDictEntry(_ dictName: String, key: String) {
    dicts[dictName]?.removeValue(forKey: key)
  }

  mutating func insertIntoSet(_ name: String, _ element: String) {
    sets[name, default: []].insert(element)
  }

  mutating func removeFromSet(_ name: String, _ element: String) {
    sets[name]?.remove(element)
  }

  mutating func setOptional(_ name: String, _ value: DSLValue?) {
    optionals[name] = value
  }

  // Deck operations
  mutating func drawFromDeck(_ deckName: String) -> DSLValue? {
    guard var deck = decks[deckName], !deck.isEmpty else { return nil }
    let card = deck.removeFirst()
    decks[deckName] = deck
    return card
  }

  mutating func shuffleDeck(_ deckName: String) {
    decks[deckName]?.shuffle()
  }

  mutating func appendToDeck(_ deckName: String, _ card: DSLValue) {
    decks[deckName, default: []].append(card)
  }

  mutating func removeDeckItem(_ deckName: String, at index: Int) {
    guard var deck = decks[deckName], index >= 0, index < deck.count else { return }
    deck.remove(at: index)
    decks[deckName] = deck
  }

  mutating func clearDeck(_ deckName: String) {
    decks[deckName] = []
  }

  // MARK: - Positions

  mutating func place(_ pieceName: String, at site: DSLValue, enumType: String) {
    positions[pieceName] = site
    pieceTypes[pieceName] = enumType
  }

  mutating func removePiece(_ pieceName: String) {
    positions.removeValue(forKey: pieceName)
    pieceTypes.removeValue(forKey: pieceName)
  }

  func getPosition(_ pieceName: String) -> DSLValue {
    positions[pieceName] ?? .nil
  }
}

// MARK: - HistoryTracking

extension InterpretedState: HistoryTracking {
  typealias Action = ActionValue
  typealias Phase = String
}

// MARK: - Equatable (for MCTS)

extension InterpretedState: Equatable {
  static func == (lhs: InterpretedState, rhs: InterpretedState) -> Bool {
    lhs.counters == rhs.counters &&
    lhs.flags == rhs.flags &&
    lhs.fields == rhs.fields &&
    lhs.dicts == rhs.dicts &&
    lhs.sets == rhs.sets &&
    lhs.decks == rhs.decks &&
    lhs.optionals == rhs.optionals &&
    lhs.history == rhs.history &&
    lhs.phase == rhs.phase &&
    lhs.ended == rhs.ended &&
    lhs.victory == rhs.victory &&
    lhs.positions == rhs.positions &&
    lhs.pieceTypes == rhs.pieceTypes
  }
}

// MARK: - CustomStringConvertible (required by OpenLoopMCTS)

extension InterpretedState: CustomStringConvertible {
  var description: String {
    "InterpretedState(phase:\(phase), ended:\(ended))"
  }
}

// MARK: - GameState (required by OpenLoopMCTS)

extension InterpretedState: GameState {
  typealias Piece = String
  typealias PiecePosition = String
  typealias Player = String
  typealias Position = String

  // swiftlint:disable unused_setter_value
  var player: String {
    get { "player1" }
    set { }
  }
  var players: [String] {
    get { ["player1"] }
    set { }
  }
  var endedInVictoryFor: [String] {
    get { victory ? ["player1"] : [] }
    set { }
  }
  var endedInDefeatFor: [String] {
    get { ended && !victory ? ["player1"] : [] }
    set { }
  }
  var position: [String: String] {
    get {
      var result: [String: String] = [:]
      for (name, value) in positions {
        result[name] = value.displayString
      }
      return result
    }
    set { }
  }
  // swiftlint:enable unused_setter_value

  func redeterminize() -> InterpretedState {
    var new = self
    for (name, _) in new.decks {
      new.shuffleDeck(name)
    }
    return new
  }
}

// MARK: - TextTableAble (required by GameRunner)

extension InterpretedState: TextTableAble {
  func printTable<Target>(
    to output: inout Target
  ) where Target: TextOutputStream {
    output.write("phase: \(phase)  ended: \(ended)  victory: \(victory)\n")
    for (name, value) in counters.sorted(by: { $0.key < $1.key }) {
      output.write("  \(name): \(value)\n")
    }
    for (name, value) in flags.sorted(by: { $0.key < $1.key }) {
      output.write("  \(name): \(value)\n")
    }
    for (name, value) in fields.sorted(by: { $0.key < $1.key }) {
      output.write("  \(name): \(value.displayString)\n")
    }
    for (name, dict) in dicts.sorted(by: { $0.key < $1.key }) {
      let entries = dict.map { "\($0.key):\($0.value.displayString)" }
        .sorted().joined(separator: ", ")
      output.write("  \(name): {\(entries)}\n")
    }
    for (name, set) in sets.sorted(by: { $0.key < $1.key }) {
      output.write("  \(name): {\(set.sorted().joined(separator: ", "))}\n")
    }
  }
}
