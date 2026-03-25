/// Mutable box for a RandomNumberGenerator, allowing mutation through
/// a @TaskLocal reference.
final class RNGBox: @unchecked Sendable {
  var rng: any RandomNumberGenerator
  init(_ rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
    self.rng = rng
  }
}

/// Global @TaskLocal RNG for deterministic benchmarking.
/// Default uses system random. Override via
/// `GameRNG.$box.withValue(RNGBox(SeededRNG(seed: 42))) { ... }`
enum GameRNG {
  @TaskLocal static var box = RNGBox()

  static func next(in range: ClosedRange<Int>) -> Int {
    Int.random(in: range, using: &box.rng)
  }

  static func pickRandom<C: Collection>(
    from collection: C
  ) -> C.Element? {
    guard !collection.isEmpty else { return nil }
    return collection.randomElement(using: &box.rng)
  }

  static func shuffle<T>(_ array: inout [T]) {
    array.shuffle(using: &box.rng)
  }
}
