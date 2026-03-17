# Redeterminize Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `redeterminize()` to `GameState` so MCTS iterations sample over hidden information rather than using a fixed world.

**Architecture:** Protocol requirement on `GameState` with default returning `self`. Hearts overrides with void-constraint-based card shuffling. LoD overrides with draw pile shuffling. MCTS calls it at the start of each iteration.

**Tech Stack:** Swift 6.2, SwiftUI, Swift Testing framework

**Spec:** `docs/superpowers/specs/2026-03-17-redeterminize-design.md`

**Test command:** `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`

**Lint command:** `/opt/homebrew/bin/swiftlint`

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `DynamicalSystems/Sources/Game.swift` | Modify | Add `redeterminize(using:) -> Self` to `GameState` protocol + default extensions |
| `DynamicalSystems/Sources/OpenLoopMCTS.swift` | Modify | Call `rootState.redeterminize()` at iteration start |
| `DynamicalSystems/Sources/Hearts/HeartsState.swift` | Modify | Add `redeterminize(using:)` override + `computeVoidConstraints` helper |
| `DynamicalSystems/Sources/Legions of Darkness/LoDState.swift` | Modify | Add `redeterminize(using:)` override |
| `DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift` | Create | Tests for all three implementations |

No `project.pbxproj` edits needed — new test files auto-discover in the test target, and all modified source files are already registered.

---

### Task 1: Protocol + Default Extension

**Files:**
- Modify: `DynamicalSystems/Sources/Game.swift:52-59`

- [ ] **Step 1: Add `redeterminize(using:)` to `GameState` protocol**

In `Game.swift`, change the `GameState` protocol and add a default extension. Insert the requirement after the `position` property (line 58), and add the extension right after the protocol closing brace (line 59):

```swift
protocol GameState: GameComponents, Equatable {
  var player: Player { get set }
  var players: [Player] { get set }
  var ended: Bool { get set }
  var endedInVictoryFor: [Player] { get set }
  var endedInDefeatFor: [Player] { get set }
  var position: [Piece: Position] { get set }
  func redeterminize(using generator: inout some RandomNumberGenerator) -> Self
}

extension GameState {
  func redeterminize(using generator: inout some RandomNumberGenerator) -> Self { self }
  func redeterminize() -> Self {
    var rng = SystemRandomNumberGenerator()
    return redeterminize(using: &rng)
  }
}
```

- [ ] **Step 2: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint DynamicalSystems/Sources/Game.swift`
Expected: no new violations

- [ ] **Step 3: Build to verify all conformers still compile**

Run: `xcodebuild build -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystems -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (the default extension satisfies the requirement for all existing conformers)

- [ ] **Step 4: Commit**

```bash
git add DynamicalSystems/Sources/Game.swift
git commit -m "feat: add redeterminize(using:) to GameState protocol"
```

---

### Task 2: MCTS Integration

**Files:**
- Modify: `DynamicalSystems/Sources/OpenLoopMCTS.swift:194`

- [ ] **Step 1: Change `var state = rootState` to call `redeterminize()`**

In `OpenLoopMCTS.swift`, line 194, change:

```swift
      var state = rootState
```

to:

```swift
      var state = rootState.redeterminize()
```

Since the default `redeterminize()` returns `self`, this is a no-op for games that don't override it. Behavior is unchanged until Hearts/LoD provide implementations.

- [ ] **Step 2: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint DynamicalSystems/Sources/OpenLoopMCTS.swift`
Expected: no new violations

- [ ] **Step 3: Build**

Run: `xcodebuild build -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystems -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add DynamicalSystems/Sources/OpenLoopMCTS.swift
git commit -m "feat: call redeterminize() at start of each MCTS iteration"
```

---

### Task 3: LoD Redeterminize (Simple Case)

**Files:**
- Modify: `DynamicalSystems/Sources/Legions of Darkness/LoDState.swift`
- Test: `DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift`

- [ ] **Step 1: Write failing test for LoD redeterminize**

Create `DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift`:

```swift
//
//  RedeterminizeTests.swift
//  DynamicalSystems
//
//  Tests for GameState.redeterminize() — Hearts void constraints,
//  LoD deck shuffling, default no-op.
//

import Testing
import Foundation

