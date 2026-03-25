/// Randomness source: nil means use real randomness, non-nil pops from list.
final class RandomSource {
  var values: [Int]
  init(_ values: [Int]) { self.values = values }
  func next(sides: Int) -> Int {
    if values.isEmpty { return GameRNG.next(in: 1...sides) }
    return values.removeFirst()
  }
}

struct ReduceResult {
  var logs: [Log]
  var followUps: [ActionValue]
}

/// Thrown by (guard) to abort a (seq) branch.
struct GuardAbort: Error {}

/// Namespace for closure types and the runtime environment
/// shared by both JSONC expression compilers and the game builder.
struct ExpressionCompiler {

  // MARK: - Closure types

  typealias Expr = (Env) throws -> DSLValue
  typealias Stmt = (Env) throws -> ReduceResult

  // MARK: - Runtime environment

  /// Lightweight runtime environment for compiled closures.
  /// One allocation per top-level condition/reduce call.
  final class Env {
    var state: InterpretedState
    let actionParams: [String: DSLValue]
    var bindings: [String: DSLValue]
    let randomSource: RandomSource?

    init(
      state: InterpretedState,
      actionParams: [String: DSLValue] = [:],
      bindings: [String: DSLValue] = [:],
      randomSource: RandomSource? = nil
    ) {
      self.state = state
      self.actionParams = actionParams
      self.randomSource = randomSource
      // Seed locals from action params so $piece etc. work without
      // an explicit (let piece (param piece)) wrapper.
      var merged = actionParams
      for (key, value) in bindings { merged[key] = value }
      self.bindings = merged
    }

    /// Temporarily bind `name` to `value`, execute `body`, then restore.
    func withBinding<T>(
      _ name: String, _ value: DSLValue,
      body: () throws -> T
    ) rethrows -> T {
      let saved = bindings[name]
      bindings[name] = value
      defer {
        if let saved {
          bindings[name] = saved
        } else {
          bindings.removeValue(forKey: name)
        }
      }
      return try body()
    }
  }
}
