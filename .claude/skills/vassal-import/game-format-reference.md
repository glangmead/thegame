# .game S-Expression Format Reference

Complete reference for the `.game` file format interpreted by the DynamicalSystems
app. A `.game` file declares a solo board game as plain text. The app parses it,
validates it, and runs it against MCTS AI.

## File Structure

A `.game` file contains one to three top-level S-expression forms:

```scheme
(game "Name"
  (players 1)
  (components ...)
  (state ...)
  (graph ...)
  (actions ...)
  (rules ...))

(define ...)   ;; zero or more macro definitions

(metadata
  (ai ...))
```

Order of top-level forms does not matter. The `(game ...)` form is required.
`(define ...)` and `(metadata ...)` are optional.

---

## S-Expression Syntax

Atoms: bare words (`hello`, `42`, `true`, `false`) or quoted strings (`"Goblin Assault"`).

Lists: parenthesized `(a b c)` or braced `{a b c}` — both produce the same list node.
Braces are conventional for inline enum-case sets and function mappings.

Comments: `;` to end of line.

Variable references: `$name` refers to a variable bound by `(let ...)`, a
`(define ...)` parameter, or a `(\\ ...)` lambda parameter. Bare names (no `$`)
refer to state fields or enum values.

---

## Components

The `(components ...)` section declares enums, structs, enum functions, and cards.

### Enums

Simple enumeration of named cases:

```scheme
(enum Track {east west gate terror sky})
(enum Phase {card army event action heroic housekeeping})
```

Sum types with associated values:

```scheme
(enum HeroLocation reserves (onTrack Track))
```

Here `reserves` is a simple case; `onTrack` carries a `Track` value.

### Structs

Named record types with typed fields:

```scheme
(struct CardDRM
  (field action String)
  (field value Int))
```

### Enum Functions

Total functions mapping every case of an enum to a value:

```scheme
(fn strength ArmyType {goblin 2 orc 3 dragon 4 troll 4})
(fn isWall Track {east true west true gate true terror false sky false})
```

The mapping must be exhaustive — every case of the domain enum must appear.
Values can be `Int`, `Bool`, `String`, or list literals.

### Cards

Inline card data, parsed into struct values:

```scheme
(cards
  (card 1 "Goblin Raid" action event: advance)
  (card 2 "Dragon Fire" action event: terror))
```

Each `(card ...)` produces a `Card` struct with fields: `number` (Int),
`title` (String), `deck` (String), plus any `key: value` pairs as additional
fields.

---

## State Schema

The `(state ...)` section declares every mutable field. The interpreter builds
a dictionary-backed state from this schema and validates all mutations at
build time.

### Field Kinds

| Form | Semantics | Default |
|------|-----------|---------|
| `(counter name min max)` | Bounded integer, mutations clamp automatically | `min` |
| `(flag name)` | Boolean | `false` |
| `(field name Type)` | Typed value (typically an enum) | first enum case |
| `(dict name KeyType ValueType)` | Dictionary indexed by key type | empty |
| `(set name ElementType)` | Unordered set | empty |
| `(deck name CardType)` | Ordered list with draw/shuffle/discard | empty |
| `(optional name ValueType)` | Nullable value | `nil` |

Use `inf` for unbounded counter max: `(counter hp 0 inf)`.

### Framework-Managed Fields

These fields exist implicitly and do not need to be declared in the schema:

- `ended` — set by `(endGame ...)`, boolean
- `victory` — set by `(endGame victory)`, boolean
- `gameAcknowledged` — typically the terminal condition
- `phase` — managed by the phase system
- `history` — action history, managed by the framework

However, `ended`, `victory`, and `gameAcknowledged` are commonly declared as
explicit `(flag ...)` entries so that page conditions can reference them. The
validator allows mutations to these names regardless of declaration.

---

## Graph

The `(graph ...)` section declares spatial topology used by game logic.

```scheme
(graph
  (track "east" length: 6 wall: true)
  (track "sky" length: 6)
  (site reserves))
```

### Tracks

`(track "name" length: N)` creates N connected sites forming a linear path.
Optional `wall: true` tags the track as a wall track.

Each site in a track gets tags: `track:<name>`, `space:<index>`.

### Sites

