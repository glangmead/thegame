//
//  MCPages.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

// swiftlint:disable:next type_body_length
enum MCPages {
  static let gameName = "Battle Card: Malayan Campaign"
  static func setupPage() -> RulePage<MalayanCampaign.State, MalayanCampaign.Action> {
    RulePage(
      name: "Setup",
      rules: [
        GameRule(
          condition: { $0.phase == .setup },
          actions: { _ in [.initialize] }
        )
      ],
      reduce: { state, action in
        guard action == .initialize else { return nil }
        state.player = .solo
        state.players = [.solo]
        state.ended = false
        // Allied setup: one anonymous unit per location (strengths from map pips)
        state.position[.ally1] = .at(.jitra)
        state.position[.ally2] = .at(.kotaBharu)
        state.position[.ally3] = .at(.kampar)
        state.position[.ally4] = .at(.kuantan)
        state.position[.ally5] = .at(.kualaLumpur)
        state.position[.ally6] = .at(.endau)
        state.position[.ally7] = .at(.kluang)
        state.strength[.ally1] = .four
        state.strength[.ally2] = .two
        state.strength[.ally3] = .two
        state.strength[.ally4] = .two
        state.strength[.ally5] = .two
        state.strength[.ally6] = .two
        state.strength[.ally7] = .two
        // Japanese setup
        state.position[.japTrunk]   = .at(.jitra)
        state.position[.japEastern] = .at(.kotaBharu)
        state.strength[.japTrunk]   = .six
        state.strength[.japEastern] = .six
        return ([], [.setPhase(.alliedWithdrawal)])
      }
    )
  }

  static func alliedWithdrawalPage() -> BudgetedPhasePage<MalayanCampaign.State, MalayanCampaign.Piece> {
    BudgetedPhasePage(
      name: "Allied Withdrawal",
      budget: .atMost(1),
      isActive: { $0.phase == .alliedWithdrawal },
      items: { state in
        // Can withdraw any allied unit that shares a location with a Japanese unit
        state.alliesOnBoard.filter { ally in
          guard let loc = state.location(of: ally) else { return false }
          return state.japaneseAt(loc) != nil && state.nextWithdrawalLocation(for: ally) != nil
        }
      },
      actionsFor: { _, piece in [.withdraw(piece)] },
      itemFrom: { action in
        if case .withdraw(let piece) = action { return piece }
        return nil
      },
      transitionAction: .setPhase(.japaneseAdvance),
      passAction: .skipWithdrawal,
      isPhaseEntry: { action in
        if case .setPhase(.alliedWithdrawal) = action { return true }
        return false
      },
      reduce: { state, action in
        switch action {
        case .withdraw(let piece):
          var logs = [Log]()
          guard let dest = state.nextWithdrawalLocation(for: piece) else { return nil }
          // Reduce strength by 1
          state.strength[piece] = DSix.minus(state.strength[piece]!, DSix.one, clamp: false)
          if state.strength[piece] == .none {
            state.removePiece(piece)
            logs.append(Log(msg: "\(piece) eliminated during withdrawal"))
            return (logs, [])
          }
          // Move toward Singapore
          state.position[piece] = .at(dest)
          logs.append(Log(msg: "\(piece) withdraws to \(dest)"))
          // Sum with any allied unit already there, discard one
          let alliesAtDest = state.alliesAt(dest).filter { $0 != piece }
          if let existing = alliesAtDest.first {
            state.strength[existing] = DSix.sum(state.strength[existing]!, state.strength[piece]!)
            state.removePiece(piece)
            logs.append(Log(msg: "\(piece) merges into \(existing) (str \(state.strength[existing]!.rawValue))"))
          }
          return (logs, [])
        case .skipWithdrawal:
          return ([Log(msg: "No withdrawal this turn")], [])
        default:
          return nil
        }
      }
    )
  }

