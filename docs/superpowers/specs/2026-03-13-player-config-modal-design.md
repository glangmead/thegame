# Player Configuration Modal Design

**Date:** 2026-03-13

## Goal

Add a per-game configuration modal that lets the user assign each player seat to one of: Interactive (human), Fast AI (50 MCTS iterations), Slow AI (1500 MCTS iterations), or Excluded (player removed from game). A toolbar gear button in each game view presents the modal. Changing configuration resets the game.

## PlayerMode Enum

Framework-level enum in a new file `PlayerConfig.swift`:

```swift
enum PlayerMode: String, CaseIterable, Identifiable {
  case interactive = "Interactive"
  case fastAI = "Fast AI"
  case slowAI = "Slow AI"
  case excluded = "None"

  var id: String { rawValue }

  var mctsIterations: Int? {
    switch self {
    case .interactive: nil
    case .fastAI: 50
    case .slowAI: 1500
    case .excluded: nil
    }
  }
}
```

Note: The case is named `.excluded` (not `.none`) to avoid ambiguity with `Optional.none`. The raw value remains `"None"` for display.

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

  @Environment(\.dismiss) private var dismiss

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
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
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

1. **Log accumulation** — `var logs: [Log] = []`. The existing `perform(_:)` method prepends returned logs to `self.logs` (inserted at index 0 for reverse-chronological display). Views read `model.logs` instead of keeping their own `@State var logs`. All games accumulate logs; the previous behavior where BC and MC replaced logs on each action is superseded.

2. **Game reset** — `game` becomes `var`. New method:
   ```swift
   func reset(with game: some PlayableGame<State, Action>) {
     self.game = game
     self.state = game.newState()
     self.logs = []
   }
   ```

3. **`isTerminal` convenience** — expose `var isTerminal: Bool { game.isTerminal(state: state) }` for use by the AI scheduler.

Note: `syncScene` is NOT placed on `GameModel`. Scene syncing is a view concern. Each view handles it reactively via `.onChange(of: model.state)` — see the AI Scheduling section.

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
1. If `model.isTerminal`, return `nil`.
2. Look up `playerModes[model.state.player]`. If `.interactive` or `.excluded`, return `nil`.
3. Get allowed actions. If empty, return `nil`.
4. If one action, pick it directly.
5. Otherwise run `mctsRecommendation` on a detached task with the mode's iteration count.
6. Pick the action with the highest value/visit ratio.
7. Compute elapsed time. If under 0.5 seconds, sleep for the remainder.
8. Call `performAction` with the chosen action.

Each view stores `@State var aiTask: Task<Void, Never>?` and triggers scheduling reactively:

```swift
.onChange(of: model.state) {
  refreshActions()
  syncScene()  // view-local method
  aiTask?.cancel()
  aiTask = scheduleAIMove(
    model: model,
    playerModes: playerModes,
    performAction: performAction
  )
}
.onDisappear { aiTask?.cancel() }
```

The `onChange` fires after every state mutation. It handles three concerns: refreshing the action list, syncing the scene, and scheduling AI. For interactive turns, `scheduleAIMove` returns `nil`. For AI turns, the scheduled task runs MCTS and calls `performAction`, which mutates state, which triggers `onChange` again — forming the auto-play loop. The loop terminates when the game reaches a terminal state (step 1) or when allowed actions are empty (step 3).

**All-AI play** is a supported use case. When all players are set to AI modes, the loop runs continuously with a 0.5-second minimum delay per move. A full Hearts game with all Fast AI players will take several minutes. This is intentional for watchability.

## Shared performAction Pattern

Each view's `performAction` reduces to:

```swift
func performAction(_ action: SomeGame.Action) {
  model.perform(action)  // logs handled internally by GameModel
}
```

The `onChange(of: model.state)` handler in the view body handles refreshing actions and syncing the scene after every state mutation (whether from interactive or AI play).

`refreshActions` becomes mode-aware: return `[]` when the current player is not `.interactive` or the game has ended.

## Per-Game Integration

### Player Types by Game

Each game has a concrete `Player` type. The `playerModes` dictionary is keyed by this type, and `scheduleAIMove` looks up `model.state.player` in the dictionary.

| Game | Player type | `state.player` values | Notes |
|------|-------------|----------------------|-------|
| Can't Stop | `CantStop.Player` | `.player1` through `.player4` | Active players filtered by `.excluded` |
| Hearts | `Hearts.Seat` | `.north`, `.east`, `.south`, `.west` | Always all 4 seats |
| Legions of Darkness | `LoD.Player` | `.solo` | Single-player |
| Battle Card | `BC.Player` | `.solo` | Single-player |
| Malayan Campaign | `MC.Player` | `.solo` | Single-player |

### Can't Stop

