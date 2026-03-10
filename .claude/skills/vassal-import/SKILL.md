# Implementing a Board Game from Vassal Module + Rules PDF

A process for turning a physical board game into a working digital implementation
using TDD, with the DynamicalSystems Swift framework as the target.

**Goal: autonomous implementation.** The agent should be able to read the rules PDF,
write tests, implement logic, and self-audit by re-reading the PDF — with minimal
user intervention. The user verifies card image data and resolves genuine ambiguities;
everything else should be derivable from the PDF.

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

Study at least one existing implementation (e.g., `Sources/Legions of Darkness/`)
to see the Components → State → Engine → Pages → Graph → SceneConfig pattern.

## The Process

### Phase 1: Deep Study of Source Material

**Vassal module gives nouns.** Read the `buildFile` XML to catalog:
- Army/piece counters (names, images, properties)
- Board layout (tracks, grids, regions)
- Decks and card counts
- Setup positions (`SetupStack` elements)
- Markers and tokens

See [vassal_reference_manual.md](vassal_reference_manual.md) for how to interpret the XML.

**Rules PDF gives verbs — and is the primary source of truth.** Read the entire
rulebook carefully, section by section. For each rule section, extract:
- The exact mechanic (what triggers it, what it does, what limits apply)
- Edge cases mentioned in the text (e.g., "except magical attacks")
- Constraints that are easy to miss (e.g., "once per turn", "only on wall tracks")
- Cross-references to other rules (e.g., "see section 6.3 for upgrades")
- DRM bonuses scattered across different sections (these are the most commonly missed)

**Read the Player Aid / reference card images too.** They often contain compact
rule summaries with details not in the main rules text (e.g., "Paladin — holy" or
upgrade effects).

**Card data lives on card images, not in the XML.** For card-driven games, the
card effects (advances, actions, events, quests, DRMs) are only printed on the
card art. Read each card image and compile the data into a JSON file stored
alongside the Vassal data (e.g., `vassal/<module>/cards.json`). Have the user
verify the data — image reading is error-prone, especially for icon counts and
icon types.

### Phase 2: Clarify Only What You Cannot Determine

**Minimize questions to the user.** Most rules can be understood by reading the
PDF carefully. Only ask the user when:
- The PDF text is genuinely ambiguous (two valid interpretations)
- Visual information on components can't be read from images (icon types, pip counts)
- Rules reference visual elements that aren't described in text (colors, symbols)
- The PDF has obvious typos or contradictions between sections

**Do not ask about:**
- Things stated clearly in the rules (even if in a different section than expected)
- Track lengths, strengths, or costs that are written in the rules or on cards
- Phase ordering that's spelled out in the sequence of play

Save important clarifications to a `rules_notes.md` file alongside the Vassal data
and to Claude's memory directory so they persist across sessions.

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

**Test pattern — every test cites its rule:**
```swift
@Test func trackLengths() {
    // Rule 4.0: East, West, Sky go from 0 to 6. Gate 0 to 4. Terror 0 to 3.
    #expect(LoD.Track.east.maxSpace == 6)
    #expect(LoD.Track.gate.maxSpace == 4)
}
```

### Phase 4: State (TDD)

Define the game state struct. Write setup tests. Parameterize random inputs.

**Include per-turn tracking fields.** Many rules have "once per turn" or "N times
per turn" constraints. These need explicit state fields (e.g., `acidUsedThisTurn`,
`meleeAttacksThisTurn`) or history-derived computed properties. Getting these wrong
is a top source of bugs — re-read each rule section for frequency constraints.

History-derived properties (scanning `history.reversed()` for actions since the
last phase boundary) are preferred over mutable counters when feasible.

### Phase 5: Game Logic (TDD) — The Core Loop

Implement rules as mutating functions on the State struct. Work section by section:

1. **Army advancement** — the core army phase mechanic
2. **Time track** — advancing time, twilight/dawn effects
3. **Battle resolution** — attacks, DRMs, retreat
4. **Actions** — build, attack, cast spell, memorize, pray, chant
5. **Heroic acts** — heroic attacks, heroic spells, rally, move
6. **Events** — card events (may need per-card logic)
7. **Quests** — card quests with target numbers
8. **Victory/defeat** — win/loss condition checks
9. **Housekeeping** — end-of-turn bookkeeping

**For each rule, the autonomous workflow is:**
1. Re-read the specific rule section in the PDF
2. Write the test (red) with a rule citation comment
3. Implement to make the test pass (green)
4. Run `RunSomeTests` to verify
5. Move to the next rule

