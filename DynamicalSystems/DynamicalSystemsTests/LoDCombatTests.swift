//
//  LoDCombatTests.swift
//  DynamicalSystems
//
//  Tests for LoD combat: Battle Resolution, Gate Targeting,
//  Hero Combat Properties, Heroic Attack, Hero Wounding,
//  Upgrade Attack DRMs, Bloody Battle, Paladin Re-roll, Turn Reset.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDCombatTests {

  // MARK: - Battle Resolution (rule 8.0)

  @Test
  func attackHitPushesBack() {
    // Rule 8.0: Modified roll > army strength pushes army back one space.
    // Goblin (strength 2) at East space 3. Roll 4 > 2 → hit, pushed to 4.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 3, pushedTo: 4))
    #expect(state.armyPosition[.east] == 4)
  }

  @Test
  func attackMiss() {
    // Rule 8.0: Modified roll ≤ strength = miss. Goblin (2) at East 3. Roll 2 ≤ 2.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 2)
    #expect(result == .miss(.east))
    #expect(state.armyPosition[.east] == 3) // unchanged
  }

  @Test
  func naturalOneAlwaysFails() {
    // Rules: Natural roll of 1 always fails, even with large DRM.
    // Goblin (2) at East 2. Roll 1 + DRM 10 would be 11, but natural 1 = fail.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 1, drm: 10)
    #expect(result == .naturalOneFail(.east))
    #expect(state.armyPosition[.east] == 2) // unchanged
  }

  @Test
  func meleeRequiresRedSpace() {
    // Rule 8.0: Melee attack only on red-tinted (melee range) spaces.
    // Goblin at East 5 (blue) → can't melee.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 6)
    #expect(result == .targetNotInMeleeRange)
  }

  @Test
  func rangedCanTargetAnySpace() {
    // Rule 8.0: Ranged attacks can target armies on any space (red or blue).
    // Goblin (2) at East 5 (blue). Roll 4 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(on: .east, attackType: .ranged, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 5, pushedTo: 6))
  }

  @Test
  func rangedCannotTargetTerror() {
    // Rule 4.2: Terror track is melee-only — no ranged attacks permitted.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.terror] = 2

    let result = state.resolveAttack(on: .terror, attackType: .ranged, dieRoll: 6)
    #expect(result == .targetNotInRange)
  }

  @Test
  func attackNotOnBoard() {
    // Attack on an army not on the board.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.terror] == nil)

    let result = state.resolveAttack(on: .terror, attackType: .melee, dieRoll: 6)
    #expect(result == .targetNotOnBoard)
  }

  @Test
  func attackWithDRM() {
    // DRMs add to die roll. Orc (strength 3) at Gate 2. Roll 2 + DRM 2 = 4 > 3 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2

    let result = state.resolveAttack(on: .gate1, attackType: .melee, dieRoll: 2, drm: 2)
    #expect(result == .hit(.gate1, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalIgnoresNegativeDRMInMelee() {
    // Rules: Magical attacks in melee range ignore negative DRMs.
    // Goblin (2) at East 2 (melee range). Roll 3, DRM -2 → effective DRM 0.
    // Modified roll = 3 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(
      on: .east, attackType: .melee, dieRoll: 3, drm: -2, isMagical: true
    )
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalKeepsPositiveDRM() {
    // Magical attack in melee range with positive DRM — DRM is kept.
    // Goblin (2) at East 2. Roll 2, DRM +1 → modified 3 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(
      on: .east, attackType: .melee, dieRoll: 2, drm: 1, isMagical: true
    )
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalAtRangeKeepsNegativeDRM() {
    // Magical attack NOT in melee range — negative DRM still applies.
    // Goblin (2) at East 5 (ranged only). Roll 3, DRM -2 → modified 1 ≤ 2 → miss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(
      on: .east, attackType: .ranged, dieRoll: 3, drm: -2, isMagical: true
    )
    #expect(result == .miss(.east))
  }

  @Test
  func hitCannotPushPastMaxSpace() {
    // Army already at max space — push has nowhere to go, stays at max.
    // Goblin (2) at East 6. Roll 4 > 2 → hit, pushed to min(7, 6) = 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.east] == 6)

    let result = state.resolveAttack(on: .east, attackType: .ranged, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 6, pushedTo: 6))
    #expect(state.armyPosition[.east] == 6)
  }

  // MARK: - Gate Targeting (rules 4.1.1, 8.1.2)

  @Test
  func gateTargetClosest() {
    // Only the closest (lowest space) Gate army can be targeted.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 4

    let targets = state.gateAttackTargets()
    #expect(targets == [.gate1]) // gate1 at 2 is closer
  }

  @Test
  func gateTargetTiedChoose() {
    // Rule 8.1.2: Both armies on same space → player can choose either.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3

    let targets = state.gateAttackTargets()
    #expect(targets.count == 2)
    #expect(targets.contains(.gate1))
    #expect(targets.contains(.gate2))
  }

  @Test
  func gateTargetOneAbsent() {
    // One Gate army not on board → the other is the only target.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = nil

    let targets = state.gateAttackTargets()
    #expect(targets == [.gate1])
  }

  // MARK: - Hero Combat Properties (Player Aid)

  @Test
  func heroCombatDRMs() {
    // Warrior gets +2, all others get +1.
    #expect(LoD.HeroType.warrior.combatDRM == 2)
    #expect(LoD.HeroType.wizard.combatDRM == 1)
    #expect(LoD.HeroType.ranger.combatDRM == 1)
    #expect(LoD.HeroType.rogue.combatDRM == 1)
    #expect(LoD.HeroType.paladin.combatDRM == 1)
    #expect(LoD.HeroType.cleric.combatDRM == 1)
  }

  @Test
  func heroAttackTypes() {
    // Warrior, Rogue, Paladin are melee. Wizard, Ranger, Cleric are ranged.
    #expect(!LoD.HeroType.warrior.isRangedCombatant)
    #expect(LoD.HeroType.wizard.isRangedCombatant)
    #expect(LoD.HeroType.ranger.isRangedCombatant)
    #expect(!LoD.HeroType.rogue.isRangedCombatant)
    #expect(!LoD.HeroType.paladin.isRangedCombatant)
    #expect(LoD.HeroType.cleric.isRangedCombatant)
  }

  @Test
  func heroWoundImmunity() {
    // Warrior (armored) and Ranger (agile) are immune to wounding in combat.
    #expect(LoD.HeroType.warrior.isWoundImmuneInCombat)
    #expect(LoD.HeroType.ranger.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.wizard.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.rogue.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.paladin.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.cleric.isWoundImmuneInCombat)
  }

}