- **Defaults:** Player 1 = Interactive, Player 2 = Fast AI, Players 3–4 = Excluded.
- **Slots:** Players 1–2 get `[.interactive, .fastAI, .slowAI]`. Players 3–4 get those plus `.excluded`.
- **State.init** takes a `players: [Player]` parameter (currently hardcoded to `[.player1, .player2]`).
- **Factory chain:** `CantStopPages.game(players:)` passes the player list into the `ComposedGame`'s `makeInitialState` closure, which calls `State(players: activePlayers)`.
- **resetGame()** derives active players from `playerModes` (exclude `.excluded`), rebuilds game via `CantStopPages.game(players:)`, calls `model.reset(with:)`, and recreates the `GameScene` (since the piece set changes with player count — placeholder pieces for excluded players don't exist).

### Hearts

- **Defaults:** South = Interactive, East/North/West = Fast AI.
- **Slots:** All four seats get `[.interactive, .fastAI, .slowAI]` (no `.excluded` — Hearts requires 4 players).
- **HeartsConfig** drops `humanSeat` in favor of `playerModes: [Seat: PlayerMode]`.
- **confirmPass AI logic** moves from HeartsView into the Hearts rules engine. `HeartsConfig` stores `playerModes`, which is available in `State` and thus in `reduce`. During the passing phase, non-interactive seats auto-select their pass cards (first 3 cards) in the reduce function. During MCTS rollouts, the rollout policy handles all seats uniformly (random selection), so the interactive/AI distinction does not affect rollout behavior — `playerModes` is only consulted at the top-level game loop.
- **HeartsView.init** no longer takes a `config` parameter. Manages its own `playerModes` state.
- **DynamicalSystemsApp** changes from `HeartsView(config: ...)` to `HeartsView()`.

### Legions of Darkness

- **Defaults:** Solo = Interactive.
- **Slots:** One entry: `PlayerSlot(player: LoD.Player.solo, label: "Solo", allowedModes: [.interactive, .fastAI, .slowAI])`.
- Toolbar gear button in the navigation bar (separate from the existing Map/Grid toggle in the status bar).
- AI scheduling via shared `onChange`.

### Battle Card: Market Garden

- **Defaults:** Solo = Interactive.
- **Slots:** One entry: `PlayerSlot(player: BC.Player.solo, label: "Solo", allowedModes: [.interactive, .fastAI, .slowAI])`.
- Same treatment as LoD.

### Malayan Campaign

- **Defaults:** Solo = Interactive.
- **Slots:** One entry: `PlayerSlot(player: MC.Player.solo, label: "Solo", allowedModes: [.interactive, .fastAI, .slowAI])`.
- Same treatment as LoD.

## Game Reset Flow

When the user taps "Start" on the config sheet:

1. Cancel `aiTask`.
2. Derive active players from `playerModes` (exclude `.excluded` entries).
3. Rebuild the game via the factory function with the new player list.
4. Call `model.reset(with: newGame)`.
5. Reset `cachedActions`.
6. Recreate and re-sync the scene. For Can't Stop, the scene must be fully recreated because the piece set depends on the player count. For other games where the piece set is fixed, calling the view's `syncScene()` method suffices.
7. Dismiss the sheet (`showConfig = false`).

## Persistence

Player mode selections are not persisted across navigation events. When the user leaves a game view and returns, defaults are restored. Persistence via `@AppStorage` or similar is explicitly deferred — it can be added later without architectural changes.

## Files Changed

**New framework file:**
- `Framework/PlayerConfig.swift` — `PlayerMode`, `PlayerSlot`, `PlayerConfigSheet`

**Modified framework files:**
- `Framework/GameModel.swift` — logs accumulation, reset method, game becomes var, isTerminal convenience
- `Framework/MCTSActionSection.swift` — add `scheduleAIMove` free function

**Modified game views (all 5):**
- `CantStopView.swift` — playerModes state, toolbar button, sheet, resetGame (with scene recreation), onChange AI scheduling, onDisappear cleanup
- `HeartsView.swift` — replace humanSeat with playerModes, remove confirmPass interception, remove HeartsAI.swift bespoke scheduling, add toolbar/sheet/reset, onDisappear cleanup
- `LoDView.swift` — playerModes state, toolbar button, sheet, AI scheduling, onDisappear cleanup
- `MCView.swift` — same as LoD
- `BCView.swift` — same as LoD

**Modified game files:**
- `CantStopState.swift` — init takes players parameter
- `CantStopPages.swift` — `game(players:)` factory accepts player list
- `HeartsComponents.swift` — HeartsConfig uses playerModes instead of humanSeat
- Hearts rule pages — confirmPass AI logic moves from view into rules engine

**Deleted file:**
- `HeartsAI.swift` — its logic is replaced by the shared `scheduleAIMove` function

**Modified app entry:**
- `DynamicalSystemsApp.swift` — HeartsView() called without config parameter

**No changes to:**
- MCTSActionSection view itself (advisory MCTS for interactive turns unchanged)
- OpenLoopMCTS.swift
- ComposedGame.swift, RulePage.swift, game protocols
