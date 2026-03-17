# AutoRule: Reactive Rules for Cross-Cutting Game Logic

## Problem

RulePage reducers accumulate conditional follow-up logic that belongs to
separate game concepts. The armyPage reducer handles acid upgrade attacks,
bloody battle marker placement, and phase transitions — none of which are
"army advancement." The paladin re-roll check is threaded through every
die-roll page via `resolveDieRollWithPaladinCheck`. These cross-cutting
concerns should be independent declarations, not embedded in unrelated
reducers.

## Design Philosophy

Two mechanisms handle two concerns:

| Concern | Mechanism | Example |
|---------|-----------|---------|
| Automatic consequence of a resolved action | AutoRule | Acid attack after advancement |
| Interruption requiring player input | Branching reducer + re-dispatch | Paladin re-roll |

**AutoRules** fire silently after an action resolves. They react to state and
mutate it. They never emit follow-up actions or return choices directly. An
auto-rule may set up state that a subsequent `GameRule` reads to offer a
player choice (e.g., setting `pendingBloodyBattleChoices`), but the auto-rule
itself only mutates state and returns logs.

**Interruptions** are handled by page reducers that detect the need for player
input, stash partial state, and return early. The intervention plays out
through normal choice rules. When done, the original action is re-dispatched
and the reducer takes the resolution path using stashed state.

## AutoRule Type

```swift
struct AutoRule<State> {
  let name: String
  let when: (State) -> Bool
  let apply: (inout State) -> [Log]
}
```

- `when` — predicate on state (may inspect `state.history.last` to check
  which action just fired).
- `apply` — mutates state, returns logs. No follow-up actions emitted.
- Auto-rules fire in list order. Each sees the state left by the prior rule.

## Dispatch Loop

`ComposedGame.reduce` changes from:

1. Append action to history, update cached phase.
2. Dispatch to first matching page reducer (priorities first).
3. Recursively dispatch follow-up actions.
4. Return logs.

To:

1. Append action to history, update cached phase.
2. Dispatch to first matching page reducer (priorities first).
3. Recursively dispatch follow-up actions.
4. **Scan `autoRules`. For each rule where `when(state)` holds, call
   `apply(&state)` and collect logs.**
5. Return logs.

Auto-rules fire after every `reduce` call, including recursive calls for
follow-up actions. Each call to `reduce` independently appends its action to
history, runs the page reducer, dispatches follow-ups, then scans auto-rules.
This is safe because each auto-rule's `when` predicate checks
`state.history.last` (or equivalent state), so it only matches the specific
action that just resolved. A follow-up like `.skipEvent` will not trigger an
auto-rule that checks for `.advanceArmies`.

## Determinism

All randomness must be recorded in actions for deterministic replay. This
constrains auto-rules: an auto-rule must not generate random values
internally. If an auto-rule's effect involves a die roll (e.g., the acid free
melee attack), the die value must already be present in the triggering action
or in state.

Auto-rules are pure functions of state. They read state (including history),
mutate state, and return logs. They never call `Int.random` or equivalent.
None of the concrete auto-rules identified for LoD involve die rolls, so this
constraint is straightforward to satisfy.

## Framework Changes

### ComposedGame

Gains one field:

```swift
autoRules: [AutoRule<State>]
```

### oapply

Gains one parameter:

```swift
autoRules: [AutoRule<State>] = []
```

### RulePage, GameRule, ForEachPage, BudgetedPhasePage

Unchanged.

### MCTS / PlayableGame

Unchanged. Auto-rules are invisible to the search — they fire inside
`reduce`, which MCTS already calls. Since auto-rules are deterministic (no
internal randomness), MCTS rollout results remain deterministic given the
same action sequence.

## Paladin Die-Roll Refactor

The paladin re-roll is refactored from a special-purpose phase interrupt into
a branching reducer + re-dispatch pattern.

### Current flow

1. Player picks a die-roll action (e.g., melee attack). Die value is baked
   into the action enum.
2. Page reducer calls `resolveDieRollWithPaladinCheck`.
3. If paladin can re-roll: stash action, switch to `.paladinReact` phase.
4. `paladinReactPage` offers accept/re-roll.
5. On accept or re-roll: resolve the stashed action.

### New flow

1. Player picks a die-roll action. Die value is in the action (for
   determinism) but **not shown to the player until the reducer rolls**.
