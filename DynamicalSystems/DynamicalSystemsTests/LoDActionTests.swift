//
//  LoDActionTests.swift
//  DynamicalSystems
//
//  Tests for LoD player actions: Memorize, Pray, Chant, Build, Cast Spell, Heroic Cast, Move Hero, Rally.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDActionTests {

  // MARK: - Memorize (rule 6.6)

  @Test
  func memorizeRevealsArcaneSpell() {
    // Memorize reveals a face-down arcane spell → known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.fireball] == .faceDown)

    let success = state.memorize(spell: .fireball)
    #expect(success)
    #expect(state.spellStatus[.fireball] == .known)
  }

  @Test
  func memorizeFailsOnDivineSpell() {
    // Cannot memorize a divine spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.memorize(spell: .cureWounds)
    #expect(!success)
    #expect(state.spellStatus[.cureWounds] == .faceDown)
  }

  @Test
  func memorizeFailsOnAlreadyKnown() {
    // Cannot memorize a spell that's already known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known

    let success = state.memorize(spell: .fireball)
    #expect(!success)
  }

  @Test
  func memorizeFailsOnCastSpell() {
    // Cannot memorize a spell that's been cast (discarded).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast

    let success = state.memorize(spell: .fireball)
    #expect(!success)
  }

  @Test
  func faceDownArcaneSpellsQuery() {
    // All 4 arcane spells start face-down.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.faceDownArcaneSpells.count == 4)

    state.spellStatus[.fireball] = .known
    #expect(state.faceDownArcaneSpells.count == 3)
    #expect(!state.faceDownArcaneSpells.contains(.fireball))
  }

  // MARK: - Pray (rule 6.7)

  @Test
  func prayRevealsDivineSpell() {
    // Pray reveals a face-down divine spell → known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.cureWounds] == .faceDown)

    let success = state.pray(spell: .cureWounds)
    #expect(success)
    #expect(state.spellStatus[.cureWounds] == .known)
  }

  @Test
  func prayFailsOnArcaneSpell() {
    // Cannot pray for an arcane spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.pray(spell: .fireball)
    #expect(!success)
  }

  @Test
  func faceDownDivineSpellsQuery() {
    // All 5 divine spells start face-down.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.faceDownDivineSpells.count == 5)

    state.spellStatus[.cureWounds] = .known
    #expect(state.faceDownDivineSpells.count == 4)
  }

  // MARK: - Chant (rule 6.5)

  @Test
  func chantSuccess() {
    // Roll 4 > 3 → +1 divine energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // divine = 5
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 4)
    #expect(success)
    #expect(state.divineEnergy == divineBefore + 1)
  }

  @Test
  func chantFailure() {
    // Roll 3 ≤ 3 → fails, no energy gained.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 3)
    #expect(!success)
    #expect(state.divineEnergy == divineBefore)
  }

  @Test
  func chantNaturalOneFails() {
    // Natural 1 always fails even with DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 1, drm: 10)
    #expect(!success)
    #expect(state.divineEnergy == divineBefore)
  }

  @Test
  func chantWithPriestDRM() {
    // Roll 3 + DRM 1 = 4 > 3 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 3, drm: 1)
    #expect(success)
    #expect(state.divineEnergy == divineBefore + 1)
  }

  @Test
  func chantDivineEnergyCapped() {
    // Divine energy capped at 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.divineEnergy = 6

    let success = state.chant(dieRoll: 5)
    #expect(success)
    #expect(state.divineEnergy == 6)
  }

  // MARK: - Build (rule 6.3)

  @Test
  func buildSuccess() {
    // Roll 4 > 3 (Grease build number) → place upgrade.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 4)
    #expect(result == .success(.grease, .east))
    #expect(state.upgrades[.east] == .grease)
  }

  @Test
  func buildRollTooLow() {
    // Roll 3 ≤ 3 → fails.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 3)
    #expect(result == .rollFailed)
    #expect(state.upgrades[.east] == nil)
  }

  @Test
  func buildNaturalOneFails() {
    // Natural 1 always fails even with DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 1, drm: 10)
    #expect(result == .rollFailed)
  }

  @Test
  func buildWithDRM() {
    // Rogue +1 build DRM. Roll 3 + DRM 1 = 4 > 3 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .oil, on: .west, dieRoll: 3, drm: 1)
    #expect(result == .success(.oil, .west))
  }

  @Test
  func buildFailsOnBreachedTrack() {
    // Cannot build on a breached track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 6)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildFailsOnOccupiedCircle() {
    // Cannot build if track already has an upgrade.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease

    let result = state.build(upgrade: .oil, on: .east, dieRoll: 6)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildFailsOnNonWallTrack() {
    // Cannot build on Terror or Sky.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .terror, dieRoll: 6)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildAcidRequiresHighRoll() {
    // Acid build number is 5. Roll 5 ≤ 5 → fails. Roll 6 > 5 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let fail = state.build(upgrade: .acid, on: .east, dieRoll: 5)
    #expect(fail == .rollFailed)

    let success = state.build(upgrade: .acid, on: .east, dieRoll: 6)
    #expect(success == .success(.acid, .east))
  }

  // MARK: - Morale Budget Snapshot (rule 6.1.1)

  @Test
  func inspireMidTurnDoesNotIncreaseActionBudget() {
    // Rule 6.1.1: morale changes during a turn don't affect action points until next turn
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.phase = .action
    state.morale = .normal // actionModifier = 0
    // Use a card that gives 4 actions
    guard let card = LoD.dayCards.first(where: { $0.actions == 4 }) else {
      Issue.record("No card with 4 actions found")
      return
    }
    state.currentCard = card
    // Snapshot the budget at turn start
    state.snapshotActionBudget = state.actionBudget
    #expect(state.actionBudgetRemaining == 4)

    // Raise morale to High (actionModifier = +1) via Inspire
    state.morale = .high
    // Budget should still be 4, not 5
    #expect(state.actionBudgetRemaining == 4,
      "Mid-turn morale change should not affect action budget")
  }

  @Test
  func rallyMidTurnDoesNotReduceActionBudget() {
    // Rule 6.1.1: morale drop mid-turn shouldn't reduce budget either
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.phase = .action
    state.morale = .high // actionModifier = +1
    guard let card = LoD.dayCards.first(where: { $0.actions == 3 }) else {
      Issue.record("No card with 3 actions found")
      return
    }
    state.currentCard = card
    // Snapshot: 3 + 1(high) = 4
    state.snapshotActionBudget = state.actionBudget
    #expect(state.actionBudgetRemaining == 4)

    // Morale drops to Normal mid-turn
    state.morale = .normal
    // Budget should still be 4
    #expect(state.actionBudgetRemaining == 4)
  }

  @Test
  func snapshotClearedInHousekeeping() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.snapshotActionBudget = 5
    state.resetTurnTracking()
    #expect(state.snapshotActionBudget == nil)
  }

}
