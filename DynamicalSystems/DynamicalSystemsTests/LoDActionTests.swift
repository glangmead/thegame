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

}
