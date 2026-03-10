//
//  LoDSpecialRulesTests.swift
//  DynamicalSystems
//
//  Tests for LoD special rules: Last Ditch Efforts, Paladin Re-roll Tracking, Bloody Battle Cost, Heroic Attack DRM, Ranger Quest DRM, Rogue Build DRM, Rogue Free Move, Magic Items, Acid Upgrade, Paladin Re-roll.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDSpecialRulesTests {

  // MARK: - Last Ditch Efforts Penalty

  @Test
  func composedGameLastDitchPenalty() {
    // Card #10: Last Ditch Efforts quest. Penalty if not attempted: morale -1.
    let card10 = LoD.dayCards.first { $0.number == 10 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card10],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)

    // Skip quest — just pass actions and heroics
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.morale == .normal) // not yet penalized

    _ = game.reduce(into: &state, action: .passHeroics)
    // Housekeeping should apply penalty: morale lowered
    #expect(state.morale == .low)
  }

  // MARK: - Paladin Re-roll Tracking

  @Test
  func paladinRerollTracking() {
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin]
    )

    // Paladin is alive and in play → can re-roll
    #expect(state.canPaladinReroll == true)

    // Use the re-roll
    state.usePaladinReroll()
    #expect(state.canPaladinReroll == false)

    // Reset at turn end
    state.resetTurnTracking()
    #expect(state.canPaladinReroll == true)
  }

  @Test
  func paladinRerollNotAvailableWhenDead() {
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin]
    )

    state.heroDead.insert(.paladin)
    #expect(state.canPaladinReroll == false)
  }

  // MARK: - Bloody Battle Cost in Composed Game (#6)

  @Test
  func bloodyBattleAttackCostsDefender() {
    // Attacking army with bloody battle marker loses a chosen defender.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .east
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.bloodyBattleArmy == .east)

    // East army at space 1 (melee range)
    state.armyPosition[.east] = 1
    let archersBefore = state.defenders[.archers]!

    // Melee attack on east, choosing to lose an archer for bloody battle
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: .archers, useMagicSword: nil))
    #expect(state.defenders[.archers] == archersBefore - 1)
  }

  @Test
  func bloodyBattleCostOnlyOncePerTurn() {
    // Second attack on same army same turn doesn't lose another defender.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .east
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.armyPosition[.east] = 1
    let archersBefore = state.defenders[.archers]!

    // First attack — costs a defender
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: .archers, useMagicSword: nil))
    #expect(state.defenders[.archers] == archersBefore - 1)

    // Second attack — no additional cost (nil defender)
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.defenders[.archers] == archersBefore - 1) // unchanged
  }

  @Test
  func bloodyBattleNoEffectOnOtherArmies() {
    // Attacking non-marked army doesn't cost a defender.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .east
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.armyPosition[.west] = 1
    let maaBeforе = state.defenders[.menAtArms]!

    // Attack west (not marked) — no bloody battle cost
    _ = game.reduce(into: &state, action: .meleeAttack(.west, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.defenders[.menAtArms] == maaBeforе)
  }

  // MARK: - Heroic Attack DRM from Cards (#8, rule 7.0)

  @Test
  func heroicAttackAppliesCardDRM() {
    // Card with heroicDRM for attack +1 → heroic attack should include it.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)
    // Use a card that has heroicDRMs for attacks
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 2, heroics: 1,
      actionDRMs: [], heroicDRMs: [LoD.CardDRM(action: .attack, track: nil, value: 1)],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    state.currentCard = card

    let drm = state.totalHeroicAttackDRM(hero: .warrior, slot: .east)
    // Warrior combatDRM (2) + card heroicDRM attack (1) + inspire (0) = 3
    #expect(drm == 3)
  }

  @Test
  func heroicAttackCardDRMTrackSpecific() {
    // Card heroicDRM restricted to east track doesn't apply to west.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.west)
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 2, heroics: 1,
      actionDRMs: [], heroicDRMs: [LoD.CardDRM(action: .attack, track: .east, value: 2)],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    state.currentCard = card

    let drm = state.totalHeroicAttackDRM(hero: .warrior, slot: .west)
    // Warrior combatDRM (2) + card heroicDRM (0, wrong track) = 2
    #expect(drm == 2)
  }

  // MARK: - Ranger Quest DRM (rule 10.3)

  @Test
  func rangerQuestDRM() {
    // Ranger alive → +1 quest DRM. Dead → 0.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .ranger]
    )
    #expect(state.questDRM() == 1)

    state.heroDead.insert(.ranger)
    #expect(state.questDRM() == 0)
  }

  @Test
  func rangerQuestDRMNotInPlay() {
    // Ranger not in hero roster → 0.
    let state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.questDRM() == 0)
  }

  // MARK: - Rogue Build DRM (rule 10.4)

  @Test
  func rogueBuildDRM() {
    // Rogue alive → totalBuildDRM includes +1.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue]
    )
    // No card DRMs, no inspire → just Rogue +1
    #expect(state.totalBuildDRM() == 1)
  }

  @Test
  func rogueBuildDRMNotWhenDead() {
    // Rogue dead → no build bonus.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue]
    )
    state.heroDead.insert(.rogue)
    #expect(state.totalBuildDRM() == 0)
  }

  // MARK: - Rogue Free Move (rule 10.4)

  @Test
  func rogueFreeMoveOfferedInActionPhase() {
    // Rogue alive → rogueMove actions offered during action phase without costing action points.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let allowed = game.allowedActions(state: state)
    // Should include rogueMove options
    let rogueMoves = allowed.filter {
      if case .rogueMove = $0 { return true }
      return false
    }
    #expect(rogueMoves.count > 0)
  }

  @Test
  func rogueFreeMoveDoesNotCostActionPoint() {
    // Using rogueMove should not decrement the action budget.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let budgetBefore = state.actionBudgetRemaining
    _ = game.reduce(into: &state, action: .rogueMove(.onTrack(.east)))
    #expect(state.actionBudgetRemaining == budgetBefore) // No action consumed
    #expect(state.heroLocation[.rogue] == .onTrack(.east))
  }

  @Test
  func rogueFreeMoveNotOfferedWhenDead() {
    // Rogue dead → no rogueMove offered.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroDead.insert(.rogue)
    _ = game.reduce(into: &state, action: .drawCard)

    let allowed = game.allowedActions(state: state)
    let rogueMoves = allowed.filter {
      if case .rogueMove = $0 { return true }
      return false
    }
    #expect(rogueMoves.count == 0)
  }

  // MARK: - Magic Items (rule 9.2)

  @Test
  func magicSwordBeforeRollAdds2DRM() {
    // Magic Sword used before rolling gives +2 DRM to melee attack.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicSword = true
    state.armyPosition[.east] = 1 // melee range
    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 1 normally always fails. With +2 DRM from sword and card DRM:
    // Card 3 has attack DRM -1. So: roll 3 + (-1) + 2 = 4. Goblin str 2. 4 > 2 = hit.
    let eastPosBefore = state.armyPosition[.east]!
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: .before))
    // Should have hit — army retreated
    #expect(state.armyPosition[.east]! > eastPosBefore)
    // Sword consumed
    #expect(state.hasMagicSword == false)
  }

  @Test
  func magicSwordAfterRollAdds1DRM() {
    // Magic Sword used after seeing roll gives +1 DRM.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicSword = true
    state.armyPosition[.east] = 1

    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 3 + card DRM (-1) + sword after (+1) = 3. Goblin str 2. 3 > 2 = hit.
    let eastPosBefore = state.armyPosition[.east]!
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: .after))
    #expect(state.armyPosition[.east]! > eastPosBefore)
    #expect(state.hasMagicSword == false)
  }

  @Test
  func magicBowBeforeRollAdds2DRM() {
    // Magic Bow used before rolling gives +2 DRM to ranged attack.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicBow = true
    _ = game.reduce(into: &state, action: .drawCard)

    let eastPosBefore = state.armyPosition[.east]!
    // Roll 1 always fails regardless of DRM (natural 1 rule)
    // Use roll 2 instead: roll 2 + bow before (+2) = 4. Goblin str 2. 4 > 2 = hit.
    _ = game.reduce(into: &state, action: .rangedAttack(.east, dieRoll: 2, bloodyBattleDefender: nil, useMagicBow: .before))
    #expect(state.armyPosition[.east]! > eastPosBefore)
    #expect(state.hasMagicBow == false)
  }

  @Test
  func magicItemNotConsumedWhenNotHeld() {
    // Trying to use magic sword when not held: no bonus, no crash.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicSword = false
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 2 + card DRM (-1) + no sword = 1. 1 is natural fail anyway, but the point
    // is it shouldn't crash.
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 2, bloodyBattleDefender: nil, useMagicSword: .before))
    #expect(state.hasMagicSword == false)
  }

  // MARK: - Acid Upgrade Free Attack (rule 6.3)

  @Test
  func acidUpgradeFreeAttackOnAdvance() {
    // Army advancing to space 1 on acid-upgraded track gets a free ranged attack.
    // Test through composed game: inject acid die roll via advanceArmies action.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2  // Will advance to 1
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    // Manually invoke advanceArmies with acid die roll = 6 (goblin str 2, 6 > 2 = hit)
    _ = game.reduce(into: &state, action: .advanceArmies(acidAttackDieRolls: [.east: 6]))

    // After acid attack hit, army should be pushed back from 1 to 2
    #expect(state.armyPosition[.east]! == 2)
  }

  @Test
  func acidUpgradeNoAttackWithoutDieRoll() {
    // Army advancing to space 1 on acid track but no die roll provided → no attack.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    // advanceArmies with no acid die rolls
    _ = game.reduce(into: &state, action: .advanceArmies(acidAttackDieRolls: [:]))

    // Without die roll, army just stays at space 1 (no free attack)
    #expect(state.armyPosition[.east]! == 1)
  }

  @Test
  func acidUpgradeNoAttackOnOtherSpaces() {
    // Army advancing to space 3 (not 1) on acid track → no free attack.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 4  // Will advance to 3
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    _ = game.reduce(into: &state, action: .advanceArmies(acidAttackDieRolls: [.east: 6]))

    // Should just advance normally to space 3 — acid only triggers at space 1
    #expect(state.armyPosition[.east]! == 3)
  }

  // MARK: - Paladin Re-roll (rule 10.2)

  @Test
  func paladinRerollOfferedAfterDieRollAction() {
    // After a die-roll action with Paladin alive, game enters paladinReact
    // and offers reroll/decline.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1  // melee range
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Perform a melee attack — should enter paladinReact phase
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)

    let allowed = game.allowedActions(state: state)
    let hasReroll = allowed.contains(where: { if case .paladinReroll = $0 { return true }; return false })
    let hasDecline = allowed.contains(where: { if case .declineReroll = $0 { return true }; return false })
    #expect(hasReroll)
    #expect(hasDecline)
  }

  @Test
  func paladinDeclineResolvesOriginalAction() {
    // Declining the re-roll resolves the original attack normally and returns to action phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1  // melee range
    _ = game.reduce(into: &state, action: .drawCard)

    // Attack with roll 6: card 3 attack DRM -1, so 6 + (-1) = 5 > goblin str 2 → hit
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)
    // Army hasn't been pushed back yet (deferred)
    #expect(state.armyPosition[.east]! == 1)

    // Decline re-roll → resolve with original die roll 6
    _ = game.reduce(into: &state, action: .declineReroll)
    #expect(state.phase == .action)
    // Now army should be pushed back (hit resolved)
    #expect(state.armyPosition[.east]! == 2)
  }

  @Test
  func paladinRerollChangesResult() {
    // Re-rolling with a better die changes the attack result.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // Original roll 1 (natural 1 always fails). Army at space 1.
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 1, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)

    // Re-roll with 6: 6 + (-1) = 5 > 2 → hit
    _ = game.reduce(into: &state, action: .paladinReroll(newDieRoll: 6))
    #expect(state.phase == .action)
    #expect(state.armyPosition[.east]! == 2)  // pushed back
    #expect(state.paladinRerollUsed == true)
  }

  @Test
  func paladinRerollUsedOnlyOnce() {
    // After using re-roll, second die-roll action resolves immediately (no react phase).
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1
    state.armyPosition[.west] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // First attack: enters paladinReact
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)
    _ = game.reduce(into: &state, action: .paladinReroll(newDieRoll: 6))
    #expect(state.paladinRerollUsed == true)

    // Second attack: should resolve immediately, no paladinReact
    _ = game.reduce(into: &state, action: .meleeAttack(.west, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .action)  // stays in action, not paladinReact
  }

  @Test
  func paladinRerollNotOfferedWhenDead() {
    // Dead Paladin → action resolves immediately, no react phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroDead.insert(.paladin)
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .action)  // resolved immediately
    #expect(state.armyPosition[.east]! == 2)  // hit resolved
  }

  @Test
  func paladinRerollWorksInHeroicPhase() {
    // Paladin re-roll also works for heroic attacks.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroLocation[.paladin] = .onTrack(.east)
    state.armyPosition[.east] = 3
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)

    // Heroic attack: should enter paladinReact
    _ = game.reduce(into: &state, action: .heroicAttack(.paladin, .east, dieRoll: 1))
    #expect(state.phase == .paladinReact)

    // Re-roll with 6: paladin combatDRM = 1, so 6 + 1 = 7 > goblin str 2 → hit
    _ = game.reduce(into: &state, action: .paladinReroll(newDieRoll: 6))
    #expect(state.phase == .heroic)  // returns to heroic phase
    #expect(state.armyPosition[.east]! == 4)  // pushed back
  }

}
