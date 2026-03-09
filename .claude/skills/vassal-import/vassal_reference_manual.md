# Vassal Engine Module Reference

Self-contained notes for parsing and understanding Vassal modules (.vmod files).
Cross-referenced with the Legions of Darkness module as a concrete example.

## 1. File Format

A `.vmod` file is a **ZIP archive**. Rename to `.zip` to extract. Contains:

- **`buildFile`** (or `buildFile.xml`) — Core XML defining the entire module structure
- **`moduledata`** — Small XML with module name, version, VASSAL version, description
- **`images/`** — All image assets (PNG, JPG, GIF, SVG)
- Optional: HTML files (for chart windows), save files (pre-defined setups)

Extensions use `.vmdx` (also ZIP). They append to but cannot modify the base module.

**LoD example:** 132 images, one `buildFile` (247 lines), one `moduledata`.

## 2. buildFile XML Structure

### Root Element

XML tags are **fully-qualified Java class names**:
```xml
<VASSAL.build.GameModule name="Game Name" version="1.0"
    VassalVersion="3.6.7" nextPieceSlotId="163">
```
Older modules (like LoD) use `<VASSAL.launch.BasicModule>` instead.

### Key Top-Level Children

| XML Element | Purpose |
|---|---|
| `module.BasicCommandEncoder` | Piece serialization (always present, empty) |
| `module.Documentation` | Help files, about screen |
| `module.PlayerRoster` | Player sides (`<entry>Side Name</entry>`) |
| `module.GlobalOptions` | Settings: autoReport, centerOnMove, HTML chat, etc. |
| `module.Map` | Main play area (can have multiple) |
| `module.PlayerHand` | Player hand (specialized Map) |
| `module.PrivateMap` | Side-restricted map |
| `module.PrototypesContainer` | Reusable trait definitions |
| `module.PieceWindow` | Game Piece Palette (piece tray for dragging) |
| `module.ChartWindow` | Reference charts/images |
| `module.DiceButton` | Numeric dice roller |
| `module.SpecialDiceButton` | Symbolic/image dice |
| `module.Chatter` | Chat log |
| `module.properties.GlobalProperties` | Module-level properties |
| `module.turn.TurnTracker` | Turn counter with nested levels |
| `module.Inventory` | Piece inventory window |
| `module.StartupGlobalKeyCommand` | Runs on game start |
| `module.DoActionButton` | Toolbar action button |

**LoD example:** Has Map, 4 prototypes, PieceWindow with 6 tabs, 2 ChartWindows
(Scenario + Player Aid), 2 SpecialDiceButtons (1d6, 2d6).

## 3. Maps, Boards, Zones, and Grids

### Map
```xml
<VASSAL.build.module.Map mapName="Main Map"
    backgroundcolor="255,255,255" markMoved="Always"
    moveWithinFormat="$pieceName$ moves $previousLocation$ -> $location$ *">
```
Contains: BoardPicker, StackMetrics, Zoomer, CounterDetailViewer, SetupStacks,
DrawPiles, GlobalProperties, SelectionHighlighters, etc.

### Board
```xml
<module.map.BoardPicker>
  <module.map.boardPicker.Board image="Main Map.jpg" name="Main Map"
      reversible="false" width="834" height="1145">
    <!-- Grid goes here -->
  </module.map.boardPicker.Board>
</module.map.BoardPicker>
```

### Grid Types

**Hex Grid:**
```xml
<board.HexGrid dx="88.66" dy="102.32" x0="89" y0="224"
    sideways="false" snapTo="true" visible="false">
  <board.mapgrid.HexGridNumbering first="H" hType="A" vType="N"
      hOff="0" vOff="-2" sep="" stagger="false"/>
</board.HexGrid>
```
- `dx`/`dy` = center-to-center distances
- `x0`/`y0` = first hex center pixel offset
- `sideways` = flat-topped (true) vs pointy-topped (false)
- Numbering: `first` = "H" (horizontal) or "V" (vertical), types = "A" (alpha) or "N" (numeric)

**Square Grid:**
```xml
<board.SquareGrid dx="300.0" dy="500.0" x0="150" y0="251"
    snapTo="true" range="Metric"/>
```

**Region Grid (Irregular — named points):**
```xml
<board.RegionGrid snapto="true" fontsize="9" visible="false">
  <board.Region name="Winchester" originx="758" originy="1052"/>
  <board.Region name="Manassas" originx="400" originy="300"/>
</board.RegionGrid>
```
Each Region is a named snap-to point at specific pixel coordinates. This is the most
common grid type for point-to-point wargames and States of Siege games.

