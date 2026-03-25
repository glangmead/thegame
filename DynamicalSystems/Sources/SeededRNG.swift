/// Xoshiro256** seedable PRNG conforming to RandomNumberGenerator.
/// Use for deterministic benchmarking and reproducible game runs.
struct SeededRNG: RandomNumberGenerator {
  private var state: (UInt64, UInt64, UInt64, UInt64)

  init(seed: UInt64) {
    // SplitMix64 to expand a single seed into 4 state words
    var z = seed
    func next() -> UInt64 {
      z &+= 0x9e3779b97f4a7c15
      var result = z
      result = (result ^ (result >> 30)) &* 0xbf58476d1ce4e5b9
      result = (result ^ (result >> 27)) &* 0x94d049bb133111eb
      return result ^ (result >> 31)
    }
    state = (next(), next(), next(), next())
  }

  mutating func next() -> UInt64 {
    let result = rotl(state.1 &* 5, 7) &* 9
    let t = state.1 << 17
    state.2 ^= state.0
    state.3 ^= state.1
    state.1 ^= state.2
    state.0 ^= state.3
    state.2 ^= t
    state.3 = rotl(state.3, 45)
    return result
  }

  private func rotl(_ x: UInt64, _ k: Int) -> UInt64 {
    (x << k) | (x >> (64 - k))
  }
}