  static func japaneseAdvancePage() -> ForEachPage<MalayanCampaign.State, MalayanCampaign.Piece> {
    ForEachPage(
      name: "Japanese Advance",
      isActive: { $0.phase == .japaneseAdvance },
      items: { state in state.japaneseOnBoard },
      actionsFor: { _, piece in [.japaneseAdvance(piece)] },
      itemFrom: { action in
        if case .japaneseAdvance(let piece) = action { return piece }
        return nil
      },
      transitionAction: .setPhase(.battle),
      isPhaseEntry: { action in
        if case .setPhase(.japaneseAdvance) = action { return true }
        return false
      },
      reduce: { state, action in
        guard case .japaneseAdvance(let jap) = action else { return nil }
        var logs = [Log]()
        guard let loc = state.location(of: jap) else { return (logs, []) }

        // Only advance if no allied unit at current location
        if !state.alliesAt(loc).isEmpty {
          logs.append(Log(msg: "\(jap) blocked by allies at \(loc)"))
          return (logs, [])
        }

        // Advance along road until hitting an allied unit or Singapore
        var currentLoc = loc
        while true {
          guard let nextLoc = state.nextLocationTowardSingapore(for: jap) else { break }
          // Check reinforcements at the location we're entering
          if let reinforce = MalayanCampaignComponents.Location.reinforcements[nextLoc] {
            state.strength[jap] = DSix.sum(state.strength[jap]!, DSix(rawValue: reinforce)!)
            logs.append(Log(msg: "\(jap) reinforced +\(reinforce) at \(nextLoc)"))
          }
          state.position[jap] = .at(nextLoc)
          currentLoc = nextLoc
          logs.append(Log(msg: "\(jap) advances to \(nextLoc)"))
          // Stop if there's an allied unit here
          if !state.alliesAt(nextLoc).isEmpty { break }
          // Stop if we reached Singapore (shouldn't normally happen with allies there)
          if nextLoc == .singapore { break }
        }
        return (logs, [])
      }
    )
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  static func battlePage() -> ForEachPage<MalayanCampaign.State, MalayanCampaign.Piece> {
    ForEachPage(
      name: "Battle",
      isActive: { $0.phase == .battle },
      items: { state in
        // Allied units that share a location with a Japanese unit
        state.alliesOnBoard.filter { ally in
          guard let loc = state.location(of: ally) else { return false }
          return state.japaneseAt(loc) != nil
        }
      },
      actionsFor: { _, piece in
        [.counterattack(piece), .defend(piece)]
      },
      itemFrom: { action in
        switch action {
        case .counterattack(let piece), .defend(let piece): return piece
        default: return nil
        }
      },
      transitionAction: .setPhase(.airSupport),
      isPhaseEntry: { action in
        if case .setPhase(.battle) = action { return true }
        return false
      },
      reduce: { state, action in
        let campaign = MalayanCampaign()
        var logs = [Log]()
        switch action {
        case .counterattack(let ally):
          guard let loc = state.location(of: ally),
                let jap = state.japaneseAt(loc) else { return nil }
          let adv = MalayanCampaign.advantage(
            alliedStrength: state.strength[ally]!,
            japaneseStrength: state.strength[jap]!
          )
          let roll = DSix.roll()
          let (allyHit, japHit) = campaign.counterattackCRT.result(adv, roll)
          state.strength[ally] = DSix.minus(state.strength[ally]!, allyHit, clamp: false)
          state.strength[jap]  = DSix.minus(state.strength[jap]!, japHit, clamp: false)
          logs.append(Log(msg: "Counterattack at \(loc): rolled \(roll.rawValue), " +
            "-\(allyHit.rawValue) allied, -\(japHit.rawValue) japanese"))
          // Eliminate if reduced below 1
          if state.strength[ally]?.rawValue ?? 0 < 1 {
            state.removePiece(ally)
            logs.append(Log(msg: "\(ally) eliminated"))
          }
          if state.strength[jap]?.rawValue ?? 0 < 1 {
            state.removePiece(jap)
            logs.append(Log(msg: "\(jap) eliminated"))
          }
        case .defend(let ally):
          guard let loc = state.location(of: ally),
                let jap = state.japaneseAt(loc) else { return nil }
          let adv = MalayanCampaign.advantage(
            alliedStrength: state.strength[ally]!,
            japaneseStrength: state.strength[jap]!
          )
          let roll = DSix.roll()
          let (allyHit, japHit) = campaign.defendCRT.result(adv, roll)
          state.strength[ally] = DSix.minus(state.strength[ally]!, allyHit, clamp: false)
          state.strength[jap]  = DSix.minus(state.strength[jap]!, japHit, clamp: false)
          logs.append(Log(msg: "Defend at \(loc): rolled \(roll.rawValue), " +
            "-\(allyHit.rawValue) allied, -\(japHit.rawValue) japanese"))
          if state.strength[ally]?.rawValue ?? 0 < 1 {
            state.removePiece(ally)
            logs.append(Log(msg: "\(ally) eliminated"))
          }
          if state.strength[jap]?.rawValue ?? 0 < 1 {
            state.removePiece(jap)
            logs.append(Log(msg: "\(jap) eliminated"))
          }
        default:
          return nil
        }
        return (logs, [])
      }
    )
  }

  static func airSupportPage() -> RulePage<MalayanCampaign.State, MalayanCampaign.Action> {
    RulePage(
      name: "Air Support",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .airSupport &&
            state.alliesAt(.kuantan).first != nil &&
            !state.japaneseOnBoard.isEmpty
          },
          actions: { _ in [.airSupport] }
        ),
        GameRule(
          condition: { $0.phase == .airSupport },
          actions: { _ in [.skipAirSupport] }
        )
      ],
      reduce: { state, action in
        switch action {
        case .airSupport:
          var logs = [Log]()
          // Subtract 1 from one Japanese unit
          if let jap = state.japaneseOnBoard.first {
            state.strength[jap] = DSix.minus(state.strength[jap]!, DSix.one, clamp: false)
            logs.append(Log(msg: "Air support: -1 to \(jap)"))
            if state.strength[jap]?.rawValue ?? 0 < 1 {
              state.removePiece(jap)
              logs.append(Log(msg: "\(jap) eliminated by air support"))
            }
          }
          return (logs, [.advanceTurn, .setPhase(.alliedWithdrawal)])
        case .skipAirSupport:
          return ([Log(msg: "No air support available")], [.advanceTurn, .setPhase(.alliedWithdrawal)])
        case .advanceTurn:
          state.turnNumber += 1
          return ([Log(msg: "Turn \(state.turnNumber)")], [])
        default:
          return nil
        }
      }
    )
  }

  static func victoryPage() -> RulePage<MalayanCampaign.State, MalayanCampaign.Action> {
    RulePage(
      name: "Victory",
      rules: [
        // Win: Allied unit of strength 3+ at Singapore
        GameRule(
          condition: { state in
            state.alliesAt(.singapore).contains(where: { ally in
              (state.strength[ally]?.rawValue ?? 0) >= 3
            })
          },
          actions: { _ in [.claimVictory] }
        ),
        // Win: All Japanese eliminated
        GameRule(
          condition: { $0.japaneseOnBoard.isEmpty && $0.phase != .setup },
          actions: { _ in [.claimVictory] }
        )
      ],
      reduce: { state, action in
        guard case .claimVictory = action else { return nil }
        state.ended = true
        state.endedInVictoryFor = [state.player]
        return ([Log(msg: "Victory!")], [])
      }
    )
  }

  static func lossPage() -> RulePage<MalayanCampaign.State, MalayanCampaign.Action> {
    RulePage(
      name: "Loss",
      rules: [
        // Lose: Endau has only Japanese (no allies)
        GameRule(
          condition: { state in
            state.japaneseAt(.endau) != nil && state.alliesAt(.endau).isEmpty &&
            state.phase != .setup
          },
          actions: { _ in [.declareLoss] }
        ),
        // Lose: Turn exceeds 6
        GameRule(
          condition: { $0.turnNumber > 6 },
          actions: { _ in [.declareLoss] }
        )
      ],
      reduce: { state, action in
        guard case .declareLoss = action else { return nil }
        state.ended = true
        state.endedInDefeatFor = [state.player]
        state.endedInVictoryFor = []
        return ([Log(msg: "Defeat!")], [])
      }
    )
  }

  // MARK: - MCTS State Evaluator

  /// Graduated evaluation: victory = 1.0, defeat scaled by how far the
  /// least-advanced Japanese unit progressed toward Singapore.
  private static func mcStateEvaluator(_ state: MalayanCampaign.State) -> Float {
    if state.endedInVictoryFor.contains(.solo) { return 1.0 }
    let trunk = japaneseProgress(state, piece: .japTrunk,
                                 road: MalayanCampaignComponents.trunkRoad)
    let eastern = japaneseProgress(state, piece: .japEastern,
                                   road: MalayanCampaignComponents.easternRoad)
    let leastProgress = min(trunk, eastern)
    if state.endedInDefeatFor.contains(.solo) {
      return 0.5 * leastProgress
    }
    // Non-terminal (rollout hit max depth)
    return 0.5 * leastProgress + 0.25
  }

  private static func japaneseProgress(
    _ state: MalayanCampaign.State,
    piece: MalayanCampaignComponents.Piece,
    road: [MalayanCampaignComponents.Location]
  ) -> Float {
    guard let loc = state.location(of: piece),
          let idx = road.firstIndex(of: loc) else { return 0 }
    return Float(idx) / Float(road.count - 1)
  }

  static func game() -> ComposedGame<MalayanCampaign.State> {
    oapply(
      gameName: gameName,
      pages: [
        setupPage(),
        alliedWithdrawalPage().asRulePage(),
        japaneseAdvancePage().asRulePage(),
        battlePage().asRulePage(),
        airSupportPage()
      ],
      priorities: [
        victoryPage(),
        lossPage()
      ],
      initialState: {
        var state = MalayanCampaign.State()
        state.history = [.setPhase(.setup)]
        return state
      },
      isTerminal: { $0.ended },
      phaseForAction: { action in
        if case .setPhase(let phase) = action { return phase }
        return nil
      },
      stateEvaluator: mcStateEvaluator
    )
  }
}