`(site name)` creates a single named site (e.g., a reserve area, a card display
zone). The site gets `label` equal to the name.

### Empty Graph

`(graph)` with no children is valid — produces an empty `SiteGraph`.

---

## Actions

The `(actions ...)` section declares every action the player can take. Actions
are schema only — they declare names and parameters. Behavior is defined in
page `(reduce ...)` clauses.

```scheme
(actions
  (action drawCard)
  (action meleeAttack (slot ArmySlot))
  (action buildUpgrade (type UpgradeType) (track Track))
  (action acknowledge))
```

### Parameters

Each parameter is `(name Type)`. Parameters represent player choices made
before the action resolves. Randomness (die rolls, draws) happens at
resolution time in reduce, not as parameters.

### Groups

UI-only sectioning for the action picker:

```scheme
(group "Combat" {meleeAttack rangedAttack})
(group "Magic" {chant memorize pray})
```

---

## Rules

The `(rules ...)` section is the heart of the game. It declares phases,
terminal conditions, pages, and reactions.

### Phases

```scheme
(phases {card army event action heroic housekeeping})
```

Declares the ordered phase cycle. The initial phase is the first in the list.
The `phase` field on state tracks the current phase.

### Terminal Condition

```scheme
(terminal (field gameAcknowledged))
```

An expression evaluated against state. When it returns true, `isTerminal`
returns true and the game ends. Defaults to checking `gameAcknowledged` if
omitted.

### Rollout Terminal

```scheme
(rolloutTerminal (field ended))
```

A faster terminal check used during MCTS rollouts. Typically checks `ended`
rather than `gameAcknowledged`, so MCTS doesn't need to simulate the
acknowledgment step.

### Pages

Pages are the primary game-flow mechanism. Each page has a name, rules
(condition → offered actions), and reduce clauses (action → mutations).

#### Standard Page

```scheme
(page "Card Phase"
  (rule (when (== phase card))
        (offer drawCard))
  (reduce drawCard
    (seq
      (draw from: dayDrawPile to: currentCard)
      (chain advanceArmies))))
```

A rule fires when its `(when ...)` condition is true, offering the listed
actions. A `(reduce actionName ...)` clause defines what happens when that
action is chosen.

#### Priority Page

```scheme
(priority "Victory"
  (rule (when (and victory (not gameAcknowledged)))
        (offer claimVictory))
  (reduce claimVictory
    (set gameAcknowledged true)))
```

Same syntax as `(page ...)` but checked before normal pages. Used for
victory/defeat acknowledgment and interrupts.

#### ForEach Page

```scheme
(forEachPage "Army Advance"
  (when (== phase army))
  (items (list east west gate))
  (transition enterEvent)
  (reduce advanceArmy
    (log "advanced")))
```

Iterates over a dynamic list of items. Each item is processed once. After all
items are processed, the transition action fires automatically.

#### Budgeted Page

```scheme
(budgetedPage "Actions"
  (when (== phase action))
  (budget (atMost 3))
  (pass endPlayerTurn)
  (reduce meleeAttack ...))
```

Allows a limited number of actions per activation. The `(pass ...)` action
lets the player end early.

### Rules Within Pages

```scheme
(rule (when CONDITION) (offer ACTION1 ACTION2 ...))
```

Multiple rules per page are allowed. The page offers the union of all
matching rules' actions.

### Reduce Clauses

```scheme
(reduce actionName BODY)
```

The body is a reduce expression (see Reduce Primitives below). Each declared
action must have exactly one reduce clause across all pages.

### Reactions

```scheme
(reaction "Name"
  (when CONDITION)
  (apply REDUCE-EXPR))
```

Reactions fire silently after action resolution (including all follow-ups).
They never offer choices — they observe and mutate. Equivalent to `AutoRule`
in the Swift framework.

---

## Reduce Primitives

The bottom-layer operations executed by the reduce engine.

### Mutations

