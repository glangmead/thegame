# Implementing a Board Game from Vassal Module + Rules PDF

A process for turning a physical board game into a playable `.game` file
interpreted by the DynamicalSystems app, with MCTS AI.

## When to Use

When the user wants to implement a new board game and has:
- An unzipped Vassal module (`.vmod` = ZIP with `buildFile` XML + `images/`)
- A rules PDF (possibly OCR'd)
- The existing DynamicalSystems framework to target

## Prerequisites

Read the `.game` format reference before starting:
- `.claude/skills/vassal-import/game-format-reference.md` — complete syntax reference

Read at least one existing `.game` file or the test examples in
`DynamicalSystemsTests/InterpretedGameTests.swift` to see the pattern.

For Vassal module interpretation:
- `.claude/skills/vassal-import/vassal_reference_manual.md` — XML parsing guide

## Output

The deliverable is a `.game` file (S-expression text) that the app interprets
at runtime. No Swift code is written for game logic — the interpreter handles
components, state, actions, pages, reactions, and MCTS integration.

The `.game` file should be placed at a location the user specifies, or
proposed as inline text for review.

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
- `evaluation`: which `.game` section covers this sentence, or why it's skipped

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

See `.claude/skills/vassal-import/vassal_reference_manual.md` for XML
interpretation. The module gives nouns (pieces, positions); the rules PDF
gives verbs (logic, phases).

## Phase 4: Build the .game File

Work through `rule` sentences with `status: "not_started"`, building the
`.game` file incrementally. Each bundle of related sentences maps to DSL
constructs.

**The process for each bundle:**

1. Find a minimal cluster of related `rule` sentences (often 2-5 sentences
   that describe one mechanic).
2. Translate them to the corresponding DSL section:
   - Nouns (piece types, tracks, enums) → `(components ...)`
   - Mutable fields → `(state ...)`
   - Player choices → `(actions ...)`
   - Board topology → `(graph ...)`
   - Phase flow, conditions, effects → `(rules ...)` pages and reactions
   - Reusable patterns → `(define ...)`
3. Update each sentence's `status` to `implemented` and `evaluation` to
   cite the DSL section that covers it.
4. Test by loading the `.game` file with `GameBuilder.buildValidated(from:)`.

**Ordering:** Start with components and state (enums, structs, cards), then
graph (tracks, sites), then actions, then core mechanics as pages (movement,
combat, resources), then card/event logic, then victory/defeat priority pages,
then housekeeping, then reactions.

**Composition:** Pages accumulate in the `(rules ...)` section. Priority pages
handle victory/defeat. Reactions handle cross-cutting consequences. Defines
factor out repeated patterns.

### DSL Mapping Guide

| Game concept | DSL construct |
|--------------|---------------|
| Piece/counter types | `(enum ...)` in components |
| Type properties (strength, cost) | `(fn ...)` in components |
| Card data | `(cards ...)` in components |
| Record types | `(struct ...)` in components |
| Bounded numbers (HP, energy) | `(counter name min max)` in state |
| On/off toggles | `(flag name)` in state |
| Per-entity state | `(dict name KeyType ValueType)` in state |
| Collections | `(set name Type)` in state |
| Card piles | `(deck name CardType)` in state |
| Nullable values | `(optional name Type)` in state |
| Army tracks, paths | `(track "name" length: N)` in graph |
| Named locations | `(site name)` in graph |
| Player choices | `(action name (param Type))` in actions |
| Phase flow | `(page ...)` with `(when (== phase X))` |
| Interrupts, victory/defeat | `(priority ...)` |
| Process-each-item mechanics | `(forEachPage ...)` |
| Limited-action phases | `(budgetedPage ...)` |
| Automatic consequences | `(reaction ...)` |
| Reusable logic | `(define "Name" (params) body)` |
| Die rolls | `(rollDie sides)` in reduce |
| Follow-up actions | `(chain actionName)` in reduce |

## Phase 5: Audit

Scan the sentence JSON for gaps:

1. Filter `category: "rule"` with `status: "not_started"` — these are missed
   rules. Implement or mark `not_implemented` with justification.
2. Filter `status: "implemented"` — re-read each sentence and verify the
   `evaluation` is accurate.
3. Produce `docs/<game>_rules_audit_summary.md`.

## Phase 6: AI and Integration

1. Add `(metadata (ai (heuristic EXPR)))` for MCTS evaluation. The heuristic
   should return higher values for better game states.
2. Add `(rolloutTerminal (field ended))` so MCTS rollouts terminate without
   simulating the acknowledgment step.
3. Test with `GameBuilder.buildValidated(from:)` to catch field reference
   errors at build time.

## Principles

- **The PDF is the source of truth.** When the `.game` file and PDF disagree, PDF wins.
- **Module gives nouns, rules give verbs.** Don't extract logic from Vassal XML.
- **Card data requires human verification.** Always have the user verify.
- **Work autonomously, report at milestones.** Don't confirm each section.
- **Cite rule numbers.** Use `;; Rule X.Y: ...` comments in the `.game` file.
- **Parameterize randomness.** Use `(rollDie N)` — the interpreter handles
  deterministic injection for testing.
- **Use defines for repeated patterns.** Factor shared logic into `(define ...)`
  forms. Keep the page-level reduce clauses readable.
- **Validate early.** Use `GameBuilder.buildValidated(from:)` after each
  significant addition to catch undefined field references.
