// swiftlint:disable file_length type_body_length
struct InterpretedState: @unchecked Sendable {
  let schema: StateSchema
  let interner: StringInterner

  // MARK: - CoW storage

  // All mutable state lives in a reference-counted box.
  // Copying InterpretedState retains one pointer instead of 11 dictionaries.
  // Mutation triggers copy-on-write via ensureUnique().
  final class Storage {
    // Flat arrays indexed by FieldID.rawValue — O(1) with zero hashing.
    var counterArr: [Int]
    var flagArr: [Bool]
    var fieldArr: [DSLValue]
    var dictArr: [[FieldID: DSLValue]]
    var setArr: [Set<FieldID>]
    var deckArr: [[DSLValue]]
    var optionalArr: [DSLValue?]
    // Runtime-keyed (piece names are dynamic).
    var positions: [FieldID: DSLValue]
    var pieceTypes: [FieldID: FieldID]
    var history: [ActionValue]
    var phase: String
    var phaseFID: FieldID?
    var ended: Bool
    var victory: Bool
    var gameAcknowledged: Bool

    init(size: Int) {
      counterArr = [Int](repeating: 0, count: size)
      flagArr = [Bool](repeating: false, count: size)
      fieldArr = [DSLValue](repeating: .nil, count: size)
      dictArr = [[FieldID: DSLValue]](repeating: [:], count: size)
      setArr = [Set<FieldID>](repeating: [], count: size)
      deckArr = [[DSLValue]](repeating: [], count: size)
      optionalArr = [DSLValue?](repeating: .some(.nil), count: size)
      positions = [:]
      pieceTypes = [:]
      history = []
      phase = ""
      ended = false
      victory = false
      gameAcknowledged = false
    }

    func copy() -> Storage {
      let new = Storage(size: 0)
      new.counterArr = counterArr
      new.flagArr = flagArr
      new.fieldArr = fieldArr
      new.dictArr = dictArr
      new.setArr = setArr
      new.deckArr = deckArr
      new.optionalArr = optionalArr
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
    self._storage = Storage(size: interner.count)
    for (name, field) in schema.fields {
      let idx = interner.intern(name).rawValue
      switch field.kind {
      case .counter(let min, _):
        _storage.counterArr[idx] = min
      case .flag:
        break // defaults to false; framework flags use dedicated properties
      case .field:
        break // defaults to .nil
      case .dict:
        break // defaults to [:]
      case .set:
        break // defaults to []
      case .deck:
        break // defaults to []
      case .optional:
        break // defaults to .some(.nil)
      }
    }
  }

  // MARK: - FieldID hot-path getters (array-indexed, zero hashing)

  func getCounter(_ fid: FieldID) -> Int {
    _storage.counterArr[fid.rawValue]
  }

  func getFlag(_ fid: FieldID) -> Bool {
    _storage.flagArr[fid.rawValue]
  }

  func getField(_ fid: FieldID) -> DSLValue {
    _storage.fieldArr[fid.rawValue]
  }

  func getDict(_ fid: FieldID) -> [FieldID: DSLValue] {
    _storage.dictArr[fid.rawValue]
  }

  func getSet(_ fid: FieldID) -> Set<FieldID> {
    _storage.setArr[fid.rawValue]
  }

  func getDeck(_ fid: FieldID) -> [DSLValue] {
    _storage.deckArr[fid.rawValue]
  }

  func getOptional(_ fid: FieldID) -> DSLValue {
    _storage.optionalArr[fid.rawValue] ?? .nil
  }

  func getPosition(_ fid: FieldID) -> DSLValue {
    _storage.positions[fid] ?? .nil
  }

  // MARK: - Direct access helpers

  func lookupInDict(_ dictFID: FieldID, key: FieldID) -> DSLValue {
    _storage.dictArr[dictFID.rawValue][key] ?? .nil
  }

  func containsInSet(_ setFID: FieldID, _ element: FieldID) -> Bool {
    _storage.setArr[setFID.rawValue].contains(element)
  }

  func deckCount(_ fid: FieldID) -> Int {
    _storage.deckArr[fid.rawValue].count
  }

  func isDeckEmpty(_ fid: FieldID) -> Bool {
    _storage.deckArr[fid.rawValue].isEmpty
  }

  var positionsByFieldID: [FieldID: DSLValue] { _storage.positions }

  // MARK: - FieldID hot-path setters

  mutating func setCounter(_ fid: FieldID, _ value: Int, min: Int, max: Int) {
    ensureUnique()
    _storage.counterArr[fid.rawValue] = Swift.min(Swift.max(value, min), max)
  }

  mutating func setFlag(_ fid: FieldID, _ value: Bool) {
    ensureUnique()
    _storage.flagArr[fid.rawValue] = value
  }

  mutating func setField(_ fid: FieldID, _ value: DSLValue) {
    ensureUnique()
    _storage.fieldArr[fid.rawValue] = value
  }

  mutating func setDictEntry(_ dictFID: FieldID, key: FieldID, value: DSLValue) {
    ensureUnique()
    _storage.dictArr[dictFID.rawValue][key] = value
  }

  mutating func removeDictEntry(_ dictFID: FieldID, key: FieldID) {
    ensureUnique()
    _storage.dictArr[dictFID.rawValue].removeValue(forKey: key)
  }

  mutating func insertIntoSet(_ fid: FieldID, _ element: FieldID) {
    ensureUnique()
    _storage.setArr[fid.rawValue].insert(element)
  }

