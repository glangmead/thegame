// swiftlint:disable file_length type_body_length
struct InterpretedState: @unchecked Sendable {
  let schema: StateSchema
  let interner: StringInterner

  // MARK: - CoW storage

  // All mutable state lives in a reference-counted box.
  // Copying InterpretedState retains one pointer instead of 11 dictionaries.
  // Mutation triggers copy-on-write via ensureUnique().
  final class Storage {
    var counters: [FieldID: Int]
    var flags: [FieldID: Bool]
    var fields: [FieldID: DSLValue]
    var dicts: [FieldID: [FieldID: DSLValue]]
    var sets: [FieldID: Set<FieldID>]
    var decks: [FieldID: [DSLValue]]
    var optionals: [FieldID: DSLValue?]
    var positions: [FieldID: DSLValue]
    var pieceTypes: [FieldID: FieldID]
    var history: [ActionValue]
    var phase: String
    var phaseFID: FieldID?
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
      new.phaseFID = phaseFID
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

  // MARK: - Framework fields

  var history: [ActionValue] {
    get { _storage.history }
    set { ensureUnique(); _storage.history = newValue }
  }
  var phase: String {
    get { _storage.phase }
    set {
      ensureUnique()
      _storage.phase = newValue
      _storage.phaseFID = interner.intern(newValue)
    }
  }
  var phaseFID: FieldID? { _storage.phaseFID }
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
    case "phase":
      if let fid = _storage.phaseFID { return .symbol(fid) }
      return .symbol(interner.intern(phase))
    default: return nil
    }
  }

  @discardableResult
  private mutating func setFrameworkField(_ name: String, _ value: DSLValue) -> Bool {
    switch name {
    case "phase":
      phase = value.displayString(interner: interner)
      return true
    default: return false
    }
  }

  // MARK: - Init

  init(schema: StateSchema, interner: StringInterner) {
    self.schema = schema
    self.interner = interner
    self._storage = Storage()
    for (name, field) in schema.fields {
      let fid = interner.intern(name)
      switch field.kind {
      case .counter(let min, _):
        _storage.counters[fid] = min
      case .flag:
        // Framework flags have dedicated storage; skip to avoid stale duplicates.
        if name != "ended" && name != "victory" && name != "gameAcknowledged" {
          _storage.flags[fid] = false
        }
      case .field:
        _storage.fields[fid] = .nil
      case .dict:
        _storage.dicts[fid] = [:]
      case .set:
        _storage.sets[fid] = []
      case .deck:
        _storage.decks[fid] = []
      case .optional:
        _storage.optionals[fid] = .some(.nil)
      }
    }
  }

  // MARK: - FieldID hot-path getters

  func getCounter(_ fid: FieldID) -> Int {
    _storage.counters[fid] ?? 0
  }

  func getFlag(_ fid: FieldID) -> Bool {
    _storage.flags[fid] ?? false
  }

  func getField(_ fid: FieldID) -> DSLValue {
    _storage.fields[fid] ?? .nil
  }

  func getDict(_ fid: FieldID) -> [FieldID: DSLValue] {
    _storage.dicts[fid] ?? [:]
  }

  func getSet(_ fid: FieldID) -> Set<FieldID> {
    _storage.sets[fid] ?? []
  }

  func getDeck(_ fid: FieldID) -> [DSLValue] {
    _storage.decks[fid] ?? []
  }

  func getOptional(_ fid: FieldID) -> DSLValue {
    if let value = _storage.optionals[fid] { return value ?? .nil }
    return .nil
  }

  func getPosition(_ fid: FieldID) -> DSLValue {
    _storage.positions[fid] ?? .nil
  }

  // MARK: - Direct access helpers

  /// O(1) lookup into a nested dict without copying the intermediate dictionary.
  func lookupInDict(_ dictFID: FieldID, key: FieldID) -> DSLValue {
    _storage.dicts[dictFID]?[key] ?? .nil
  }

  /// O(1) membership test without copying the set.
  func containsInSet(_ setFID: FieldID, _ element: FieldID) -> Bool {
    _storage.sets[setFID]?.contains(element) ?? false
  }

  func deckCount(_ fid: FieldID) -> Int {
    _storage.decks[fid]?.count ?? 0
  }

  func isDeckEmpty(_ fid: FieldID) -> Bool {
    _storage.decks[fid]?.isEmpty ?? true
  }

  var positionsByFieldID: [FieldID: DSLValue] { _storage.positions }

  // MARK: - FieldID hot-path setters

  mutating func setCounter(_ fid: FieldID, _ value: Int, min: Int, max: Int) {
    ensureUnique()
    _storage.counters[fid] = Swift.min(Swift.max(value, min), max)
  }

  mutating func setFlag(_ fid: FieldID, _ value: Bool) {
    ensureUnique()
    _storage.flags[fid] = value
  }

  mutating func setField(_ fid: FieldID, _ value: DSLValue) {
    ensureUnique()
    _storage.fields[fid] = value
  }

  mutating func setDictEntry(_ dictFID: FieldID, key: FieldID, value: DSLValue) {
    ensureUnique()
    _storage.dicts[dictFID, default: [:]][key] = value
  }

  mutating func removeDictEntry(_ dictFID: FieldID, key: FieldID) {
    ensureUnique()
    _storage.dicts[dictFID]?.removeValue(forKey: key)
  }

  mutating func insertIntoSet(_ fid: FieldID, _ element: FieldID) {
    ensureUnique()
    _storage.sets[fid, default: []].insert(element)
  }

  mutating func removeFromSet(_ fid: FieldID, _ element: FieldID) {
    ensureUnique()
    _storage.sets[fid]?.remove(element)
  }

  mutating func setOptional(_ fid: FieldID, _ value: DSLValue?) {
    ensureUnique()
    _storage.optionals[fid] = value
  }

  mutating func drawFromDeck(_ fid: FieldID) -> DSLValue? {
    guard var deck = _storage.decks[fid], !deck.isEmpty else { return nil }
    let card = deck.removeFirst()
    ensureUnique()
    _storage.decks[fid] = deck
    return card
  }

  mutating func shuffleDeck(_ fid: FieldID) {
    if var deck = _storage.decks[fid] {
      GameRNG.shuffle(&deck)
      ensureUnique()
      _storage.decks[fid] = deck
    }
  }

  mutating func appendToDeck(_ fid: FieldID, _ card: DSLValue) {
    ensureUnique()
    _storage.decks[fid, default: []].append(card)
  }

  mutating func removeDeckItem(_ fid: FieldID, at index: Int) {
    guard var deck = _storage.decks[fid], index >= 0, index < deck.count else { return }
    deck.remove(at: index)
    ensureUnique()
    _storage.decks[fid] = deck
  }

  mutating func clearDeck(_ fid: FieldID) {
    ensureUnique()
    _storage.decks[fid] = []
  }

  // MARK: - Positions (FieldID)

  mutating func place(_ piece: FieldID, at site: DSLValue, enumType: FieldID) {
    ensureUnique()
    _storage.positions[piece] = site
    _storage.pieceTypes[piece] = enumType
  }

  mutating func removePiece(_ piece: FieldID) {
    ensureUnique()
    _storage.positions.removeValue(forKey: piece)
    _storage.pieceTypes.removeValue(forKey: piece)
  }

  // MARK: - String-keyed cold-path getters

  func getCounter(_ name: String) -> Int {
    getCounter(interner.intern(name))
  }

  func getFlag(_ name: String) -> Bool {
    if let fwk = getFrameworkFlag(name) { return fwk }
    return getFlag(interner.intern(name))
  }

  func getField(_ name: String) -> DSLValue {
    if let fwk = getFrameworkField(name) { return fwk }
    return getField(interner.intern(name))
  }

  func getDict(_ name: String) -> [String: DSLValue] {
    let fid = interner.intern(name)
    let dict = _storage.dicts[fid] ?? [:]
    var result: [String: DSLValue] = [:]
    for (key, value) in dict {
      result[interner.resolve(key)] = value
    }
    return result
  }

  func lookupInDict(_ dictName: String, key: String) -> DSLValue {
    lookupInDict(interner.intern(dictName), key: interner.intern(key))
  }

  func getSet(_ name: String) -> Set<String> {
    let fid = interner.intern(name)
    let set = _storage.sets[fid] ?? []
    return Set(set.map { interner.resolve($0) })
  }

  func containsInSet(_ setName: String, _ element: String) -> Bool {
    containsInSet(interner.intern(setName), interner.intern(element))
  }

  func getDeck(_ name: String) -> [DSLValue] {
    getDeck(interner.intern(name))
  }

  func deckCount(_ name: String) -> Int {
    deckCount(interner.intern(name))
  }

  func isDeckEmpty(_ name: String) -> Bool {
    isDeckEmpty(interner.intern(name))
  }

  func getOptional(_ name: String) -> DSLValue {
    getOptional(interner.intern(name))
  }

  func getPosition(_ name: String) -> DSLValue {
    getPosition(interner.intern(name))
  }

  /// Generic get: looks across all field types.
  /// Framework fields (ended, victory, gameAcknowledged, phase) are checked
  /// before the schema dicts so that direct property mutations stay visible.
  func get(_ name: String) -> DSLValue {
    if let fwk = getFrameworkFlag(name) { return .bool(fwk) }
    if let fwk = getFrameworkField(name) { return fwk }
    let fid = interner.intern(name)
    if let value = _storage.counters[fid] { return .int(value) }
    if let value = _storage.flags[fid] { return .bool(value) }
    if let value = _storage.fields[fid] { return value }
    if let value = _storage.optionals[fid] { return value ?? .nil }
    return .nil
  }

  // MARK: - String-keyed cold-path setters

  mutating func setCounter(_ name: String, _ value: Int) {
    guard let field = schema.field(name),
          case .counter(let min, let max) = field.kind else { return }
    setCounter(interner.intern(name), value, min: min, max: max)
  }

  mutating func incrementCounter(_ name: String, by amount: Int) {
    let fid = interner.intern(name)
    let current = _storage.counters[fid] ?? 0
    setCounter(name, current + amount)
  }

  mutating func decrementCounter(_ name: String, by amount: Int) {
    let fid = interner.intern(name)
    let current = _storage.counters[fid] ?? 0
    setCounter(name, current - amount)
  }

  mutating func setFlag(_ name: String, _ value: Bool) {
    if setFrameworkFlag(name, value) { return }
    setFlag(interner.intern(name), value)
  }

  mutating func setField(_ name: String, _ value: DSLValue) {
    if setFrameworkField(name, value) { return }
    setField(interner.intern(name), value)
  }

  mutating func setDictEntry(_ dictName: String, key: String, value: DSLValue) {
    setDictEntry(interner.intern(dictName), key: interner.intern(key), value: value)
  }

  mutating func removeDictEntry(_ dictName: String, key: String) {
    removeDictEntry(interner.intern(dictName), key: interner.intern(key))
  }

  mutating func insertIntoSet(_ name: String, _ element: String) {
    insertIntoSet(interner.intern(name), interner.intern(element))
  }

  mutating func removeFromSet(_ name: String, _ element: String) {
    removeFromSet(interner.intern(name), interner.intern(element))
  }

  mutating func setOptional(_ name: String, _ value: DSLValue?) {
    setOptional(interner.intern(name), value)
  }

  mutating func drawFromDeck(_ deckName: String) -> DSLValue? {
    drawFromDeck(interner.intern(deckName))
  }

  mutating func shuffleDeck(_ deckName: String) {
    shuffleDeck(interner.intern(deckName))
  }

  mutating func appendToDeck(_ deckName: String, _ card: DSLValue) {
    appendToDeck(interner.intern(deckName), card)
  }

  mutating func removeDeckItem(_ deckName: String, at index: Int) {
    removeDeckItem(interner.intern(deckName), at: index)
  }

  mutating func clearDeck(_ deckName: String) {
    clearDeck(interner.intern(deckName))
  }

  mutating func place(_ pieceName: String, at site: DSLValue, enumType: String) {
    place(interner.intern(pieceName), at: site, enumType: interner.intern(enumType))
  }

  mutating func removePiece(_ pieceName: String) {
    removePiece(interner.intern(pieceName))
  }

  // MARK: - Forwarded properties (string-keyed for external consumers)

  var counters: [String: Int] {
    var result: [String: Int] = [:]
    for (fid, value) in _storage.counters {
      result[interner.resolve(fid)] = value
    }
    return result
  }

  var flags: [String: Bool] {
    var result: [String: Bool] = [:]
    for (fid, value) in _storage.flags {
      result[interner.resolve(fid)] = value
    }
    // Framework flags have dedicated storage; override stale dict entries.
    result["ended"] = ended
    result["victory"] = victory
    result["gameAcknowledged"] = gameAcknowledged
    return result
  }

  var fields: [String: DSLValue] {
    var result: [String: DSLValue] = [:]
    for (fid, value) in _storage.fields {
      result[interner.resolve(fid)] = value
    }
    return result
  }

  var dicts: [String: [String: DSLValue]] {
    var result: [String: [String: DSLValue]] = [:]
    for (fid, dict) in _storage.dicts {
      var inner: [String: DSLValue] = [:]
      for (key, value) in dict {
        inner[interner.resolve(key)] = value
      }
      result[interner.resolve(fid)] = inner
    }
    return result
  }

  var sets: [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for (fid, set) in _storage.sets {
      result[interner.resolve(fid)] = Set(set.map { interner.resolve($0) })
    }
    return result
  }

  var decks: [String: [DSLValue]] {
    var result: [String: [DSLValue]] = [:]
    for (fid, deck) in _storage.decks {
      result[interner.resolve(fid)] = deck
    }
    return result
  }

  var optionals: [String: DSLValue?] {
    var result: [String: DSLValue?] = [:]
    for (fid, value) in _storage.optionals {
      result[interner.resolve(fid)] = value
    }
    return result
  }

  var positions: [String: DSLValue] {
    var result: [String: DSLValue] = [:]
    for (fid, value) in _storage.positions {
      result[interner.resolve(fid)] = value
    }
    return result
  }

  var pieceTypes: [String: String] {
    var result: [String: String] = [:]
    for (fid, value) in _storage.pieceTypes {
      result[interner.resolve(fid)] = interner.resolve(value)
    }
    return result
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
      for (fid, value) in _storage.positions {
        result[interner.resolve(fid)] = value.displayString(interner: interner)
      }
      return result
    }
    set { }
  }
  // swiftlint:enable unused_setter_value

  func redeterminize() -> InterpretedState {
    var new = self
    for fid in new._storage.decks.keys.sorted() {
      new.shuffleDeck(fid)
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
      output.write("  \(name): \(value.displayString(interner: interner))\n")
    }
    for (name, dict) in dicts.sorted(by: { $0.key < $1.key }) {
      let entries = dict.map { "\($0.key):\($0.value.displayString(interner: interner))" }
        .sorted().joined(separator: ", ")
      output.write("  \(name): {\(entries)}\n")
    }
    for (name, set) in sets.sorted(by: { $0.key < $1.key }) {
      output.write("  \(name): {\(set.sorted().joined(separator: ", "))}\n")
    }
  }
}
// swiftlint:enable file_length type_body_length
