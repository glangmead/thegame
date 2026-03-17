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
Tests inject determinism via a seeded RNG on state.

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
  `state.rollDie()` directly.
- `withNewDieRoll(_ action:, newDieRoll:) -> Action` — no die values in
  actions to replace.
- `isDieRollAction(_ action:) -> Bool` — still needed for
  `resolveDieRollWithPaladinCheck`, but the check is about action type, not
  die value presence.

## RNG on State

State gains a seedable random number generator:

```swift
var rng: SeededRNG = SeededRNG()
```

where `SeededRNG` is a simple value-type PRNG:

```swift
struct SeededRNG: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64 = 0) {
    state = seed == 0 ? UInt64.random(in: 1...UInt64.max) : seed
  }

  mutating func next() -> UInt64 {
    // SplitMix64
    state &+= 0x9e3779b97f4a7c15
    var z = state
    z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
    z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
    return z ^ (z >> 31)
  }
}
```

A convenience method on state:

```swift
mutating func rollDie() -> Int {
  Int.random(in: 1...6, using: &rng)
}
```

### Equatable / Hashable

`SeededRNG` is excluded from `Equatable` and `Hashable` conformance on
state. Two states that differ only in RNG seed are considered equal. This
is correct: the RNG is an implementation detail, not game state.

### MCTS

Each MCTS rollout copies state, which copies the RNG. Different rollouts
from the same state will produce different die sequences because the RNG
state diverges after the first roll. This is the desired behavior — MCTS
samples over stochastic outcomes naturally.

### Tests

Tests create state with a fixed seed:

```swift
var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
state.rng = SeededRNG(seed: 42)
```

With a fixed seed, `state.rollDie()` produces a deterministic sequence.
Tests that currently inject `dieRoll: 5` instead set up the seed to produce
the desired value, or call `rollDie()` and adapt expectations to the
deterministic sequence.

For tests that need a specific die value at a specific point, a helper:

```swift
extension SeededRNG {
  /// Create an RNG that produces the given values in order, then random.
  static func fixed(_ values: [Int]) -> SeededRNG { ... }
}
```

This is a test-only convenience. Implementation TBD — could use a wrapper
that feeds from an array then falls through to SplitMix64, or could just
document the seed-to-sequence mapping for common seeds.

## Reducer Changes

Every reducer that currently reads `dieRoll` from the action instead calls
`state.rollDie()`. Examples:

**Before:**
```swift
case .combat(.meleeAttack(let slot, let dieRoll, let bbDef, let sword)):
  return resolveMeleeAttack(slot: slot, dieRoll: Self.effectiveDie(dieRoll), ...)
```

**After:**
```swift
case .combat(.meleeAttack(let slot, let bbDef, let sword)):
  let dieRoll = state.rollDie()
  return resolveMeleeAttack(slot: slot, dieRoll: dieRoll, ...)
```

The internal resolution methods (`resolveAttack`, `build`, `chant`, `rally`,
`attemptQuest`, etc.) keep their `dieRoll: Int` parameter — they receive
the already-rolled value. Only the top-level dispatch changes.

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
- On `.paladinReroll`: the reducer calls `state.rollDie()` to get the new
  value and resolves. The `newDieRoll:` parameter is removed from the
  action.
- On `.declineReroll`: the reducer uses the die value already rolled and
  stashed in state during the first pass (stored in a new field,
  `firstDieRoll: Int?`, as described in the AutoRule spec).

Wait — this means the initial die roll needs to be stashed somewhere before
the paladin deferral. Currently the die is in the action; after the refactor
it needs to be rolled and stored in state. This is the `firstDieRoll` field
from the AutoRule spec.

The full paladin flow after this refactor:

1. Page reducer receives action (no die value).
2. Checks `canPaladinReroll`.
3. **If false:** calls `state.rollDie()`, resolves immediately.
4. **If true:** calls `state.rollDie()`, stores in `state.firstDieRoll`,
   stashes action in `pendingDieRollAction`, switches to `.paladinReact`.
5. On `.declineReroll`: resolves using `state.firstDieRoll`.
6. On `.paladinReroll`: calls `state.rollDie()` for new value, resolves
   using the new value.

This matches the AutoRule spec's paladin design (minus the `newDieRoll:`
parameter, which is now generated internally).

## Scope

### In scope
- Remove `dieRoll` / `randomSpell` / `dieRolls` from all LoD action cases
  and parameter structs.
- Remove `acidAttackDieRolls` from `advanceArmies`.
- Remove `newDieRoll` from `paladinReroll`.
- Add `SeededRNG` type and `rollDie()` method to state.
- Add `firstDieRoll: Int?` to state for paladin deferral.
- Update all reducers to call `state.rollDie()`.
- Update all `allowedActions` closures to drop die placeholders.
- Delete `effectiveDie`, `withNewDieRoll`.
- Update all tests to use seeded RNG.

### Out of scope (deferred to AutoRule refactor)
- Extracting acid attack to a separate choice rule.
- Extracting bloody battle / quest penalty to auto-rules.
- Replacing `paladinReactPage` with `dieDecisionPage`.
- The keep/reroll action redesign.

## Testing Strategy

1. Add `SeededRNG` with unit tests for deterministic output.
2. Update each action case one at a time — remove die parameter, update
   reducer, update tests. Build and test after each case.
3. Verify all 503 tests pass after the full migration.
4. Verify MCTS still plays games to completion (smoke test via gamer CLI).

## Files Affected

### Framework
- New file: `SeededRNG.swift` (or in existing framework file)

### LoD Sources
- `LoDAction.swift` — Action enum, EventResolution, SpellCastParams
- `LoDActionGroups.swift` — CombatAction, BuildAction, MagicAction,
  HeroicAction, QuestAction
- `LoDState.swift` — add `rng`, `firstDieRoll`
- `LoDStateResolve.swift` — delete `effectiveDie`, `withNewDieRoll`;
  update all resolvers
- `LoDStateEvents.swift` — `concreteEventResolutions` drops die params
- `LoDGamePages.swift` — armyPage (drop acidAttackDieRolls), eventPage
- `LoDGamePagesCombat.swift` — drop dieRoll: 0 in actions
- `LoDGamePagesBuild.swift` — drop dieRoll: 0 in actions
- `LoDGamePagesMagic.swift` — drop dieRoll: 0 and randomSpell: nil
- `LoDGamePagesHeroic.swift` — drop dieRoll: 0 in actions
- `LoDGamePagesQuest.swift` — drop dieRoll: 0 in actions
- `LoDChainLightningPage.swift` — drop dieRoll from action + reducer
- `LoDGame.swift` — paladinReactPage updates

### Tests
- Every test file that constructs LoD actions with die values (all of them).
- New test file or section for `SeededRNG`.