### Zoned Grid
Divides a board into zones, each with its own grid or properties:
```xml
<board.ZonedGrid>
  <board.mapgrid.Zone name="Reserve"
      path="2495,1783;2773,1790;2755,1505;2469,1502"
      locationFormat="$name$" useParentGrid="false"/>
</board.ZonedGrid>
```
- `path` = polygon vertices as `x,y;x,y;...`
- `locationFormat` = `$name$` (zone name) or `$gridLocation$` (grid ref within zone)

**LoD example:** Single zone "Reserve" defined by a rectangle polygon. No grid —
pieces snap to named regions or are free-placed.

### Map Sub-Components of Interest

| Component | Purpose |
|---|---|
| `map.SetupStack` | Pieces placed on map at game start |
| `map.DrawPile` | Deck of cards |
| `map.Zoomer` | Zoom levels (comma-separated, e.g., "0.3,0.5,1.0") |
| `map.CounterDetailViewer` | Mouseover popup (delay, zoom, format) |
| `map.LayeredPieceCollection` | Drawing order by property value |
| `map.StackMetrics` | Stack visual offsets |
| `map.MassKeyCommand` | Global Key Command on all map pieces |
| `map.HighlightLastMoved` | Visual highlight on last-moved piece |

## 4. Game Pieces

### Piece Definition

Pieces live inside `PieceSlot` elements:
```xml
<widget.PieceSlot entryName="Goblin" gpid="42" height="77" width="77">
  [SERIALIZED TRAIT STRING]
</widget.PieceSlot>
```
`gpid` = Global Piece ID, unique integer per piece definition slot.

### Trait Serialization Format

The text content of a PieceSlot is a **tab-delimited string** of traits:
```
+/null/prototype;Card Day\tpiece;;;Day12.jpg;Day12/\tnull;0;0;42
```

- **TAB** (`\t`) separates traits
- **Semicolons** (`;`) separate fields within a trait
- **Backslashes** escape nested content
- Traits listed in order; `piece` (BasicPiece) is always last
- Format: `traitId;field1;field2;...`

### Common Trait IDs

| ID | Trait | Key Fields |
|---|---|---|
| `piece` | Basic Piece | `;;;image.png;PieceName` |
| `prototype` | Use Prototype | `prototype;PrototypeName` |
| `mark` | Marker (read-only property) | `mark;PropertyName` + value in state |
| `PROP` | Dynamic Property (mutable) | name, initial value, constraints |
| `calcProp` | Calculated Property | BeanShell expression |
| `emb2` | Layer/Embellishment | Multiple images, activation keys |
| `obs` | Mask (face-down) | back image, display style |
| `report` | Report Action | message format |
| `macro` | Trigger Action | fires other key commands |
| `setprop` | Set Global Property | target property, operation |
| `globalhotkey` | Global Hotkey | sends hotkey to other pieces |
| `sendto` | Send to Location | destination map/zone/coords |
| `return` | Return to Deck | target deck name |
| `delete` | Delete | removes piece from game |
| `replace` | Replace With Other | swaps for different piece |
| `placemark` | Place Marker | creates new piece |
| `rotate` | Can Rotate | rotation angles |
| `hideCmd` | Restrict Commands | conditional menu hiding |
| `deselect` | Deselect | removes from selection |
| `submenu` | Sub-Menu | groups menu items |

### BasicPiece (always last)
```
piece;;;imagename.png;Piece Name
```
Fields: (cloneKey);(deleteKey);(moveKey);image;name

### Prototype Definition
```xml
<module.PrototypeDefinition name="Card Day" description="">
  [SERIALIZED TRAIT STRING — same format as PieceSlot]
</module.PrototypeDefinition>
```
When a piece uses `prototype;Card Day`, the prototype's traits are inserted at that
position in the trait list.

**LoD example — 4 prototypes:**
- "Card Day" — Return to Deck (DrawDay → "Day/Night Discard") + Mask (Day Back.jpg)
- "Card Night" — Return to Deck (DrawNight → discard) + Mask (Night back.jpg)
- "Spell Arcane" — Mask (Arcane Back.png)
- "Spell Devine" — Mask (Devine Back.png) [sic — typo in module]

### Trait Ordering Rules
- **Drawing**: BasicPiece drawn first (bottom), then traits overlay upward
- **Key Commands**: Processed bottom-to-top for most traits; top-to-bottom for Trigger/Report
- **Control**: Mask, Restrict Commands, Can Rotate only affect traits above them

### Properties Exposed by BasicPiece
Position: `CurrentX`, `CurrentY`, `CurrentMap`, `CurrentBoard`, `CurrentZone`, `LocationName`
Identity: `BasicName`, `PieceName`, `PieceId`, `PieceUID`
Stack: `StackPos`, `StackSize`, `DeckName`, `DeckPosition`
State: `Selected`, `Moved`, `Invisible`, `Obscured`
Previous: `OldX`, `OldY`, `OldMap`, `OldBoard`, `OldZone`, `OldLocationName`

