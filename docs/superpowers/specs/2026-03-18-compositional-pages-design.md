# Compositional Pages Refactoring — Design Spec

**Date:** 2026-03-18
**Status:** Draft

## Problem

Three "god structs" — `EventResolution`, `QuestRewardParams`, `SpellCastParams` — union unrelated fields into flat product types. Each struct accumulates per-card or per-spell fields that are meaningless outside their specific context (e.g., `advanceSky: Bool` on `EventResolution` is only relevant to Bump in the Night). This violates compositionality: game-level types know about individual card internals.

Additionally, `eventPage` is a monolithic `switch card.number` with 18 branches, and `magicPage` dispatches through `applySpellEffect` with a similar switch. Quest reward choices are defined in `QuestRewardParams` but never wired up — the sub-resolution flow doesn't exist.

## Solution

Decompose into per-event, per-spell, and per-quest-reward RulePages. Each page owns its condition, action enumeration, and reduce logic. The three god structs are deleted. Action cases carry exactly the data they need as associated values.

## Design

### 1. Action Enum Transformation

`LoD.Action` grows from ~20 to ~45 cases. Each case is self-documenting and carries typed data.

**Events** (replacing `resolveEvent(EventResolution)` and `skipEvent`):

15 no-choice bare cases (covering 16 event cards; `midnightMagic` handles both card 27 and card 32):
- `catapultShrapnel`, `rocksOfAges`, `actsOfValor`, `distractedDefenders`, `brokenWalls`, `lamentationOfWomen`, `reignOfArrows`, `trappedByFlames`, `bannersInDistance`, `campfires`, `councilOfHeroes`, `paleMoonlight`, `waningMoon`, `midnightMagic`, `mysticForcesReborn`

Note: Death and Despair (card 29) already has its own sub-page and is unchanged.

5 choice events with sub-enums:
- `bumpInTheNight(BumpInTheNightAction)` — `advanceSky`, `advanceOthers([ArmySlot])`
- `deserters(DesertersAction)` — `loseTwoDefenders(DefenderType, DefenderType)`, `loseMorale`
- `bloodyHandprints(BloodyHandprintsAction)` — `chooseHero(HeroType)`
- `assassinsCreedo(AssassinsCreedoAction)` — `chooseHero(HeroType?)`
- `harbingers(HarbingersAction)` — `chooseSlot(ArmySlot?)`

**Spells** (replacing `magic(.castSpell(spell, heroic, params))`):
- `fireball(slot: ArmySlot)`
- `slow(slot: ArmySlot, heroic: Bool)`
- `cureWounds(heroes: [HeroType], heroic: Bool)`
- `massHeal(defenders: [DefenderType], heroic: Bool)`
- `divineWrath(slots: [ArmySlot], heroic: Bool)`
- `raiseDead(defenders: [DefenderType], returnHero: HeroType?, heroic: Bool)`
- `inspire(heroic: Bool)`

Chain Lightning and Fortune keep their existing sub-enum patterns.

**Quest rewards** (newly functional, replacing empty `QuestRewardParams`):
- `scrollsOfTheDead(SpellType)`
- `putForthTheCall(DefenderType)`
- `lastDitchEfforts(HeroType)`
- `pillarsOfTheEarth(ArmySlot)`
- `prophecyRevealed(discardIndex: Int)`

`MagicAction` retains `chant`, `memorize`, `pray` but drops `castSpell`. `QuestAction.quest` becomes `quest(isHeroic: Bool, pointsSpent: Int)` — no `reward` param.

### 2. Event Pages

**`eventPage` is deleted.** No central dispatcher. Each event page's rule checks `phase == .event && currentCard?.number == myNumber` directly.

**15 no-choice events** grouped in `LoDEventPagesSimple.swift`. Each is a `static var` returning `RulePage<State, Action>`. `midnightMagicPage` handles both card 27 and card 32 (condition: `currentCard?.number == 27 || currentCard?.number == 32`). Pattern:

