# Implementing a Board Game from Vassal Module + Rules PDF

A process for turning a physical board game into a working digital implementation
using TDD, with the DynamicalSystems Swift framework as the target.

## When to Use

When the user wants to implement a new board game and has:
- An unzipped Vassal module (`.vmod` = ZIP with `buildFile` XML + `images/`)
- A rules PDF (possibly OCR'd)
- The existing DynamicalSystems framework to target

## Prerequisites

Before starting, understand the target framework by reading these files:
- `Sources/Game.swift` — protocols: `GameComponents`, `GameState`, `PlayableGame`
- `Sources/Framework/ComposedGame.swift` — `oapply()` composition
- `Sources/Framework/RulePage.swift` — condition/action rule pages
- `Sources/Framework/HistoryTracking.swift` — history-derived state
- `Sources/Framework/ForEachPage.swift`, `BudgetedPhasePage.swift` — meta-rules

Study at least one existing implementation (e.g., `Sources/Battle Card/`) to see
the Components → State → Engine → Pages → Graph → SceneConfig pattern.

## The Process

### Phase 1: Study the Source Material

**Vassal module gives nouns.** Read the `buildFile` XML to catalog:
- Army/piece counters (names, images, properties)
- Board layout (tracks, grids, regions)
- Decks and card counts
- Setup positions (`SetupStack` elements)
- Markers and tokens

See [vassal_reference_manual.md](vassal_reference_manual.md) for how to interpret the XML.

**Rules PDF gives verbs.** Read the rulebook to understand:
- Sequence of play (turn phases)
- Movement/advancement rules
- Combat/resolution mechanics
- Victory and defeat conditions
- Special cases, exceptions, edge rules

**Card data lives on card images, not in the XML.** For card-driven games, the
card effects (advances, actions, events, quests, DRMs) are only printed on the
card art. Read each card image and compile the data into a JSON file stored
alongside the Vassal data (e.g., `vassal/<module>/cards.json`). Have the user
verify the data — image reading is error-prone, especially for icon counts and
icon types.

### Phase 2: Ask Clarifying Questions

After studying both sources, identify ambiguities and ask the user **one question
at a time**. Common areas needing clarification:

- Track lengths and space numbering (verify against the board image)
- Army/unit strength values (verify against counter images)
- Card icon meanings that are hard to distinguish visually
- Rules that reference visual elements (colors, symbols) on components
- Scenario-specific setup details

Save important rules clarifications to a `rules_notes.md` file alongside the
Vassal data. Also save a copy to Claude's memory directory so it persists across
sessions.

### Phase 3: Components (TDD)

Define the game's vocabulary as Swift enums. Write tests first that assert
properties derived from the rules, then implement to make them pass.

**What to define:**
- Tracks/locations and their properties (length, type, adjacency)
- Piece/army types and their attributes (strength, special rules)
- Hero/character types and their abilities
- Resource types and ranges (energy, morale, defenders)
- Upgrade/spell/card types with costs and effects
- Turn phases in order
- Scenarios with their setup data

**Test pattern:**
```swift
@Test func trackLengths() {
    // Rule reference in comment
    #expect(LoD.Track.east.maxSpace == 6)
    #expect(LoD.Track.gate.maxSpace == 4)
}
```

Each test should cite the rule number it's asserting. This makes the test suite
a machine-readable summary of the rulebook.

### Phase 4: State (TDD)

Define the game state struct with all the fields needed to fully describe a
game in progress. Write setup tests that assert the initial state matches the
scenario card.

**What to include:**
- Piece positions (per track, per slot)
- Resource levels (energy, defenders, morale)
- Marker states (spells: face-down/known/cast; upgrades: placed/not)
- Board state (breaches, barricades)
- Time/turn tracking
- Victory/defeat flags

**Test pattern for setup:**
```swift
@Test func greenskinArmyPlacement() {
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.east] == 6)  // Goblin at East 6
}
```

For setup functions that involve randomness (die rolls, shuffles), parameterize
the random inputs so tests are deterministic.

### Phase 5: Game Logic (TDD)

Implement the rules as mutating functions on the State struct. Work through the
rulebook section by section, in roughly this order:

1. **Army advancement** — the core army phase mechanic
2. **Time track** — advancing time, twilight/dawn effects
3. **Battle resolution** — attacks, DRMs, retreat
4. **Actions** — build, attack, cast spell, memorize, pray, chant
5. **Heroic acts** — heroic attacks, heroic spells, rally, move
6. **Events** — card events (may need per-card logic)
7. **Quests** — card quests with target numbers
8. **Victory/defeat** — win/loss condition checks
9. **Housekeeping** — end-of-turn bookkeeping

For each rule:
1. Write the test (red)
2. Translate the test assertion to natural language
3. Present to the user for confirmation ("does this match your reading?")
4. Implement to make the test pass (green)
5. Move to the next rule

**Present tests in batches** grouped by rule section. Show the user a table of
test names and what rule each one asserts. Get confirmation before moving on.

### Phase 6: Rule Pages and Composition

Once the state mutations are solid, wrap them in `RulePage` instances following
the framework pattern:
- One page per phase (card, army, event, action, housekeeping)
- Priority pages for victory and defeat (checked every phase)
- Use `ForEachPage` / `BudgetedPhasePage` where applicable
- Compose with `oapply()` into a `ComposedGame`

### Phase 7: Rendering (later)

SpriteKit rendering using Vassal board/piece images. This phase uses `SceneConfig`
(declarative DSL) and `GameScene`. Deferred until game logic is complete and tested.

## Xcode Project Notes

The project uses file-system-synchronized groups (objectVersion 77). New source
files in `Sources/` are auto-discovered by the main app target. However, the
**test target** requires manual addition to `membershipExceptions` in the
`project.pbxproj` file. When adding a new source file:

1. Create the file in `Sources/<Game Name>/`
2. Edit `project.pbxproj` → find `Exceptions for "Sources" folder in "DynamicalSystemsTests" target`
3. Add the file path to `membershipExceptions` in alphabetical order
4. Build and run tests to verify

## Key Principles

- **Module gives nouns, rules give verbs.** Don't try to extract game logic from
  the Vassal XML. It only has piece definitions, positions, and images.
- **Card data requires human verification.** Image reading is unreliable for
  distinguishing similar icons. Always have the user verify card data.
- **One question at a time.** Don't overwhelm with multiple clarifications.
- **Cite rule numbers in tests.** The test suite should read like a rules summary.
- **Parameterize randomness.** Die rolls, shuffles, and draws should be injectable
  for deterministic testing.
- **Save clarifications persistently.** Write rules notes to both the Vassal
  directory and Claude's memory directory so they survive across sessions.
