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
rulebook carefully, section by section. **Account for every single sentence.**

**Produce a sentence-level JSON as the primary Phase 1 deliverable.** Extract
every sentence from the rulebook into a JSON array stored at
`docs/<game>_rules_sentences.json`. Each entry has:

```json
{
  "section": "4.1.2",
  "sentence": "The first time an army would advance from the 1 to the 0 space, instead remove any upgrade on that track from the game and add a breach marker to that track's castle circle.",
  "category": "rule",
  "status": "not_started",
  "evaluation": ""
}
```

Fields:
- `section`: rule number from the PDF
- `sentence`: the exact sentence text
- `category`: one of `rule` (requires implementation), `flavor` (no implementation),
  `formatting` (visual/typographic convention), `example` (illustrative only),
  `cross_reference` (just points to another section)
- `status`: one of `not_started`, `implemented`, `partially_implemented`,
  `not_implemented` (consciously skipped), `not_applicable`
- `evaluation`: free text noting which code/tests handle this sentence, or why
  it's skipped. Include file names, function names, and test names.

This JSON is the single source of truth for coverage. It serves as:
- The study artifact (Phase 1) — forces you to read every sentence
- The implementation checklist (Phases 3–5) — update status as you go
- The audit checklist (Phase 5a) — scan for `not_started` entries
- The deliverable for user review — they can see exactly what's covered

Categorizing sentences is fast and valuable. Roughly 30% of sentences will be
`flavor`, `formatting`, `example`, or `cross_reference` — marking them upfront
prevents wasted effort during implementation. The remaining `rule` sentences are
your implementation backlog.

For each `rule` sentence, also extract during this read:
- The exact mechanic (what triggers it, what it does, what limits apply)
- Edge cases mentioned in the text (e.g., "except magical attacks")
- Constraints that are easy to miss (e.g., "once per turn", "only on wall tracks")
- Cross-references to other rules (e.g., "see section 6.3 for upgrades")
- DRM bonuses scattered across different sections (these are the most commonly missed)
- **Nested decision points and multi-step resolution sequences** (see below)

**Identify every nested choice system.** Many rules create multi-step resolution
sequences where the player must see intermediate results before making the next
decision. These are the hardest mechanics to implement correctly because they
require the game state to pause mid-resolution and present a sub-menu of choices.
For each rule, ask: "Does this create a sequence where the player acts, observes
a result, then acts again?" Catalog every instance:

- **Sequential attacks with observation:** "Make N attacks, one at a time" means
  the player sees each attack result before choosing the next target. This cannot
  be implemented as an atomic function that takes all targets upfront.
- **Conditional branches mid-resolution:** "If the attack fails, you may re-roll"
  requires the player to see the failure before deciding. "Roll the die; you may
  sacrifice units to reduce the result" requires seeing the roll first.
- **Choice-then-subchoice:** "Gain a defender OR return a dead hero" is a branch;
  each branch may itself require a choice (which defender type? which hero?).
  Heroic versions often upgrade exclusive-OR to inclusive-AND/OR, creating
  compound choices.
- **Reactive interrupts:** "After any die roll, you may re-roll once per turn"
  creates a potential decision point after every die roll in the entire game.
- **Free-form interleaving:** "The Rogue can move at any point during the action
  phase without using an action" means extra choice points between every action.