```swift
static var catapultShrapnelPage: RulePage<State, Action> {
  RulePage(
    name: "Catapult Shrapnel",
    rules: [
      GameRule(
        condition: { $0.phase == .event && $0.currentCard?.number == 1 },
        actions: { _ in [.catapultShrapnel] }
      )
    ],
    reduce: { state, action in
      guard case .catapultShrapnel = action else { return nil }
      let dieRoll = LoD.rollDie()
      state.eventCatapultShrapnel(dieRoll: dieRoll)
      state.phase = .action
      return ([Log(msg: "Catapult Shrapnel: rolled \(dieRoll)")], [])
    }
  )
}
```

A `noEventPage` handles cards with no event: condition `phase == .event && currentCard?.event == nil`, action `skipEvent`, reduce sets `phase = .action`.

**Mutual exclusion:** `noEventPage` and per-event pages cannot both activate. `noEventPage` requires `event == nil`; per-event pages target specific card numbers that always have events. No overlap is possible.

**5 choice events** each get their own file, following the Death and Despair pattern: sub-enum, rule with action enumeration, reduce with pattern matching. The enumeration logic currently in `bumpInTheNightResolutions()` etc. moves into the page's `actions` closure.

Event pages set `state.phase = .action` in their reduce. `nextPhase(for:)` no longer needs to know about event actions.

**Acts of Valor bug fix:** Currently `eventActsOfValor(woundHeroes:)` takes a `Bool` parameter, but `concreteEventResolutions` always passes `false`, so the event never actually wounds heroes. This is a pre-existing bug. The new `actsOfValorPage` will call `eventActsOfValor(woundHeroes: true)` — the correct game behavior per rule text ("Wound all unwounded heroes. If ≥1 wounded, +1 attack DRM this turn."). This is an intentional behavior change.

### 3. Spell Pages

**`magicPage` shrinks** to chant, memorize, pray only.

Each spell gets its own page and file. The page owns:
- Condition: can I cast this spell? (phase, energy, known status, sub-resolution check)
- Action enumeration: valid targets/params for MCTS (one action per valid targeting combination)
- Reduce: deduct energy, apply effect, log

The underlying state mutation helpers (`applyFireball`, `applySlow`, etc.) stay where they are.

**`concreteSpellActions()` deleted.** Enumeration logic moves into each page's `actions` closure.
**`applySpellEffect()` deleted.** Effect logic moves into each page's reduce.
**`SpellCastParams` deleted.**

### 4. Quest Reward Pages

Quest resolution splits into two steps for choice quests:

1. Player picks `quest(isHeroic:pointsSpent:)`. `questPage` rolls the die.
2. On success:
   - No-choice quests (Forlorn Hope, Manastones, Magic Bow, Vorpal Blade, Mirror of Moon): reward applied immediately in `questPage`'s reduce.
   - Choice quests: `questRewardPending` set to `true`. The per-quest reward page's rule activates.

5 quest reward sub-pages, each in its own file. Pattern:

```swift
static var scrollsOfTheDeadPage: RulePage<State, Action> {
  RulePage(
    name: "Scrolls of the Dead",
    rules: [
      GameRule(
        condition: { $0.questRewardPending && $0.currentCard?.number == 2 },
        actions: { state in
          state.faceDownArcaneSpells.map { .scrollsOfTheDead($0) }
            + state.faceDownDivineSpells.map { .scrollsOfTheDead($0) }
        }
      )
    ],
    reduce: { state, action in
      guard case .scrollsOfTheDead(let spell) = action else { return nil }
      state.questScrollsOfDead(chosenSpell: spell)
      state.questRewardPending = false
      return ([Log(msg: "Quest reward: Scrolls of the Dead — learned \(spell)")], [])
    }
  )
}
```

**New state field:** `questRewardPending: Bool` on `LoD.State`, reset in `resetTurnTracking()`.

