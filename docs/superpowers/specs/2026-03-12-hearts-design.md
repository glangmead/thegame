# Hearts Card Game — Design Spec

## Overview

4-player Hearts card game with 3 AI opponents (MCTS-driven) and 1 human player. Built on the existing ComposedGame/RulePage framework with SpriteKit rendering and SwiftUI action panel. Supports all-AI mode and configurable score limits.

## Rules

Standard 4-player trick-avoidance game, 52-card deck, 13 cards per player.

### Scoring
- Each heart: +1 point (13 total)
- Queen of Spades: +13 points
- Jack of Diamonds: -10 points (bonus)
- Shooting the moon (Old Moon): shooter scores 0, all others receive +26
- Game ends when any player reaches the score limit (configurable, default 100)
- Lowest cumulative score wins; tied players share the victory

### Card Passing
3 cards passed simultaneously before each hand. Direction rotates:

| Hand mod 4 | Direction |
|------------|-----------|
| 0 | Left |
| 1 | Right |
| 2 | Across |
| 3 | No pass (hold) |

Players choose cards to pass before seeing incoming cards.

### Trick Play
- 2 of clubs leads the first trick of each hand
- Must follow the led suit if able; otherwise may play any card
- First trick: no hearts or Queen of Spades (unless hand contains only penalty cards)
- Highest card of the led suit wins the trick; no trump
- Winner of each trick leads the next

### Hearts Breaking
- Hearts cannot be led until broken
- Hearts are broken when a heart or Queen of Spades is discarded on a non-heart trick
- Exception: if a player holds only hearts, they may lead a heart even if unbroken

## Types

### Hearts.Seat
```swift
enum Seat: CaseIterable, Hashable, Sendable {
  case north, east, south, west
}
```
Compass positions. Configurable human assignment; default `.south`. `nil` for all-AI.

### Hearts.Card
```swift
struct Card: Hashable, Comparable, Sendable {
  enum Suit: Int, CaseIterable, Comparable { case clubs, diamonds, spades, hearts }
  enum Rank: Int, CaseIterable, Comparable { case two = 2, three, ..., ace = 14 }
  let suit: Suit
  let rank: Rank
}
```
`Comparable` orders by suit then rank (clubs < diamonds < spades < hearts).

### Hearts.PassDirection
```swift
enum PassDirection: Sendable { case left, right, across, none }
```
Computed from `handNumber % 4`.

### Hearts.Phase
```swift
enum Phase: Hashable, Sendable {
  case passing, playing, trickResolution, handEnd, gameEnd
}
```

### GameComponents associated types
```swift
typealias Piece = Card
typealias Position = CardPosition
typealias PiecePosition = CardPosition  // same type; no separate concept needed

enum CardPosition: Hashable, Sendable {
  case inHand(Seat)
  case inTrick(seatIndex: Int)  // 0–3 position in current trick
  case inWonPile(Seat)
  case inDeck  // not yet dealt
}
```

### HeartsConfig
```swift
struct HeartsConfig: Equatable, Sendable {
  var humanSeat: Seat? = .south
  var scoreLimit: Int = 100
  var aiDelaySeconds: Double = 0.75
}
```

## State

```swift
Hearts.State: HistoryTracking, GameState, Equatable, Sendable, CustomStringConvertible
```

### GameState conformance
- `player: Seat` — current turn
- `players: [Seat]` — `[.north, .east, .south, .west]`
- `ended: Bool`, `endedInVictoryFor: [Seat]`, `endedInDefeatFor: [Seat]`
- `position: [Piece: Position]` — card positions for SpriteKit

### HistoryTracking conformance
- `history: [Hearts.Action]`
- `phase: Phase`