**Do not present each test to the user for confirmation.** Work autonomously
through the rules. The user will review the code at natural milestones (end of a
phase, end of a major rule section). Report progress as a summary table of tests
added and rules covered.

### Phase 5a: Audit — Re-Read the Entire PDF

**This is the most critical phase.** After the initial implementation pass, re-read
the rules PDF from cover to cover and compare every statement against the existing
implementation. This audit typically finds 10-15 issues per game. Common categories:

**Mechanic misclassification:**
- Upgrade was implemented as a DRM when it's actually a breach-prevention roll
  (e.g., Grease in LoD is NOT a DRM — it forces a die roll when army reaches space 0)
- Attack type wrong (e.g., Acid free attack is MELEE, not ranged)

**Missing constraints:**
- "Cannot build if army is on space 1" — easy to miss in a long rule section
- "Once per turn" limits (Acid free attack, bloody battle cost)
- "Limited by defender count" (melee attacks ≤ men-at-arms, ranged ≤ archers)
- Spell targeting restrictions (Wizard must be on same track for targeted arcane spells)

**Missing bonuses/DRMs scattered across sections:**
- Hero abilities mentioned in one section that affect actions defined in another
  (e.g., Paladin +1 rally DRM is in the hero section, not the rally section)
- Card DRMs that apply to specific action types

