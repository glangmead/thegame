# .game.jsonc Format Reference

Complete reference for the `.game.jsonc` file format interpreted by the
DynamicalSystems app. A `.game.jsonc` file declares a solo board game as
JSON with comments. The app parses it, validates it, and runs it against
MCTS AI.

## File Structure

A `.game.jsonc` file is a single JSON object with these top-level keys:

```jsonc
{
  "game": "Name",
  "players": 1,
  "components": { ... },
  "state": { ... },
  "graph": { ... },
  "actions": { ... },
  "rules": { ... },
  "defines": [ ... ],
  "metadata": { ... },
  "scene": { ... }
}
```

`"game"` and `"players"` are required. All other sections are optional.

---

## JSON with Comments

The parser accepts standard JSON extended with `//` line comments.
Comments are stripped before parsing.

Variable references: `"$name"` refers to a variable bound by `{"let": ...}`,
a define parameter, or a `{"fn": ...}` lambda parameter. Bare names (no `$`)
refer to state fields or enum values.

Enum case references: `".caseName"` (dot prefix) explicitly marks an enum
case. Bare strings matching a declared enum case are also resolved as enum
values.

---

## Components

The `"components"` object declares enums, structs, functions, cards, and CRTs.

### Enums

```jsonc
"enums": [
  {"name": "Phase", "values": ["card", "army", "event", "action"]},
  {"name": "AllyPiece", "values": ["allied101st", "allied82nd"],
   "player": 0, "displayNames": ["101st", "82nd"]},
  {"name": "ArmySlot", "values": ["east", "west", "gate"],
   "player": 1, "displayNames": ["East", "West", "Gate"]}
]
```

- `"player"`: assigns all cases to a player index (0 = protagonist, 1 = opponent).
  Used by the renderer to color pieces.
- `"displayNames"`: parallel array of human-readable names for each case.

### Structs

Named record types with typed fields:

```jsonc
"structs": [
  {"name": "CardDRM", "fields": [
    {"name": "action", "type": "String"},
    {"name": "value", "type": "Int"}
  ]}
]
```

### Functions

Total functions mapping every case of an enum to a value:

```jsonc
"functions": [
  {"name": "armyStrength", "domain": "ArmySlot",
   "mapping": {"east": 2, "west": 3, "gate": 2}}
]
```

The mapping must cover every case of the domain enum.

### Cards

Inline card data. Each card is a struct-like object with arbitrary fields:

```jsonc
"cards": [
  {"number": 1, "title": "Goblin Raid", "deck": "dayDeck",
   "advances": ["east", "west"], "actions": 3, "heroics": 1,
   "eventNumber": 1}
]
```

The `"deck"` field determines which state deck the card is added to during
`makeInitialState`. Cards are shuffled and drawn at runtime.

### Combat Results Tables (CRT)

#### 2D CRT

```jsonc
"crts": [
  {"name": "attackCRT",
   "row": "Advantage", "col": [1, 6],
   "results": ["allyHits", "germanHits", "controlGained"],
   "entries": {
     "allies":  [{"dice": [1], "values": [1, 0, false]},
                 {"dice": [2, 3, 4], "values": [1, 1, true]},
                 {"dice": [5, 6], "values": [0, 1, true]}],
     "germans": [{"dice": [1], "values": [3, 0, false]},
                 {"dice": [2, 3, 4], "values": [2, 1, false]},
                 {"dice": [5, 6], "values": [1, 0, true]}]
   }}
]
```

Called as `{"attackCRT": ["$rowValue", "$dieRoll"]}`. Returns a struct with
result fields accessible via `{"get": ["$result", "allyHits"]}`.

#### 1D CRT

```jsonc
{"name": "airdropPenalty",
 "col": [1, 6],
 "entries": [
   {"dice": [1, 2], "values": [2]},
   {"dice": [3, 4], "values": [1]},
   {"dice": [5, 6], "values": [0]}
 ]}
```

Called as `{"airdropPenalty": ["$roll"]}`. Returns a scalar value.

---

## State Schema

The `"state"` object declares every mutable field.

