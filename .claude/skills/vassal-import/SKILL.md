# Implementing a Board Game from Vassal Module + Rules PDF

A process for turning a physical board game into a working digital implementation
using TDD, with the DynamicalSystems Swift framework as the target.

## When to Use

When the user wants to implement a new board game and has:
- An unzipped Vassal module (`.vmod` = ZIP with `buildFile` XML + `images/`)
- A rules PDF (possibly OCR'd)
- The existing DynamicalSystems framework to target

## Prerequisites

Read the framework code before starting:
- `Sources/Game.swift` — protocols: `GameComponents`, `GameState`, `PlayableGame`
- `Sources/Framework/ComposedGame.swift` — `oapply()` composition
- `Sources/Framework/RulePage.swift` — condition/action rule pages
- `Sources/Framework/ForEachPage.swift`, `BudgetedPhasePage.swift` — meta-rules

Read at least one existing implementation (e.g., `Sources/Legions of Darkness/`)
to see the Components -> State -> Pages -> ComposedGame -> Graph -> SceneConfig pattern.

## Phase 1: Extract Every Sentence

Read the rules PDF cover-to-cover and extract every sentence into a JSON file
at `docs/<game>_rules_sentences.json`. Each entry:

```json
{
  "section": "4.1.2",
  "sentence": "The first time an army would advance from the 1 to the 0 space, instead remove any upgrade on that track.",
  "category": "rule",
  "status": "not_started",
  "evaluation": ""
}
```

Fields:
- `section`: rule number from the PDF
- `sentence`: exact sentence text
- `category`: `rule` | `flavor` | `formatting` | `example` | `cross_reference`
- `status`: `not_started` | `implemented` | `partially_implemented` | `not_implemented` | `not_applicable`
- `evaluation`: which code/tests cover this sentence, or why it's skipped

Roughly 30% of sentences will be non-`rule`. Marking them upfront prevents
wasted effort during implementation. The remaining `rule` sentences are the
implementation backlog.

## Phase 2: Collect Component Text

Many games have rules printed on components (cards, player aids, tiles) that
aren't in the main rulebook. For card-driven games, the card effects are only
on the card art.

1. Read each card/component image and compile data into a JSON file
   (e.g., `vassal/<module>/cards.json`).
2. **Have the user verify** — image reading is error-prone for icons and numbers.
3. Add sentences from component text to the rules JSON using a `"section"` that
   identifies the component (e.g., `"card:15"`, `"player_aid:combat_table"`).

## Phase 3: Vassal Module for Components

Read the `buildFile` XML to catalog the physical components:
- Piece/counter types, names, images
- Board layout (tracks, grids, regions)
- Decks, card counts, setup positions

See `docs/vassal_reference_manual.md` for XML interpretation. The module gives
nouns (pieces, positions); the rules PDF gives verbs (logic, phases).

## Phase 4: Agglutinative Implementation

Work through `rule` sentences with `status: "not_started"`, implementing them
in small bundles. Each bundle becomes one RulePage or AutoRule.

**The process for each bundle:**

1. Find a minimal cluster of related `rule` sentences (often 2-5 sentences
   that describe one mechanic).
2. Write tests for those sentences (red). Cite rule numbers in comments.
3. Implement the minimal code to pass (green) — typically one of:
   - A mutating function on State
   - A RulePage with condition/actions/reduce
   - An AutoRule
4. Run tests to verify.
5. Update each sentence's `status` to `implemented` and `evaluation` to
   cite the test names and source files.
6. Move to the next bundle.

**Ordering:** Start with components and state (enums, structs, setup), then
core mechanics (movement, combat, resources), then card/event logic, then
victory/defeat, then housekeeping. But follow natural dependencies — if
sentence A references a concept from sentence B, implement B first.

**Composition:** As pages accumulate, compose them with `oapply()` into a
`ComposedGame`. Priority pages handle victory/defeat. AutoRules handle
cross-cutting consequences that fire after any action.

## Phase 5: Audit

Scan the sentence JSON for gaps:

1. Filter `category: "rule"` with `status: "not_started"` — these are missed
   rules. Implement or mark `not_implemented` with justification.
2. Filter `status: "implemented"` — re-read each sentence and verify the
   `evaluation` is accurate. Does the test actually test what the sentence says?
3. Produce `docs/<game>_rules_audit_summary.md`.

## Phase 6: MCTS and CLI Integration

1. Set `endedInVictoryFor` / `endedInDefeatFor` at every `ended = true` site.
2. Write an MCTS smoke test verifying non-zero reward signal.
3. Add the game to the `gamer` CLI in `DynamicalSystems/gamer/GamerTool.swift`.
4. Write integration tests: at least one victory playthrough and one defeat.

## Phase 7: Rendering (later)

SpriteKit rendering using Vassal board/piece images. Uses `SceneConfig`
(declarative DSL) and `GameScene`. Deferred until game logic is complete.

## Principles

- **The PDF is the source of truth.** When code and PDF disagree, PDF wins.
- **Module gives nouns, rules give verbs.** Don't extract logic from Vassal XML.
- **Card data requires human verification.** Always have the user verify.
- **Work autonomously, report at milestones.** Don't confirm each test.
- **Cite rule numbers in every test.** `// Rule X.Y: ...` comment.
- **Parameterize randomness.** Die rolls and shuffles must be injectable.

## Xcode Project Notes

File-system-synchronized groups (objectVersion 77). New source files in
`Sources/` are auto-discovered by the app target. The **test target** requires
manual `membershipExceptions` edits in `project.pbxproj`.
