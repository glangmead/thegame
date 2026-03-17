//
//  LoDAutoRuleTests.swift
//  DynamicalSystems
//
//  Tests for LoD-specific auto-rules: bloody battle placement, gate tie, quest penalty.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDAutoRuleTests {

  // MARK: - Bloody Battle Marker Placement (non-gate, single army)

  @Test
  func bloodyBattlePlacedOnSingleArmy() {
    let card = LoD.Card(
      number: 99, file: "test", title: "Test BB",
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
    #expect(state.bloodyBattleArmy == .east)
    #expect(state.pendingBloodyBattleChoices == nil)
    #expect(state.phase == .action)
  }

  @Test
  func bloodyBattlePlacedOnCloserGateArmy() {
    let card = LoD.Card(
      number: 99, file: "test", title: "Test BB Gate",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .gate
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 4
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.bloodyBattleArmy == .gate1)
    #expect(state.pendingBloodyBattleChoices == nil)
  }

  // MARK: - Bloody Battle Gate Tie

  @Test
  func bloodyBattleGateTieSetsChoices() {
    let card = LoD.Card(
      number: 99, file: "test", title: "Test BB Tie",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .gate
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.bloodyBattleArmy == nil)
    #expect(state.pendingBloodyBattleChoices != nil)
    #expect(state.phase == .army)
    _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
    #expect(state.bloodyBattleArmy == .gate1)
    #expect(state.pendingBloodyBattleChoices == nil)
    #expect(state.phase == .action)
  }

  @Test
  func bloodyBattleGateTieWithEvent() {
    let card = LoD.Card(
      number: 99, file: "test", title: "Test BB Tie Event",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: LoD.CardEvent(title: "Test Event", text: "test"),
      quest: nil, time: 1, bloodyBattle: .gate
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .army)
    _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate2))
    #expect(state.bloodyBattleArmy == .gate2)
    #expect(state.phase == .event)
  }

  // MARK: - Quest Penalty Auto-Rule

  @Test
  func questPenaltyFiresExactlyOnce() {
    let card10 = LoD.dayCards.first { $0.number == 10 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card10],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.morale == .normal)
    _ = game.reduce(into: &state, action: .endPlayerTurn)
    #expect(state.morale == .low)
  }

  // MARK: - Budget Tracking After No-Event Card

  @Test
  func budgetTrackingWorksAfterNoEventCard() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.actionPointsSpent == 0)
    #expect(state.actionBudgetRemaining == state.snapshotActionBudget!)
  }

  // MARK: - Clearing

  @Test
  func bloodyBattleClearedOnNewTurn() {
    let card = LoD.Card(
      number: 99, file: "test", title: "Test BB Clear",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .east
    )
    let cardNoBB = LoD.Card(
      number: 98, file: "test", title: "No BB",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card, cardNoBB],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.bloodyBattleArmy == .east)
    _ = game.reduce(into: &state, action: .endPlayerTurn)
    #expect(state.bloodyBattleArmy == nil)
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.bloodyBattleArmy == nil)
  }

  // MARK: - Acid Free Melee Attack (GameRule)

  @Test
  func acidAttackOfferedWhenEligible() {
    // Army at space 2 on acid track, card advances east -> arrives space 1.
    // After drawCard, player should be offered .acidMeleeAttack(.east).
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Acid",
      deck: .day, advances: [.east], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2
    state.upgrades[.east] = .acid
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.acidEligibleSlots.contains(.east))
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(.acidMeleeAttack(.east)))
  }

  @Test
  func acidAttackResolvesAndPreventsSecondUse() {
    // Dispatch .acidMeleeAttack -> die roll resolves, acidUsedThisTurn set.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Acid",
      deck: .day, advances: [.east], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2
    state.upgrades[.east] = .acid
    _ = game.reduce(into: &state, action: .drawCard)

    let eastPosBefore = state.armyPosition[.east]!
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .acidMeleeAttack(.east))
    }
    // Hit: army retreated from space 1
    #expect(state.armyPosition[.east]! > eastPosBefore)
    #expect(state.acidUsedThisTurn)
    // No longer offered
    let actions = game.allowedActions(state: state)
    #expect(!actions.contains(.acidMeleeAttack(.east)))
  }

  @Test
  func acidAttackNotOfferedWhenArmyNotAtSpace1() {
    // Army at space 4, advances to 3. No acid offer.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Acid No",
      deck: .day, advances: [.east], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 4
    state.upgrades[.east] = .acid
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.acidEligibleSlots.isEmpty)
    let actions = game.allowedActions(state: state)
    #expect(!actions.contains(where: {
      if case .acidMeleeAttack = $0 { return true }
      return false
    }))
  }
}