```jsonc
"state": {
  "fields": [
    {"name": "phase", "type": "Phase"},
    {"name": "morale", "type": "Morale"}
  ],
  "counters": [
    {"name": "score", "min": 0, "max": 10},
    {"name": "hp", "min": 0, "max": "inf"}
  ],
  "flags": ["ended", "victory", "gameAcknowledged"],
  "dicts": [
    {"name": "armyPosition", "key": "ArmySlot", "value": "Int"},
    {"name": "armyStrengthDict", "key": "ArmySlot", "value": "Int"}
  ],
  "sets": [
    {"name": "breaches", "type": "Track"}
  ],
  "decks": [
    {"name": "dayDeck", "cardType": "Card"}
  ],
  "optionals": [
    {"name": "currentCard", "type": "Card"},
    {"name": "slowedArmy", "type": "ArmySlot"}
  ]
}
```

### Field Kinds

| Key | Semantics | Default |
|-----|-----------|---------|
| `"fields"` | Typed value (typically an enum) | first enum case |
| `"counters"` | Bounded integer, mutations clamp automatically | `min` |
| `"flags"` | Boolean | `false` |
| `"dicts"` | Dictionary indexed by key type | empty |
| `"sets"` | Unordered set | empty |
| `"decks"` | Ordered list with draw/shuffle/discard. Requires `"cardType"`. | empty, populated from cards |
| `"optionals"` | Nullable value | `null` |

### Framework-Managed Fields

These fields exist implicitly:

- `ended` — set by `{"endGame": [...]}`, boolean
- `victory` — set by `{"endGame": ["victory"]}`, boolean
- `gameAcknowledged` — typically the terminal condition
- `phase` — managed by the phase system
- `history` — action history, managed by the framework

Declaring `ended`, `victory`, and `gameAcknowledged` as explicit flags is
common so page conditions can reference them.

---

## Graph

The `"graph"` object declares spatial topology.

```jsonc
"graph": {
  "tracks": [
    {"name": "eastTrack", "length": 7, "tags": ["army", "east"],
     "displayNames": ["E0", "E1", "E2", "E3", "E4", "E5", "E6"]},
    {"name": "road", "length": 5,
     "displayNames": ["Belgium", "Eindhoven", "Grave", "Nijmegen", "Arnhem"],
     "tags": ["road"]}
  ],
  "connections": [
    {"type": "crossConnect", "from": "alliedTrack", "to": "road", "offset": 1}
  ]
}
```

### Tracks

Each track entry creates a linear sequence of connected sites.

- `"name"`: track identifier used in `{"site": ["trackName", index]}`
- `"length"`: number of sites
- `"tags"`: string array for categorization and styling
- `"displayNames"`: optional labels for each site (must match length)

### Connections

- `"crossConnect"`: creates parallel edges between corresponding sites of
  two tracks. `"offset"` shifts the alignment.

### Empty Graph

`"graph": {}` or omitting the key produces an empty `SiteGraph`.

---

## Actions

The `"actions"` object declares every action the player can take.

```jsonc
"actions": {
  "actions": [
    {"name": "drawCard"},
    {"name": "meleeAttack", "params": [{"name": "slot", "type": "ArmySlot"}]},
    {"name": "buildUpgrade", "params": [
      {"name": "type", "type": "UpgradeType"},
      {"name": "track", "type": "Track"}
    ]},
    {"name": "acknowledge"}
  ],
  "groups": [
    {"name": "Combat", "actions": ["meleeAttack", "rangedAttack"]},
    {"name": "Magic", "actions": ["chant", "memorize", "pray"]}
  ]
}
```

### Parameters

Each parameter has `"name"` and `"type"`. Parameters represent player choices.
Randomness (die rolls, draws) happens at resolution time in reduce.

### Display Names

Actions can have `"displayName"` for UI rendering. By default the action's
coded name and parameter display names are composed automatically.

---

## Rules

The `"rules"` object is the heart of the game.

```jsonc
"rules": {
  "terminal": "gameAcknowledged",
  "rolloutTerminal": "ended",
  "pages": [ ... ],
  "priorities": [ ... ],
  "reactions": [ ... ]
}
```

### Terminal and Rollout Terminal

- `"terminal"`: field name or expression. When truthy, `isTerminal` returns
  true. Defaults to `gameAcknowledged`.
- `"rolloutTerminal"`: faster check for MCTS rollouts. Typically `"ended"`.

### Phases

Phases are implicit — determined by the order pages appear and the phase
values used in conditions. The initial phase is the first value of the
Phase enum.

### Pages

#### Standard Page

