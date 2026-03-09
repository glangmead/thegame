//
//  MalayanCampaignTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/9/26.
//

import Testing

@MainActor
struct MalayanCampaignTests {

  // MARK: - Deterministic Analysis

  /// Verify the advantage calculation matches expectations for key matchups.
  @Test
  func testAdvantageCalculation() {
    // Str 2 vs str 3: 3 >= 6? No. 3 > 2? Yes → Japanese
    #expect(MalayanCampaign.advantage(alliedStrength: .two, japaneseStrength: .three) == .japanese)
    // Str 4 vs str 5: 5 >= 12? No. 5 > 4? Yes → Japanese
    #expect(MalayanCampaign.advantage(alliedStrength: .four, japaneseStrength: .five) == .japanese)
    // Equal str 3 vs 3: 3 >= 9? No. 3 > 3? No → AlliedOrNone
    #expect(MalayanCampaign.advantage(alliedStrength: .three, japaneseStrength: .three) == .alliedOrNone)
    // Str 1 vs Str 4 (after reinforcement): 4 >= 3? Yes → Decisive
    #expect(MalayanCampaign.advantage(alliedStrength: .one, japaneseStrength: .four) == .japaneseDecisive)
  }

  /// Check that the defend CRT always kills a str-1 unit against Decisive advantage.
  @Test
  func testDefendCRTAlwaysKillsStr1VsDecisive() {
    let mc = MalayanCampaign()
    for roll in DSix.allFaces() {
      let (allyHit, _) = mc.defendCRT.result(.japaneseDecisive, roll)
      // Minimum allied hit is 2 for Decisive, which kills a str-1 unit
      #expect(allyHit.rawValue >= 2, "Defend: roll \(roll) should deal >= 2 to allies vs Decisive, got \(allyHit.rawValue)")
    }
  }

  /// Check that counterattack CRT always kills a str-1 unit against Decisive advantage.
  @Test
  func testCounterattackCRTAlwaysKillsStr1VsDecisive() {
    let mc = MalayanCampaign()
    for roll in DSix.allFaces() {
      let (allyHit, _) = mc.counterattackCRT.result(.japaneseDecisive, roll)
      #expect(allyHit.rawValue >= 3, "Counterattack: roll \(roll) should deal >= 3 to allies vs Decisive, got \(allyHit.rawValue)")
    }
  }

  // MARK: - Game Flow Diagnostics

  /// Play N games with random action selection and report statistics.
  /// This diagnoses whether the game ends too quickly or always loses.
  @Test
  func testMCRandomGameStatistics() {
    let game = MCPages.game()
    let numGames = 50
    var wins = 0
    var losses = 0
    var turnCounts = [Int]()
    var actionCounts = [Int]()
    var deadlocks = 0
    var endauLosses = 0
    var turnLimitLosses = 0

    for _ in 0..<numGames {
      var state = game.newState()
      _ = game.reduce(into: &state, action: .initialize)
      var actionCount = 1
      let maxActions = 200

      while !state.ended && actionCount < maxActions {
        let actions = game.allowedActions(state: state)
        if actions.isEmpty {
          deadlocks += 1
          break
        }
        let action = actions.randomElement()!
        _ = game.reduce(into: &state, action: action)
        actionCount += 1
      }

      if state.endedInVictoryFor.isNonEmpty { wins += 1 }
      if state.endedInDefeatFor.isNonEmpty {
        losses += 1
        // Identify loss reason
        if state.japaneseAt(.endau) != nil && state.alliesAt(.endau).isEmpty {
          endauLosses += 1
        } else if state.turnNumber > 6 {
          turnLimitLosses += 1
        }
      }
      turnCounts.append(state.turnNumber)
      actionCounts.append(actionCount)
    }

    let avgTurns = Double(turnCounts.reduce(0, +)) / Double(numGames)

    let histogram = Dictionary(grouping: turnCounts, by: { $0 }).mapValues(\.count).sorted(by: { $0.key < $1.key })

    #expect(deadlocks == 0, "No deadlocks should occur")
    #expect(wins + losses == numGames, "Every game should end in win or loss")
  }

