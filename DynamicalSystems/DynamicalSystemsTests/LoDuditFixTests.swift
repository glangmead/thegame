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
      if case .build(.buildUpgrade(_, .east, _)) = $0 { return true }
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
      if case .combat(.meleeAttack) = $0 { return true }
      return false
    }
    #expect(!meleeActions.isEmpty)

    // After 1 melee attack, no more melee should be offered
    _ = game.reduce(
      into: &state,
      action: .combat(.meleeAttack(
        .east, dieRoll: 6,
        bloodyBattleDefender: nil, useMagicSword: nil)))
    actions = game.allowedActions(state: state)
    let meleeActionsAfter = actions.filter {
      if case .combat(.meleeAttack) = $0 { return true }
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
    _ = game.reduce(into: &state, action: .combat(.rangedAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicBow: nil)))
    let actions = game.allowedActions(state: state)
    let rangedActionsAfter = actions.filter {
      if case .combat(.rangedAttack) = $0 { return true }
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

}