```jsonc
{
  "page": "Card Phase",
  "rules": [
    {"when": {"==": ["phase", ".card"]},
     "offer": ["drawCard"]}
  ],
  "reduce": {
    "drawCard": {"seq": [
      {"draw": ["dayDeck", "currentCard"]},
      {"setPhase": [".army"]}
    ]}
  }
}
```

A rule fires when its `"when"` condition is true, offering the listed actions.
A reduce clause defines what happens when that action is chosen.

#### Priority Page

```jsonc
{
  "priority": "Victory",
  "rules": [
    {"when": {"and": ["victory", {"not": ["gameAcknowledged"]}]},
     "offer": ["claimVictory"]}
  ],
  "reduce": {
    "claimVictory": {"seq": [
      {"endGame": ["victory"]},
      {"set": ["gameAcknowledged", true]}
    ]}
  }
}
```

Checked before normal pages. Used for victory/defeat and interrupts.

#### ForEach Page

```jsonc
{
  "forEachPage": "Army Advance",
  "when": {"==": ["phase", ".army"]},
  "items": {"list": ["east", "west", "gate"]},
  "transition": "enterEvent",
  "reduce": {
    "advanceArmy": {"advanceSingleArmy": ["$item"]}
  }
}
```

Iterates over a dynamic list. Each item is processed once. After all items,
the transition action fires.

#### Budgeted Page

```jsonc
{
  "budgetedPage": "Actions",
  "when": {"==": ["phase", ".action"]},
  "budget": {"atMost": 3},
  "pass": "endPlayerTurn",
  "rules": [
    {"when": {"condition": "..."}, "offer": ["meleeAttack", "buildUpgrade"]}
  ],
  "reduce": {
    "meleeAttack": { ... },
    "endPlayerTurn": {"setPhase": [".housekeeping"]}
  }
}
```

Allows a limited number of actions per activation. The pass action lets
the player end early.

### Rules Within Pages

```jsonc
{"when": CONDITION, "offer": ["action1", "action2"]}
```

Multiple rules per page are allowed. The page offers the union of all
matching rules' actions.

### Reactions

```jsonc
{
  "reaction": "Check Defeat",
  "when": {"allDefendersGone": []},
  "apply": {"seq": [
    {"set": ["ended", true]},
    {"log": ["All defenders lost"]}
  ]}
}
```

Reactions fire silently after action resolution. They never offer choices.

---

## Reduce Primitives

### Mutations

| Form | Effect |
|------|--------|
| `{"set": ["field", value]}` | Assign any state field |
| `{"increment": ["field", N]}` | Add N, clamp to counter max |
| `{"decrement": ["field", N]}` | Subtract N, clamp to counter min |
| `{"insertInto": ["setField", element]}` | Add to set |
| `{"removeFrom": ["setField", element]}` | Remove from set |
| `{"setEntry": ["dictField", key, value]}` | Set dictionary entry |
| `{"removeEntry": ["dictField", key]}` | Remove dictionary entry |
| `{"draw": ["deckField", "optField"]}` | Draw top card from deck |
| `{"shuffle": ["deckField"]}` | Randomize deck order |
| `{"discard": ["optField", "deckField"]}` | Return card to deck |
| `{"appendTo": ["listField", element]}` | Append to list |
| `{"removeAt": ["listField", index]}` | Remove by index |
| `{"clearList": ["listField"]}` | Empty a list |
| `{"setPhase": [".phaseName"]}` | Explicit phase transition |
| `{"endGame": ["victory"]}` | Set ended + victory |
| `{"endGame": ["defeat"]}` | Set ended + defeat |

### Piece Operations

| Form | Effect |
|------|--------|
| `{"place": ["pieceName", {"site": ["track", idx]}]}` | Place piece on board site |
| `{"move": ["pieceName", {"site": ["track", idx]}]}` | Move piece to new site |
| `{"remove": ["pieceName"]}` | Remove piece from board |

The piece name must be a case of an enum with a `"player"` assignment for
correct rendering. The track name must be a literal string (not a variable);
the index can be a runtime expression.

### Control Flow

| Form | Effect |
|------|--------|
| `{"seq": [expr, ...]}` | Execute in order |
| `{"if": [cond, then, else?]}` | Conditional branch (else is optional) |
| `{"forEach": [collection, {"fn": ["item", body]}]}` | Iteration |
| `{"guard": [condition]}` | Abort rest of seq if false |
| `{"chain": ["actionName"]}` | Dispatch follow-up action through pages |
| `{"let": ["name", value, body]}` | Bind variable for use in body |
| `{"let": ["n1", v1, "n2", v2, body]}` | Multiple bindings |
| `{"log": ["message"]}` | Emit log entry |
| `{"log": [{"format": ["template {}", arg1]}]}` | Formatted log |

