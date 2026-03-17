# Die Roll Refactor: Actions as Player Intent

## Problem

Die values are currently embedded in LoD action enum cases (e.g.,
`.meleeAttack(.east, dieRoll: 3, ...)`). This conflates player decisions
with random outcomes, and misleads MCTS — the search tree treats "attack
with die=3" and "attack with die=5" as separate actions the player can
choose between, when the player actually commits to attacking and then rolls.

MCTS should evaluate "melee attack on East" as a single action with
stochastic outcomes, building statistics across rollouts that sample
different die values.

Battle Card already does this correctly — its action enum carries no die
values, and rolls happen as side effects in reducers.

## Design

Actions represent pure player intent. Die values are removed from all
action enum cases. Randomness happens during resolution (in reducers).
Tests inject determinism via `@TaskLocal` dependency injection on the
`LoD` namespace.

## Action Enum Changes

### Actions that lose `dieRoll` parameters

| Action | Current | New |
|--------|---------|-----|
| `CombatAction.meleeAttack` | `(slot, dieRoll:, bloodyBattleDefender:, useMagicSword:)` | `(slot, bloodyBattleDefender:, useMagicSword:)` |
| `CombatAction.rangedAttack` | `(slot, dieRoll:, bloodyBattleDefender:, useMagicBow:)` | `(slot, bloodyBattleDefender:, useMagicBow:)` |
| `BuildAction.buildUpgrade` | `(upgrade, track, dieRoll:)` | `(upgrade, track)` |
| `BuildAction.buildBarricade` | `(track, dieRoll:)` | `(track)` |
| `MagicAction.chant` | `(dieRoll:)` | `(no params)` |
| `HeroicAction.heroicAttack` | `(hero, slot, dieRoll:)` | `(hero, slot)` |
| `HeroicAction.rally` | `(dieRoll:)` | `(no params)` |
| `QuestAction.quest` | `(isHeroic:, dieRoll:, reward:, pointsSpent:)` | `(isHeroic:, reward:, pointsSpent:)` |
| `ChainLightningAction.targetBolt` | `(slot, dieRoll:)` | `(slot)` |

### Actions that lose `randomSpell` parameters

| Action | Current | New |
|--------|---------|-----|
| `MagicAction.memorize` | `(randomSpell: SpellType?)` | `(no params)` |
| `MagicAction.pray` | `(randomSpell: SpellType?)` | `(no params)` |

Random spell draws happen during resolution, not at action creation.

### Actions that lose die roll fields in their parameter structs

| Struct | Field removed |
|--------|---------------|
| `EventResolution` | `dieRoll: Int`, `barricadeDieRoll: Int?`, `randomSpell: SpellType?` |
| `SpellCastParams` | `dieRolls: [Int]` (used by chain lightning, divine wrath) |

`EventResolution` retains its player-choice fields: `chosenHero`,
`chosenSlot`, `woundHeroes`, `chosenSpell`, `chosenDefender`,
`discardIndex`, `deserterDefenders`, `advanceSky`, `otherAdvances`.

### Actions that lose other die-related parameters

| Action | Parameter removed |
|--------|-------------------|
| `advanceArmies` | `acidAttackDieRolls: [ArmySlot: Int]` — becomes just `.advanceArmies` |
| `paladinReroll` | `newDieRoll: Int` — the paladin refactor (AutoRule spec) will redesign this; for now the re-roll generates its own random value during resolution |

## Deleted Code

- `effectiveDie(_ dieRoll: Int) -> Int` — no longer needed. Reducers call
  `LoD.rollDie()` directly.
- `withNewDieRoll(_ action:, newDieRoll:) -> Action` — no die values in
  actions to replace.

## Retained Code

- `isDieRollAction(_ action:) -> Bool` — still needed for
  `resolveDieRollWithPaladinCheck`. The check is about action type, not
  die value presence.

## RNG Injection via @TaskLocal

Die rolling is injected as a `@TaskLocal` closure on the `LoD` namespace.
No RNG state lives in `LoD.State`. No new types are introduced.

```swift
extension LoD {
  @TaskLocal static var rollDie: () -> Int = { Int.random(in: 1...6) }
}
```

Reducers call `LoD.rollDie()` wherever they need a die value. The default
closure uses `Int.random`, which is correct for production and MCTS — each
rollout samples independently.

### MCTS

MCTS rollouts use the default `Int.random` closure. Different rollouts
from the same state produce different die sequences naturally. No RNG
state needs to be copied with the game state.

### Tests

Tests override `rollDie` via `@TaskLocal` `withValue` to inject a
deterministic sequence:

```swift
var rolls = [3, 5, 1].makeIterator()
LoD.$rollDie.withValue({ rolls.next()! }) {
  _ = game.reduce(into: &state, action: .combat(.meleeAttack(.east, bloodyBattleDefender: nil, useMagicSword: nil)))
  XCTAssertEqual(state.defenders[.east], 2) // die was 3
}
```

