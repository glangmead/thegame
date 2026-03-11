//
//  LoDSpecialRulesTests.swift
//  DynamicalSystems
//
//  Tests for LoD special rules: Last Ditch Efforts,
//  Paladin Re-roll Tracking, Bloody Battle Cost,
//  Heroic Attack DRM, Ranger Quest DRM, Rogue Build DRM,
//  Rogue Free Move, Magic Items, Acid Upgrade, Paladin Re-roll.
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
    let archersPosBefore = state.defenderPosition[.archers]!

    // Melee attack on east, choosing to lose an archer for bloody battle
    _ = game.reduce(
      into: &state,
      action: .combat(.meleeAttack(
        .east, dieRoll: 6,
        bloodyBattleDefender: .archers, useMagicSword: nil)))
    #expect(state.defenderPosition[.archers] == archersPosBefore + 1)
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
    let archersPosBefore = state.defenderPosition[.archers]!

    // First attack — costs a defender
    _ = game.reduce(
      into: &state,
      action: .combat(.meleeAttack(
        .east, dieRoll: 6,
        bloodyBattleDefender: .archers, useMagicSword: nil)))
    #expect(state.defenderPosition[.archers] == archersPosBefore + 1)

    // Second attack — no additional cost (nil defender)
    _ = game.reduce(
      into: &state,
      action: .combat(.meleeAttack(
        .east, dieRoll: 6,
        bloodyBattleDefender: nil, useMagicSword: nil)))
    #expect(state.defenderPosition[.archers] == archersPosBefore + 1) // unchanged
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
    let maaValueBefore = state.defenderValue(for: .menAtArms)

    // Attack west (not marked) — no bloody battle cost
    _ = game.reduce(
      into: &state,
      action: .combat(.meleeAttack(
        .west, dieRoll: 6,
        bloodyBattleDefender: nil, useMagicSword: nil)))
    #expect(state.defenderValue(for: .menAtArms) == maaValueBefore)
  }

}