---

## Expressions

Pure expressions used in conditions, reduce bodies, and heuristics.

### Arithmetic

```jsonc
{"+": [a, b]}  {"-": [a, b]}  {"*": [a, b]}  {"/": [a, b]}  {"%": [a, b]}
{"min": [a, b]}  {"max": [a, b]}  {"abs": [a]}
```

### Comparison

```jsonc
{"==": [a, b]}  {"!=": [a, b]}  {">": [a, b]}  {"<": [a, b]}
{">=": [a, b]}  {"<=": [a, b]}
```

### Boolean

```jsonc
{"and": [a, b]}  {"or": [a, b]}  {"not": [a]}
```

Short-circuit evaluation for `and`/`or`.

### Collections

```jsonc
{"contains": ["setField", element]}       // set membership test
{"lookup": ["dictField", key]}             // dictionary access
{"count": ["deckOrListField"]}             // length
{"isEmpty": ["collection"]}                // empty check
{"nth": [list, index]}                     // index into list (0-based)
{"list": [elem1, elem2, ...]}             // construct list literal
{"filter": [list, {"fn": ["item", cond]}]} // filter to matching
{"map": [list, {"fn": ["item", expr]}]}    // transform elements
{"get": [struct, "fieldName"]}             // struct field accessor
```

### State Access

```jsonc
"fieldName"                                // bare name reads state field
{"field": ["name"]}                        // explicit field read
"$paramName"                               // read action parameter or binding
```

### Site Operations

```jsonc
{"site": ["trackName", index]}             // construct site value
{"pos": ["pieceName"]}                     // get piece's current site
{"advance": [site, "trackName", N]}        // site N steps along track
{"trackOf": [site]}                        // track name of a site
{"indexOf": [site]}                        // index within track
{"adjacent": [site, "trackName"]}          // parallel site on another track
{"pieceAt": [site]}                        // piece occupying site, or null
```

### Randomness

```jsonc
{"rollDie": [sides]}                       // random integer 1..sides
{"randomElement": [collection]}            // pick random element
```

### String Formatting

```jsonc
{"format": ["template {} attacks {}", arg1, arg2]}
```

### History Queries

```jsonc
{"historyCount": [{"since": "marker"}, {"matching": {"fn": ["a", cond]}}]}
```

---

## Defines

Reusable logic defined in the top-level `"defines"` array. Defines expand
inline at each call site.

### Parameterless Define

```jsonc
{"name": "drawsFromDayDeck",
 "params": [],
 "body": {"<": ["timePosition", 6]}}
```

Called as `{"drawsFromDayDeck": []}`.

### Parameterized Define

```jsonc
{"name": "advanceSingleArmy",
 "params": ["slot"],
 "body": {"setEntry": ["armyPosition", "$slot",
   {"-": [{"lookup": ["armyPosition", "$slot"]}, 1]}]}}
```

Called as `{"advanceSingleArmy": ["east"]}`.

### Composition

Defines can call other defines. The expander enforces an acyclic call graph
at parse time — cyclic definitions throw `cyclicDefine`. To implement loops,
create a one-step helper and call it N times:

```jsonc
{"name": "advanceTimeOneStep", "params": [], "body": { ... }},
{"name": "advanceTime", "params": ["spaces"],
 "body": {"seq": [
   {"if": [{">=": ["$spaces", 1]}, {"advanceTimeOneStep": []}]},
   {"if": [{">=": ["$spaces", 2]}, {"advanceTimeOneStep": []}]},
   {"if": [{">=": ["$spaces", 3]}, {"advanceTimeOneStep": []}]}
 ]}}
```

---

## Metadata

Optional section for AI configuration.

```jsonc
"metadata": {
  "ai": {
    "heuristic": {"+": [
      {"*": [0.5, {"/": ["score", 10.0]}]},
      {"*": [0.25, {"/": [{"alliedCityCount": []}, 4.0]}]}
    ]}
  }
}
```

The heuristic expression is evaluated against state, returning a float for
MCTS state evaluation. Higher = better for the player.

---

## Scene

Optional section for visual styling.

```jsonc
"scene": {
  "stroke": "black",
  "lineWidth": 1,
  "fill": "white"
}
```

