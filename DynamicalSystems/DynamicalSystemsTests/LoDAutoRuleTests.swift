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
    #expect(state.phase == .action)
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

  // MARK: - Quest Reward Forfeit

  @Test
  func questRewardForfeitWhenNoDeadHeroes() {
    // Card 10 quest reward page (Last Ditch Efforts): return a dead hero.
    // If no heroes are dead, the auto-rule should clear questRewardPending
    // when it fires after a reduce.
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    var state = game.newState()
    state.phase = .action
    state.currentCard = LoD.dayCards.first { $0.number == 10 }
    state.snapshotActionBudget = 3
    state.questRewardPending = true
    #expect(state.heroDead.isEmpty)
    #expect(state.isInSubResolution)

    // Auto-rules fire in reduce(), not allowedActions(). Dispatch skipEvent
    // (no page handles it from .action phase) to trigger auto-rule scan.
    _ = game.reduce(into: &state, action: .skipEvent)
    #expect(!state.questRewardPending, "Auto-rule should have cleared questRewardPending")
    #expect(!state.isInSubResolution)
    let actions = game.allowedActions(state: state)
    #expect(!actions.isEmpty, "Normal actions should be available after forfeit")
    #expect(actions.contains(.endPlayerTurn))
  }

  @Test
  func questRewardNotForfeitWhenDeadHeroExists() {
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    var state = game.newState()
    state.phase = .action
    state.currentCard = LoD.dayCards.first { $0.number == 10 }
    state.snapshotActionBudget = 3
    state.questRewardPending = true
    state.heroDead = [.warrior]

    let actions = game.allowedActions(state: state)
    #expect(state.questRewardPending, "Should stay pending when hero is dead")
    #expect(actions.contains(.lastDitchEfforts(.warrior)))
  }

  // MARK: - Bug Reproduction: Card 16 Empty Actions

  @Test
  func card16LamentationThenHeroicHasActions() {
    let card16 = LoD.dayCards.first { $0.number == 16 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card16],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .lamentationOfWomen)
    state.heroWounded = [.warrior, .wizard, .cleric]
    _ = game.reduce(into: &state, action: .heroic(.moveHero(.warrior, .onTrack(.east))))

    let actions = game.allowedActions(state: state)
    #expect(!actions.isEmpty, "Should have actions after heroic on card 16")
    #expect(actions.contains(.endPlayerTurn))
    #expect(state.phase == .action)
    #expect(!state.isInSubResolution)
  }

  @Test
  func fullGameRolloutDoesNotDeadlock() {
    // Run 200 full random games to find any empty-actions deadlocks
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    for rollout in 0..<200 {
      var state = game.newState()
      for step in 0..<500 {
        if game.isTerminal(state: state) { break }
        let actions = game.allowedActions(state: state)
        if actions.isEmpty {
          Issue.record("""
            Empty actions at game \(rollout), step \(step):
            phase=\(state.phase), ended=\(state.ended),
            isInSubResolution=\(state.isInSubResolution),
            chainLightning=\(state.chainLightningState != nil),
            fortune=\(state.fortuneState != nil),
            deathAndDespair=\(state.deathAndDespairState != nil),
            pendingBB=\(state.pendingBloodyBattleChoices != nil),
            questRewardPending=\(state.questRewardPending),
            card=\(state.currentCard?.number ?? -1),
            last5=\(state.history.suffix(5))
            """)
          break
        }
        let action = actions.randomElement()!
        _ = game.reduce(into: &state, action: action)
      }
    }
  }

  @Test
  func mctsStressTestFromVariousStates() throws {
    // Run MCTS from 10 different random game states
    for trial in 0..<10 {
      let game = LoD.composedGame(windsOfMagicArcane: 3)
      var state = game.newState()
      // Play random actions to reach a mid-game state
      let targetSteps = 20 + trial * 5
      for _ in 0..<targetSteps {
        if game.isTerminal(state: state) { break }
        let actions = game.allowedActions(state: state)
        guard !actions.isEmpty else { break }
        _ = game.reduce(into: &state, action: actions.randomElement()!)
      }
      guard !game.isTerminal(state: state) else { continue }
      // Run MCTS from this mid-game state
      let mcts = OpenLoopMCTS(state: state, reducer: game)
      let result = try mcts.recommendation(iters: 200, numRollouts: 1)
      #expect(!result.isEmpty, "Trial \(trial): MCTS should produce recommendations")
    }
  }
}
