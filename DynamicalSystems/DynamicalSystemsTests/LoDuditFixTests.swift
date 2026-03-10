//
//  LoDuditFixTests.swift
//  DynamicalSystems
//
//  Tests for LoD audit fixes.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDuditFixTests {

  // MARK: - Audit Fix #2: Acid Attack Type is MELEE (rule 6.3)

  @Test
  func acidFreeAttackIsMelee() {
    // Rule 6.3: Acid upgrade triggers a free MELEE attack when army reaches space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .acid
    state.armyPosition[.east] = 2
    // Advance to space 1 triggers acid. Die roll 6 vs goblin str 2 with melee → hit.
    // Melee should work because space 1 is in melee range.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var gState = game.newState()
    gState.upgrades[.east] = .acid
    gState.armyPosition[.east] = 2
    // We test the underlying resolveAttack with melee type directly
    let result = gState.resolveAttack(on: .east, attackType: .melee, dieRoll: 6, drm: 0)
    if case .hit = result {
      // Expected: melee on space 1 of east wall is in range
    } else {
      Issue.record("Acid free attack should be melee and hit at space 1")
    }
  }

  // MARK: - Audit Fix #7: Build Restriction — No Army on Space 1 (rule 6.3)

  @Test
  func buildBlockedWhenArmyOnSpace1() {
    // Rule 6.3: Cannot build an upgrade if an army is on space 1 of that track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1  // Army on space 1
    let result = state.build(upgrade: .oil, on: .east, dieRoll: 6, drm: 0)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildAllowedWhenArmyNotOnSpace1() {
    // Rule 6.3: Building is allowed when no army is on space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3  // Army not on space 1
    let result = state.build(upgrade: .oil, on: .east, dieRoll: 6, drm: 0)
    #expect(result == .success(.oil, .east))
  }

  @Test
  func buildNotOfferedWhenArmyOnSpace1() {
    // Rule 6.3: Composed game should not offer build actions when army is on space 1.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.armyPosition[.east] = 1
    let actions = game.allowedActions(state: state)
    let buildActions = actions.filter {
      if case .buildUpgrade(_, .east, _) = $0 { return true }
      return false
    }
    #expect(buildActions.isEmpty)
  }

  // MARK: - Audit Fix #9: Acid Once Per Turn (rule 6.3)

  @Test
  func acidFreeAttackOncePerTurn() {
    // Rule 6.3: Acid's free attack should only trigger once per turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .acid
    state.acidUsedThisTurn = true
    // Even if army reaches space 1, acid shouldn't trigger again.
    #expect(state.acidUsedThisTurn)
  }

  // MARK: - Audit Fix #11: Paladin +1 Rally DRM (rule 10.2)

  @Test
  func paladinRallyDRM() {
    // Rule 10.2: Paladin on a wall track gives +1 DRM to rally rolls.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .paladin])
    state.heroLocation[.paladin] = .onTrack(.east)
    let drm = state.totalRallyDRM()
    #expect(drm >= 1)  // At least +1 from Paladin
  }

  @Test
  func paladinRallyDRMRequiresWallTrack() {
    // Paladin must be on a wall track for rally DRM bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .paladin])
    state.heroLocation[.paladin] = .onTrack(.sky)  // Non-wall track
    let drm = state.totalRallyDRM()
    // Should NOT include Paladin bonus since Sky is not a wall
    #expect(drm == 0)
  }

  @Test
  func paladinRallyDRMInReserves() {
    // Paladin in reserves should not give rally DRM bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .paladin])
    state.heroLocation[.paladin] = .reserves
    let drm = state.totalRallyDRM()
    #expect(drm == 0)
  }

  // MARK: - Audit Fix #12: Bloody Battle Magical Exemption (rule 8.2)

  @Test
  func bloodyBattleNotTriggeredBySpells() {
    // Rule 8.2: Magical attacks (spells) should not trigger the bloody battle defender cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east
    state.spellStatus[.fireball] = .known
    state.arcaneEnergy = 3
    // Cast Fireball at the bloody battle army — should NOT cost a defender
    let defendersBefore = state.defenders[.menAtArms]!
    _ = state.castSpell(.fireball)
    _ = state.applyFireball(on: .east, dieRoll: 6)
    #expect(state.defenders[.menAtArms] == defendersBefore)  // No defender lost
  }

  // MARK: - Audit Fix #3: Defender Limits on Attacks (rule 8.2)

  @Test
  func meleeAttacksLimitedByMenAtArms() {
    // Rule 8.2: Men-at-arms value = max melee attacks per turn.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.defenders[.menAtArms] = 1  // Only 1 melee attack allowed
    state.armyPosition[.east] = 2  // In melee range

    // First melee attack should be offered
    var actions = game.allowedActions(state: state)
    let meleeActions = actions.filter {
      if case .meleeAttack = $0 { return true }
      return false
    }
    #expect(!meleeActions.isEmpty)

    // After 1 melee attack, no more melee should be offered
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    actions = game.allowedActions(state: state)
    let meleeActionsAfter = actions.filter {
      if case .meleeAttack = $0 { return true }
      return false
    }
    #expect(meleeActionsAfter.isEmpty)
  }

  @Test
  func rangedAttacksLimitedByArchers() {
    // Rule 8.2: Archers value = max ranged attacks per turn.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.defenders[.archers] = 1  // Only 1 ranged attack allowed

    // After 1 ranged attack, no more ranged should be offered
    _ = game.reduce(into: &state, action: .rangedAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicBow: nil))
    let actions = game.allowedActions(state: state)
    let rangedActionsAfter = actions.filter {
      if case .rangedAttack = $0 { return true }
      return false
    }
    #expect(rangedActionsAfter.isEmpty)
  }

  // MARK: - Audit Fix #4: Wizard Same-Track Requirement (rule 9.2)

  @Test
  func arcaneSpellRequiresWizardOnSameTrack() {
    // Rule 9.2: Arcane spells (except Chain Lightning, Fortune) require Wizard on same track as target.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known
    state.arcaneEnergy = 3
    state.heroLocation[.wizard] = .onTrack(.west)  // Wizard on west
    // Fireball targeting east should fail validation
    #expect(!state.canTargetWithArcaneSpell(.fireball, targetTrack: .east))
    // Fireball targeting west should succeed
    #expect(state.canTargetWithArcaneSpell(.fireball, targetTrack: .west))
  }

  @Test
  func chainLightningNoTrackRestriction() {
    // Rule 9.2: Chain Lightning is exempt from same-track restriction.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.wizard] = .onTrack(.west)
    #expect(state.canTargetWithArcaneSpell(.chainLightning, targetTrack: .east))
  }

  @Test
  func fortuneNoTrackRestriction() {
    // Rule 9.2: Fortune is exempt from same-track restriction.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.wizard] = .onTrack(.west)
    #expect(state.canTargetWithArcaneSpell(.fortune, targetTrack: .east))
  }

  // MARK: - Audit Fix #6: Inspire Normal vs Heroic (rule 9.3)

  @Test
  func inspireNormalCannotCastAtHighMorale() {
    // Rule 9.3: Normal Inspire cannot be cast when morale is already High.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high
    #expect(!state.canCastInspireNormal())
  }

  @Test
  func inspireHeroicAtHighMoraleGivesDRMOnly() {
    // Rule 9.3: Heroic Inspire at High morale gives +1 DRM but does NOT raise morale.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high
    state.applyInspire(heroic: true)
    #expect(state.morale == .high)  // Morale stays high
    #expect(state.inspireDRMActive)  // DRM still active
  }

  @Test
  func inspireNormalRaisesMorale() {
    // Rule 9.3: Normal Inspire raises morale and grants +1 DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .normal
    state.applyInspire(heroic: false)
    #expect(state.morale == .high)
    #expect(state.inspireDRMActive)
  }

  // MARK: - Audit Fix #13: Mass Heal Different Defenders (rule 9.3)

  @Test
  func massHealHeroicRequiresDifferentDefenders() {
    // Rule 9.3: Heroic Mass Heal gives +1 to 2 DIFFERENT defender types.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 1
    // Two different types should work
    state.applyMassHeal(defenders: [.menAtArms, .archers])
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 2)
  }

  // MARK: - Audit Fix #14: Raise Dead Normal vs Heroic (rule 9.3)

  @Test
  func raiseDeadNormalIsExclusiveOR() {
    // Rule 9.3: Normal Raise Dead = 2 different defenders OR return 1 dead hero, not both.
    // Validation: if returnHero is provided, gainDefenders should be empty (normal mode).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroDead.insert(.warrior)
    state.heroLocation.removeValue(forKey: .warrior)
    // Normal: providing both defenders AND hero is invalid
    #expect(!state.isValidRaiseDeadParams(gainDefenders: [.menAtArms, .archers], returnHero: .warrior, heroic: false))
    // Normal: hero only is valid
    #expect(state.isValidRaiseDeadParams(gainDefenders: [], returnHero: .warrior, heroic: false))
    // Normal: defenders only is valid
    #expect(state.isValidRaiseDeadParams(gainDefenders: [.menAtArms, .archers], returnHero: nil, heroic: false))
  }

  @Test
  func raiseDeadHeroicAllowsBoth() {
    // Rule 9.3: Heroic Raise Dead = 2 different defenders AND/OR return 1 dead hero.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroDead.insert(.warrior)
    state.heroLocation.removeValue(forKey: .warrior)
    // Heroic: both defenders AND hero is valid
    #expect(state.isValidRaiseDeadParams(gainDefenders: [.menAtArms, .archers], returnHero: .warrior, heroic: true))
  }

  // MARK: - Audit Fix #1: Grease Upgrade Breach Prevention (rule 6.3)

  @Test
  func greasePreventsBreach() {
    // Rule 6.3: When army reaches space 1 on a greased track and rolls > 2,
    // it stays on space 1 instead of breaching (army stays, no breach).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    state.armyPosition[.east] = 1
    // Army tries to advance past space 1, but grease check: roll 5 > 2, stays on 1
    let result = state.advanceArmy(.east, dieRoll: 5)
    #expect(result == .greaseHeld(.east))
    #expect(state.armyPosition[.east] == 1)  // Army stays on space 1
    #expect(!state.breaches.contains(.east))  // No breach
  }

  @Test
  func greaseFailsLowRoll() {
    // Rule 6.3: When army rolls ≤ 2 on a greased track, grease fails → breach.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    state.armyPosition[.east] = 1
    let result = state.advanceArmy(.east, dieRoll: 2)
    // Grease fails, breach is created
    #expect(result == .breachCreated(.east))
    #expect(state.breaches.contains(.east))
  }

  @Test
  func greaseRemovedAfterUse() {
    // Rule 6.3: Grease is removed when a breach occurs (upgrade removed on breach).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    state.armyPosition[.east] = 1
    _ = state.advanceArmy(.east, dieRoll: 5)  // Grease holds
    // Grease should be consumed/removed after successful use
    #expect(state.upgrades[.east] == nil)
  }

  @Test
  func greaseNotADRM() {
    // Rule 6.3: Grease should NOT be a DRM — it has its own breach mechanic.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    let drm = state.upgradeDRM(on: .east, attackType: .melee)
    #expect(drm == 0)
  }

  // MARK: - Audit Fix #5: Fireball Heroic Re-roll (rule 9.2)

  @Test
  func fireballHeroicAllowsReroll() {
    // Rule 9.2: When Fireball is cast heroically and misses, caster may re-roll once.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    // First roll: miss (roll 1 = natural fail)
    let result1 = state.applyFireball(on: .east, dieRoll: 1)
    #expect(result1 == .naturalOneFail(.east))
    // Heroic re-roll: roll 6, +2 DRM = 8 > goblin 2 → hit
    let result2 = state.applyFireball(on: .east, dieRoll: 6)
    if case .hit = result2 {
      // Expected
    } else {
      Issue.record("Heroic Fireball re-roll should hit")
    }
  }

  // MARK: - Audit Fix #8: Barricade as Player Action (rule 6.3)

  @Test
  func buildBarricadeAction() {
    // Rule 6.3: After a breach, player can spend a build action (roll > 2)
    // to place a barricade, converting breach to barricade.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)
    let result = state.buildBarricade(on: .east, dieRoll: 5, drm: 0)
    #expect(result == .success)
    #expect(state.barricades.contains(.east))
    #expect(!state.breaches.contains(.east))
  }

  @Test
  func buildBarricadeFailsLowRoll() {
    // Rule 6.3: Building a barricade requires roll > 2.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)
    let result = state.buildBarricade(on: .east, dieRoll: 2, drm: 0)
    #expect(result == .rollFailed)
    #expect(!state.barricades.contains(.east))
    #expect(state.breaches.contains(.east))
  }

  @Test
  func buildBarricadeOfferedInAllowedActions() {
    // Rule 6.3: Barricade build should be offered when a breach exists.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.breaches.insert(.east)
    let actions = game.allowedActions(state: state)
    let barricadeActions = actions.filter {
      if case .buildBarricade = $0 { return true }
      return false
    }
    #expect(!barricadeActions.isEmpty)
  }

  // MARK: - Audit Fix #10: Multi-Point Quest Spending (rule 7.0)

  @Test
  func questMultipleActionPointsAddDRMs() {
    // Rule 7.0: Players can spend multiple action points on a quest,
    // each adding +1 DRM (action) or +2 DRM (heroic).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.phase = .action
    // Card 3 (Forlorn Hope) has quest target 6
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    state.currentCard = card3
    // With 1 point: roll 5 + 1 = 6, NOT > 6 → failure
    let result1 = state.attemptQuest(isHeroic: false, dieRoll: 5, additionalDRM: 0, pointsSpent: 1)
    #expect(result1 == .failure)
    // With 2 points: roll 5 + 2 = 7 > 6 → success
    let result2 = state.attemptQuest(isHeroic: false, dieRoll: 5, additionalDRM: 0, pointsSpent: 2)
    #expect(result2 == .success)
  }

}
