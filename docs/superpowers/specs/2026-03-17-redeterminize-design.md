# Redeterminize Design

## Goal

Add `func redeterminize() -> Self` to the `GameState` protocol so that each MCTS iteration can start from a reshuffled version of the hidden information. This implements the "determinization" technique from information-set MCTS (see *Dice, Cards, Action!* §4). The default returns `self`. Games with hidden state override it.

## Protocol Change

In `Game.swift`, add `redeterminize()` as a protocol requirement on `GameState`:

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

The parameterized form allows deterministic testing. The no-argument convenience form uses the system RNG.

All existing `GameState` conformers (Malayan Campaign, etc.) get the default for free.

## MCTS Integration

In `OpenLoopMCTS.recommendation(iters:numRollouts:)`, line 194 currently reads:

```swift
var state = rootState
```

Change to:

```swift
var state = rootState.redeterminize()
```

Each iteration now starts from a potentially different assignment of hidden information, so the tree statistics reflect uncertainty rather than a single fixed world.

## Hearts Implementation

### What is hidden

The human player (typically `.south`) knows their own hand but not the opponents' hands. The 9 (or fewer) cards held by the 3 opponents are the hidden information.

### Constraint: suit-following voids

Hearts requires following the led suit. When a player plays off-suit, they reveal a **void** — they have zero cards of the led suit. Once void in a suit, always void (cards only leave hands, never enter). A valid redeterminization must not give an opponent a card of a suit they've shown a void in.

### Algorithm

`Hearts.State.redeterminize() -> Hearts.State`:

1. **Guard**: if no `humanSeat` in config, return `self`. If opponents hold ≤ 1 card total, return `self`.

2. **Compute void constraints** from existing state data (no new fields):
   - Find the current hand's start in `history` (index after the last `.startNewHand`, or 0).
   - Extract all `.playCard(card)` actions from the current hand, grouped into tricks of 4. Only **completed** tricks (full groups of 4) enter the backward trace. Leftover cards from an incomplete trick are handled separately via `currentTrick`.
   - **Backward-trace trick leaders**: the current trick's leader is `state.trickLeader`. For each completed trick working backwards, the trick's cards determine the winning index (position of the highest card matching the led suit). The previous trick's leader is `nextTrickLeader.offset(by: -winningIndex)`.
   - With leaders known, each card's player is `leader.offset(by: cardIndex)`. For followers (index > 0): if `card.suit != ledSuit`, record `ledSuit` as a void for that seat.
   - For the **in-progress trick**, use `state.currentTrick` directly — each `TrickPlay` already carries its `.seat`. The leader is `state.trickLeader`, and the led suit is `currentTrick[0].card.suit`. For each follower where `play.card.suit != ledSuit`, record the void.

3. **Pool and shuffle**: collect all opponents' **current** (post-passing) cards into a single array. These are the cards the human cannot see. Shuffle.

4. **Redistribute**: split the shuffled cards back to opponents, preserving each opponent's original card count. **Reject** if any opponent receives a card of a suit they're void in.

5. **Retry**: up to 100 attempts. On success, copy `self`, replace opponents' hands with the candidate (sorted), call `syncPositions()`, return. On failure (100 misses), return `self`.

### Correctness argument

The void constraint is sufficient because:
- The human's hand is unchanged — they know their own cards. ✓
- Played cards are unchanged — they were in each player's hand when played. ✓
- When a player followed suit, they had at least the card they played. ✓
- When a player played off-suit, they had no cards of the led suit. The void constraint prevents assigning such cards. ✓
- Future play is unconstrained — the MCTS simulation will enforce rules naturally. ✓

### Efficiency

The backward trick-leader trace is O(tricks) — at most 13 per hand. The shuffle-and-check loop runs up to 100 times; each check is O(opponents × cards). Since `redeterminize()` is called once per MCTS iteration (which itself simulates a full game), the overhead is negligible.

If constraints are very tight (e.g., 3 opponents each void in 3 suits with 1 card remaining), the rejection sampling may fail often. The 100-attempt cap and fallback to `self` prevent this from becoming a bottleneck. In practice, tight constraints arise only near end-of-hand when few cards remain, so shuffle-and-check succeeds quickly.

## Legions of Darkness Implementation

### What is hidden

The remaining event cards in the draw piles. The player has seen played cards but not the order of upcoming draws.

### Algorithm

`LoD.State.redeterminize() -> LoD.State`:

```swift
var copy = self
copy.dayDrawPile.shuffle()
copy.nightDrawPile.shuffle()
return copy
```

No constraints — any permutation of the remaining draw pile is equally likely. Discard piles are face-up (known to the player) and need not be shuffled.

## Files Changed

| File | Change |
|------|--------|
| `Game.swift` | Add `redeterminize() -> Self` requirement to `GameState`, default extension |
| `OpenLoopMCTS.swift` | Line 194: `var state = rootState.redeterminize()` |
| `HeartsState.swift` | Add `redeterminize()` override + private `computeVoidConstraints` helper |
| `LoDState.swift` | Add `redeterminize()` override |

## Edge Cases

- **Passing phase**: no tricks played yet, no void constraints. Shuffle is unconstrained. ✓
- **Trick resolution phase** (4 cards played, not yet resolved): the 4th card is in `currentTrick`, so void detection covers it. ✓
- **Hand 0 vs later hands**: `startNewHand` presence in history distinguishes them. For hand 0, the hand starts at history index 0. ✓
- **All opponents have 0 cards**: guard returns `self`. ✓
- **Single card remaining across opponents**: guard returns `self` (shuffling 1 card is pointless). ✓
- **First-trick penalty rule** (can't play hearts/Q♠ on trick 1 when void in clubs, unless forced): this constrains which card was played, not whether a void exists. The void constraint still holds — if someone played off-suit on trick 1, they're void in clubs. ✓