**Normal vs heroic mode differences:**
- Spells often have different effects in normal vs heroic mode
  (e.g., Inspire at High morale: normal=can't cast, heroic=DRM only)
- Heroic versions may allow "both" where normal allows "either/or"
  (e.g., Raise Dead normal: defenders OR hero; heroic: defenders AND/OR hero)

**Missing actions entirely:**
- Build Barricade (repair a breach) — a separate action from Build Upgrade
- Specific free actions triggered by upgrades or hero abilities

**Magical exemptions:**
- "Magical attacks don't trigger bloody battle defender cost"
- Spell attacks vs physical attacks having different rules

**For each audit finding:**
1. Write a new test that exposes the bug (with "Audit Fix #N" in the MARK comment)
2. Fix the implementation
3. Run all tests to verify no regressions

### Phase 6: Rule Pages and Composition

Wrap state mutations in `RulePage` instances:
- One page per phase (card, army, event, action, housekeeping)
- Priority pages for victory and defeat (checked every phase)
- Use `ForEachPage` / `BudgetedPhasePage` where applicable
- Compose with `oapply()` into a `ComposedGame`

**Key pattern: `gameAcknowledged` vs `ended`.** Use `gameAcknowledged` for
`isTerminal` so that priority pages can offer `claimVictory` / `declareLoss`
before the game stops accepting input. `ended` is set by state mutations;
`gameAcknowledged` is set by the priority page reducer.

### Phase 6a: MCTS Compatibility

The `OpenLoopMCTS` search uses `state.endedInVictoryFor` and `state.endedInDefeatFor`
(from the `GameState` protocol) to backpropagate win/loss values. If these arrays
are never populated, MCTS gets zero reward signal and degenerates to random play.

**Required steps:**

1. **Set `endedInVictoryFor` / `endedInDefeatFor` at every site where `ended = true`.**
   Victory sites set `endedInVictoryFor = players; endedInDefeatFor = []`.
   Defeat sites set `endedInDefeatFor = players; endedInVictoryFor = []`.
   Do this in the state mutations themselves (not the acknowledgment pages), because
   MCTS rollouts stop at `!state.ended` and never process the acknowledgment action.

2. **Write an MCTS smoke test** that runs `OpenLoopMCTS` on the game and verifies
   it produces non-zero win/loss values. Example:
   ```swift
   @Test func mctsProducesNonZeroValues() {
       let game = Game.composedGame(...)
       var state = game.newState()
       let mcts = OpenLoopMCTS(state: state, reducer: game)
       let recs = mcts.recommendation(iters: 50, numRollouts: 1)
       let totalValue = recs.values.map { $0.0 }.reduce(0, +)
       #expect(totalValue > 0, "MCTS must observe at least one win or loss")
   }
   ```

3. **Add the game to the `gamer` CLI target** in `DynamicalSystems/gamer/main.swift`.
   Wire up the game enum case, `composedGame()` factory, and any game-specific
   CLI options (scenario selection, etc.) so `gamer --game <name>` works.

### Phase 6b: Integration Tests

Write at least two integration tests using the composed game:
1. **Victory playthrough** — use deterministic card sequences to reach the win condition
2. **Defeat playthrough** — use deterministic cards to trigger a loss condition

These should exercise the full `reduce` → `allowedActions` loop, verifying that
phases transition correctly and priority pages fire at the right time.

```swift
@Test func fullGameVictoryPlaythrough() {
    let safeCard = Game.dayCards.first { $0.number == 3 }!
    let game = Game.composedGame(
        shuffledDayCards: Array(repeating: safeCard, count: 20),
        shuffledNightCards: Array(repeating: safeCard, count: 20)
    )
    var state = game.newState()
    for _ in 0..<15 {
        _ = game.reduce(into: &state, action: .drawCard)
        _ = game.reduce(into: &state, action: .passActions)
        _ = game.reduce(into: &state, action: .passHeroics)
    }
    #expect(state.victory == true)
    let actions = game.allowedActions(state: state)
    #expect(actions == [.claimVictory])
}
```

### Phase 7: Rendering (later)

SpriteKit rendering using Vassal board/piece images. This phase uses `SceneConfig`
(declarative DSL) and `GameScene`. Deferred until game logic is complete and tested.

## Rules PDF Reading Strategy

The PDF should be read **at least three times** during implementation:

1. **First read (Phase 1):** Survey pass. Understand the game's structure, phases,
   and major mechanics. Take notes on rule sections and cross-references.

2. **Second read (Phase 5):** Implementation pass. Read each section immediately
   before writing its tests and implementation. Pay attention to:
   - Exact wording of constraints ("must", "may", "cannot", "once per turn")
   - Parenthetical exceptions ("except magical attacks")
   - References to other sections ("see 6.3")

3. **Third read (Phase 5a):** Audit pass. Read cover-to-cover with the implemented
   tests open. For each rule statement, verify there's a corresponding test. Flag
   any discrepancy. This pass is where most bugs are found.

**When in doubt, re-read.** If a test fails unexpectedly or a mechanic feels wrong,
go back to the PDF rather than guessing. The PDF is the source of truth.

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

- **The PDF is the source of truth.** When implementation and PDF disagree, the
  PDF wins. Re-read the relevant section before changing a test.
- **Module gives nouns, rules give verbs.** Don't try to extract game logic from
  the Vassal XML. It only has piece definitions, positions, and images.
- **Card data requires human verification.** Image reading is unreliable for
  distinguishing similar icons. Always have the user verify card data.
- **Work autonomously, report at milestones.** Don't ask the user to confirm each
  test. Work through rule sections, then report what you covered.
- **Cite rule numbers in every test.** The test suite should read like a rules
  summary. Each `@Test` function gets a `// Rule X.Y: ...` comment.
- **Audit after implementation.** Budget a full re-read of the PDF after the first
  pass. Expect to find ~10-15 issues. This is normal, not a failure.
- **Parameterize randomness.** Die rolls, shuffles, and draws should be injectable
  for deterministic testing.
- **Track per-turn limits explicitly.** Use history-derived computed properties or
  state fields for "once per turn" and "N per turn" constraints.
- **Watch for scattered DRMs.** Bonuses are often mentioned in one section but
  affect mechanics defined in another. Cross-reference hero abilities, card DRMs,
  and upgrade effects against every die-roll action.
- **Normal vs heroic is never just "same but better."** Re-read both modes of
  every spell/ability. The heroic version often changes targeting, limits, or
  exclusive-or into inclusive-or.

## Common Pitfalls (from LoD experience)

| Pitfall | Example | Fix |
|---------|---------|-----|
| Mechanic misclassification | Grease as DRM (was breach-prevention roll) | Re-read the specific rule; don't infer from similar mechanics |
| Wrong attack type | Acid as ranged (was melee) | Check the rule for explicit attack type |
| Missing "once per turn" | Acid firing on every army advance | Add `usedThisTurn` field, reset in housekeeping |
| Missing limits | Unlimited melee attacks (should be ≤ men-at-arms) | Check defender section for per-turn caps |
| Scattered bonuses | Paladin rally DRM in hero section | Cross-reference all hero/item abilities against each action |
| Normal/heroic confusion | Inspire same in both modes (heroic allows at High morale) | Read both mode descriptions for every spell |
| Missing action type | No build-barricade action (separate from build-upgrade) | Look for actions that apply in different board states (breached vs unbreached) |
| Magical exemptions | Bloody battle cost on spell attacks (should be exempt) | Check if physical/magical distinction matters for each triggered cost |
| Targeting restrictions | Arcane spells with no track restriction (Wizard must be same track) | Check each spell class for targeting rules |
| Empty MCTS reward signal | `endedInVictoryFor`/`endedInDefeatFor` never set (MCTS sees all-zero values) | Set these arrays at every `ended = true` site; write an MCTS smoke test |
| Game missing from CLI | Implemented game not wired into `gamer` tool | Add game enum case + factory to `main.swift` as part of Phase 6a |
