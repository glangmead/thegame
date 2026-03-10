//
//  LoDHeroicAttackTests.swift
//  DynamicalSystems
//
//  Tests for LoD heroic attack resolution (rule 7.0).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDHeroicAttackTests {

  // MARK: - Heroic Attack (rule 7.0)

  @Test
  func heroicAttackHit() throws {
    // Warrior (+2 melee) attacks Goblin (strength 2) at East space 2.
    // Roll 2 + DRM 2 = 4 > 2 → hit, pushed to 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 2)
    let result = try outcome.get()
    #expect(result.attackResult == .hit(.east, pushedFrom: 2, pushedTo: 3))
    #expect(!result.heroWounded)
    #expect(!result.heroKilled)
  }

  @Test
  func heroicAttackMiss() throws {
    // Rogue (+1 melee) attacks Orc (strength 3) at Gate space 2.
    // Roll 2 + DRM 1 = 3 ≤ 3 → miss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2
    state.heroLocation[.rogue] = .onTrack(.gate)

    let outcome = state.resolveHeroicAttack(hero: .rogue, on: .gate1, dieRoll: 2)
    let result = try outcome.get()
    #expect(result.attackResult == .miss(.gate1))
    #expect(!result.heroWounded)
  }

  @Test
  func heroicAttackNaturalOneWoundsHero() throws {
    // Rule 7.0: Natural 1 on heroic attack fails AND wounds non-immune hero.
    // Wizard (+1 ranged) attacks Goblin at East 5. Roll 1 → fail + wound.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 1)
    let result = try outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(result.heroWounded)
    #expect(!result.heroKilled)
    #expect(state.heroWounded.contains(.wizard))
  }

  @Test
  func heroicAttackNaturalOneDoesNotWoundImmune() throws {
    // Warrior (armored) and Ranger (agile) are immune to wounding in combat.
    // Warrior attacks Goblin at East 2. Roll 1 → fail but NOT wounded.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 1)
    let result = try outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(!result.heroWounded)
    #expect(!result.heroKilled)
    #expect(!state.heroWounded.contains(.warrior))
  }

  @Test
  func heroicAttackSecondWoundKillsHero() throws {
    // Already-wounded hero rolls natural 1 → killed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)
    state.heroWounded.insert(.wizard) // already wounded

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 1)
    let result = try outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(!result.heroWounded) // not "newly wounded" — killed instead
    #expect(result.heroKilled)
    #expect(state.heroDead.contains(.wizard))
    #expect(!state.heroWounded.contains(.wizard))
    #expect(state.heroLocation[.wizard] == nil) // removed from play
  }

  @Test
  func heroicAttackRangedHero() throws {
    // Wizard (+1 ranged) can target blue spaces. Goblin (2) at East 5.
    // Roll 3 + DRM 1 = 4 > 2 → hit, pushed to 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 3)
    let result = try outcome.get()
    #expect(result.attackResult == .hit(.east, pushedFrom: 5, pushedTo: 6))
  }

  @Test
  func heroicAttackMeleeHeroCannotReachBlueSpace() throws {
    // Warrior (melee) cannot target army at East 5 (blue/ranged-only space).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 6)
    let result = try outcome.get()
    #expect(result.attackResult == .targetNotInMeleeRange)
    #expect(!result.heroWounded) // no wound on validation failure
  }

  @Test
  func heroicAttackRequiresSameTrack() {
    // Rule 7.3: Hero must be on the same track as the target army.
    // Warrior on East track cannot attack army on West track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .west, dieRoll: 6)
    #expect(outcome == .failure(.heroOnWrongTrack))
  }

  @Test
  func heroicAttackRequiresTrackAssignment() {
    // Hero in reserves cannot make heroic attacks.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    // Warrior is in reserves (default from setup)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 6)
    #expect(outcome == .failure(.heroOnWrongTrack))
  }

  @Test
  func heroicAttackHeroNotInPlay() {
    // Hero not in game (e.g. Ranger not in Greenskin default roster).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let outcome = state.resolveHeroicAttack(hero: .ranger, on: .east, dieRoll: 6)
    #expect(outcome == .failure(.heroNotOnTrack))
  }

}