  /// Play a single game step-by-step, logging every action, to trace game flow.
  @Test
  func testMCSingleGameTrace() {
    let game = MCPages.game()
    var state = game.newState()
    _ = game.reduce(into: &state, action: .initialize)
    var log = "=== Malayan Campaign Single Game Trace ===\n"
    log += "After setup: \(state)\n"

    var actionCount = 0
    let maxActions = 200

    while !state.ended && actionCount < maxActions {
      let actions = game.allowedActions(state: state)
      if actions.isEmpty {
        log += "DEADLOCK at action \(actionCount), phase: \(state.phase.name), turn: \(state.turnNumber)\n"
        Issue.record("Deadlock: no actions available")
        return
      }

      let action = actions.randomElement()!
      let logs = game.reduce(into: &state, action: action)
      actionCount += 1

      switch action {
      case .setPhase(let phase):
        log += "  -> Phase: \(phase.name)\n"
      case .withdraw(let piece):
        log += "  Withdraw \(piece.shortName)\n"
      case .japaneseAdvance(let piece):
        log += "  Advance \(piece.shortName)\n"
        for l in logs { log += "    \(l.msg)\n" }
      case .counterattack(let piece), .defend(let piece):
        let verb = action.description.hasPrefix("Counter") ? "Counterattack" : "Defend"
        log += "  \(verb) \(piece.shortName)\n"
        for l in logs { log += "    \(l.msg)\n" }
      case .advanceTurn:
        log += "--- Turn \(state.turnNumber) ---\n"
        log += "  State: \(state)\n"
      case .claimVictory:
        log += "*** VICTORY on turn \(state.turnNumber) ***\n"
      case .declareLoss:
        log += "*** LOSS on turn \(state.turnNumber) ***\n"
        log += "  Final state: \(state)\n"
      default:
        break
      }
    }

    #expect(state.ended, "Game should have ended within \(maxActions) actions")
  }

  /// Test that the ForEachPage empty-items fix works: if no battles exist,
  /// the battle phase should auto-transition to air support.
  @Test
  func testBattlePhaseAutoTransitionsWhenNoBattles() {
    let game = MCPages.game()
    var state = game.newState()
    _ = game.reduce(into: &state, action: .initialize)

    // Manually set up a state where Japanese and allies don't share any location
    state.position[.japTrunk] = .at(.jitra)
    state.position[.japEastern] = .at(.kotaBharu)
    // Move allies away from Japanese
    state.position[.ally1] = .at(.kampar)
    state.position[.ally2] = .offBoard
    state.strength.removeValue(forKey: .ally2)

    // Force into battle phase
    state.phase = .battle
    state.history.append(.setPhase(.battle))

    let actions = game.allowedActions(state: state)
    // Should offer the transition action since no allies share location with Japanese
    #expect(!actions.isEmpty, "Battle phase with no battles should not deadlock")
  }

  /// Test that Allied Withdrawal with no candidates auto-skips.
  @Test
  func testWithdrawalAutoSkipsWhenNoCandidates() {
    let game = MCPages.game()
    var state = game.newState()
    _ = game.reduce(into: &state, action: .initialize)

    // Move Japanese away from all allies (ensure no overlap)
    state.position[.japTrunk] = .at(.jitra)
    state.position[.japEastern] = .at(.kotaBharu)
    // Move allies to locations without Japanese
    state.position[.ally1] = .at(.kampar)
    state.position[.ally2] = .offBoard
    state.strength.removeValue(forKey: .ally2)
    state.position[.ally3] = .at(.kampar)
    state.position[.ally4] = .at(.kuantan)
    state.position[.ally5] = .at(.kualaLumpur)
    state.position[.ally6] = .at(.endau)
    state.position[.ally7] = .at(.kluang)

    // Force into withdrawal phase
    state.phase = .alliedWithdrawal
    state.history.append(.setPhase(.alliedWithdrawal))

    let actions = game.allowedActions(state: state)
    #expect(actions.contains(.skipWithdrawal), "Withdrawal with no candidates should offer skip")
  }
}
