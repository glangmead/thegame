import Observation

@Observable
final class InterpretedState: @unchecked Sendable {
  let schema: StateSchema
  private(set) var counters: [String: Int] = [:]
  private(set) var flags: [String: Bool] = [:]
  private(set) var fields: [String: DSLValue] = [:]
  private(set) var dicts: [String: [String: DSLValue]] = [:]
  private(set) var sets: [String: Set<String>] = [:]
  private(set) var decks: [String: [DSLValue]] = [:]
  private(set) var optionals: [String: DSLValue?] = [:]
  var history: [ActionValue] = []
  var phase: String = ""

  // Framework fields
  var ended: Bool = false
  var victory: Bool = false
  var gameAcknowledged: Bool = false

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
    if name == "ended" { return ended }
    if name == "victory" { return victory }
    if name == "gameAcknowledged" { return gameAcknowledged }
    return flags[name] ?? false
  }

  func getField(_ name: String) -> DSLValue {
    if name == "phase" { return .enumCase(type: "Phase", value: phase) }
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
    if name == "ended" { return .bool(ended) }
    if name == "victory" { return .bool(victory) }
    if name == "gameAcknowledged" { return .bool(gameAcknowledged) }
    if name == "phase" { return .enumCase(type: "Phase", value: phase) }
    if let value = counters[name] { return .int(value) }
    if let value = flags[name] { return .bool(value) }
    if let value = fields[name] { return value }
    if let value = optionals[name] { return value ?? .nil }
    return .nil
  }

  // MARK: - Mutators

  func setCounter(_ name: String, _ value: Int) {
    guard let field = schema.field(name),
          case .counter(let min, let max) = field.kind else { return }
    counters[name] = Swift.min(Swift.max(value, min), max)
  }

  func incrementCounter(_ name: String, by amount: Int) {
    let current = counters[name] ?? 0
    setCounter(name, current + amount)
  }

  func decrementCounter(_ name: String, by amount: Int) {
    let current = counters[name] ?? 0
    setCounter(name, current - amount)
  }

  func setFlag(_ name: String, _ value: Bool) {
    if name == "ended" { ended = value; return }
    if name == "victory" { victory = value; return }
    if name == "gameAcknowledged" { gameAcknowledged = value; return }
    flags[name] = value
  }

  func setField(_ name: String, _ value: DSLValue) {
    fields[name] = value
  }

  func setDictEntry(_ dictName: String, key: String, value: DSLValue) {
    dicts[dictName, default: [:]][key] = value
  }

  func removeDictEntry(_ dictName: String, key: String) {
    dicts[dictName]?.removeValue(forKey: key)
  }

  func insertIntoSet(_ name: String, _ element: String) {
    sets[name, default: []].insert(element)
  }

  func removeFromSet(_ name: String, _ element: String) {
    sets[name]?.remove(element)
  }

  func setOptional(_ name: String, _ value: DSLValue?) {
    optionals[name] = value
  }

  // Deck operations
  func drawFromDeck(_ deckName: String) -> DSLValue? {
    guard var deck = decks[deckName], !deck.isEmpty else { return nil }
    let card = deck.removeFirst()
    decks[deckName] = deck
    return card
  }

  func shuffleDeck(_ deckName: String) {
    decks[deckName]?.shuffle()
  }

  func appendToDeck(_ deckName: String, _ card: DSLValue) {
    decks[deckName, default: []].append(card)
  }

  func removeDeckItem(_ deckName: String, at index: Int) {
    guard var deck = decks[deckName], index >= 0, index < deck.count else { return }
    deck.remove(at: index)
    decks[deckName] = deck
  }

  func clearDeck(_ deckName: String) {
    decks[deckName] = []
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
    lhs.victory == rhs.victory
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
    get { [:] }
    set { }
  }
  // swiftlint:enable unused_setter_value

  func redeterminize() -> InterpretedState {
    let new = copy()
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

// MARK: - Copying (for MCTS rollouts)

extension InterpretedState {
  func copy() -> InterpretedState {
    let new = InterpretedState(schema: schema)
    new.counters = counters
    new.flags = flags
    new.fields = fields
    new.dicts = dicts
    new.sets = sets
    new.decks = decks
    new.optionals = optionals
    new.history = history
    new.phase = phase
    new.ended = ended
    new.victory = victory
    new.gameAcknowledged = gameAcknowledged
    return new
  }
}
