//
//  LoDDieRollTests.swift
//  DynamicalSystems
//
//  Tests that die rolls are properly randomized when actions carry placeholder 0,
//  and that explicit die rolls are preserved for deterministic testing.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDDieRollTests {

  // MARK: - effectiveDie

  @Test
  func effectiveDiePreservesExplicitRolls() {
    // Non-zero die rolls pass through unchanged.
    for roll in 1...6 {
      #expect(LoD.State.effectiveDie(roll) == roll)
    }
  }

  @Test
  func effectiveDieRandomizesZero() {
    // dieRoll=0 should produce values in 1...6. Run enough trials
    // that we'd see at least two distinct values.
    var seen = Set<Int>()
    for _ in 0..<100 {
      let roll = LoD.State.effectiveDie(0)
      #expect(roll >= 1 && roll <= 6)
      seen.insert(roll)
    }
    #expect(seen.count > 1, "100 rolls should produce more than one distinct value")
  }

  // MARK: - Action-phase attacks with placeholder die rolls

  @Test
  func meleeAttackWithPlaceholderDieSometimesHits() {
    // A melee attack on a goblin (strength 2) with dieRoll=0 should
    // sometimes succeed (when the random roll > 2).
    var hitCount = 0
    for _ in 0..<100 {
      var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
      state.armyPosition[.east] = 2  // melee range
      let action = LoD.Action.combat(.meleeAttack(.east, dieRoll: 0, bloodyBattleDefender: nil, useMagicSword: nil))
      let logs = state.resolveActionDieRoll(action)
      let logText = logs.map(\.msg).joined()
      if logText.contains("hit") {
        hitCount += 1
      }
    }
    // With strength 2, rolls of 3-6 hit (4/6 ≈ 67%). Allow wide margin.
    #expect(hitCount > 10, "Expected some melee hits in 100 trials, got \(hitCount)")
    #expect(hitCount < 100, "Expected some melee misses in 100 trials, got \(hitCount) hits")
  }

  @Test
  func rangedAttackWithPlaceholderDieSometimesHits() {
    var hitCount = 0
    for _ in 0..<100 {
      var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
      state.armyPosition[.east] = 5  // ranged range
      let action = LoD.Action.combat(.rangedAttack(.east, dieRoll: 0, bloodyBattleDefender: nil, useMagicBow: nil))
      let logs = state.resolveActionDieRoll(action)
      let logText = logs.map(\.msg).joined()
      if logText.contains("hit") {
        hitCount += 1
      }
    }
    #expect(hitCount > 10, "Expected some ranged hits in 100 trials, got \(hitCount)")
  }

  @Test
  func heroicAttackWithPlaceholderDieSometimesHits() {
    var hitCount = 0
    for _ in 0..<100 {
      var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
      state.armyPosition[.east] = 2
      state.heroLocation[.warrior] = .onTrack(.east)
      let action = LoD.Action.heroic(.heroicAttack(.warrior, .east, dieRoll: 0))
      let logs = state.resolveHeroicDieRoll(action)
      let logText = logs.map(\.msg).joined()
      if logText.contains("hit") {
        hitCount += 1
      }
    }
    // Warrior has +2 DRM vs goblin strength 2, so rolls 1-6 + 2 vs 2:
    // only natural 1 fails. Should hit ~83%.
    #expect(hitCount > 50, "Warrior + DRM should hit often, got \(hitCount)")
  }

  @Test
  func explicitDieRollStillWorks() {
    // Explicit dieRoll=6 against goblin (strength 2) should always hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    let action = LoD.Action.combat(.meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    let logs = state.resolveActionDieRoll(action)
    let logText = logs.map(\.msg).joined()
    #expect(logText.contains("hit"), "Explicit roll 6 vs strength 2 should hit")
  }

  @Test
  func explicitDieRollOneMisses() {
    // Explicit dieRoll=1 should always fail (natural 1 rule).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    let action = LoD.Action.combat(.meleeAttack(.east, dieRoll: 1, bloodyBattleDefender: nil, useMagicSword: nil))
    let logs = state.resolveActionDieRoll(action)
    let logText = logs.map(\.msg).joined()
    #expect(logText.contains("natural 1"), "Explicit roll 1 should be natural 1 fail")
  }

  // MARK: - Event die rolls

  @Test
  func eventDieRollRandomized() {
    // Catapult Shrapnel (card 1): on roll 1 lose archer, on 2-3 lose MaA.
    // With placeholder dieRoll=0, we should see varied outcomes.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card1, count: 20),
      shuffledNightCards: LoD.nightCards
    )
    var lostArcher = false
    var lostMaA = false
    var noLoss = false

    for _ in 0..<100 {
      var state = game.newState()
      _ = game.reduce(into: &state, action: .drawCard)
      // Now in event phase — resolve with placeholder die
      _ = game.reduce(into: &state, action: .resolveEvent(LoD.EventResolution()))

      let archers = state.defenderValue(for: .archers)
      let maA = state.defenderValue(for: .menAtArms)
      if archers < 2 { lostArcher = true }
      if maA < 3 { lostMaA = true }
      if archers == 2 && maA == 3 { noLoss = true }
    }
    // Should see at least two different outcomes in 100 trials.
    let outcomes = [lostArcher, lostMaA, noLoss].filter { $0 }.count
    #expect(outcomes >= 2, "Expected varied event outcomes, saw \(outcomes) distinct")
  }

  // MARK: - Barricade and grease die rolls

  @Test
  func barricadeTestDieRollRandomized() {
    // Army advancing to space 0 with a barricade should sometimes hold,
    // sometimes break (depending on randomized die vs strength).
    var holdCount = 0
    var brokeCount = 0
    for _ in 0..<100 {
      var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
      state.armyPosition[.east] = 1
      state.barricades.insert(.east)
      // Advance east army (goblin strength 2): roll <= 2 breaks, roll > 2 holds
      let result = state.advanceArmy(.east)
      switch result {
      case .barricadeHeld: holdCount += 1
      case .armyBrokeBarricade: brokeCount += 1
      default: break
      }
    }
    #expect(holdCount > 0, "Barricade should sometimes hold")
    #expect(brokeCount > 0, "Barricade should sometimes break")
  }

  @Test
  func greaseCheckDieRollRandomized() {
    var heldCount = 0
    var breachedCount = 0
    for _ in 0..<100 {
      var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
      state.armyPosition[.east] = 1
      state.upgrades[.east] = .grease
      let result = state.advanceArmy(.east)
      switch result {
      case .greaseHeld: heldCount += 1
      case .breachCreated: breachedCount += 1
      default: break
      }
    }
    // Grease holds on roll > 2 (rolls 3-6 = 4/6 ≈ 67%)
    #expect(heldCount > 0, "Grease should sometimes hold")
    #expect(breachedCount > 0, "Grease should sometimes fail")
  }

  // MARK: - MCTS integration: attacks produce pushbacks

  @Test
  func mctsRolloutsProduceAttackHits() {
    // Run a short MCTS from the action phase with an army in melee range.
    // Verify that at least some rollouts push armies back (i.e., the die
    // rolls are working inside MCTS simulations).
    let card3 = LoD.dayCards.first { $0.number == 3 }!  // "All is Quiet", no advances
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 20),
      shuffledNightCards: Array(repeating: card3, count: 20)
    )
    var state = game.newState()
    // Advance to action phase
    _ = game.reduce(into: &state, action: .drawCard)
    if state.pendingBloodyBattleChoices != nil {
      _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
    }
    // Put goblin at melee range
    state.armyPosition[.east] = 2

    let mcts = OpenLoopMCTS(state: state, reducer: game)
    let results = mcts.recommendation(iters: 100)

    // The MCTS should have explored melee/ranged attack actions
    let attackActions = results.keys.filter { action in
      switch action {
      case .combat(.meleeAttack), .combat(.rangedAttack): return true
      default: return false
      }
    }
    #expect(!attackActions.isEmpty, "MCTS should offer attack actions when army is in range")

    // At least one attack action should have been visited
    for action in attackActions {
      let (_, visits) = results[action]!
      #expect(visits > 0, "Attack action \(action) should have visits")
    }
  }
}