---

## Runtime Value Types (DSLValue)

All runtime values are one of:

| Case | Example |
|------|---------|
| `.int(Int)` | `42` |
| `.float(Float)` | `1.5` |
| `.bool(Bool)` | `true`, `false` |
| `.string(String)` | `"Goblin Assault"` |
| `.enumCase(type, value)` | `"east"` resolved as `ArmySlot.east` |
| `.list([DSLValue])` | `{"list": [1, 2, 3]}` |
| `.structValue(type, fields)` | Card instances |
| `.site(track, index)` | `{"site": ["road", 2]}` |
| `.nil` | absent optional, JSON `null` |

Enum cases are resolved by the `ComponentRegistry` — bare names matching a
declared enum case are automatically wrapped. When multiple enums share a
case name, the first-defined enum wins.

---

## Interpretation Pipeline

When a `.game.jsonc` file is loaded:

1. **Parse** — JSONC text → `JSONValue` tree (strip comments, parse JSON).
2. **Build components** — `JSONComponentRegistry` from `"components"`.
3. **Build state schema** — `JSONStateSchema` from `"state"`.
4. **Build actions** — `JSONActionSchema` from `"actions"`.
5. **Expand defines** — `JSONDefineExpander` processes `"defines"`, validates
   acyclic call graph.
6. **Build graph** — `JSONGraphBuilder` from `"graph"`.
7. **Compile expressions** — `JSONExpressionCompiler` with all registries.
8. **Build pages** — `JSONPageBuilder` constructs `RulePage`, `ForEachPage`,
   `BudgetedPhasePage` from `"rules"`.
9. **Build reactions** — Extract `"reactions"` from rules.
10. **Populate decks** — Cards with matching `"deck"` fields are added to
    state decks during `makeInitialState`.
11. **Compose** — Everything assembled into `ComposedGame<InterpretedState>`.
12. **Metadata** — `JSONMetadataBuilder` extracts heuristic if present.

The resulting `ComposedGame` conforms to `PlayableGame` and works with the
MCTS engine, SwiftUI views (`InterpretedGameView`), and CLI gamer tool.

---

## Complete Minimal Example

```jsonc
{
  "game": "Coin Flip",
  "players": 1,
  "components": {
    "enums": [
      {"name": "Phase", "values": ["play", "done"]}
    ]
  },
  "state": {
    "counters": [{"name": "score", "min": 0, "max": 10}],
    "flags": ["ended", "victory", "gameAcknowledged"]
  },
  "actions": {
    "actions": [
      {"name": "flipHeads"},
      {"name": "flipTails"},
      {"name": "acknowledge"}
    ]
  },
  "rules": {
    "terminal": "gameAcknowledged",
    "pages": [
      {
        "page": "Play",
        "rules": [
          {"when": {"==": ["phase", ".play"]},
           "offer": ["flipHeads", "flipTails"]}
        ],
        "reduce": {
          "flipHeads": {"seq": [
            {"increment": ["score", 1]},
            {"if": [{">=": ["score", 3]},
              {"seq": [{"endGame": ["victory"]}, {"setPhase": [".done"]}]},
              {"log": ["Heads! +1"]}
            ]}
          ]},
          "flipTails": {"log": ["Tails, no points"]}
        }
      }
    ],
    "priorities": [
      {
        "priority": "Victory",
        "rules": [
          {"when": {"and": ["victory", {"not": ["gameAcknowledged"]}]},
           "offer": ["acknowledge"]}
        ],
        "reduce": {
          "acknowledge": {"set": ["gameAcknowledged", true]}
        }
      }
    ]
  }
}
```

## Wiring a New Game

After creating the `.game.jsonc` file:

1. Place it in `DynamicalSystems/Resources/`.
2. Add it to `membershipExceptions` in `project.pbxproj` for the
   DynamicalSystems target (INCLUDE semantics).
3. Add a `NavigationLink` in `DynamicalSystemsApp.swift`:
   ```swift
   NavigationLink("Game Name (JSONC)") {
     InterpretedGameView(
       game: InterpretedGameView.loadBundleGame("Game Name")
     )
   }
   ```
4. Add an enum case and switch branch in `GamerTool.swift`:
   ```swift
   case gameNameJSONC = "GameNameJSONC"
   // ...
   case .gameNameJSONC:
     let game = try loadDotGame("Game Name")
     // ... GameRunner setup
   ```