2. Page reducer checks `canPaladinReroll`.
   - **If false:** reads die from the action, resolves immediately. One step.
   - **If true:** reads die from the action, stashes value in
     `state.firstDieRoll`, stashes action in `state.pendingDieRollAction`,
     sets phase to `.dieDecision`. Returns log showing the roll. No
     resolution yet.
3. `dieDecisionPage` offers `.keepRoll` and `.reroll(newDieRoll: Int)` (if
   paladin not yet used). The `.reroll` action carries a pre-generated die
   value for determinism.
4. `.keepRoll` reducer: re-dispatches `pendingDieRollAction` as a follow-up
   action. Does **not** set `paladinRerollUsed` — the paladin opportunity
   was offered but not consumed.
5. `.reroll(newDieRoll:)` reducer: overwrites `firstDieRoll` with the new
   value, sets `paladinRerollUsed = true`, re-dispatches
   `pendingDieRollAction` as a follow-up action.
6. The original page reducer runs again. `firstDieRoll` is set, so it takes
   the resolution path: reads the die value from `firstDieRoll`, resolves,
   clears `firstDieRoll` and `pendingDieRollAction`.

### Shared helper

A helper replaces `resolveDieRollWithPaladinCheck`:

```swift
/// Check whether to resolve a die-roll action atomically or defer for
/// paladin re-roll. Page reducers call this instead of resolving directly.
///
/// Returns (logs, followUps). If deferring, logs show the roll and
/// followUps is empty. If resolving, the caller should proceed with
/// resolution using the die value from the action.
mutating func dieRollBranch(action: Action) -> DieRollDecision
```

where `DieRollDecision` is:

```swift
enum DieRollDecision {
  case deferred([Log])       // paladin may re-roll; reducer returns early
  case resolve(dieValue: Int) // proceed with resolution using this die value
}
```

Each page reducer calls this helper. If it returns `.deferred(logs)`, the
reducer returns `(logs, [])`. If it returns `.resolve(dieValue:)`, the
reducer proceeds with its specific resolution logic. This avoids duplicating
the branching logic across every die-roll page.

### User experience

- **Paladin available:** tap action → see die roll → choose keep or re-roll →
  see result.
- **Paladin unavailable:** tap action → see result (die rolled internally).

The blind re-roll is preserved: the player sees only the first roll when
deciding whether to use the paladin.

### State changes

**Added:**
- `firstDieRoll: Int?` — the die value from the initial roll.

**Retained:**
- `pendingDieRollAction: Action?` — which action to re-dispatch.
- `paladinRerollUsed: Bool` — one re-roll per turn.

**Removed:**
- `phaseBeforePaladinReact: Phase?` — no longer needed.
- `resolveDieRollWithPaladinCheck()` method — replaced by `dieRollBranch()`.

**Removed page:**
- `paladinReactPage` — replaced by `dieDecisionPage`.

**Phase enum:**
- `.paladinReact` removed, `.dieDecision` added.
- `nextPhase(for:)` in LoDGame.swift updated accordingly.

**Action enum:**
- `.paladinReroll(newDieRoll:)` removed, replaced by `.reroll(newDieRoll:)`.
- `.declineReroll` removed, replaced by `.keepRoll`.

**resetTurnTracking:**
- Remove `phaseBeforePaladinReact = nil`.
- `pendingDieRollAction = nil` and `firstDieRoll = nil` still cleared.

### dieDecisionPage

Replaces `paladinReactPage`. A lightweight RulePage:

```swift
RulePage(
  name: "Die Decision",
  rules: [
    GameRule(
      condition: { $0.phase == .dieDecision && $0.firstDieRoll != nil },
      actions: { state in
        var actions: [Action] = [.keepRoll]
        if !state.paladinRerollUsed {
          actions.append(.reroll(newDieRoll: Int.random(in: 1...6)))
        }
        return actions
      }
    )
  ],
  reduce: { state, action in
    switch action {
    case .keepRoll:
      guard let pending = state.pendingDieRollAction else { return nil }
      return ([], [pending])
    case .reroll(let newDieRoll):
      state.firstDieRoll = newDieRoll
      state.paladinRerollUsed = true
      guard let pending = state.pendingDieRollAction else { return nil }
      return ([Log(msg: "Paladin re-roll: \(newDieRoll)")], [pending])
    default:
      return nil
    }
  }
)
```

### Die values stay in actions

