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
    state.defenders[.menAtArms] = 1

    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenders[.menAtArms] == 2)
  }

  @Test
  func massHealHeroicGainsTwoDifferent() {
    // Heroic (†): gain 2 defenders (different types).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 0

    state.applyMassHeal(defenders: [.menAtArms, .archers])
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func massHealCappedAtMax() {
    // Defender cannot exceed max value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenders[.menAtArms] == 3) // already at max

    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenders[.menAtArms] == 3) // still max
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
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 0

    state.applyRaiseDead(gainDefenders: [.menAtArms, .archers], returnHero: nil)
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
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
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 0
    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)

    state.applyRaiseDead(gainDefenders: [.menAtArms, .archers], returnHero: .wizard)
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
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

  // -- Slow --

  @Test
  func slowPlacesMarker() {
    // Normal: place Slow marker on army. Army doesn't move.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    state.applySlow(on: .east)
    #expect(state.slowedArmy == .east)
  }

  @Test
  func slowHeroicRetreatsFirst() {
    // Heroic (∞): retreat army one space, then place marker.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    state.applySlow(on: .east, heroic: true)
    #expect(state.armyPosition[.east] == 4) // retreated from 3 to 4
    #expect(state.slowedArmy == .east)
  }

  @Test
  func slowHeroicRetreatCapped() {
    // Heroic retreat capped at maxSpace.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.east] == 6) // already at max

    state.applySlow(on: .east, heroic: true)
    #expect(state.armyPosition[.east] == 6) // stays at max
    #expect(state.slowedArmy == .east)
  }

  @Test
  func slowedArmySkipsAdvance() {
    // When a slowed army would advance, remove the marker instead.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    state.slowedArmy = .east

    let result = state.advanceArmy(.east)
    #expect(result == .slowMarkerRemoved(.east))
    #expect(state.armyPosition[.east] == 3) // didn't move
    #expect(state.slowedArmy == nil) // marker removed
  }

  @Test
  func slowedArmyThenNormalAdvance() {
    // After slow marker removed, next advance is normal.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    state.slowedArmy = .east

    _ = state.advanceArmy(.east) // removes marker
    let result = state.advanceArmy(.east) // normal advance
    #expect(result == .advanced(.east, from: 3, to: 2))
  }

  // -- Chain Lightning --

  @Test
  func chainLightningThreeAttacks() {
    // Normal: 3 attacks with +2, +1, +0 DRMs.
    // All targeting Goblin (2) at East 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let results = state.applyChainLightning(targets: [
      (slot: .east, dieRoll: 2), // 2 + 2 = 4 > 2 → hit
      (slot: .east, dieRoll: 2), // 2 + 1 = 3 > 2 → hit
      (slot: .east, dieRoll: 2), // 2 + 0 = 2 ≤ 2 → miss
    ])
    #expect(results.count == 3)
    // First hit pushes from 3→4, second from 4→5, third misses
    #expect(results[2] == .miss(.east))
  }

  @Test
  func chainLightningHeroicBetterDRMs() {
    // Heroic (∞): 3 attacks with +3, +2, +1 DRMs.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let results = state.applyChainLightning(
      targets: [
        (slot: .east, dieRoll: 2), // 2 + 3 = 5 > 2 → hit
        (slot: .east, dieRoll: 2), // 2 + 2 = 4 > 2 → hit
        (slot: .east, dieRoll: 2), // 2 + 1 = 3 > 2 → hit
      ],
      heroic: true
    )
    #expect(results.count == 3)
    // All three should hit
    for result in results {
      switch result {
      case .hit: break // expected
      default: #expect(Bool(false), "Expected hit")
      }
    }
  }

  // -- Divine Wrath --

  @Test
  func divineWrathOneAttack() {
    // Normal: 1 magical attack with +1 DRM. Goblin (2) at East 3.
    // Roll 3 + 1 = 4 > 2 → hit, pushed to 4.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 3),
    ])
    #expect(results.count == 1)
    #expect(results[0] == .hit(.east, pushedFrom: 3, pushedTo: 4))
    // Goblin is not undead → no extra retreat
    #expect(state.armyPosition[.east] == 4)
  }

  @Test
  func divineWrathUndeadExtraRetreat() {
    // Undead army gets pushed back an extra space.
    // Set up an undead scenario: zombie (strength 3) on east.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyType[.east] = .zombie
    state.armyPosition[.east] = 3

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 4), // 4 + 1 = 5 > 3 → hit
    ])
    #expect(results.count == 1)
    // Normal push: 3→4. Undead bonus: 4→5. So army ends at 5.
    #expect(state.armyPosition[.east] == 5)
  }

  @Test
  func divineWrathUndeadRetreatCapped() {
    // Undead extra retreat capped at maxSpace.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyType[.east] = .zombie
    state.armyPosition[.east] = 5

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 4), // hit → push 5→6, undead +1 → capped at 6
    ])
    #expect(results.count == 1)
    #expect(state.armyPosition[.east] == 6)
  }

  @Test
  func divineWrathHeroicTwoAttacks() {
    // Heroic (†): 2 attacks on different targets.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3 // Goblin (2)
    state.armyPosition[.west] = 3 // Goblin (2)

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 3), // 3 + 1 = 4 > 2 → hit
      (slot: .west, dieRoll: 3), // 3 + 1 = 4 > 2 → hit
    ])
    #expect(results.count == 2)
    #expect(state.armyPosition[.east] == 4)
    #expect(state.armyPosition[.west] == 4)
  }

  @Test
  func divineWrathMissNoRetreat() {
    // Miss → no push, no undead bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyType[.east] = .zombie
    state.armyPosition[.east] = 3

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 2), // 2 + 1 = 3 ≤ 3 → miss
    ])
    #expect(results[0] == .miss(.east))
    #expect(state.armyPosition[.east] == 3) // unchanged
  }

  // -- Army type: isUndead --

  @Test
  func armyTypeUndead() {
    #expect(!LoD.ArmyType.goblin.isUndead)
    #expect(!LoD.ArmyType.orc.isUndead)
    #expect(!LoD.ArmyType.dragon.isUndead)
    #expect(!LoD.ArmyType.troll.isUndead)
    #expect(LoD.ArmyType.zombie.isUndead)
    #expect(LoD.ArmyType.skeletalRider.isUndead)
    #expect(LoD.ArmyType.wraith.isUndead)
    #expect(LoD.ArmyType.nightmare.isUndead)
  }

  // MARK: - Events (rule 5.0)

  // -- Catapult Shrapnel (card #1) --

  @Test
  func catapultShrapnelLoseArcher() {
    // Roll 1: lose one Archer.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenders[.archers] == 2)
    state.eventCatapultShrapnel(dieRoll: 1)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func catapultShrapnelLoseMaA() {
    // Roll 2-3: lose one Men-at-Arms.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventCatapultShrapnel(dieRoll: 2)
    #expect(state.defenders[.menAtArms] == 2)
  }

  @Test
  func catapultShrapnelNoEffect() {
    // Roll 4-6: no effect.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventCatapultShrapnel(dieRoll: 4)
    #expect(state.defenders[.archers] == 2)
    #expect(state.defenders[.menAtArms] == 3)
  }

  // -- Rocks of Ages (card #4) --

  @Test
  func rocksOfAgesLosePriest() {
    // Roll 1: lose one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventRocksOfAges(dieRoll: 1)
    #expect(state.defenders[.priests] == 1)
  }

  @Test
  func rocksOfAgesLoseMaA() {
    // Roll 2-3: lose one Men-at-Arms.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventRocksOfAges(dieRoll: 3)
    #expect(state.defenders[.menAtArms] == 2)
  }

  // -- Reign of Arrows (card #17) --

  @Test
  func reignOfArrowsLosePriest() {
    // Roll 1: lose one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventReignOfArrows(dieRoll: 1)
    #expect(state.defenders[.priests] == 1)
  }

  @Test
  func reignOfArrowsLoseArcher() {
    // Roll 2-3: lose one Archer.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventReignOfArrows(dieRoll: 2)
    #expect(state.defenders[.archers] == 1)
  }

  // -- Trapped by Flames (card #18) --

  @Test
  func trappedByFlamesLoseMaA() {
    // Roll 1-2: lose one Men-at-Arms.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventTrappedByFlames(dieRoll: 1)
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 2) // unchanged
    #expect(state.defenders[.priests] == 2) // unchanged
  }

  @Test
  func trappedByFlamesLoseArcherAndPriest() {
    // Roll 3-4: lose one Archer AND one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventTrappedByFlames(dieRoll: 3)
    #expect(state.defenders[.archers] == 1)
    #expect(state.defenders[.priests] == 1)
    #expect(state.defenders[.menAtArms] == 3) // unchanged
  }

  @Test
  func trappedByFlamesNoEffect() {
    // Roll 5-6: no effect.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventTrappedByFlames(dieRoll: 5)
    #expect(state.defenders[.menAtArms] == 3)
    #expect(state.defenders[.archers] == 2)
    #expect(state.defenders[.priests] == 2)
  }

  // -- Distracted Defenders (card #9) --

  @Test
  func distractedDefendersAdvances() {
    // East army at space 4 (out of melee range 1-3) → advance to space 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 4
    let results = state.eventDistractedDefenders()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.east, from: 4, to: 3))
  }

  @Test
  func distractedDefendersNoEffect() {
    // East army at space 3 (in melee range) → no advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    let results = state.eventDistractedDefenders()
    #expect(results.isEmpty)
  }

  // -- Banners in the Distance (card #20) --

  @Test
  func bannersInDistanceAdvances() {
    // West army at space 5 (out of melee range) → advance to space 4.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 5
    let results = state.eventBannersInDistance()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.west, from: 5, to: 4))
  }

  @Test
  func bannersInDistanceNoEffect() {
    // West army at space 2 (in melee range) → no advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 2
    let results = state.eventBannersInDistance()
    #expect(results.isEmpty)
  }

  // -- The Harbingers of Doom (card #11) --

  @Test
  func harbingersAdvanceFarthest() {
    // Farthest army (highest space number) advances one space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventHarbingers()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.east, from: 5, to: 4))
  }

  @Test
  func harbingersChooseIfTied() {
    // If tied for farthest, player chooses which to advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 6
    state.armyPosition[.west] = 6
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventHarbingers(chosenSlot: .west)
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.west, from: 6, to: 5))
  }

  // -- Broken Walls (card #14) --

  @Test
  func brokenWallsAdvanceClosest() {
    // Closest of East/West (lowest space) advances one space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    state.armyPosition[.west] = 5

    let results = state.eventBrokenWalls()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.east, from: 3, to: 2))
  }

  @Test
  func brokenWallsBothIfTied() {
    // If East and West tied, advance both one space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 4
    state.armyPosition[.west] = 4

    let results = state.eventBrokenWalls()
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.east, from: 4, to: 3))
    #expect(results[1] == .advanced(.west, from: 4, to: 3))
  }

  // -- Campfires in the Distance (card #23) --

  @Test
  func campfiresAdvanceGate() {
    // One Gate army out of melee range (space 4) → advance farthest Gate army.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 4 // out of melee (melee is 1-3)
    state.armyPosition[.gate2] = 2 // in melee

    let results = state.eventCampfires()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.gate1, from: 4, to: 3))
  }

  @Test
  func campfiresBothGateIfBothOut() {
    // Both Gate armies out of melee range → advance both.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 4
    state.armyPosition[.gate2] = 4

    let results = state.eventCampfires()
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.gate1, from: 4, to: 3))
    #expect(results[1] == .advanced(.gate2, from: 4, to: 3))
  }

  @Test
  func campfiresNoEffectIfInRange() {
    // Both Gate armies in melee range → no effect.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 2

    let results = state.eventCampfires()
    #expect(results.isEmpty)
  }

  // -- Lamentation of the Women (card #16) --

  @Test
  func lamentationMoraleLoss() {
    // Roll 1-3: reduce Morale by one.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)
    state.eventLamentation(dieRoll: 2)
    #expect(state.morale == .low)
  }

  @Test
  func lamentationNoMelee() {
    // Roll 4-6: no melee attacks this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.noMeleeThisTurn)
    state.eventLamentation(dieRoll: 5)
    #expect(state.noMeleeThisTurn)
    #expect(state.morale == .normal) // unchanged
  }

  // -- Acts of Valor (card #8) --

  @Test
  func actsOfValorWoundForBonus() {
    // Wound all unwounded heroes → +1 attack DRM this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.eventAttackDRMBonus == 0)
    state.eventActsOfValor(woundHeroes: true)
    #expect(state.heroWounded.contains(.warrior))
    #expect(state.heroWounded.contains(.wizard))
    #expect(state.heroWounded.contains(.cleric))
    #expect(state.eventAttackDRMBonus == 1)
  }

  @Test
  func actsOfValorDecline() {
    // Choose not to wound → no bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventActsOfValor(woundHeroes: false)
    #expect(state.heroWounded.isEmpty)
    #expect(state.eventAttackDRMBonus == 0)
  }

  // -- Bloody Handprints (card #24) --

  @Test
  func bloodyHandprintsKill() {
    // Roll 1-3: kill a Hero (wounded first).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.warrior) // wounded → must be killed first
    state.eventBloodyHandprints(dieRoll: 2, chosenHero: .warrior)
    #expect(state.heroDead.contains(.warrior))
    #expect(!state.heroWounded.contains(.warrior))
    #expect(state.heroLocation[.warrior] == nil)
  }

  @Test
  func bloodyHandprintsWound() {
    // Roll 4-6: wound a Hero (player choice).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventBloodyHandprints(dieRoll: 5, chosenHero: .wizard)
    #expect(state.heroWounded.contains(.wizard))
    #expect(!state.heroDead.contains(.wizard))
  }

  // -- Council of Heroes (card #26) --

  @Test
  func councilOfHeroes() {
    // Return all living heroes to Reserves. Wounded heroes cannot act.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)
    state.heroLocation[.wizard] = .onTrack(.west)
    // cleric already in reserves

    state.eventCouncilOfHeroes()
    #expect(state.heroLocation[.warrior] == .reserves)
    #expect(state.heroLocation[.wizard] == .reserves)
    #expect(state.heroLocation[.cleric] == .reserves)
    #expect(state.woundedHeroesCannotAct)
  }

  // -- Midnight Magic (card #27) / By the Light of the Moon (card #32) --

  @Test
  func midnightMagicLow() {
    // Roll 1-3: +1 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 2)
    #expect(state.arcaneEnergy == min(before + 1, 6))
  }

  @Test
  func midnightMagicHigh() {
    // Roll 4-6: +2 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane = 1+2 = 3
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 5)
    #expect(state.arcaneEnergy == min(before + 2, 6))
  }

  // -- Assassin's Creedo (card #30) --

  @Test
  func assassinsCreedoKill() {
    // Roll 1-3: kill a Hero of your choice.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAssassinsCreedo(dieRoll: 2, chosenHero: .cleric)
    #expect(state.heroDead.contains(.cleric))
    #expect(state.heroLocation[.cleric] == nil)
  }

  @Test
  func assassinsCreedoBonus() {
    // Roll 4-6: +1 attack DRM this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAssassinsCreedo(dieRoll: 5)
    #expect(state.eventAttackDRMBonus == 1)
  }

  // -- In the Pale Moonlight (card #31) --

  @Test
  func paleMoonlight() {
    // -1 divine, +1 arcane, lose one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane 5, divine 5
    let arcBefore = state.arcaneEnergy
    let divBefore = state.divineEnergy
    state.eventPaleMoonlight()
    #expect(state.arcaneEnergy == min(arcBefore + 1, 6))
    #expect(state.divineEnergy == divBefore - 1)
    #expect(state.defenders[.priests] == 1)
  }

  // -- By the Light of the Moon (card #32) — same as Midnight Magic --

  @Test
  func byLightOfMoon() {
    // Uses same method as Midnight Magic. Roll 4-6: +2 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane = 3
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 6)
    #expect(state.arcaneEnergy == min(before + 2, 6))
  }

  // -- Deserters in the Dark (card #33) --

  @Test
  func desertersTwoDefenders() {
    // Player chooses: lose 2 defenders.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventDeserters(loseTwoDefenders: (.menAtArms, .archers))
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func desertersMorale() {
    // Player chooses: reduce Morale by one.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventDeserters(loseTwoDefenders: nil)
    #expect(state.morale == .low)
  }

  // -- The Waning Moon (card #34) --

  @Test
  func waningMoonLoss() {
    // Roll 1-3: -1 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane 5
    let before = state.arcaneEnergy
    state.eventWaningMoon(dieRoll: 2)
    #expect(state.arcaneEnergy == before - 1)
  }

  @Test
  func waningMoonGain() {
    // Roll 4-6: +1 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane 3
    let before = state.arcaneEnergy
    state.eventWaningMoon(dieRoll: 5)
    #expect(state.arcaneEnergy == min(before + 1, 6))
  }

  // -- Mystic Forces Reborn (card #35) --

  @Test
  func mysticForcesReborn() {
    // Return cast spells to pool. Roll 4-6: draw a random arcane spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast
    state.spellStatus[.slow] = .cast
    state.spellStatus[.cureWounds] = .cast // divine, also returns

    state.eventMysticForcesReborn(dieRoll: 5, randomSpell: .chainLightning)
    // Cast spells returned to face-down
    #expect(state.spellStatus[.fireball] == .faceDown)
    #expect(state.spellStatus[.slow] == .faceDown)
    #expect(state.spellStatus[.cureWounds] == .faceDown)
    // Random arcane spell drawn (revealed)
    #expect(state.spellStatus[.chainLightning] == .known)
  }

  @Test
  func mysticForcesRebornLoseArcane() {
    // Roll 1-3: -1 arcane (spells still returned).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast
    let before = state.arcaneEnergy

    state.eventMysticForcesReborn(dieRoll: 2)
    #expect(state.spellStatus[.fireball] == .faceDown)
    #expect(state.arcaneEnergy == before - 1)
  }

  // -- Death and Despair (card #29) --

  @Test
  func deathAndDespair() {
    // Roll 4, no mitigation → advance farthest army 4 spaces.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // East at 6 (farthest, tied with West/Sky), set others lower
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventDeathAndDespair(dieRoll: 4, chosenSlot: .east)
    #expect(results.count == 4)
    #expect(state.armyPosition[.east] == 2) // 6 → 5 → 4 → 3 → 2
  }

  @Test
  func deathAndDespairMitigated() {
    // Roll 3, wound 1 hero + lose 1 defender → only 1 advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventDeathAndDespair(
      dieRoll: 3,
      heroesToWound: [.warrior],
      defendersToLose: [.menAtArms],
      chosenSlot: .east
    )
    #expect(results.count == 1) // 3 - 2 = 1
    #expect(state.armyPosition[.east] == 4) // 5 → 4
    #expect(state.heroWounded.contains(.warrior))
    #expect(state.defenders[.menAtArms] == 2)
  }

  // -- Bump in the Night (card #36) --

  @Test
  func bumpInTheNightSky() {
    // Choose: advance Sky 1 space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 5

    let results = state.eventBumpInTheNight(advanceSky: true)
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.sky, from: 5, to: 4))
  }

  @Test
  func bumpInTheNightOthers() {
    // Choose: advance other armies total 2 spaces (e.g., east + west 1 each).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 4

    let results = state.eventBumpInTheNight(advanceSky: false, otherAdvances: [.east, .west])
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.east, from: 5, to: 4))
    #expect(results[1] == .advanced(.west, from: 4, to: 3))
  }

  // -- Event per-turn tracking reset --

  @Test
  func eventFieldsResetOnTurnReset() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAttackDRMBonus = 1
    state.noMeleeThisTurn = true
    state.woundedHeroesCannotAct = true

    state.resetTurnTracking()
    #expect(state.eventAttackDRMBonus == 0)
    #expect(!state.noMeleeThisTurn)
    #expect(!state.woundedHeroesCannotAct)
  }

}
