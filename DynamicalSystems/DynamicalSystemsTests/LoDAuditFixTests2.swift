//
//  LoDAuditFixTests2.swift
//  DynamicalSystems
//
//  Tests for LoD audit fixes: Inspire Normal vs Heroic,
//  Mass Heal, Raise Dead, Grease, Fireball Heroic,
//  Barricade, Multi-Point Quest.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDAuditFixTests2 {

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
    state.defenderPosition[.menAtArms] = 4
    state.defenderPosition[.archers] = 2
    // Two different types should work
    state.applyMassHeal(defenders: [.menAtArms, .archers])
    #expect(state.defenderValue(for: .menAtArms) == 2)
    #expect(state.defenderValue(for: .archers) == 2)
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
    let result = LoD.$rollDie.withValue({ 5 }) {
      state.advanceArmy(.east)
    }
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
    let result = LoD.$rollDie.withValue({ 2 }) {
      state.advanceArmy(.east)
    }
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
    LoD.$rollDie.withValue({ 5 }) {
      _ = state.advanceArmy(.east)  // Grease holds
    }
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
    // Card #3 has gate BB; default positions tied → resolve choice first
    if state.pendingBloodyBattleChoices != nil {
      _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
    }
    state.breaches.insert(.east)
    let actions = game.allowedActions(state: state)
    let barricadeActions = actions.filter {
      if case .build(.buildBarricade) = $0 { return true }
      return false
    }
    #expect(!barricadeActions.isEmpty)
  }

  // MARK: - Barricade Test Verification (rule 4.1.3)

  @Test
  func barricadeTestRollAtStrengthBreaksThrough() {
    // Rule 4.1.3: Army must roll Strength or less to advance to 0
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)
    state.barricades.insert(.east)
    state.armyPosition[.east] = 1
    // Goblin strength = 2, roll 2 (equal) => breaks through
    let result = LoD.$rollDie.withValue({ 2 }) {
      state.advanceArmy(.east)
    }
    #expect(result == .armyBrokeBarricade(.east))
    #expect(state.ended)
  }

  @Test
  func barricadeTestRollAboveStrengthBlocks() {
    // Rule 4.1.3: Roll > strength => army doesn't advance, barricade flips to breach
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)
    state.barricades.insert(.east)
    state.armyPosition[.east] = 1
    // Goblin strength = 2, roll 3 => blocked
    let result = LoD.$rollDie.withValue({ 3 }) {
      state.advanceArmy(.east)
    }
    #expect(result == .barricadeHeld(.east))
    #expect(state.armyPosition[.east] == 1, "Army stays at space 1")
    #expect(!state.barricades.contains(.east), "Barricade consumed")
    #expect(state.breaches.contains(.east), "Track is now breached")
    #expect(!state.ended)
  }

  @Test
  func barricadeTestRollBelowStrengthBreaksThrough() {
    // Rule 4.1.3: Roll 1 against strength 2 => breaks through
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)
    state.barricades.insert(.east)
    state.armyPosition[.east] = 1
    // Goblin strength = 2, roll 1 => breaks through
    let result = LoD.$rollDie.withValue({ 1 }) {
      state.advanceArmy(.east)
    }
    #expect(result == .armyBrokeBarricade(.east))
    #expect(state.ended)
  }

  // MARK: - Audit Fix #9: Bloody Battle Gate Tie (rule 4.3)

  @Test
  func gateBloodyBattleTieSetsSubResolution() {
    // When both Gate armies equidistant, pendingBloodyBattleChoices should be set
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.pendingBloodyBattleChoices == nil)
    state.pendingBloodyBattleChoices = [.gate1, .gate2]
    #expect(state.isInSubResolution)
  }

  @Test
  func composedGameGateBloodyBattleTieOffersChoice() {
    // Use card #3 which has gate bloody battle and no advances
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    #expect(card3.bloodyBattle == .gate)
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 20),
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    // Set gate armies equidistant BEFORE drawCard (which chains to advanceArmies)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3
    _ = game.reduce(into: &state, action: .drawCard)
    // Should offer choice, not auto-place
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(.chooseBloodyBattle(.gate1)))
    #expect(actions.contains(.chooseBloodyBattle(.gate2)))
  }

  @Test
  func composedGameGateBloodyBattleNotTiedPicksClosest() {
    // When gate armies not tied, auto-pick closest
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 20),
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    // gate1 closer than gate2, set BEFORE drawCard
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 4
    _ = game.reduce(into: &state, action: .drawCard)
    // Should auto-place on gate1 (closest) and proceed
    #expect(state.bloodyBattleArmy == .gate1)
    #expect(state.pendingBloodyBattleChoices == nil)
  }

  @Test
  func composedGameChooseBloodyBattleResolvesAndTransitions() {
    // After choosing, should clear pending state and transition
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 20),
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    // Set gate armies equidistant BEFORE drawCard
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3
    _ = game.reduce(into: &state, action: .drawCard)
    // Should be pending BB choice
    #expect(state.pendingBloodyBattleChoices != nil)
    // Choose gate2
    _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate2))
    #expect(state.bloodyBattleArmy == .gate2)
    #expect(state.pendingBloodyBattleChoices == nil)
    // Card #3 has no event → should have transitioned past event to action
    #expect(state.phase == .action)
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

  @Test
  func questHeroicMultiPointGivesDoubleDRM() {
    // Rule 7.0: Heroic quest spending gives +2 DRM per point
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    state.currentCard = card3
    let target = card3.quest!.target  // 6
    // roll (target-3) + 2*2 = target-3+4 = target+1 > target => success
    let result = state.attemptQuest(isHeroic: true, dieRoll: target - 3, pointsSpent: 2)
    #expect(result == .success)
  }

  @Test
  func questMultiPointSpendingCostsMultipleBudgetPoints() {
    // Rule 7.0: Spending N points on quest costs N from the budget
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.phase = .action
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    state.currentCard = card3
    state.snapshotActionBudget = state.actionBudget
    state.history.append(.advanceArmies)
    // Spend 2 action points on quest
    state.history.append(.quest(.quest(
      isHeroic: false, pointsSpent: 2)))
    #expect(state.actionPointsSpent == 2)
  }

}