**Survey cards for the same patterns.** If a game has event cards, quest cards,
item cards, or spell cards, their text often contains miniature decision systems:
nested choices, conditional branches, timing decisions ("use before or after an
attack"), and variable-investment mechanics ("spend N actions for +N DRM, then
roll"). Read every card and flag any that create sub-phases of play. Cards are
the most common source of missed nested choices because their text is terse and
effects are spread across many individual cards rather than consolidated in one
rule section.

**Produce a nested-choice inventory.** Before writing any code, compile a list of
every mechanic that requires mid-resolution player input. Classify each as:
1. **Multi-step sequential** — player must observe intermediate state (e.g.,
   "make 3 attacks, choosing targets after each result")
2. **Branching with sub-choices** — player picks a path, then makes further
   decisions within that path (e.g., "gain defenders OR return a hero")
3. **Conditional reaction** — player decides after seeing a random outcome
   (e.g., "if attack fails, may re-roll")
4. **Reactive interrupt** — can trigger at many points during play (e.g.,
   paladin re-roll, rogue free movement)
5. **Variable investment** — player chooses how many resources to spend before
   a single roll (e.g., "spend actions/heroics for DRM, then roll")

This inventory drives the state-machine design: each multi-step mechanic needs
intermediate game states with their own `allowedActions`, not a single atomic
action enum case with all parameters baked in.

**Read the Player Aid / reference card images too.** They often contain compact
rule summaries with details not in the main rules text (e.g., "Paladin — holy" or
upgrade effects).

**Watch for "printed value" tracks.** Some tracks have values printed at each
space that are NOT simply 0, 1, 2, 3. Phrases like "refer to the number under
the X marker" or "the number shown on the space" indicate the track position
and the game-mechanical value diverge. When you see such a sentence, examine
the board image to read the printed values at each space, and ask the user to
verify. Model these as a position index with a value-lookup array, not as a
simple integer count.

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
5. Update the sentence JSON: set `status` to `implemented` and fill in
   `evaluation` with the test name(s) and source file(s) that cover the sentence
6. Move to the next rule

**The sentence JSON drives the work.** Filter for `category: "rule"` entries
with `status: "not_started"` to find what's left. Working section by section
through the JSON ensures nothing is skipped. At the end of each work session,
the JSON reflects exactly what has and hasn't been covered.

**Do not present each test to the user for confirmation.** Work autonomously
through the rules. The user will review the code at natural milestones (end of a
phase, end of a major rule section). Report progress as a summary table of tests
added and rules covered.

### Phase 5a: Audit — Scan the Sentence JSON

**This is the most critical phase.** After the initial implementation pass, scan
the sentence JSON for gaps. The mechanical process:

1. Filter for all entries with `category: "rule"` and `status: "not_started"`.
   These are rules you missed entirely. For each, decide: implement it, or mark
   `not_implemented` with a justification (e.g., "Undead scenario not yet scoped").

2. Filter for `status: "implemented"`. For each, re-read the original sentence
   and verify the `evaluation` field is accurate. Check that the cited tests
   actually test what the sentence says. This is where subtle misimplementations
   surface — the sentence says X, the code does something close but not quite X.

3. Filter for `status: "partially_implemented"`. These are known gaps. Decide
   whether to finish them now or defer.

4. Produce a summary file (`docs/<game>_rules_audit_summary.md`) listing
   "Not Implemented" and "Potential Issues" sections, with sentence references.

This audit typically finds 10-15 issues per game. Common categories:

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

**Atomic implementation of multi-step mechanics:**
- A spell says "make 3 attacks, choosing targets after each result" but the action
  enum takes all 3 targets at once — the player never sees intermediate results
- An event says "roll die, then sacrifice units to reduce the advance" but the
  action takes sacrifices alongside the die roll — the player should see the roll first
- A quest reward says "draw a spell of your choice" but the choice is a parameter
  on the quest action — it should be a nested sub-phase with its own allowedActions
- Any "if X fails, you may Y" conditional requires seeing the failure before deciding
- Check every spell, event card, and ability for sentences containing "then",
  "one at a time", "you may", "of your choice", or "after seeing the result" —
  these signal that atomic parameter-passing is wrong and a state machine is needed

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

#### Composable Page State and Actions (TCA-Style Embedding)

The overall game State is a **product** of all page states, and the overall
Action enum is a **coproduct** of all page action types. This follows the
composition pattern from The Composable Architecture (TCA): each stateful
page declares its own `State` struct and `Action` enum. The global State
gets one `Optional` field per stateful page; the global Action gets one
case per page action type. No changes to the `RulePage` framework are
needed — the composition is entirely at the game level.

**Litmus test — when does a page need local state?** A page needs its own
state if **either:**

1. **Multi-step resolution (Prong 1):** Resolution requires multiple
   round-trips with the player where later choices depend on intermediate
   outcomes that don't exist yet when the first action is chosen. Example:
   "make 3 attacks, choosing targets after each result" — the result of
   attack 1 affects the player's choice for attack 2.

2. **Feature-scoped persistence (Prong 2):** The page introduces persistent
   bookkeeping that no other page would need if this page didn't exist.
   Example: a magic item's existence and per-turn usage tracking are
   meaningless outside that item's RulePage. Moving the item's state from
   the global struct to an `Optional` page field means the state vanishes
   when the feature is inactive.

**Everything else** — branch-then-pick, path choices, hero selection,
defender type selection — is fully captured by enumerating all valid
concrete parameterized actions. No local state needed; just generate N
action values, one per valid combination, in the page's `actions` closure.

**Pattern for multi-step pages:**

```swift
// 1. Define page-local state and actions
struct ChainLightningState: Equatable, Hashable {
  let heroic: Bool
  var boltIndex: Int = 0
  var results: [AttackResult] = []
}

enum ChainLightningAction: ActionGroup, Hashable {
  static let groupName = "Chain Lightning"
  case targetBolt(ArmySlot, dieRoll: Int)
}

// 2. Embed in global types
// In State: var chainLightningState: ChainLightningState?
// In Action: case chainLightning(ChainLightningAction)

// 3. Guard other pages with isInSubResolution
var isInSubResolution: Bool {
  chainLightningState != nil || fortuneState != nil // etc.
}

// 4. Write a RulePage whose condition checks its own state
static var chainLightningPage: RulePage<State, Action> {
  RulePage(
    name: "Chain Lightning",
    rules: [
      GameRule(
        condition: { $0.chainLightningState != nil },
        actions: { state in /* enumerate targets for current bolt */ }
      )
    ],
    reduce: { state, action in
      guard case .chainLightning(let sub) = action else { return nil }
      // resolve bolt, update page state, clear when complete
    }
  )
}

// 5. Activation: the casting page sets up the sub-state instead of
//    resolving atomically
case .chainLightning:
  state.chainLightningState = ChainLightningState(heroic: heroic)
```

**Pattern for feature-scoped persistent pages:**

```swift
// 1. Define minimal page state (existence = feature is active)
struct MagicItemState: Equatable, Hashable { }

// 2. Embed as Optional in global State
// var magicSwordState: MagicItemState?

// 3. Quest reward activates: magicSwordState = MagicItemState()
// 4. Item use consumes: magicSwordState = nil
// 5. Other pages read the Optional to know if the feature is available
```

**Concrete action enumeration for choice-having mechanics:**

When a spell, event, or ability involves player choices but does NOT need
multi-step resolution (i.e., the entire decision can be captured in one
action value), enumerate all valid concrete parameterized actions in the
page's `actions` closure. Do NOT offer a single action with empty/default
parameters — MCTS and the UI need to see every valid choice as a distinct
action.

```swift
// Bad: one action with empty params (MCTS can't explore choices)
actions.append(.magic(.castSpell(.raiseDead, heroic: false, SpellCastParams())))

// Good: one action per valid combination
for pair in defenderPairs {
  actions.append(.magic(.castSpell(.raiseDead, heroic: false,
    SpellCastParams(defenders: [pair.0, pair.1]))))
}
for hero in deadHeroes {
  actions.append(.magic(.castSpell(.raiseDead, heroic: false,
    SpellCastParams(returnHero: hero))))
}
```

#### Factoring Actions into Sub-Enums

When a game has many action types (e.g., 15+ cases), factor the `Action` enum
into logical sub-enums grouped by domain. The outer enum becomes a coproduct
(tagged union) of the inner types:

```swift
indirect enum Action: Hashable, GroupedAction {
  case combat(CombatAction)
  case build(BuildAction)
  case magic(MagicAction)
  case heroic(HeroicAction)
  case quest(QuestAction)
  // Plus ungrouped top-level cases (drawCard, passActions, etc.)
}
```

Each inner enum conforms to `ActionGroup` (defined in `Game.swift`), which
provides a `groupName` used by the UI for sectioned rendering. The outer enum
conforms to `GroupedAction`, whose default implementation uses `Mirror` to
extract the group name from a wrapped sub-enum value, falling back to "General"
for unwrapped cases.

**Benefits:**

1. **Compositional structure.** Each sub-enum owns its domain's cases and
   descriptions. Adding a new combat variant means editing only `CombatAction`,
   not a monolithic 25-case switch. Pattern matching on the outer enum can
   match at the group level (`case .combat:`) or drill in
   (`case .combat(.meleeAttack(let slot, ...)):`).

2. **One RulePage per sub-enum.** Each group gets its own page (e.g.,
   `combatPage`, `buildPage`, `magicPage`). The page's `reduce` matches on
   its group case and delegates to shared resolution helpers. This replaces
   a monolithic action page with focused, testable pages.

3. **Grouped UI rendering.** `MCTSActionSection` accepts an optional `grouping`
   closure. When provided, actions render under section headers (e.g., "Combat",
   "Fortification", "Magic") instead of a single flat list. The view passes
   `{ $0.actionGroup }` to enable this. Games with fewer actions can omit the
   closure for flat rendering.

4. **Shared paladin-style interrupt handling.** When multiple pages need the
   same die-roll deferral logic (e.g., Paladin re-roll), extract a shared
   helper like `resolveDieRollWithPaladinCheck(_:phase:)` that each page's
   reducer calls. This eliminates duplicated re-roll/defer/resolve code.

**When to factor:** Do this when the action count exceeds ~15 cases and there
are natural domain groupings. For simpler games with 5-10 actions, a flat enum
and single action page are fine.

**Sub-enum parameters may diverge from the flat version.** Merging similar
cases is encouraged: e.g., `questAction` + `questHeroic` become
`QuestAction.quest(isHeroic:dieRoll:reward:)`. Similarly, `memorize(SpellType)`
can become `MagicAction.memorize(randomSpell: SpellType?)` where `nil` means
"draw randomly at resolution" and non-nil is the deterministic test path.

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

The PDF should be read **at least three times** during implementation. The
sentence-level JSON turns each read into a concrete, traceable activity.

1. **First read (Phase 1) — Extraction.** Read cover-to-cover and extract every
   sentence into the JSON. Categorize each as `rule`, `flavor`, `formatting`,
   `example`, or `cross_reference`. Set all `rule` entries to `status: "not_started"`.
   This produces the implementation backlog. Also identify nested-choice mechanics
   and catalog them separately (see Phase 1 details).

2. **Second read (Phase 5) — Implementation.** Work through `rule` entries section
   by section. Before writing each test, re-read the sentence. After the test
   passes, update the JSON entry's `status` to `implemented` and fill in
   `evaluation` with file/test references. At any point, filtering for
   `not_started` shows exactly what remains.

3. **Third read (Phase 5a) — Audit.** Scan the JSON mechanically:
   - Any `rule` entry still `not_started`? Implement it or mark `not_implemented`.
   - For each `implemented` entry, re-read the sentence and verify the evaluation
     is accurate. Does the test actually test what the sentence says? This catches
     subtle misimplementations where the code does something close but not right.
   - Produce the summary file.

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
| Placeholder die rolls never randomized | Actions generated with `dieRoll: 0` resolved literally — every attack misses | Use `effectiveDie()`: randomize 0 → 1-6 at resolution time, pass through non-zero for deterministic tests |
| Multi-step mechanic implemented atomically | Chain Lightning takes all 3 targets upfront — player never sees attack 1 before choosing target 2 | Identify every "one at a time" / "then choose" / "you may re-roll" sentence; implement as state-machine sub-phases with intermediate `allowedActions` |
| Card text creates hidden sub-phases | Quest reward "draw a spell of your choice" baked into quest action params — no nested choice | Read every card; any "of your choice", "you may", or "then" on a card creates a sub-phase needing its own `allowedActions` |
| Force-unwrap on optional die roll | Barricade/grease paths crash when `dieRoll` is `nil` | Use `effectiveDie(dieRoll ?? 0)` instead of `dieRoll!` |
| Track conflated with value | Defenders stored as count 0-3 (was actually a 6-space track with values [3,2,2,2,1,0]) | When the PDF says "refer to the number under the X marker" or similar, the track positions and game-mechanical values are not the same. Ask the user for the printed value at each space. |

### Phase 6c: Die Roll Randomization Tests

When actions carry placeholder die rolls (e.g., `dieRoll: 0`), the resolution layer
must randomize them. This is easy to get wrong — the actions look correct in tests
(which supply explicit rolls) but silently break in MCTS rollouts and CLI play.

**Write statistical tests that verify randomization works end-to-end:**

```swift
@Test func meleeAttackWithPlaceholderDieSometimesHits() {
    // Placeholder dieRoll=0 should be randomized, so attacks against
    // a low-strength army sometimes hit and sometimes miss.
    var hitCount = 0
    for _ in 0..<100 {
        var state = Game.setup(...)
        state.armyPosition[.east] = 2  // melee range
        let action = Action.meleeAttack(.east, dieRoll: 0, ...)
        let logs = state.resolveActionDieRoll(action)
        if logs.map(\.msg).joined().contains("hit") { hitCount += 1 }
    }
    #expect(hitCount > 10, "Expected some hits in 100 trials")
    #expect(hitCount < 100, "Expected some misses in 100 trials")
}
```

**Also test that explicit die rolls still work** (determinism for unit tests):

```swift
@Test func explicitDieRollStillWorks() {
    // Explicit dieRoll=6 against strength 2 should always hit.
    var state = Game.setup(...)
    let action = Action.meleeAttack(.east, dieRoll: 6, ...)
    let logs = state.resolveActionDieRoll(action)
    #expect(logs.map(\.msg).joined().contains("hit"))
}
```

**Test every path that consumes a die roll:**
- Action-phase attacks (melee, ranged)
- Heroic-phase attacks
- Build upgrade/barricade rolls
- Chant, rally, quest rolls
- Event die rolls
- Barricade test rolls (army reaching breached/barricaded wall)
- Grease/upgrade defense rolls

**The `effectiveDie` pattern:** A static helper that returns `Int.random(in: 1...6)`
when given 0, and passes through any non-zero value unchanged. Apply it at the
resolution boundary — NOT in `allowedActions` (which generates actions for the
MCTS tree and needs stable identities) and NOT deep in state mutation functions
(which should remain pure and testable with explicit rolls).