| Form | Effect |
|------|--------|
| `(set field value)` | Assign any state field |
| `(increment field N)` | Add N, clamp to counter max |
| `(decrement field N)` | Subtract N, clamp to counter min |
| `(insertInto setField element)` | Add to set |
| `(removeFrom setField element)` | Remove from set |
| `(setEntry dictField key value)` | Set dictionary entry |
| `(removeEntry dictField key)` | Remove dictionary entry |
| `(draw from: deckField to: optField)` | Draw top card from deck |
| `(shuffle deckField)` | Randomize deck order |
| `(discard from: optField to: deckField)` | Return card to deck |
| `(appendTo listField element)` | Append to list |
| `(removeAt listField index)` | Remove by index |
| `(clearList listField)` | Empty a list |
| `(setPhase phase)` | Explicit phase transition |
| `(endGame victory)` / `(endGame defeat)` | Set ended + victory/defeat |

### Control Flow

| Form | Effect |
|------|--------|
| `(seq expr ...)` | Execute in order |
| `(if cond then else?)` | Conditional branch |
| `(forEach collection (\\ (item) body))` | Iteration |
| `(guard condition)` | Abort rest of seq if false |
| `(chain actionName)` | Dispatch follow-up action through pages |
| `(let name value body)` | Bind variable for use in body |
| `(log message)` | Emit log entry |

### Guard Semantics

`(guard condition)` inside a `(seq ...)` aborts the remaining sequence if
false. Mutations before the guard persist — there is no rollback. It is not
a page-level dispatch mechanism.

### Chain Semantics

`(chain actionName)` queues a follow-up action. The framework dispatches it
through the page system after the current reduce completes. This enables
recursive resolution and cross-cutting interrupts (e.g., paladin reroll).

---

## Expressions

Pure expressions used in conditions, reduce bodies, and heuristics.

### Arithmetic

```scheme
(+ a b)  (- a b)  (* a b)  (/ a b)  (% a b)
(min a b)  (max a b)  (abs a)
```

### Comparison

```scheme
(== a b)  (!= a b)  (> a b)  (< a b)  (>= a b)  (<= a b)
```

### Boolean

```scheme
(and a b)  (or a b)  (not a)
```

`(and ...)` and `(or ...)` use short-circuit evaluation.

### Collections

```scheme
(contains setField element)     ;; set membership test
(lookup dictField key)          ;; dictionary access
(count deckOrListField)         ;; length
(isEmpty collection)            ;; empty check
(nth list index)                ;; index into list (0-based)
(list elem1 elem2 ...)          ;; construct list literal
(filter list (\\ (item) cond))  ;; filter to matching
(map list (\\ (item) expr))     ;; transform elements
```

### State Access

```scheme
fieldName                       ;; bare name reads a state field
(field name)                    ;; explicit field read
(param name)                    ;; read action parameter
(. structField memberField)     ;; struct field accessor
```

### Variable Binding

```scheme
(let x 5 (+ $x 3))             ;; binds $x = 5, evaluates body
```

Scoping is lexical. Inner bindings shadow outer ones.

### Randomness

```scheme
(rollDie sides)                 ;; random integer 1..sides
(randomElement collection)      ;; pick random element
```

These only execute at resolution time (inside reduce). The interpreter
accepts a deterministic random source for testing.

### String Formatting

```scheme
(format "{} attacks {}" slotName targetName)
```

### History Queries

```scheme
(historyCount (since marker) (matching (\\ (a) condition)))
```

---

## Defines

Macros that expand inline at the call site. Defined at the top level of the
`.game` file.

### Parameterless Define

```scheme
(define "drawsFromDayDeck" (< timePosition 6))
```

Called as `(drawsFromDayDeck)` — expands to `(< timePosition 6)`.

### Parameterized Define

```scheme
(define "AdvanceArmy" (slot)
  (setEntry armyPosition $slot (- (lookup armyPosition $slot) 1)))
```

Called as `(AdvanceArmy east)` — substitutes `east` for every `$slot` in
the body.

### Composition

Defines can call other defines. The expander enforces an acyclic call graph
at parse time — cyclic definitions are a build error.

---

## Metadata

Optional section for AI configuration.

### Heuristic

```scheme
(metadata
  (ai
    (heuristic (/ score 10))))
```

An expression evaluated against state, returning a float used by MCTS as
the state evaluation function. The expression has access to all state fields
and expression operators.

---

## Runtime Value Types (DSLValue)

All runtime values are one of:

