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

  // MARK: - Cast Spell (rule 6.4)

  @Test
  func castKnownArcaneSpell() {
    // Cast Fireball (cost 1 arcane). Arcane energy reduced, spell marked cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane = 5
    state.spellStatus[.fireball] = .known

    let result = state.castSpell(.fireball)
    #expect(result == .success(.fireball, heroic: false))
    #expect(state.spellStatus[.fireball] == .cast)
    #expect(state.arcaneEnergy == 4) // 5 - 1
  }

  @Test
  func castKnownDivineSpell() {
    // Cast Cure Wounds (cost 1 divine). Divine energy reduced.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // divine = 5
    state.spellStatus[.cureWounds] = .known

    let result = state.castSpell(.cureWounds)
    #expect(result == .success(.cureWounds, heroic: false))
    #expect(state.spellStatus[.cureWounds] == .cast)
    #expect(state.divineEnergy == 4) // 5 - 1
  }

  @Test
  func castExpensiveSpell() {
    // Cast Fortune (cost 4 arcane).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane = 5
    state.spellStatus[.fortune] = .known

    let result = state.castSpell(.fortune)
    #expect(result == .success(.fortune, heroic: false))
    #expect(state.arcaneEnergy == 1) // 5 - 4
  }

  @Test
  func castFailsNotKnown() {
    // Cannot cast a face-down spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.fireball] == .faceDown)

    let result = state.castSpell(.fireball)
    #expect(result == .spellNotKnown)
  }

  @Test
  func castFailsAlreadyCast() {
    // Cannot cast a spell that's already been cast (discarded).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast

    let result = state.castSpell(.fireball)
    #expect(result == .spellNotKnown)
  }

  @Test
  func castFailsInsufficientArcane() {
    // Not enough arcane energy to cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fortune] = .known // cost 4
    state.arcaneEnergy = 3

    let result = state.castSpell(.fortune)
    #expect(result == .insufficientEnergy)
    #expect(state.arcaneEnergy == 3) // unchanged
    #expect(state.spellStatus[.fortune] == .known) // still known
  }

  @Test
  func castFailsInsufficientDivine() {
    // Not enough divine energy to cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.raiseDead] = .known // cost 4
    state.divineEnergy = 3

    let result = state.castSpell(.raiseDead)
    #expect(result == .insufficientEnergy)
    #expect(state.divineEnergy == 3) // unchanged
  }

  @Test
  func knownSpellsQuery() {
    // Query which spells are known and available to cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.knownSpells.isEmpty) // all face-down

    state.spellStatus[.fireball] = .known
    state.spellStatus[.cureWounds] = .known
    #expect(state.knownSpells.count == 2)

    state.spellStatus[.fireball] = .cast
    #expect(state.knownSpells.count == 1)
    #expect(state.knownSpells.contains(.cureWounds))
  }

  // MARK: - Heroic Cast (rule 7.2)

  @Test
  func heroicCastArcaneWithWizard() {
    // Wizard alive → can heroic cast arcane spell (enhanced effect).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // has wizard, arcane = 5
    state.spellStatus[.fireball] = .known

    let result = state.castSpell(.fireball, heroic: true)
    #expect(result == .success(.fireball, heroic: true))
    #expect(state.spellStatus[.fireball] == .cast)
    #expect(state.arcaneEnergy == 4)
  }

  @Test
  func heroicCastDivineWithCleric() {
    // Cleric alive → can heroic cast divine spell (enhanced effect).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // has cleric, divine = 5
    state.spellStatus[.cureWounds] = .known

    let result = state.castSpell(.cureWounds, heroic: true)
    #expect(result == .success(.cureWounds, heroic: true))
    #expect(state.spellStatus[.cureWounds] == .cast)
  }

  @Test
  func heroicCastArcaneFailsWithoutWizard() {
    // No Wizard → cannot heroic cast arcane spell.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .ranger, .cleric]
    )
    state.spellStatus[.fireball] = .known

    let result = state.castSpell(.fireball, heroic: true)
    #expect(result == .heroicRequiresHero)
    #expect(state.spellStatus[.fireball] == .known) // not cast
  }

  @Test
  func heroicCastDivineFailsWithoutCleric() {
    // No Cleric → cannot heroic cast divine spell.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .ranger]
    )
    state.spellStatus[.cureWounds] = .known

    let result = state.castSpell(.cureWounds, heroic: true)
    #expect(result == .heroicRequiresHero)
    #expect(state.spellStatus[.cureWounds] == .known) // not cast
  }

  @Test
  func heroicCastFailsWithDeadWizard() {
    // Wizard dead → cannot heroic cast arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known
    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)

    let result = state.castSpell(.fireball, heroic: true)
    #expect(result == .heroicRequiresHero)
  }

  @Test
  func canHeroicCastQuery() {
    // Query whether heroic cast is available for a spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.canHeroicCast(.fireball)) // wizard alive
    #expect(state.canHeroicCast(.cureWounds)) // cleric alive

    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)
    #expect(!state.canHeroicCast(.fireball)) // wizard dead
    #expect(state.canHeroicCast(.cureWounds)) // cleric still alive
  }

  // MARK: - Move Hero (rule 7.1)

  @Test
  func moveHeroToTrack() {
    // Move Warrior from reserves to East track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.heroLocation[.warrior] == .reserves)

    state.moveHero(.warrior, to: .onTrack(.east))
    #expect(state.heroLocation[.warrior] == .onTrack(.east))
  }

  @Test
  func moveHeroBetweenTracks() {
    // Move hero from one track to another.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)

    state.moveHero(.warrior, to: .onTrack(.west))
    #expect(state.heroLocation[.warrior] == .onTrack(.west))
  }

  @Test
  func moveHeroBackToReserves() {
    // Move hero from a track back to reserves.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)

    state.moveHero(.warrior, to: .reserves)
    #expect(state.heroLocation[.warrior] == .reserves)
  }

  // MARK: - Rally (rule 7.4)

  @Test
  func rallySuccess() {
    // Roll 5 > 4 → raise morale one step.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)

    let success = state.rally(dieRoll: 5)
    #expect(success)
    #expect(state.morale == .high)
  }

  @Test
  func rallyFailure() {
    // Roll 4 ≤ 4 → fails.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 4)
    #expect(!success)
    #expect(state.morale == .normal)
  }

  @Test
  func rallyNaturalOneFails() {
    // Natural 1 always fails even with DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 1, drm: 10)
    #expect(!success)
    #expect(state.morale == .normal)
  }

  @Test
  func rallyWithDRM() {
    // Paladin +1 rally DRM. Roll 4 + DRM 1 = 5 > 4 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 4, drm: 1)
    #expect(success)
    #expect(state.morale == .high)
  }

  @Test
  func rallyMoraleCapped() {
    // Morale already high → stays high.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high

    let success = state.rally(dieRoll: 6)
    #expect(success)
    #expect(state.morale == .high)
  }

}
