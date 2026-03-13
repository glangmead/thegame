# Player Configuration Modal Design

**Date:** 2026-03-13

## Goal

Add a per-game configuration modal that lets the user assign each player seat to one of: Interactive (human), Fast AI (50 MCTS iterations), Slow AI (1500 MCTS iterations), or None (player excluded). A toolbar gear button in each game view presents the modal. Changing configuration resets the game.

## PlayerMode Enum

Framework-level enum in a new file `PlayerConfig.swift`:

```swift
enum PlayerMode: String, CaseIterable, Identifiable {
  case interactive = "Interactive"
  case fastAI = "Fast AI"
  case slowAI = "Slow AI"
  case none = "None"

  var id: String { rawValue }

  var mctsIterations: Int? {
    switch self {
    case .interactive: nil
    case .fastAI: 50
    case .slowAI: 1500
    case .none: nil
    }
  }
}
```

## PlayerConfigSheet

Generic reusable view in `PlayerConfig.swift`:

```swift
struct PlayerSlot<Player: Hashable>: Identifiable {
  let player: Player
  let label: String
  let allowedModes: [PlayerMode]
  var id: String { label }
}

struct PlayerConfigSheet<Player: Hashable>: View {
  let slots: [PlayerSlot<Player>]
  @Binding var modes: [Player: PlayerMode]
  let onStart: () -> Void

  var body: some View {
    NavigationStack {
      Form {
        ForEach(slots) { slot in
          Picker(slot.label, selection: binding(for: slot.player)) {
            ForEach(slot.allowedModes) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
        }
      }
      .navigationTitle("Configure Players")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Start") { onStart() }
        }
      }
    }
  }

  private func binding(for player: Player) -> Binding<PlayerMode> {
    Binding(
      get: { modes[player, default: .interactive] },
      set: { modes[player] = $0 }
    )
  }
}
```

## GameModel Changes

`GameModel.swift` modifications:

1. **Log accumulation** — `var logs: [Log] = []`. The existing `perform(_:)` method appends returned logs to `self.logs` (inserted at index 0 for reverse-chronological display). Views read `model.logs` instead of keeping their own `@State var logs`.

2. **Scene sync closure** — `var syncScene: () -> Void = {}`. Each view sets this at init time, capturing its scene, pieces, graph, and adapter logic. Called after every action.

3. **Game reset** — `game` becomes `var`. New method:
   ```swift
   func reset(with game: some PlayableGame<State, Action>) {
     self.game = game
     self.state = game.newState()
     self.logs = []
   }
   ```

4. **`isTerminal` convenience** — expose `var isTerminal: Bool { game.isTerminal(state: state) }` for use by the AI scheduler.

## AI Scheduling

A free function in `MCTSActionSection.swift` (or a new file):

```swift
func scheduleAIMove<State, Action>(
  model: GameModel<State, Action>,
  playerModes: [State.Player: PlayerMode],
  performAction: @escaping (Action) -> Void
) -> Task<Void, Never>?
```

Logic:
1. Look up `playerModes[model.state.player]`. If `.interactive` or `.none`, return `nil`.
2. Get allowed actions. If empty, return `nil`.
3. If one action, pick it directly.
4. Otherwise run `mctsRecommendation` on a detached task with the mode's iteration count.
5. Pick the action with the highest value/visit ratio.
6. Compute elapsed time. If under 0.5 seconds, sleep for the remainder.
7. Call `performAction` with the chosen action.

Each view stores `@State var aiTask: Task<Void, Never>?` and triggers scheduling reactively:

```swift
.onChange(of: model.state) {
  aiTask?.cancel()
  aiTask = scheduleAIMove(
    model: model,
    playerModes: playerModes,
    performAction: performAction
  )
}
```

The `onChange` fires after every state mutation. For interactive turns, `scheduleAIMove` returns `nil`. For AI turns, the scheduled task runs MCTS and calls `performAction`, which mutates state, which triggers `onChange` again — forming the auto-play loop.

