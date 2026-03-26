// swiftlint:disable file_length
struct InterpretedState: @unchecked Sendable {
  let schema: StateSchema

  // MARK: - CoW storage

  // All mutable state lives in a reference-counted box.
  // Copying InterpretedState retains one pointer instead of 11 dictionaries.
  // Mutation triggers copy-on-write via ensureUnique().
  final class Storage {
    var counters: [String: Int]
    var flags: [String: Bool]
    var fields: [String: DSLValue]
    var dicts: [String: [String: DSLValue]]
    var sets: [String: Set<String>]
    var decks: [String: [DSLValue]]
    var optionals: [String: DSLValue?]
    var positions: [String: DSLValue]
    var pieceTypes: [String: String]
    var history: [ActionValue]
    var phase: String
    var ended: Bool
    var victory: Bool
    var gameAcknowledged: Bool

    init() {
      counters = [:]
      flags = [:]
      fields = [:]
      dicts = [:]
      sets = [:]
      decks = [:]
      optionals = [:]
      positions = [:]
      pieceTypes = [:]
      history = []
      phase = ""
      ended = false
      victory = false
      gameAcknowledged = false
    }

    func copy() -> Storage {
      let new = Storage()
      new.counters = counters
      new.flags = flags
      new.fields = fields
      new.dicts = dicts
      new.sets = sets
      new.decks = decks
      new.optionals = optionals
      new.positions = positions
      new.pieceTypes = pieceTypes
      new.history = history
      new.phase = phase
      new.ended = ended
      new.victory = victory
      new.gameAcknowledged = gameAcknowledged
      return new
    }
  }

  private var _storage: Storage

  private mutating func ensureUnique() {
    if !isKnownUniquelyReferenced(&_storage) {
      _storage = _storage.copy()
    }
  }

  // MARK: - Forwarded properties

  var counters: [String: Int] { _storage.counters }
  var flags: [String: Bool] { _storage.flags }
  var fields: [String: DSLValue] { _storage.fields }
  var dicts: [String: [String: DSLValue]] { _storage.dicts }
  var sets: [String: Set<String>] { _storage.sets }
  var decks: [String: [DSLValue]] { _storage.decks }
  var optionals: [String: DSLValue?] { _storage.optionals }
  var positions: [String: DSLValue] { _storage.positions }
  var pieceTypes: [String: String] { _storage.pieceTypes }