### Game-specific fields
- `hands: [Seat: [Card]]` — each player's current hand
- `currentTrick: [(seat: Seat, card: Card)]` — 0–4 cards in the current trick
- `trickLeader: Seat` — who leads the current trick
- `heartsBroken: Bool`
- `gameAcknowledged: Bool` — set true by `.declareWinner`; `isTerminal` requires both `ended && gameAcknowledged`
- `passingState: PassingState?` — sub-state during passing phase
  - `selected: [Card]` — 0–3 cards picked so far
  - `direction: PassDirection`
- `tricksTaken: [Seat: [[Card]]]` — won cards grouped by trick
- `handPenalties: [Seat: Int]` — penalty points this hand
- `cumulativeScores: [Seat: Int]`
- `handNumber: Int`
- `turnNumber: Int` — trick count within the hand (1–13)
- `config: HeartsConfig`

### Derived properties
- `passDirection: PassDirection` — from `handNumber % 4`
- `legalPlays: [Card]` — legal cards for current player given trick state, hearts broken, first-trick rules
- `isShootingTheMoon(seat:) -> Bool`

### Text rendering
`CustomStringConvertible` produces a readable dump:
```
═══ Hearts: Hand 3 / Trick 7 ═══
Pass: Across | Hearts: broken

  North (AI):  [13 cards]
  East  (AI):  [13 cards]
  South (You): 3♥ 7♥ J♠ Q♦ 4♣ 8♠ 10♦ A♠
  West  (AI):  [13 cards]

  Trick: North→5♣  West→K♣  East→2♣  South→_

  Scores:  N:14  E:23  S:8  W:31
```
Hands sorted by suit (♣♦♠♥) then rank. AI hands show card count only.

## Actions

```swift
enum Hearts.Action: Hashable, CustomStringConvertible {
  // Passing phase (sub-state pattern)
  case selectPassCard(Card)
  case confirmPass(aiPasses: [Seat: [Card]])  // packs AI choices for deterministic replay

  // Playing phase
  case playCard(Card)

  // Trick resolution (auto-dispatched follow-up)
  case resolveTrick

  // Hand end
  case scoreHand
  case startNewHand(shuffledDeck: [Card])  // packs deck order for deterministic replay

  // Game end
  case declareWinner
}
```

Actions are value types packing all parameters for deterministic history replay. Random values (AI pass choices, deck shuffle order) are computed by the caller and embedded in the action so that replaying the history reproduces the exact same state. AI vs human distinction lives in the view layer, not in the action enum.

No `GroupedAction` conformance — Hearts actions are flat with at most ~13 options per turn, so sectioned display is unnecessary.

## RulePages

### passingPage
- Active when `passingState != nil`
- Rule 1: `selected.count < 3` → `.selectPassCard(card)` for each card in hand
- Rule 2: `selected.count == 3` → `.confirmPass`
- `.confirmPass(aiPasses:)` reduce: human's 3 selected cards come from `passingState.selected`; AI choices come from the action's `aiPasses` parameter (pre-computed by the caller — random during live play, deterministic during replay). Execute all 4 passes simultaneously, clear `passingState`, transition to `.playing`. Set `player` to whoever holds the 2 of clubs.

### singlePlayPage
- Active during `.playing` phase
- Rule: `.playCard(card)` for each card in `legalPlays`
- Reduce: append card to `currentTrick`, advance `player` clockwise to next seat. When `currentTrick.count == 4`, emit `.resolveTrick` as follow-up.

### trickPage
- Handles `.resolveTrick`
- Reduce: determine winner (highest card of led suit), move cards to `tricksTaken[winner]`, update `heartsBroken` if any heart or Q♠ was played, set `trickLeader = winner`, set `player = winner` (winner leads next trick), increment `turnNumber`. If trick 13, emit `.scoreHand` as follow-up. Otherwise transition to `.playing` phase — if `player` (the trick winner) is an AI seat, the view layer's AI loop picks this up and runs MCTS for the next play.