## Shared performAction Pattern

Each view's `performAction` reduces to:

```swift
func performAction(_ action: SomeGame.Action) {
  model.perform(action)        // logs handled internally
  cachedActions = model.allowedActions  // suppress if AI turn (see refreshActions below)
  model.syncScene()
}
```

`refreshActions` becomes mode-aware: return `[]` when the current player is not `.interactive` or the game has ended.

## Per-Game Integration

### Can't Stop

- **Defaults:** Player 1 = Interactive, Player 2 = Fast AI, Players 3–4 = None.
- **Slots:** Players 1–2 get `[.interactive, .fastAI, .slowAI]`. Players 3–4 get those plus `.none`.
- **State.init** takes a `players: [Player]` parameter (currently hardcoded to `[.player1, .player2]`).
- **resetGame()** derives active players from `playerModes` (exclude `.none`), rebuilds game and model.

### Hearts

- **Defaults:** South = Interactive, East/North/West = Fast AI.
- **Slots:** All four seats get `[.interactive, .fastAI, .slowAI]` (no `.none` — Hearts requires 4 players).
- **HeartsConfig** drops `humanSeat` in favor of `playerModes: [Seat: PlayerMode]`.
- **confirmPass AI logic** moves from HeartsView into the Hearts rules engine. During the passing phase, AI seats auto-select their pass cards in `reduce` rather than the view intercepting the action.
- **HeartsView.init** no longer takes a `config` parameter. Manages its own `playerModes` state.
- **DynamicalSystemsApp** changes from `HeartsView(config: ...)` to `HeartsView()`.

### Legions of Darkness

- **Defaults:** Solo = Interactive.
- **Slots:** One entry: `("Solo", [.interactive, .fastAI, .slowAI])`.
- Toolbar button, sheet, AI scheduling via shared `onChange`.

### Battle Card: Market Garden

- **Defaults:** Solo = Interactive.
- **Slots:** One entry: `("Solo", [.interactive, .fastAI, .slowAI])`.
- Same treatment as LoD.

### Malayan Campaign

- **Defaults:** Solo = Interactive.
- **Slots:** One entry: `("Solo", [.interactive, .fastAI, .slowAI])`.
- Same treatment as LoD.

## Game Reset Flow

When the user taps "Start" on the config sheet:

1. Cancel `aiTask`.
2. Derive active players from `playerModes` (exclude `.none` entries).
3. Rebuild the game via the factory function with the new player list.
4. Call `model.reset(with: newGame)`.
5. Reset `cachedActions`.
6. Re-sync the scene (via `model.syncScene()`).
7. Dismiss the sheet (`showConfig = false`).

## Files Changed

**New framework file:**
- `Framework/PlayerConfig.swift` — `PlayerMode`, `PlayerSlot`, `PlayerConfigSheet`

**Modified framework files:**
- `Framework/GameModel.swift` — logs, syncScene closure, reset method, game becomes var
- `Framework/MCTSActionSection.swift` — add `scheduleAIMove` free function

**Modified game views (all 5):**
- `CantStopView.swift` — playerModes state, toolbar button, sheet, resetGame, onChange AI scheduling
- `HeartsView.swift` — replace humanSeat with playerModes, remove confirmPass interception, add toolbar/sheet/reset
- `LoDView.swift` — playerModes state, toolbar button, sheet, AI scheduling
- `MCView.swift` — same as LoD
- `BCView.swift` — same as LoD

**Modified game files:**
- `CantStopState.swift` — init takes players parameter
- `HeartsComponents.swift` — HeartsConfig uses playerModes instead of humanSeat
- Hearts rule pages — confirmPass AI logic moves from view into rules engine

**Modified app entry:**
- `DynamicalSystemsApp.swift` — HeartsView() called without config parameter

**No changes to:**
- MCTSActionSection view itself (advisory MCTS for interactive turns unchanged)
- OpenLoopMCTS.swift
- ComposedGame.swift, RulePage.swift, game protocols