Tests that currently inject `dieRoll: 5` instead provide `[5]` (or
whatever sequence is needed) via `withValue`. The closure is called once
per `rollDie()` invocation in the reducer, consuming values in order.

For tests that need multiple rolls in a single reduce call (e.g., chain
lightning with multiple bolts), the array simply has multiple entries:

```swift
var rolls = [4, 2, 6].makeIterator()
LoD.$rollDie.withValue({ rolls.next()! }) {
  // three bolts, three rolls
}
```

### Random Spell Draws

`memorize` and `pray` currently carry `randomSpell: SpellType?`. After
the refactor, the random spell draw also uses an injected closure:

```swift
extension LoD {
  @TaskLocal static var drawRandomSpell: (LoD.State) -> SpellType? = { state in
    state.availableSpells.randomElement()
  }
}
```

Tests override this the same way as `rollDie`.

## Reducer Changes

Every reducer that currently reads `dieRoll` from the action instead calls
`LoD.rollDie()`. The internal resolution methods (`resolveAttack`, `build`,
`chant`, `rally`, `attemptQuest`, etc.) keep their `dieRoll: Int`
parameter — they receive the already-rolled value. Only the top-level
dispatch changes.

### Die-roll action reducers

**Before:**
```swift
case .combat(.meleeAttack(let slot, let dieRoll, let bbDef, let sword)):
  return resolveMeleeAttack(slot: slot, dieRoll: Self.effectiveDie(dieRoll), ...)
```

**After:**
```swift
case .combat(.meleeAttack(let slot, let bbDef, let sword)):
  let dieRoll = LoD.rollDie()
  return resolveMeleeAttack(slot: slot, dieRoll: dieRoll, ...)
```

Same pattern for `rangedAttack`, `buildUpgrade`, `buildBarricade`, `chant`,
`heroicAttack`, `rally`, `quest`.

### Spell cast resolution (Fireball, Divine Wrath, Chain Lightning)

`applySpellEffect` currently reads `params.dieRolls` for spells that roll
dice. After removing `SpellCastParams.dieRolls`, each spell calls
`LoD.rollDie()` at resolution time:

**Before:**
```swift
case .fireball:
  let dieRoll = params.dieRolls.first ?? 0
  applyFireball(on: target, dieRoll: Self.effectiveDie(dieRoll))
```

**After:**
```swift
case .fireball:
  let dieRoll = LoD.rollDie()
  applyFireball(on: target, dieRoll: dieRoll)
```

Spell-cast die rolls are not eligible for paladin re-roll (per
`isDieRollAction`). They always resolve immediately.

### Event page reducer

The event page reducer currently reads `resolution.dieRoll`,
`resolution.barricadeDieRoll`, and `resolution.randomSpell`. After the
refactor:

- `resolution.dieRoll` → `LoD.rollDie()` at resolution time
- `resolution.barricadeDieRoll` → `LoD.rollDie()` when barricade test needed
- `resolution.randomSpell` → `LoD.drawRandomSpell(state)` (for Mystic
  Forces Reborn)

### `advanceArmy` method

`advanceArmy(_:dieRoll:)` currently takes an optional `dieRoll: Int?`
parameter used for barricade and grease checks. The `dieRoll` parameter is
removed. The method calls `LoD.rollDie()` internally when it hits a
barricade or grease check. All callers (armyPage, event handlers like
`eventDistractedDefenders`, `eventBannersInDistance`, `eventHarbingers`,
etc.) drop their die roll arguments.

### Death and Despair sub-resolution

`DeathAndDespairState` currently stores `let dieRoll: Int`, initialized
from `EventResolution.dieRoll`. After the refactor, the die roll is
generated via `LoD.rollDie()` when the Death and Despair sub-resolution
begins, and stored in `DeathAndDespairState`.

## allowedActions Changes

GameRule `actions` closures simplify — no more `dieRoll: 0` placeholders:

**Before:**
```swift
actions.append(.combat(.meleeAttack(slot, dieRoll: 0, bloodyBattleDefender: nil, useMagicSword: nil)))
```

**After:**
```swift
actions.append(.combat(.meleeAttack(slot, bloodyBattleDefender: nil, useMagicSword: nil)))
```

## Paladin Re-Roll

The paladin re-roll mechanism continues to work with minimal changes:

- `resolveDieRollWithPaladinCheck` still defers die-roll actions when the
  paladin can re-roll.
- `pendingDieRollAction` stashes the action (which no longer carries a die
  value).
- On `.paladinReroll`: the reducer calls `LoD.rollDie()` to get the new
  value and resolves. The `newDieRoll:` parameter is removed from the
  action.