## 5. Decks and Cards

### Deck (DrawPile)
```xml
<module.map.DrawPile name="Day Deck" x="2700" y="227"
    width="300" height="445"
    faceDown="Always" shuffle="Always" maxStack="1"
    draw="true" allowSelect="false" allowMultiple="false"
    reshufflable="false" reshuffleTarget="">
  <!-- PieceSlot children = cards in the deck -->
</module.map.DrawPile>
```

Key attributes:
- `faceDown`: "Always" / "Never" / "Use Preferences Setting"
- `shuffle`: "Always" (at game start) / "Never" / "Via right-click Menu"
- `draw`: whether dragging draws a card
- `reshufflable`: if true, cards can be sent to `reshuffleTarget` deck
- `maxStack`: visual display limit
- `allowSelect`: pick specific cards from deck

### Deck Properties
- `<deckname>_numPieces` — number of cards remaining

### Deck Global Key Commands
```xml
<module.map.DeckGlobalKeyCommand
    name="Draw Night Card" hotkey="DrawNight" deckCount="1"/>
```
Sends a key command to N cards in the deck.

**LoD example:** 6 decks:
- Day Deck (25 cards, Day1–Day25 + Day26–28 in palette), shuffle Always
- Night Deck (20 cards, Night1–Night20), shuffle Always
- Day/Night Discard (receives from both decks via DeckGKC)
- Arcane Spell Deck (7 spells), shuffle Always
- Divine Spell Deck (8 spells), shuffle Always
- Random Hero Deck (6 heroes, off-screen at -100,-100, sends heroes to Reserve zone)

## 6. At-Start Stacks (Setup Pieces)

```xml
<module.map.SetupStack name="Time - Day/Night"
    owningBoard="Main Map" useGridLocation="false"
    x="186" y="188">
  <widget.PieceSlot entryName="Day/Night" gpid="99">
    piece;;;Day:Night.png;Day/Night
  </widget.PieceSlot>
</module.map.SetupStack>
```

Pieces placed on the map when a new game starts. Can use grid location or raw
pixel coordinates.

**LoD example — 7 setup stacks:**
1. Defenders - Ranged Attacks marker at (1996, 820)
2. Defenders - Melee Attacks marker at (2095, 522)
3. Defenders - Chant DRM marker at (1910, 1121)
4. Time - Day/Night marker at (186, 188)
5. Morale marker at (543, 443) — flippable: +1 / -1
6. Arcane energy marker at (432, 1921)
7. Divine energy marker at (435, 1918)

## 7. Piece Palette (PieceWindow)

Provides draggable pieces organized in tabs/panels:
```xml
<module.PieceWindow name="Token" buttonName="Reserve">
  <widget.TabWidget entryName="Reseve">
    <widget.PanelWidget entryName="Reserve" nColumns="3">
      <widget.PieceSlot entryName="Acid" gpid="81">
        piece;;;Acid.png;Acid
      </widget.PieceSlot>
    </widget.PanelWidget>
  </widget.TabWidget>
</module.PieceWindow>
```

Container hierarchy: PieceWindow → TabWidget → PanelWidget/ListWidget → PieceSlot

**LoD example — 6 panels:**
1. Reserve: Acid, Grease, Lava, Oil (upgrades), Bloody Battle, Breach markers
2. Hero: Cleric, Paladin, Ranger, Rogue, Warrior, Wizard (front/back flippable)
3. Darkness: Wraith, Skeletal, Orc, Troll, Dragon, Nightmare, Zombie, Goblin
4. Guardian: Prince, Archmage, King + Day26-28 special cards
5. Spell: Fireling, Golem (summoned creatures)
6. Boss: Orc Boss, Undead Boss (front = normal, back = enraged)

## 8. Dice

### Numeric Dice (DiceButton)
```xml
<module.DiceButton name="1d6" nDice="1" nSides="6"
    addToEach="0" addToTotal="0"
    reportFormat="** $playerName$ rolls $result$ **"
    reportTotal="true"/>
```
Properties: `<name>_result`, `<name>_total`

### Symbolic Dice (SpecialDiceButton)
```xml
<module.SpecialDiceButton name="1d6"
    resultFormat="[$result1$]" resultButton="true">
  <module.SpecialDie name="">
    <module.SpecialDieFace icon="D6_Black1.png" text="1" value="0"/>
    <!-- ... 6 faces ... -->
  </module.SpecialDie>
</module.SpecialDiceButton>
```
Each die has named faces with icon, text, and numeric value.