Die-roll action cases **retain** their `dieRoll` parameter. The die value is
pre-generated when the action is created (in `allowedActions`) and embedded
in the action for deterministic replay. The reducer reads it from the action.
The difference from the current design is only in the paladin branching: the
reducer may stash the value in `firstDieRoll` instead of resolving
immediately.

## Concrete AutoRules for Legions of Darkness

### Ordering

Auto-rules fire in list order. The canonical ordering for LoD:

1. Bloody battle marker placement
2. Bloody battle gate tie
3. Quest penalty

Rules #1 and #2 are mutually exclusive (either there's a gate tie or there
isn't).

### 1. Bloody battle marker placement

```
when: last action was advanceArmies,
      card specifies bloodyBattle track,
      bloodyBattleArmy is nil,
      no gate tie (single army or unambiguous closest)
apply: set bloodyBattleArmy to closest army on the track
```

Extracted from armyPage reducer (LoDGamePages.swift, lines 116-137).

### 2. Bloody battle gate tie

```
when: last action was advanceArmies,
      card specifies bloodyBattle on gate track,
      two gate armies tied at same position
apply: set pendingBloodyBattleChoices,
       set phase to .army (override phaseForAction's transition)
```

Mutually exclusive with #1. Sets up a player choice — the existing
`GameRule` in armyPage already offers `.chooseBloodyBattle` when
`pendingBloodyBattleChoices` is set.

**Phase interaction:** `phaseForAction(.advanceArmies)` currently maps to
`.event`, which fires in step 1 of `reduce` before auto-rules run. The
gate-tie auto-rule must set phase back to `.army` so the `chooseBloodyBattle`
GameRule (which checks `phase == .army`) can fire. Auto-rules may override
the phase set by `phaseForAction` — this is expected and intentional.

Alternatively, `phaseForAction(.advanceArmies)` could return `nil` (no
automatic phase transition), and the armyPage reducer handles the transition
to `.event` explicitly. This avoids the override pattern. The implementation
plan should decide which approach is cleaner.

### 3. Quest penalty

```
when: last action was performHousekeeping,
      card is #10 (Last Ditch Efforts),
      no quest action in history since last drawCard
apply: apply quest penalty (lose defenders/morale)
```

Extracted from `performHousekeeping()` in LoDStateComposed.swift.

## Acid Free Melee Attack — Choice Rule, Not AutoRule

The acid upgrade (rule 6.3) says "make a free melee attack" — this is a
player action, not an automatic consequence. It is extracted from the
armyPage reducer but becomes a `GameRule` rather than an `AutoRule`:

```
condition: phase is action,
           some army is at space 1 on a track with acid upgrade,
           acid not used this turn
actions:   offer .acidMeleeAttack(slot, dieRoll:) for the eligible slot
```

The `advanceArmies` action drops its `acidAttackDieRolls` parameter entirely.
The acid attack becomes a normal action with its die value in the action
enum, handled by the combat page or a dedicated rule.

## What Stays Unchanged

- **Priority pages** (victory/defeat) — these present choices requiring
  player acknowledgment. Not auto-rules.
- **Sub-resolutions** (chain lightning, fortune, death & despair) — multi-step
  interactive sequences with their own pages.
- **Event dispatch** — pure dispatch by card number. No conditional follow-ups.
- **Combat/build/magic/quest/heroic page reducers** — simple action→mutation
  after the paladin refactor. Each either resolves atomically or defers to
  the die decision flow.

## Impact on armyPage

The armyPage reducer shrinks from ~70 lines to ~15:

1. For each track on the card, call `advanceArmyOnTrack`.
2. Log results.
3. Transition to event phase or emit `.skipEvent`.

Acid, bloody battle, and the associated conditional branching are gone.

## Impact on performHousekeeping

Shrinks to:

1. Advance time by card's time value.
2. Reset per-turn tracking.
3. Check victory.

Quest penalty logic is gone.

## Testing

- Existing tests continue to pass (behavior unchanged, just restructured).
- Each auto-rule gets its own test: set up state, dispatch the triggering
  action through ComposedGame, assert the auto-rule's effects.
- Paladin tests cover both paths: atomic resolution (paladin unavailable) and
  branching flow (paladin available → keep/reroll → resolution).
- Auto-rule determinism: tests inject die values via action parameters and
  verify that auto-rules produce identical results on replay.