### handPage
- Handles `.scoreHand` and `.startNewHand`
- `.scoreHand` reduce: compute penalties, check shooting the moon (Old Moon), update `cumulativeScores`. If any score >= `scoreLimit`, set `ended`, populate victory/defeat arrays, transition to `.gameEnd`. Otherwise offer `.startNewHand`.
- `.startNewHand(shuffledDeck:)` reduce: deal 13 cards to each seat from the pre-shuffled deck (packed in the action for deterministic replay), increment `handNumber`, reset `turnNumber` to 0, clear `heartsBroken`, clear `tricksTaken` and `handPenalties`, set up `passingState` (or skip to `.playing` for hold hands and set `player` to holder of 2♣).

### gameEndPage (priority)
- Condition: `ended && !gameAcknowledged`
- Offers `.declareWinner`
- Reduce: set `gameAcknowledged = true`

### phaseForAction mapping
```swift
{ action in
  switch action {
  case .selectPassCard, .confirmPass: return .passing
  case .playCard:                     return .playing
  case .resolveTrick:                 return .trickResolution
  case .scoreHand, .startNewHand:     return .handEnd
  case .declareWinner:                return .gameEnd
  }
}
```

### Composed game
```swift
oapply(
  pages: [passingPage, singlePlayPage, trickPage, handPage],
  priorities: [gameEndPage],
  initialState: { Hearts.State.newGame(config: config, shuffledDeck: deck) },
  isTerminal: { $0.ended && $0.gameAcknowledged },
  phaseForAction: { ... },
  stateEvaluator: heartsEvaluator
)
```

## SpriteKit Scene

### HeartsSceneConfig
- Green felt background
- 4 player positions at compass points
- Center trick area: 4 card positions in a cross layout
- Score labels rendered on the field near each player
- South: face-up SVG card images in a fan
- North/East/West: card back images, card count indicator

### HeartsPieceAdapter
Maps `Hearts.State` to `[GamePiece]`:
- Cards in hands → pieces in player fan zones
- Cards in `currentTrick` → pieces in center, offset by seat
- Won trick stacks → pile indicator (count, not individual cards)

### HeartsGraph
Minimal `SiteGraph` with ~12 sites:
- 4 hand zones (one per seat)
- 4 trick-play positions (center cross)
- 4 won-tricks pile positions

Well-known IDs at 500+ per project convention.

## Card Art

SVG assets from saulspatz/SVGCards (public domain / Byron Knoll):
- 52 card faces from `Decks/Vertical2/svgs/`
- Card backs: `blueBack.svg` and `redBack.svg`
- Added to Xcode asset catalog as SVG-backed image sets
- SVGs in the asset catalog are rasterized by the asset system; SpriteKit loads them via `SKTexture(imageNamed:)`

Minor provenance note: the Ace of Spades was vectorized from Suzanne Tyson artwork; if this matters, substitute from another source.

## View Layer

### HeartsView
SwiftUI, same responsive split layout as LoDView:
- `SpriteView(scene:)` — the card table
- SwiftUI side panel:
  - **Status bar**: hand number, turn number, pass direction
  - **MCTSActionSection**: legal plays or pass selections with MCTS win% stats
  - **Log**: trick history ("East wins trick 4: K♣ > 5♣ > 2♣ > A♣")

Landscape = side-by-side. Portrait = tabbed.

### AI turn loop
When `state.player != config.humanSeat`:
1. Run MCTS `recommendation(iters:)` on background task
2. Wait `config.aiDelaySeconds` (0.75s default)
3. Apply best action
4. Repeat until human's turn or game ends

AI plays within a trick are sequential with delays so the user sees cards appear one at a time.

### All-AI mode
When `config.humanSeat == nil`, the entire game auto-plays. Useful for testing and observing AI behavior.

## MCTS Integration

### Algorithm
OpenLoopMCTS as-is, no determinization. The open-loop structure averages over opponent behaviors via random rollouts without explicitly resampling hidden hands. Determinization (IS-MCTS) deferred to a future standalone project.