- On `.declineReroll`: the reducer uses the die value already rolled and
  stashed in `state.firstDieRoll` during the first pass.

The initial die roll needs to be stashed somewhere before the paladin
deferral. Currently the die is in the action; after the refactor it is
rolled via `LoD.rollDie()` and stored in `state.firstDieRoll`.

The full paladin flow after this refactor:

1. Page reducer receives action (no die value).
2. Checks `canPaladinReroll`.
3. **If false:** calls `LoD.rollDie()`, resolves immediately.
4. **If true:** calls `LoD.rollDie()`, stores in `state.firstDieRoll`,
   stashes action in `pendingDieRollAction`, switches to `.paladinReact`.
5. On `.declineReroll`: the reducer resolves the pending action using the
   stashed value. It wraps the resolution call in
   `LoD.$rollDie.withValue({ state.firstDieRoll! })` so that when the
   resolver calls `LoD.rollDie()`, it gets the stashed value.
6. On `.paladinReroll`: calls `LoD.rollDie()` for a fresh value, resolves
   using it (the resolver's own `LoD.rollDie()` call produces this value).

This matches the AutoRule spec's paladin design (minus the `newDieRoll:`
parameter, which is now generated internally).

## Scope

### In scope
- Remove `dieRoll` / `randomSpell` / `dieRolls` from all LoD action cases
  and parameter structs.
- Remove `acidAttackDieRolls` from `advanceArmies`.
- Remove `newDieRoll` from `paladinReroll`.
- Add `@TaskLocal static var rollDie` and `drawRandomSpell` on `LoD`.
- Add `firstDieRoll: Int?` to state for paladin deferral.
- Update all reducers to call `LoD.rollDie()`.
- Update all `allowedActions` closures to drop die placeholders.
- Delete `effectiveDie`, `withNewDieRoll`.
- Update all tests to use `LoD.$rollDie.withValue`.

### Replay determinism

Action history will no longer contain die values. Replaying the same
action sequence against the default `Int.random` closure will not
reproduce the same game. This is an accepted tradeoff — the primary
consumers of action history are MCTS (which wants stochastic rollouts)
and the game log (which records outcomes in `Log` messages). If
deterministic replay is needed later, it can be added by recording
`LoD.rollDie()` results in a separate trace, outside the action enum.

### Out of scope (deferred to AutoRule refactor)
- Extracting acid attack to a separate choice rule.
- Extracting bloody battle / quest penalty to auto-rules.
- Replacing `paladinReactPage` with `dieDecisionPage`.
- The keep/reroll action redesign.

## Testing Strategy

1. Add `@TaskLocal` declarations on `LoD`. Verify a simple test can
   override `rollDie` via `withValue`.
2. Update each action case one at a time — remove die parameter, update
   reducer, wrap test in `withValue`. Build and test after each case.
3. Verify all 503 tests pass after the full migration.
4. Verify MCTS still plays games to completion (smoke test via gamer CLI).

## Files Affected

### LoD Sources
- `LoDAction.swift` — Action enum, EventResolution, SpellCastParams
- `LoDActionGroups.swift` — CombatAction, BuildAction, MagicAction,
  HeroicAction, QuestAction
- `LoDState.swift` — add `firstDieRoll`
- `LoDDependencies.swift` — new file with `@TaskLocal` declarations
- `LoDStateResolve.swift` — delete `effectiveDie`, `withNewDieRoll`;
  update all resolvers
- `LoDStateCombat.swift` — `advanceArmy` drops `dieRoll:` parameter,
  calls `LoD.rollDie()` for barricade/grease checks
- `LoDStateComposed.swift` — `applySpellEffect` calls `LoD.rollDie()`
  for Fireball/Divine Wrath
- `LoDStateEvents.swift` — `concreteEventResolutions` drops die params
- `LoDGamePages.swift` — armyPage (drop acidAttackDieRolls), eventPage
  (roll at resolution time instead of reading from EventResolution)
- `LoDGamePagesCombat.swift` — drop dieRoll: 0 in actions
- `LoDGamePagesBuild.swift` — drop dieRoll: 0 in actions
- `LoDGamePagesMagic.swift` — drop dieRoll: 0 and randomSpell: nil
- `LoDGamePagesHeroic.swift` — drop dieRoll: 0 in actions
- `LoDGamePagesQuest.swift` — drop dieRoll: 0 in actions
- `LoDChainLightningPage.swift` — drop dieRoll from action + reducer
- `LoDDeathAndDespairPage.swift` — `DeathAndDespairState.dieRoll`
  generated via `LoD.rollDie()` at initialization
- `LoDGame.swift` — paladinReactPage updates, declineReroll uses
  `withValue` to inject stashed die

### Tests
- Every test file that constructs LoD actions with die values (all of them).
  Each test wraps its reduce calls in `LoD.$rollDie.withValue { ... }`.
