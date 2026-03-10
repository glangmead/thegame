//
//  LoDActionSpellTests.swift
//  DynamicalSystems
//
//  Tests for LoD player actions: Cast Spell, Heroic Cast, Move Hero, Rally.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDActionSpellTests {

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

}