### State evaluator
Score-based relative standing heuristic. Each AI seat creates its own MCTS instance with itself as `rootState.player`. The `PlayableGame.stateEvaluator` closure evaluates from the perspective of `rootState.player` (which is the seat being decided for). The backprop loop applies this value to all players' trees, but `recommendation()` only reports stats for `rootState.player`, so the incorrect values on opponent trees are harmless — they are never read.

```swift
// The evaluator always evaluates from state.player's perspective.
// Each AI seat creates its own MCTS with itself as rootState.player.
func heartsEvaluator(_ state: Hearts.State) -> Float {
  let seat = state.player
  let myPenalties = state.cumulativeScores[seat]! + state.handPenalties[seat]!
  let maxPenalties = max across all seats
  let minPenalties = min across all seats

  if myPenalties == minPenalties { return 1.0 }
  if maxPenalties == minPenalties { return 0.5 }
  return 1.0 - Float(myPenalties - minPenalties) / Float(maxPenalties - minPenalties)
}
```

### Rollout policy
Random legal play (default). Hands are 13 tricks (52 actions max), so rollouts are fast.

### Iteration count
Default 500 iterations per AI decision. Tunable based on play quality vs response time.

## Gamer CLI

Hearts wired into the existing `gamer` CLI tool:
- `Hearts.State` conforms to `TextTableAble` (required by `GameRunner`) in addition to `CustomStringConvertible`
- `printTable(to:)` renders the same text format as `description`
- Lists numbered legal actions
- Accepts keyboard input to pick an action
- AI turns auto-play with text state printed after each
- Same pattern as Malayan Campaign and LoD

## Testing

Swift Testing framework (not XCTest). All test files in `DynamicalSystemsTests/` (auto-discovered by test target). Source files in `Sources/Hearts/` require `membershipExceptions` additions.

### HeartsComponentsTests
- Card comparison, suit/rank ordering
- Deck creation: 52 cards, no duplicates
- Legal play computation: all edge cases (void in suit, first trick restrictions, hearts not broken, only-hearts exception, only-penalty-cards exception)

### HeartsStateTests
- Deal: 4 hands of 13
- Pass mechanics: correct seats for each direction
- Trick resolution: highest of led suit wins
- Hearts broken detection
- Shooting the moon: Old Moon scoring
- Jack of Diamonds: -10 applied
- Score accumulation across hands
- Game end at score limit
- Winner determination (lowest score, ties)

### HeartsComposedGameTests
- Full hand playthrough: deal → pass → 13 tricks → scoring
- Full game to score limit
- Phase transitions: passing → playing → trickResolution → handEnd → new hand
- Follow-up cascading: trick → score → new hand
- gameEndPage priority fires at score limit
- Pass direction rotation over 4+ hands
- Hold hand (no pass) works
- AI vs AI full game completes without crashes
- MCTS produces legal actions

## File Organization

```
Sources/Hearts/
  HeartsComponents.swift    — Seat, Card, Suit, Rank, PassDirection, Phase, HeartsConfig
  HeartsState.swift         — State struct, setup, derived properties, CustomStringConvertible
  HeartsAction.swift        — Action enum, GroupedAction conformance
  HeartsGame.swift          — composedGame(), oapply wiring
  HeartsPages.swift         — passingPage, singlePlayPage, trickPage, handPage, gameEndPage
  HeartsGraph.swift         — SiteGraph with ~12 sites
  HeartsPieceAdapter.swift  — State → [GamePiece] mapping
  HeartsSceneConfig.swift   — SceneConfig for green felt table
  HeartsView.swift          — SwiftUI view with SpriteKit + panel
  HeartsEvaluator.swift     — MCTS state evaluator
  HeartsText.swift          — CustomStringConvertible, TextTableAble conformance

DynamicalSystemsTests/
  HeartsComponentsTests.swift
  HeartsStateTests.swift
  HeartsComposedGameTests.swift
```