| Case | Example |
|------|---------|
| `.int(Int)` | `42` |
| `.float(Float)` | `1.5` |
| `.bool(Bool)` | `true`, `false` |
| `.string(String)` | `"Goblin Assault"` |
| `.enumCase(type, value)` | `east` resolved as `Track.east` |
| `.list([DSLValue])` | `(list 1 2 3)` |
| `.structValue(type, fields)` | Card instances |
| `.nil` | absent optional |

Enum cases are resolved by the `ComponentRegistry` — bare names that match
a declared enum case are automatically wrapped.

---

## Validation

`GameBuilder.buildValidated(from:)` performs static checks at parse time:

- Every `(set ...)`, `(increment ...)`, `(decrement ...)` etc. targets a
  field declared in the state schema (or a builtin like `ended`/`victory`).
- Define call graphs are acyclic.
- All S-expressions parse without error.

---

## Interpretation Pipeline

When a `.game` file is loaded:

1. **Parse** — S-expression text → `SExpr` tree (atoms and lists).
2. **Classify** — Top-level forms sorted into `game`, `define`, `metadata`.
3. **Expand** — `DefineExpander` processes all `(define ...)` forms, validates
   acyclic call graph.
4. **Build components** — `ComponentRegistry` from `(components ...)`.
5. **Build state schema** — `StateSchema` from `(state ...)`.
6. **Build actions** — `ActionSchema` from `(actions ...)`.
7. **Build graph** — `GraphBuilder` from `(graph ...)`.
8. **Build pages** — `PageBuilder` constructs `RulePage`, `ForEachPage`,
   `BudgetedPhasePage` instances from `(rules ...)`.
9. **Build reactions** — `PageBuilder` extracts `(reaction ...)` forms.
10. **Validate** — `Validator` checks all mutation targets exist.
11. **Compose** — Everything assembled into a `ComposedGame<InterpretedState>`.
12. **Metadata** — `MetadataBuilder` extracts heuristic if present.

The resulting `ComposedGame` conforms to `PlayableGame` and works with the
existing MCTS engine, SwiftUI views, and CLI gamer tool.

---

## Complete Minimal Example

```scheme
(game "Coin Flip"
  (players 1)
  (components
    (enum Phase {play done}))
  (state
    (counter score 0 10)
    (flag ended)
    (flag victory)
    (flag gameAcknowledged)
    (field phase Phase))
  (graph)
  (actions
    (action flipHeads)
    (action flipTails)
    (action acknowledge))
  (rules
    (phases {play done})
    (terminal (field gameAcknowledged))
    (page "Play"
      (rule (when (== phase play))
            (offer flipHeads flipTails))
      (reduce flipHeads
        (seq (increment score 1)
             (if (>= score 3)
               (seq (endGame victory) (setPhase done))
               (log "tails, no points"))))
      (reduce flipTails
        (log "tails, no points")))
    (priority "Victory"
      (rule (when (and victory (not gameAcknowledged)))
            (offer acknowledge))
      (reduce acknowledge
        (set gameAcknowledged true)))))
```

## Example with Die Rolls and Heuristic

```scheme
(game "Coin Collector"
  (players 1)
  (components
    (enum Phase {flip done})
    (enum Outcome {heads tails}))
  (state
    (counter heads 0 10)
    (counter tails 0 3)
    (field phase Phase)
    (flag ended)
    (flag victory)
    (flag gameAcknowledged))
  (actions
    (action flip)
    (action acknowledge))
  (rules
    (phases {flip done})
    (terminal (field gameAcknowledged))
    (rolloutTerminal (field ended))
    (page "Flip"
      (rule (when (and (== phase flip) (not ended)))
            (offer flip))
      (reduce flip
        (seq
          (let coin (rollDie 2))
          (if (== $coin 1)
            (seq
              (increment heads 1)
              (set tails 0)
              (if (>= heads 10)
                (endGame victory)
                (log "Heads!")))
            (seq
              (increment tails 1)
              (if (>= tails 3)
                (endGame defeat)
                (log "Tails...")))))))
    (priority "End"
      (rule (when (and ended (not gameAcknowledged)))
            (offer acknowledge))
      (reduce acknowledge
        (set gameAcknowledged true)))))

(metadata
  (ai
    (heuristic (- (* 0.1 heads) (* 0.3 tails)))))
```