  var history: [ActionValue] {
    get { _storage.history }
    set { ensureUnique(); _storage.history = newValue }
  }
  var phase: String {
    get { _storage.phase }
    set { ensureUnique(); _storage.phase = newValue }
  }
  var ended: Bool {
    get { _storage.ended }
    set { ensureUnique(); _storage.ended = newValue }
  }
  var victory: Bool {
    get { _storage.victory }
    set { ensureUnique(); _storage.victory = newValue }
  }
  var gameAcknowledged: Bool {
    get { _storage.gameAcknowledged }
    set { ensureUnique(); _storage.gameAcknowledged = newValue }
  }

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
    self._storage = Storage()
    for (name, field) in schema.fields {
      switch field.kind {
      case .counter(let min, _):
        _storage.counters[name] = min
      case .flag:
        _storage.flags[name] = false
      case .field:
        _storage.fields[name] = .nil
      case .dict:
        _storage.dicts[name] = [:]
      case .set:
        _storage.sets[name] = []
      case .deck:
        _storage.decks[name] = []
      case .optional:
        _storage.optionals[name] = .some(.nil)
      }
    }
  }

  // MARK: - Getters

  func getCounter(_ name: String) -> Int {
    _storage.counters[name] ?? 0
  }

  func getFlag(_ name: String) -> Bool {
    if let fwk = getFrameworkFlag(name) { return fwk }
    return _storage.flags[name] ?? false
  }

  func getField(_ name: String) -> DSLValue {
    if let fwk = getFrameworkField(name) { return fwk }
    return _storage.fields[name] ?? .nil
  }

  func getDict(_ name: String) -> [String: DSLValue] {
    _storage.dicts[name] ?? [:]
  }

  /// O(1) lookup into a nested dict without copying the intermediate dictionary.
  func lookupInDict(_ dictName: String, key: String) -> DSLValue {
    _storage.dicts[dictName]?[key] ?? .nil
  }

  func getSet(_ name: String) -> Set<String> {
    _storage.sets[name] ?? []
  }

  /// O(1) membership test without copying the set.
  func containsInSet(_ setName: String, _ element: String) -> Bool {
    _storage.sets[setName]?.contains(element) ?? false
  }

  func getDeck(_ name: String) -> [DSLValue] {
    _storage.decks[name] ?? []
  }

  func deckCount(_ name: String) -> Int {
    _storage.decks[name]?.count ?? 0
  }

  func isDeckEmpty(_ name: String) -> Bool {
    _storage.decks[name]?.isEmpty ?? true
  }

  func getOptional(_ name: String) -> DSLValue {
    if let value = _storage.optionals[name] { return value ?? .nil }
    return .nil
  }

  /// Generic get: looks across all field types.
  /// Framework fields (ended, victory, gameAcknowledged, phase) are checked
  /// before the schema dicts so that direct property mutations stay visible.
  func get(_ name: String) -> DSLValue {
    if let fwk = getFrameworkFlag(name) { return .bool(fwk) }
    if let fwk = getFrameworkField(name) { return fwk }
    if let value = _storage.counters[name] { return .int(value) }
    if let value = _storage.flags[name] { return .bool(value) }
    if let value = _storage.fields[name] { return value }
    if let value = _storage.optionals[name] { return value ?? .nil }
    return .nil
  }

  // MARK: - Mutators

  mutating func setCounter(_ name: String, _ value: Int) {
    guard let field = schema.field(name),
          case .counter(let min, let max) = field.kind else { return }
    ensureUnique()
    _storage.counters[name] = Swift.min(Swift.max(value, min), max)
  }

  mutating func incrementCounter(_ name: String, by amount: Int) {
    let current = _storage.counters[name] ?? 0
    setCounter(name, current + amount)
  }

  mutating func decrementCounter(_ name: String, by amount: Int) {
    let current = _storage.counters[name] ?? 0
    setCounter(name, current - amount)
  }

  mutating func setFlag(_ name: String, _ value: Bool) {
    if setFrameworkFlag(name, value) { return }
    ensureUnique()
    _storage.flags[name] = value
  }

  mutating func setField(_ name: String, _ value: DSLValue) {
    if setFrameworkField(name, value) { return }
    ensureUnique()
    _storage.fields[name] = value
  }

  mutating func setDictEntry(_ dictName: String, key: String, value: DSLValue) {
    ensureUnique()
    _storage.dicts[dictName, default: [:]][key] = value
  }

  mutating func removeDictEntry(_ dictName: String, key: String) {
    ensureUnique()
    _storage.dicts[dictName]?.removeValue(forKey: key)
  }

  mutating func insertIntoSet(_ name: String, _ element: String) {
    ensureUnique()
    _storage.sets[name, default: []].insert(element)
  }

  mutating func removeFromSet(_ name: String, _ element: String) {
    ensureUnique()
    _storage.sets[name]?.remove(element)
  }

  mutating func setOptional(_ name: String, _ value: DSLValue?) {
    ensureUnique()
    _storage.optionals[name] = value
  }

  // Deck operations
  mutating func drawFromDeck(_ deckName: String) -> DSLValue? {
    guard var deck = _storage.decks[deckName], !deck.isEmpty else { return nil }
    let card = deck.removeFirst()
    ensureUnique()
    _storage.decks[deckName] = deck
    return card
  }

  mutating func shuffleDeck(_ deckName: String) {
    if var deck = _storage.decks[deckName] {
      GameRNG.shuffle(&deck)
      ensureUnique()
      _storage.decks[deckName] = deck
    }
  }

  mutating func appendToDeck(_ deckName: String, _ card: DSLValue) {
    ensureUnique()
    _storage.decks[deckName, default: []].append(card)
  }

  mutating func removeDeckItem(_ deckName: String, at index: Int) {
    guard var deck = _storage.decks[deckName], index >= 0, index < deck.count else { return }
    deck.remove(at: index)
    ensureUnique()
    _storage.decks[deckName] = deck
  }

  mutating func clearDeck(_ deckName: String) {
    ensureUnique()
    _storage.decks[deckName] = []
  }

  // MARK: - Positions

  mutating func place(_ pieceName: String, at site: DSLValue, enumType: String) {
    ensureUnique()
    _storage.positions[pieceName] = site
    _storage.pieceTypes[pieceName] = enumType
  }

  mutating func removePiece(_ pieceName: String) {
    ensureUnique()
    _storage.positions.removeValue(forKey: pieceName)
    _storage.pieceTypes.removeValue(forKey: pieceName)
  }

  func getPosition(_ pieceName: String) -> DSLValue {
    _storage.positions[pieceName] ?? .nil
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
    if lhs._storage === rhs._storage { return true }
    return lhs._storage.counters == rhs._storage.counters &&
    lhs._storage.flags == rhs._storage.flags &&
    lhs._storage.fields == rhs._storage.fields &&
    lhs._storage.dicts == rhs._storage.dicts &&
    lhs._storage.sets == rhs._storage.sets &&
    lhs._storage.decks == rhs._storage.decks &&
    lhs._storage.optionals == rhs._storage.optionals &&
    lhs._storage.history == rhs._storage.history &&
    lhs._storage.phase == rhs._storage.phase &&
    lhs._storage.ended == rhs._storage.ended &&
    lhs._storage.victory == rhs._storage.victory &&
    lhs._storage.positions == rhs._storage.positions &&
    lhs._storage.pieceTypes == rhs._storage.pieceTypes
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
      for (name, value) in _storage.positions {
        result[name] = value.displayString
      }
      return result
    }
    set { }
  }
  // swiftlint:enable unused_setter_value

  func redeterminize() -> InterpretedState {
    var new = self
    for name in new._storage.decks.keys.sorted() {
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
// swiftlint:enable file_length
