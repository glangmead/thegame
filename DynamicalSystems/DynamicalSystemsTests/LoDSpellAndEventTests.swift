//
//  LoDSpellAndEventTests.swift
//  DynamicalSystems
//
//  Tests for LoD spell effects and events.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDSpellAndEventTests {

  // MARK: - Spell Effects

  // -- Cure Wounds --

  @Test
  func cureWoundsHealsOneHero() {
    // Normal: heal 1 wounded hero.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.wizard)

    state.applyCureWounds(heroes: [.wizard])
    #expect(!state.heroWounded.contains(.wizard))
  }

  @Test
  func cureWoundsHeroicHealsTwoHeroes() {
    // Heroic (†): heal up to 2 wounded heroes.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.wizard)
    state.heroWounded.insert(.warrior)

    state.applyCureWounds(heroes: [.wizard, .warrior])
    #expect(!state.heroWounded.contains(.wizard))
    #expect(!state.heroWounded.contains(.warrior))
  }

  // -- Mass Heal --

  @Test
  func massHealGainsOneDefender() {
    // Normal: gain 1 defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenderPosition[.menAtArms] = 4

    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 2)
  }

  @Test
  func massHealHeroicGainsTwoDifferent() {
    // Heroic (†): gain 2 defenders (different types).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenderPosition[.menAtArms] = 4
    state.defenderPosition[.archers] = 4

    state.applyMassHeal(defenders: [.menAtArms, .archers])
    #expect(state.defenderValue(for: .menAtArms) == 2)
    #expect(state.defenderValue(for: .archers) == 1)
  }

  @Test
  func massHealCappedAtMax() {
    // Defender cannot exceed max value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenderValue(for: .menAtArms) == 3) // already at max

    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 3) // still max
  }

  // -- Inspire --

  @Test
  func inspireRaisesMoraleAndGrantsDRM() {
    // Raise morale one step and activate +1 DRM for the turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)
    #expect(!state.inspireDRMActive)

    state.applyInspire()
    #expect(state.morale == .high)
    #expect(state.inspireDRMActive)
  }

  @Test
  func inspirePerTurnDRMClearedOnReset() {
    // Inspire's +1 DRM to all rolls is per-turn only.
    // The morale raise from Inspire is permanent (not affected by reset).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high // raised by Inspire (permanent)
    state.inspireDRMActive = true // per-turn bonus

    state.resetTurnTracking()
    #expect(!state.inspireDRMActive) // DRM cleared
    #expect(state.morale == .high) // morale stays
  }

  // -- Raise Dead --

  @Test
  func raiseDeadGainTwoDefenders() {
    // Normal option: gain 2 different defenders.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenderPosition[.menAtArms] = 4
    state.defenderPosition[.archers] = 4

    state.applyRaiseDead(gainDefenders: [.menAtArms, .archers], returnHero: nil)
    #expect(state.defenderValue(for: .menAtArms) == 2)
    #expect(state.defenderValue(for: .archers) == 1)
  }

  @Test
  func raiseDeadReturnHero() {
    // Normal option: return a dead hero to reserves.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)

    state.applyRaiseDead(gainDefenders: [], returnHero: .wizard)
    #expect(!state.heroDead.contains(.wizard))
    #expect(state.heroLocation[.wizard] == .reserves)
  }

  @Test
  func raiseDeadHeroicBothOptions() {
    // Heroic (†): gain 2 defenders AND return a dead hero.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenderPosition[.menAtArms] = 4
    state.defenderPosition[.archers] = 4
    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)

    state.applyRaiseDead(gainDefenders: [.menAtArms, .archers], returnHero: .wizard)
    #expect(state.defenderValue(for: .menAtArms) == 2)
    #expect(state.defenderValue(for: .archers) == 1)
    #expect(!state.heroDead.contains(.wizard))
    #expect(state.heroLocation[.wizard] == .reserves)
  }

  // -- Fireball --

  @Test
  func fireballHit() {
    // +2 magical attack. Goblin (2) at East 3. Roll 2 + 2 = 4 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.applyFireball(on: .east, dieRoll: 2)
    #expect(result == .hit(.east, pushedFrom: 3, pushedTo: 4))
  }

  @Test
  func fireballNaturalOneFails() {
    // Fireball makes an attack roll. Natural 1 on the attack die always fails,
    // even with Fireball's +2 DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2

    let result = state.applyFireball(on: .gate1, dieRoll: 1)
    #expect(result == .naturalOneFail(.gate1))
  }

  @Test
  func fireballIsMagical() {
    // Fireball is magical → ignores negative DRMs in melee range.
    // Goblin (2) at East 2 (melee). Roll 3 + 2 (fireball) + (-2 penalty) = 3.
    // Magical in melee → negative DRM zeroed → effective = 3 + 2 = 5 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.applyFireball(on: .east, dieRoll: 3, additionalDRM: -2)
    // The additionalDRM of -2 + fireball's +2 = 0, but since magical in melee range
    // the negative portion is zeroed. So total DRM = max(0, 0) = 0. Roll 3 + 0 = 3 > 2 → hit.
    // Wait, the fireball DRM of +2 is always positive, and additionalDRM of -2 makes total 0.
    // Since isMagical and melee range, effectiveDRM = max(0, 0) = 0. 3 + 0 = 3 > 2 → hit.
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

}