**`isInSubResolution` updated:** Add `|| questRewardPending` to the computed property. While a quest reward choice is pending, normal action-phase pages (combat, build, magic, heroic, general, quest) must not enumerate actions.

**Paladin re-roll interaction:** `resolveQuestAction` is called inside `paladinReactPage`'s reduce, which injects a fixed die value. If the quest succeeds and requires a choice, `questRewardPending` is set to `true`. After `paladinReactPage` restores the phase to `.action`, the quest reward page's condition (`questRewardPending && currentCard?.number == N`) activates correctly — no special handling needed.

**`QuestRewardParams` deleted.** **`applyQuestReward(params:)` deleted.**

### 5. Phase Transition & oapply

**`snapshotActionBudget` centralized.** All direct assignments in `armyPage` and `eventPage` are removed. A single auto-rule is the sole source:

```swift
GameAutoRule(
  when: { $0.phase == .action && $0.snapshotActionBudget == nil },
  apply: { state in
    state.snapshotActionBudget = state.actionBudget
    return []
  }
)
```

Event pages set `state.phase = .action` in their reduce. The auto-rule fires once per turn after that transition. (A follow-up refactoring will collapse `snapshotActionBudget` into a single `actionBudget` set by the card.)

**`nextPhase(for:)` simplified.** `resolveEvent` and `skipEvent` cases removed (event pages and `noEventPage` set `state.phase = .action` directly in their reduce).

**History sentinel update.** Four computed properties (`actionPointsSpent`, `heroicPointsSpent`, `meleeAttacksThisTurn`, `rangedAttacksThisTurn`) scan `history` backwards and stop at `.advanceArmies`, `.skipEvent`, or `.resolveEvent`. After this refactoring, `.resolveEvent` is deleted and `.skipEvent` may be retained or replaced. The scan must recognize the new per-event action cases as sentinels, or rely on `.advanceArmies` alone. Since `.advanceArmies` always precedes the event phase which always precedes the action phase, `.advanceArmies` is a sufficient sentinel. Update the four computed properties to stop at `.advanceArmies` only (plus `.skipEvent` if retained). The per-event action cases will fall between `.advanceArmies` and the action-phase actions, so the scan will still stop at the correct boundary.

**`actionGroup` for new flat cases.** The new spell actions (`.fireball`, `.slow`, etc.) are flat on `LoD.Action`, not nested under `.magic(...)`. The `GroupedAction` reflection-based `actionGroup` will return `"General"` for these. The `actionGroup` computed property needs explicit cases mapping spell actions → `"Magic"`, event actions → `"Event"` (or similar), and quest reward actions → `"Quest"`. Same for `description` — all new cases need `CustomStringConvertible` entries.

**`oapply` pages list expands** to ~47 pages + 2 priorities:

```swift
pages: [
  cardPage, armyPage, noEventPage,
  // 15 simple event pages
  catapultShrapnelPage, rocksOfAgesPage, actsOfValorPage,
  distractedDefendersPage, brokenWallsPage, lamentationPage,
  reignOfArrowsPage, trappedByFlamesPage, bannersInDistancePage,
  campfiresPage, councilOfHeroesPage, paleMoonlightPage,
  waningMoonPage, midnightMagicPage, mysticForcesRebornPage,
  // 5 choice event pages
  bumpInTheNightPage, desertersPage, bloodyHandprintsPage,
  assassinsCreedoPage, harbingersPage,
  // Existing sub-resolution pages
  chainLightningPage, fortunePage, deathAndDespairPage,
  // Spell pages
  fireballPage, slowPage, cureWoundsPage, massHealPage,
  divineWrathPage, raiseDeadPage, inspirePage,
  // Remaining player-turn pages
  magicPage, questPage,
  // Quest reward pages
  scrollsOfTheDeadPage, putForthTheCallPage, lastDitchEffortsPage,
  pillarsOfTheEarthPage, prophecyRevealedPage,
  // Original pages
  combatPage, buildPage, heroicPage, generalPage, acidPage,
  paladinReactPage, housekeepingPage
]
```