// Deterministic RNG that returns values from a fixed sequence.
struct SeededRNG: RandomNumberGenerator {
  var state: UInt64
  mutating func next() -> UInt64 {
    // xorshift64
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

@Suite
struct LoDRedeterminizeTests {
  @Test
  func redeterminizeShufflesDrawPiles() {
    var state = LoD.State.greenskinSetup(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.Card.dayDeck,
      shuffledNightCards: LoD.Card.nightDeck
    )
    let originalDay = state.dayDrawPile
    let originalNight = state.nightDrawPile

    // Use a seeded RNG so the shuffle is deterministic but different
    var rng = SeededRNG(state: 42)
    let result = state.redeterminize(using: &rng)

    // Cards are the same set, just reordered
    #expect(Set(result.dayDrawPile) == Set(originalDay))
    #expect(Set(result.nightDrawPile) == Set(originalNight))
    // At least one pile should differ in order (with overwhelming probability)
    #expect(result.dayDrawPile != originalDay || result.nightDrawPile != originalNight)
    // Discard piles unchanged
    #expect(result.dayDiscardPile == state.dayDiscardPile)
    #expect(result.nightDiscardPile == state.nightDiscardPile)
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/LoDRedeterminizeTests 2>&1 | tail -10`
Expected: FAIL — `LoD.State` uses the default (returns `self`), so piles are identical.

- [ ] **Step 3: Implement LoD redeterminize**

In `LoDState.swift`, add a new extension at the end of the file:

```swift
// MARK: - Redeterminize

extension LoD.State {
  func redeterminize(using generator: inout some RandomNumberGenerator) -> LoD.State {
    var copy = self
    copy.dayDrawPile.shuffle(using: &generator)
    copy.nightDrawPile.shuffle(using: &generator)
    return copy
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/LoDRedeterminizeTests 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 5: Run swiftlint on both files**

Run: `/opt/homebrew/bin/swiftlint "DynamicalSystems/Sources/Legions of Darkness/LoDState.swift" DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift`
Expected: no new violations

- [ ] **Step 6: Commit**

```bash
git add "DynamicalSystems/Sources/Legions of Darkness/LoDState.swift" DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift
git commit -m "feat: implement LoD redeterminize — shuffle draw piles"
```

---

### Task 4: Hearts Void Constraint Computation

This is the core algorithm. We implement the backward trick-leader trace and void detection as a private helper on `Hearts.State`, then test it directly.

**Files:**
- Modify: `DynamicalSystems/Sources/Hearts/HeartsState.swift`
- Modify: `DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift`

- [ ] **Step 1: Write failing tests for void constraint detection**

Append to `RedeterminizeTests.swift`:

```swift
@Suite
struct HeartsVoidConstraintTests {
  // Deterministic deck: fullDeck dealt round-robin (index % 4 = seat).
  // North=0 gets indices 0,4,8,... East=1 gets 1,5,9,... etc.
  private func makeState(humanSeat: Hearts.Seat = .south) -> Hearts.State {
    var modes: [Hearts.Seat: PlayerMode] = [
      .north: .fastAI, .east: .fastAI,
      .south: .fastAI, .west: .fastAI
    ]
    modes[humanSeat] = .interactive
    let config = Hearts.HeartsConfig(
      playerModes: modes, scoreLimit: 100)
    return Hearts.State.newGame(
      config: config, shuffledDeck: Hearts.fullDeck)
  }

  @Test
  func noVoidsBeforeAnyPlay() {
    // Fresh state in passing phase — no tricks, no voids
    let state = makeState()
    let voids = state.computeVoidConstraints(humanSeat: .south)
    #expect(voids.isEmpty)
  }

  @Test
  func voidDetectedWhenPlayingOffSuit() {
    // Set up a state mid-trick where east played off-suit
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    // Simulate: south leads 5♣, west follows 7♣, north follows K♣,
    // east plays 3♥ (void in clubs)
    state.trickLeader = .south
    state.currentTrick = [
      Hearts.TrickPlay(seat: .south, card: Hearts.Card(suit: .clubs, rank: .five)),
      Hearts.TrickPlay(seat: .west, card: Hearts.Card(suit: .clubs, rank: .seven)),
      Hearts.TrickPlay(seat: .north, card: Hearts.Card(suit: .clubs, rank: .king)),
      Hearts.TrickPlay(seat: .east, card: Hearts.Card(suit: .hearts, rank: .three)),
    ]
    let voids = state.computeVoidConstraints(humanSeat: .south)
    #expect(voids[.east] == Set([Hearts.Card.Suit.clubs]))
    #expect(voids[.north] == nil)
    #expect(voids[.west] == nil)
  }

  @Test
  func backwardTraceRecoversTrickLeaders() {
    // Build a state with one completed trick in history and one in-progress.
    // Completed trick: south leads 2♣, west plays 3♣, north plays A♣, east plays 4♣.
    // North wins (ace of clubs). North becomes next leader.
    // In-progress trick: north leads 5♦, east plays 2♠ (void in diamonds).
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    // History: the completed trick's playCard actions + resolveTrick
    state.history = [
      .playCard(Hearts.Card(suit: .clubs, rank: .two)),   // south
      .playCard(Hearts.Card(suit: .clubs, rank: .three)),  // west
      .playCard(Hearts.Card(suit: .clubs, rank: .ace)),    // north
      .playCard(Hearts.Card(suit: .clubs, rank: .four)),   // east
      .resolveTrick,
    ]
    // Current trick (in-progress): north leads, east plays off-suit
    state.trickLeader = .north
    state.currentTrick = [
      Hearts.TrickPlay(seat: .north, card: Hearts.Card(suit: .diamonds, rank: .five)),
      Hearts.TrickPlay(seat: .east, card: Hearts.Card(suit: .spades, rank: .two)),
    ]
    let voids = state.computeVoidConstraints(humanSeat: .south)
    // East showed void in diamonds via the in-progress trick
    #expect(voids[.east] == Set([Hearts.Card.Suit.diamonds]))
  }

  @Test
  func multipleCompletedTricksBackwardTrace() {
    // Two completed tricks, no in-progress trick.
    // Trick 1: south leads 2♣, west 3♣, north A♣, east 4♣ → north wins (index 2)
    // Trick 2: north leads K♦, east 5♠ (void ♦), south Q♦, west 7♦ → south wins (index 2)
    // Current trick leader = south (winner of trick 2).
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 3
    state.history = [
      .playCard(Hearts.Card(suit: .clubs, rank: .two)),
      .playCard(Hearts.Card(suit: .clubs, rank: .three)),
      .playCard(Hearts.Card(suit: .clubs, rank: .ace)),
      .playCard(Hearts.Card(suit: .clubs, rank: .four)),
      .resolveTrick,
      .playCard(Hearts.Card(suit: .diamonds, rank: .king)),
      .playCard(Hearts.Card(suit: .spades, rank: .five)),
      .playCard(Hearts.Card(suit: .diamonds, rank: .queen)),
      .playCard(Hearts.Card(suit: .diamonds, rank: .seven)),
      .resolveTrick,
    ]
    state.trickLeader = .south
    state.currentTrick = []
    let voids = state.computeVoidConstraints(humanSeat: .south)
    // East played 5♠ when ♦ was led in trick 2 → void in ♦
    #expect(voids[.east] == Set([Hearts.Card.Suit.diamonds]))
    // No other voids
    #expect(voids[.north] == nil)
    #expect(voids[.west] == nil)
  }

  @Test
  func noVoidsDuringPlayingPhaseBeforeFirstCard() {
    // In playing phase, turnNumber = 1, but no cards played yet
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 1
    state.passingState = nil
    state.currentTrick = []
    let voids = state.computeVoidConstraints(humanSeat: .south)
    #expect(voids.isEmpty)
  }

  @Test
  func handStartIndexRespectsStartNewHand() {
    // History contains actions from a previous hand, then startNewHand,
    // then current hand's tricks. Voids from the previous hand are ignored.
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    state.handNumber = 1
    // Previous hand's trick (west played off-suit in spades — should be ignored)
    state.history = [
      .playCard(Hearts.Card(suit: .spades, rank: .ace)),
      .playCard(Hearts.Card(suit: .hearts, rank: .two)),
      .playCard(Hearts.Card(suit: .spades, rank: .king)),
      .playCard(Hearts.Card(suit: .spades, rank: .queen)),
      .resolveTrick,
      .scoreHand,
      .startNewHand(shuffledDeck: Hearts.fullDeck),
      // Current hand's trick: south leads ♣, all follow
      .playCard(Hearts.Card(suit: .clubs, rank: .two)),
      .playCard(Hearts.Card(suit: .clubs, rank: .three)),
      .playCard(Hearts.Card(suit: .clubs, rank: .ace)),
      .playCard(Hearts.Card(suit: .clubs, rank: .four)),
      .resolveTrick,
    ]
    state.trickLeader = .north
    state.currentTrick = []
    let voids = state.computeVoidConstraints(humanSeat: .south)
    // No voids in current hand — everyone followed suit
    #expect(voids.isEmpty)
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/HeartsVoidConstraintTests 2>&1 | tail -10`
Expected: FAIL — `computeVoidConstraints` does not exist yet.

- [ ] **Step 3: Implement `computeVoidConstraints`**

In `HeartsState.swift`, add a new extension:

```swift
// MARK: - Redeterminize Helpers

extension Hearts.State {
  /// Derive suit voids for each opponent from the current hand's trick history.
  /// A void is recorded when a player plays off-suit (card suit != led suit).
  /// Uses backward trick-leader tracing from `trickLeader` through completed
  /// tricks in `history`, plus direct inspection of `currentTrick`.
  func computeVoidConstraints(
    humanSeat: Hearts.Seat
  ) -> [Hearts.Seat: Set<Hearts.Card.Suit>] {
    var voids: [Hearts.Seat: Set<Hearts.Card.Suit>] = [:]

    // Find current hand's start in history
    let handStartIndex: Int
    if let idx = history.lastIndex(where: {
      if case .startNewHand = $0 { return true }
      return false
    }) {
      handStartIndex = idx + 1
    } else {
      handStartIndex = 0
    }

    // Extract completed tricks from history (groups of 4 playCard actions)
    var completedTricks: [[Hearts.Card]] = []
    var currentGroup: [Hearts.Card] = []
    for i in handStartIndex..<history.count {
      if case .playCard(let card) = history[i] {
        currentGroup.append(card)
        if currentGroup.count == 4 {
          completedTricks.append(currentGroup)
          currentGroup = []
        }
      }
    }
    // leftover cards belong to the in-progress trick handled via currentTrick

    // Backward-trace trick leaders.
    // trickLeaders[i] = leader of completed trick i.
    // trickLeaders[completedTricks.count] = state.trickLeader (current trick).
    let n = completedTricks.count
    var trickLeaders = Array(repeating: Hearts.Seat.south, count: n + 1)
    trickLeaders[n] = trickLeader

    for i in stride(from: n - 1, through: 0, by: -1) {
      let trick = completedTricks[i]
      let ledSuit = trick[0].suit
      let candidates = trick.enumerated().filter { $0.element.suit == ledSuit }
      let bestIdx = candidates.max(by: { $0.element.rank < $1.element.rank })!.offset
      trickLeaders[i] = trickLeaders[i + 1].offset(by: -bestIdx)
    }

    // Scan completed tricks for voids
    for (i, trick) in completedTricks.enumerated() {
      let leader = trickLeaders[i]
      let ledSuit = trick[0].suit
      for j in 1..<4 {
        let seat = leader.offset(by: j)
        if seat != humanSeat && trick[j].suit != ledSuit {
          voids[seat, default: Set()].insert(ledSuit)
        }
      }
    }

    // Scan in-progress trick for voids (currentTrick has TrickPlay with seat)
    if let firstPlay = currentTrick.first {
      let ledSuit = firstPlay.card.suit
      for play in currentTrick.dropFirst() {
        if play.seat != humanSeat && play.card.suit != ledSuit {
          voids[play.seat, default: Set()].insert(ledSuit)
        }
      }
    }

    return voids
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/HeartsVoidConstraintTests 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 5: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint DynamicalSystems/Sources/Hearts/HeartsState.swift DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift`
Expected: no new violations

- [ ] **Step 6: Commit**

```bash
git add DynamicalSystems/Sources/Hearts/HeartsState.swift DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift
git commit -m "feat: add computeVoidConstraints for Hearts redeterminize"
```

---

### Task 5: Hearts Redeterminize

Combine void constraints with shuffle-and-reject to implement the full override.

**Files:**
- Modify: `DynamicalSystems/Sources/Hearts/HeartsState.swift`
- Modify: `DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift`

- [ ] **Step 1: Write failing tests for Hearts redeterminize**

Append to `RedeterminizeTests.swift`:

```swift
@Suite
struct HeartsRedeterminizeTests {
  private func makeState(humanSeat: Hearts.Seat = .south) -> Hearts.State {
    var modes: [Hearts.Seat: PlayerMode] = [
      .north: .fastAI, .east: .fastAI,
      .south: .fastAI, .west: .fastAI
    ]
    modes[humanSeat] = .interactive
    let config = Hearts.HeartsConfig(
      playerModes: modes, scoreLimit: 100)
    return Hearts.State.newGame(
      config: config, shuffledDeck: Hearts.fullDeck)
  }

  @Test
  func redeterminizePreservesHumanHand() {
    var state = makeState()
    // Skip to playing phase
    state.phase = .playing
    state.turnNumber = 1
    state.passingState = nil
    state.player = .south

    let humanHand = state.hands[.south]!
    var rng = SeededRNG(state: 99)
    let result = state.redeterminize(using: &rng)
    #expect(result.hands[.south] == humanHand)
  }

  @Test
  func redeterminizePreservesTotalCards() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 1
    state.passingState = nil
    state.player = .south

    var rng = SeededRNG(state: 99)
    let result = state.redeterminize(using: &rng)
    let allBefore = Hearts.Seat.allCases.flatMap { state.hands[$0] ?? [] }
    let allAfter = Hearts.Seat.allCases.flatMap { result.hands[$0] ?? [] }
    #expect(Set(allBefore) == Set(allAfter))
  }

  @Test
  func redeterminizeRespectsVoidConstraints() {
    // Set up state where east is void in clubs, then redeterminize many times.
    // East should never receive a club.
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    state.passingState = nil
    state.trickLeader = .south
    // In-progress trick: south leads clubs, east plays off-suit
    state.currentTrick = [
      Hearts.TrickPlay(seat: .south, card: Hearts.Card(suit: .clubs, rank: .five)),
      Hearts.TrickPlay(seat: .west, card: Hearts.Card(suit: .clubs, rank: .seven)),
      Hearts.TrickPlay(seat: .north, card: Hearts.Card(suit: .clubs, rank: .king)),
      Hearts.TrickPlay(seat: .east, card: Hearts.Card(suit: .hearts, rank: .three)),
    ]
    // Remove played cards from hands
    state.hands[.south]?.removeAll { $0 == Hearts.Card(suit: .clubs, rank: .five) }
    state.hands[.west]?.removeAll { $0 == Hearts.Card(suit: .clubs, rank: .seven) }
    state.hands[.north]?.removeAll { $0 == Hearts.Card(suit: .clubs, rank: .king) }
    state.hands[.east]?.removeAll { $0 == Hearts.Card(suit: .hearts, rank: .three) }

    for seed: UInt64 in 1...20 {
      var rng = SeededRNG(state: seed)
      let result = state.redeterminize(using: &rng)
      let eastHand = result.hands[.east] ?? []
      let eastClubs = eastHand.filter { $0.suit == .clubs }
      #expect(eastClubs.isEmpty, "Seed \(seed): east got clubs \(eastClubs) despite void")
    }
  }

  @Test
  func redeterminizeReturnsSelfWhenNoHumanSeat() {
    // Config with all AI — no human seat
    let config = Hearts.HeartsConfig(playerModes: [
      .north: .fastAI, .east: .fastAI,
      .south: .fastAI, .west: .fastAI
    ], scoreLimit: 100)
    let state = Hearts.State.newGame(config: config, shuffledDeck: Hearts.fullDeck)
    let result = state.redeterminize()
    #expect(result == state)
  }

  @Test
  func redeterminizeDuringPassingPhase() {
    // During passing, no tricks exist. Shuffle is unconstrained.
    let state = makeState()
    #expect(state.phase == .passing)
    var rng = SeededRNG(state: 55)
    let result = state.redeterminize(using: &rng)
    // Human hand unchanged
    #expect(result.hands[.south] == state.hands[.south])
    // Total cards unchanged
    let allBefore = Hearts.Seat.allCases.flatMap { state.hands[$0] ?? [] }
    let allAfter = Hearts.Seat.allCases.flatMap { result.hands[$0] ?? [] }
    #expect(Set(allBefore) == Set(allAfter))
  }

  @Test
  func redeterminizeChangesOpponentHands() {
    // Verify that opponents' hands actually differ from original
    // (with overwhelming probability across multiple seeds).
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 1
    state.passingState = nil
    state.player = .south

    var anyDifferent = false
    for seed: UInt64 in 1...10 {
      var rng = SeededRNG(state: seed)
      let result = state.redeterminize(using: &rng)
      if result.hands[.north] != state.hands[.north]
        || result.hands[.east] != state.hands[.east]
        || result.hands[.west] != state.hands[.west] {
        anyDifferent = true
        break
      }
    }
    #expect(anyDifferent, "Opponents' hands should differ in at least one of 10 seeds")
  }

  @Test
  func redeterminizePreservesOpponentCardCounts() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 1
    state.passingState = nil
    state.player = .south

    let countsBefore: [Hearts.Seat: Int] = Dictionary(
      uniqueKeysWithValues: Hearts.Seat.allCases.map {
        ($0, state.hands[$0]?.count ?? 0)
      })
    var rng = SeededRNG(state: 77)
    let result = state.redeterminize(using: &rng)
    for seat in Hearts.Seat.allCases {
      #expect(result.hands[seat]?.count == countsBefore[seat])
    }
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/HeartsRedeterminizeTests 2>&1 | tail -10`
Expected: FAIL — `Hearts.State` uses the default (returns `self`), so hands are identical and the "Preserves human hand" test may vacuously pass, but the void constraint test will fail since the hands never actually change.

- [ ] **Step 3: Implement Hearts redeterminize**

In `HeartsState.swift`, add to the redeterminize helpers extension:

```swift
  func redeterminize(
    using generator: inout some RandomNumberGenerator
  ) -> Hearts.State {
    guard let humanSeat = config.humanSeat else { return self }
    let opponents = Hearts.Seat.allCases.filter { $0 != humanSeat }

    // Pool opponents' current (post-passing) cards
    var hiddenCards: [Hearts.Card] = []
    var opponentCounts: [Hearts.Seat: Int] = [:]
    for seat in opponents {
      let cards = hands[seat] ?? []
      hiddenCards.append(contentsOf: cards)
      opponentCounts[seat] = cards.count
    }
    guard hiddenCards.count > 1 else { return self }

    // Compute void constraints
    let voids = computeVoidConstraints(humanSeat: humanSeat)

    // Shuffle-and-reject
    for _ in 0..<100 {
      var shuffled = hiddenCards
      shuffled.shuffle(using: &generator)

      var candidate: [Hearts.Seat: [Hearts.Card]] = [:]
      var valid = true
      var offset = 0
      for seat in opponents {
        let count = opponentCounts[seat]!
        let assigned = Array(shuffled[offset..<(offset + count)])
        offset += count
        if let seatVoids = voids[seat],
           assigned.contains(where: { seatVoids.contains($0.suit) }) {
          valid = false
          break
        }
        candidate[seat] = assigned.sorted()
      }

      if valid {
        var result = self
        for seat in opponents {
          result.hands[seat] = candidate[seat]
        }
        result.syncPositions()
        return result
      }
    }

    return self
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/HeartsRedeterminizeTests 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 5: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint DynamicalSystems/Sources/Hearts/HeartsState.swift DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift`
Expected: no new violations

- [ ] **Step 6: Commit**

```bash
git add DynamicalSystems/Sources/Hearts/HeartsState.swift DynamicalSystems/DynamicalSystemsTests/RedeterminizeTests.swift
git commit -m "feat: implement Hearts redeterminize with void constraints"
```

---

### Task 6: Full Test Suite + Lint

Run the complete test suite and lint to verify nothing is broken.

- [ ] **Step 1: Run all tests**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`
Expected: All tests pass. Note: per project memory, mass test runner has pre-existing parallelism flakiness — if a few unrelated tests fail, re-run individual suites to confirm.

- [ ] **Step 2: Run full swiftlint**

Run: `cd DynamicalSystems && /opt/homebrew/bin/swiftlint`
Expected: no new violations from our changes

- [ ] **Step 3: Fix any issues found**

If tests fail or lint violations appear, fix them and re-run.

- [ ] **Step 4: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: address lint/test issues from redeterminize implementation"
```