  mutating func removeFromSet(_ fid: FieldID, _ element: FieldID) {
    ensureUnique()
    _storage.setArr[fid.rawValue].remove(element)
  }

  mutating func setOptional(_ fid: FieldID, _ value: DSLValue?) {
    ensureUnique()
    _storage.optionalArr[fid.rawValue] = value
  }

  mutating func drawFromDeck(_ fid: FieldID) -> DSLValue? {
    guard !_storage.deckArr[fid.rawValue].isEmpty else { return nil }
    ensureUnique()
    return _storage.deckArr[fid.rawValue].removeFirst()
  }

  mutating func shuffleDeck(_ fid: FieldID) {
    ensureUnique()
    GameRNG.shuffle(&_storage.deckArr[fid.rawValue])
  }

  mutating func appendToDeck(_ fid: FieldID, _ card: DSLValue) {
    ensureUnique()
    _storage.deckArr[fid.rawValue].append(card)
  }

  mutating func removeDeckItem(_ fid: FieldID, at index: Int) {
    let idx = fid.rawValue
    guard index >= 0, index < _storage.deckArr[idx].count else { return }
    ensureUnique()
    _storage.deckArr[idx].remove(at: index)
  }

  mutating func clearDeck(_ fid: FieldID) {
    ensureUnique()
    _storage.deckArr[fid.rawValue] = []
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
    let idx = interner.intern(name).rawValue
    var result: [String: DSLValue] = [:]
    for (key, value) in _storage.dictArr[idx] {
      result[interner.resolve(key)] = value
    }
    return result
  }

  func lookupInDict(_ dictName: String, key: String) -> DSLValue {
    lookupInDict(interner.intern(dictName), key: interner.intern(key))
  }

  func getSet(_ name: String) -> Set<String> {
    let idx = interner.intern(name).rawValue
    return Set(_storage.setArr[idx].map { interner.resolve($0) })
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
    // Fall back to schema lookup for type dispatch.
    guard let def = schema.field(name) else { return .nil }
    let idx = interner.intern(name).rawValue
    switch def.kind {
    case .counter: return .int(_storage.counterArr[idx])
    case .flag: return .bool(_storage.flagArr[idx])
    case .field: return _storage.fieldArr[idx]
    case .optional: return _storage.optionalArr[idx] ?? .nil
    default: return .nil
    }
  }

  // MARK: - String-keyed cold-path setters

  mutating func setCounter(_ name: String, _ value: Int) {
    guard let field = schema.field(name),
          case .counter(let min, let max) = field.kind else { return }
    setCounter(interner.intern(name), value, min: min, max: max)
  }

  mutating func incrementCounter(_ name: String, by amount: Int) {
    let fid = interner.intern(name)
    let current = _storage.counterArr[fid.rawValue]
    setCounter(name, current + amount)
  }

  mutating func decrementCounter(_ name: String, by amount: Int) {
    let fid = interner.intern(name)
    let current = _storage.counterArr[fid.rawValue]
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
    for (name, def) in schema.fields where def.kind.isCounter {
      result[name] = _storage.counterArr[interner.intern(name).rawValue]
    }
    return result
  }

  var flags: [String: Bool] {
    var result: [String: Bool] = [:]
    for (name, def) in schema.fields where def.kind.isFlag {
      result[name] = _storage.flagArr[interner.intern(name).rawValue]
    }
    result["ended"] = ended
    result["victory"] = victory
    result["gameAcknowledged"] = gameAcknowledged
    return result
  }

  var fields: [String: DSLValue] {
    var result: [String: DSLValue] = [:]
    for (name, def) in schema.fields where def.kind.isField {
      result[name] = _storage.fieldArr[interner.intern(name).rawValue]
    }
    return result
  }

  var dicts: [String: [String: DSLValue]] {
    var result: [String: [String: DSLValue]] = [:]
    for (name, def) in schema.fields where def.kind.isDict {
      let inner = _storage.dictArr[interner.intern(name).rawValue]
      var converted: [String: DSLValue] = [:]
      for (key, value) in inner { converted[interner.resolve(key)] = value }
      result[name] = converted
    }
    return result
  }

  var sets: [String: Set<String>] {
    var result: [String: Set<String>] = [:]
    for (name, def) in schema.fields where def.kind.isSet {
      let inner = _storage.setArr[interner.intern(name).rawValue]
      result[name] = Set(inner.map { interner.resolve($0) })
    }
    return result
  }

  var decks: [String: [DSLValue]] {
    var result: [String: [DSLValue]] = [:]
    for (name, def) in schema.fields where def.kind.isDeck {
      result[name] = _storage.deckArr[interner.intern(name).rawValue]
    }
    return result
  }

  var optionals: [String: DSLValue?] {
    var result: [String: DSLValue?] = [:]
    for (name, def) in schema.fields where def.kind.isOptional {
      result[name] = _storage.optionalArr[interner.intern(name).rawValue]
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
    return lhs._storage.counterArr == rhs._storage.counterArr &&
    lhs._storage.flagArr == rhs._storage.flagArr &&
    lhs._storage.fieldArr == rhs._storage.fieldArr &&
    lhs._storage.dictArr == rhs._storage.dictArr &&
    lhs._storage.setArr == rhs._storage.setArr &&
    lhs._storage.deckArr == rhs._storage.deckArr &&
    lhs._storage.optionalArr == rhs._storage.optionalArr &&
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
    for (name, def) in schema.fields where def.kind.isDeck {
      let fid = interner.intern(name)
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