### 6. Deletions Summary

**Deleted types:** `EventResolution`, `QuestRewardParams`, `SpellCastParams`

**Deleted functions:**
- `concreteEventResolutions(for:)` and all `*Resolutions()` helpers
- `concreteSpellActions(spell:heroic:)`
- `applySpellEffect(spell:heroic:params:)`
- `applyQuestReward(params:)`

**Deleted action cases:** `resolveEvent(EventResolution)`, `MagicAction.castSpell(SpellType, heroic: Bool, SpellCastParams)`

Note: `skipEvent` is retained — `noEventPage` still emits it. It is removed from `nextPhase(for:)` since `noEventPage` sets `state.phase = .action` directly in its reduce.

### 7. New Files

- `LoDEventPagesSimple.swift` — 15 no-choice event pages + `noEventPage`
- `LoDBumpInTheNightPage.swift`
- `LoDDesertersPage.swift`
- `LoDBloodyHandprintsPage.swift`
- `LoDAssassinsCreedoPage.swift`
- `LoDHarbingersPage.swift`
- `LoDFireballPage.swift`
- `LoDSlowPage.swift`
- `LoDCureWoundsPage.swift`
- `LoDMassHealPage.swift`
- `LoDDivineWrathPage.swift`
- `LoDRaiseDeadPage.swift`
- `LoDInspirePage.swift`
- `LoDScrollsOfTheDeadPage.swift`
- `LoDPutForthTheCallPage.swift`
- `LoDLastDitchEffortsPage.swift`
- `LoDPillarsOfTheEarthPage.swift`
- `LoDProphecyRevealedPage.swift`

### 8. Modified Files

- `LoDAction.swift` — ~30 new action cases, 3 struct deletions, `description` expanded
- `LoDActionGroups.swift` — `MagicAction` loses `castSpell`; `QuestAction.quest` loses `reward` param; `actionGroup` updated for new flat cases
- `LoDGamePages.swift` — `eventPage` deleted, `armyPage` loses direct `snapshotActionBudget` assignments
- `LoDGame.swift` — `nextPhase` simplified, `oapply` pages list expanded, snapshot auto-rule added
- `LoDGamePagesMagic.swift` — shrinks to chant/memorize/pray only
- `LoDGamePagesQuest.swift` — quest action loses reward param, reduce triggers `questRewardPending` on success for choice quests
- `LoDState.swift` — `questRewardPending` field added, `isInSubResolution` updated, history sentinel properties updated to use `.advanceArmies` only, `actionPointsSpent` updated to count new flat spell action cases (`.fireball`, `.slow`, `.cureWounds`, `.massHeal`, `.divineWrath`, `.raiseDead`, `.inspire`) in addition to `.magic` (chant/memorize/pray)
- `LoDStateComposed.swift` — `applySpellEffect` and `applyQuestReward` deleted, `resetTurnTracking` clears `questRewardPending`
- `LoDStateEvents.swift` — resolution enumeration functions deleted, mutation functions stay, `eventActsOfValor` parameter removed (always wounds)
- `LoDStateActions.swift` — `concreteSpellActions` deleted
- `LoDStateResolve.swift` — `resolveQuestAction` updated (no more params, sets `questRewardPending` on success for choice quests)

### 9. Tests

Existing unit tests call state mutation functions directly — unchanged. Integration tests using `resolveEvent(EventResolution)`, `QuestRewardParams`, or `SpellCastParams` need updating to new action cases. New integration tests needed for quest reward sub-page flows.

**Affected test files:**
- `LoDComposedGameTests.swift`
- `LoDAuditFixTests2.swift`
- `LoDDeathAndDespairPageTests.swift`
- `LoDComposedGameSpellTests.swift`
- `LoDDieRollTests.swift`
- `LoDComposedGameActionTests.swift`
- `LoDSubResolutionIntegrationTests.swift`
- `LoDConcreteActionTests.swift`