**LoD example:** Two SpecialDiceButtons (1d6 and 2d6), using D6_Black1-6.png faces.

## 9. Properties and Expressions

### Property Hierarchy (search order)
1. Piece properties (traits on the piece)
2. Zone properties
3. Map properties
4. Module-level properties

### Global Properties
```xml
<module.properties.GlobalProperty name="VP" initialValue="15"
    isNumeric="true" min="0" max="30" wrap="false"/>
```
Can exist at module, map, or zone level.

### Expression Types

**BeanShell** (in `{}`): Full arithmetic, comparison, logical, ternary, string methods.
```
{GetProperty("VP") > 10 ? "winning" : "losing"}
```

**Simple/Old-Style**: `$PropertyName$` substitution only. No nesting.

**Property Match** (for GKC filtering): `CurrentMap == Main Map && Strength > 3`

### Useful Functions
- `GetProperty(name)`, `GetMapProperty(name, map)`, `GetZoneProperty(name, zone, map)`
- `SumStack(prop)`, `CountStack(expr)`, `SumLocation(prop)`, `SumZone(prop, zone, map)`
- `Random(max)`, `Random(min, max)`, `IsRandom()`, `IsRandom(percent)`
- `Range(x1,y1,x2,y2)` in grid units, `RangePx(...)` in pixels

## 10. Turn Tracker

```xml
<module.turn.TurnTracker name="Turn"
    turnFormat="$level1$ $level2$"
    reportFormat="Turn updated from $oldTurn$ to $newTurn$">
  <module.turn.CounterTurnLevel property="Turn"
      start="1" incr="1" loop="false" loopLimit="-1"
      turnFormat="$value$">
    <module.turn.ListTurnLevel property="Phase"
        list="Army,Event,Action,Housekeeping"
        turnFormat="$value$"/>
  </module.turn.CounterTurnLevel>
</module.turn.TurnTracker>
```

Levels nest: advancing increments the deepest level; when it wraps, the parent increments.

- **CounterTurnLevel**: Numeric (start, increment, optional loop)
- **ListTurnLevel**: Cycles through comma-separated list
- **TurnGlobalHotkey**: Fires a key command when match expression is true on advance

## 11. Key Commands and Hotkeys

### Encoding in XML
- Keyboard shortcuts: `keycode,modifiers` (e.g., `84,520` = Ctrl+Shift+T)
- Named commands: `57348,0,commandName` (57348 is a special marker)

### Two Types
- **Hotkeys**: Sent to all Components (toolbar buttons, etc.)
- **Key Commands**: Sent to specific pieces and all their traits

### Global Key Commands (5 varieties)
1. **Piece-level** (`globalhotkey` trait): piece → other pieces
2. **Module-level** (`module.MassKeyCommand`): toolbar → any piece
3. **Map-level** (`module.map.MassKeyCommand`): map toolbar → map pieces
4. **Deck-level** (DeckGlobalKeyCommand): deck → cards in deck
5. **Startup** (`module.StartupGlobalKeyCommand`): runs on game start/load

## 12. Chart Windows

```xml
<module.ChartWindow name="Player Aid" buttonText="Player Aid">
  <widget.TabWidget entryName="Player Aid">
    <widget.HtmlChart chartName="Player Aid"
        fileName="Player Aid.jpg"/>
  </widget.TabWidget>
</module.ChartWindow>
```

Display reference images/HTML. Can have tabs.

**LoD example:** Two chart windows — "Scenario" (3 scenario setup images) and
"Player Aid" (one reference image).

## 13. What Vassal Modules Give Us (vs. Rules PDF)

### From the Module (machine-readable)
- **Complete piece inventory** with images and properties
- **Deck compositions** — exactly which cards are in each deck
- **Map layout** — board image, zones, grid coordinates
- **Setup positions** — where pieces start (pixel coords or grid refs)
- **Dice configuration** — number, sides, faces
- **Turn structure** — if a TurnTracker is defined
- **Property definitions** — game state variables

### Only from the Rules PDF
- **Game logic** — how combat works, what actions cost, DRMs
- **Win/loss conditions** — when the game ends
- **Card effects** — what each card does when drawn
- **Phase sequence** — what happens in what order
- **Special rules** — exceptions, edge cases, scenario-specific rules

### The Sweet Spot
The module provides the **nouns** (pieces, maps, decks, positions) while the
rules provide the **verbs** (move, attack, draw, resolve). Together they give us
everything needed to implement a game:
- Module → `GameComponents` (enum definitions, initial positions, deck contents)
- Rules → `RulePages` (game logic, phase transitions, combat resolution)
- Module images → SVG map verification (cross-check positions against the board)
