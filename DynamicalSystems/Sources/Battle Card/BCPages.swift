//
//  BCPages.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Foundation

enum BCPages {
  static func setupPage() -> RulePage<BattleCard.State, BattleCard.Action> {
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
        state.position[.thirtycorps]     = BattleCard.Position.onTrack(0)
        state.position[.allied101st]     = BattleCard.Position.onTrack(1)
        state.position[.germanEindhoven] = BattleCard.Position.onTrack(1)
        state.position[.allied82nd]      = BattleCard.Position.onTrack(2)
        state.position[.germanGrave]     = BattleCard.Position.onTrack(2)
        state.position[.germanNijmegen]  = BattleCard.Position.onTrack(3)
        state.position[.allied1st]       = BattleCard.Position.onTrack(4)
        state.position[.germanArnhem]    = BattleCard.Position.onTrack(4)
        state.strength[.allied101st]     = DSix.six
        state.strength[.allied82nd]      = DSix.six
        state.strength[.allied1st]       = DSix.five
        state.strength[.germanEindhoven] = DSix.two
        state.strength[.germanGrave]     = DSix.two
        state.strength[.germanNijmegen]  = DSix.one
        state.strength[.germanArnhem]    = DSix.two
        state.control[1] = .germans
        state.control[2] = .germans
        state.control[3] = .germans
        state.control[4] = .germans
        state.weather = .fog
        return ([], [.setPhase(.airdrop)])
      }
    )
  }

  static func advanceAllyPage() -> RulePage<BattleCard.State, BattleCard.Action> {
    RulePage(
      name: "Advance ally",
      rules: [
        GameRule(
          condition: { state in
            state.phase == .advance &&
            state.cityPastXXXCorps != nil &&
            state.control[state.cityPastXXXCorps!] == .allies
          },
          actions: { _ in [.advance30Corps] }
        ),
        GameRule(
          condition: { state in
            state.phase == .advance
          },
          actions: { state in
            let corpsPos = state.position[.thirtycorps]!
            if let ally = state.allyIn(pos: corpsPos) {
              return [.advanceAllies(ally)]
            }
            return []
          }
        ),
        GameRule(
          condition: { state in
            state.phase == .advance &&
            state.cityPastXXXCorps != nil &&
            state.control[state.cityPastXXXCorps!] == .germans
          },
          actions: { _ in [.skipAdvance] }
        )
      ],
      reduce: { state, action in
        var logs = [Log]()
        switch action {
        case .advanceAllies(let ally):
          if case let .onTrack(startingCity) = state.position[ally] {
            let destCity = BattleCard.Position.onTrack(startingCity + 1)
            logs.append(Log(msg: "Advancing \(ally) to \(destCity)"))
            if let destAlly = state.allyIn(pos: destCity) {
              state.strength[destAlly] = DSix.sum(state.strength[ally]!, state.strength[destAlly]!)
              state.removePiece(ally)
            } else {
              state.position[ally]! = destCity
            }
          }
          return (logs, [.setPhase(.rollForWeather)])
        case .advance30Corps:
          if case let .onTrack(city) = state.position[.thirtycorps] {
            let destCity = BattleCard.Position.onTrack(city + 1)
            state.position[.thirtycorps] = destCity
            state.removePiece(state.germanIn(pos: destCity)!)
            logs.append(Log(msg: "Advancing \(BattleCard.Piece.thirtycorps) to \(destCity)"))
          }
          return (logs, [.setPhase(.rollForWeather)])
        case .skipAdvance:
          return ([Log(msg: "Can't advance into German control")], [.setPhase(.rollForWeather)])
        default:
          return nil
        }
      }
    )
  }

  static func checkWeatherPage() -> RulePage<BattleCard.State, BattleCard.Action> {
    RulePage(
      name: "Check weather",
      rules: [
        GameRule(
          condition: { $0.phase == .rollForWeather },
          actions: { _ in [.roll1stAirborne] }
        )
      ],
      reduce: { state, action in
        guard action == .roll1stAirborne else { return nil }
        var logs = [Log]()
        if state.weather == .fog {
          logs.append(Log(msg: "Rolling to see if the fog clears:"))
          if DSix.greater(DSix(rawValue: state.turnNumber)!, DSix.roll()) {
            logs.append(Log(msg: "🌤️ Yes, weather clear!"))
            state.weather = .clear
            state.weatherCleared = true
          } else {
            logs.append(Log(msg: "☁️ No, still foggy."))
          }
        }
        return (logs, [.setPhase(.reinforce1st)])
      }
    )
  }

  static func reinforce1stPage() -> RulePage<BattleCard.State, BattleCard.Action> {
    RulePage(
      name: "Reinforce 1st",
      rules: [
        GameRule(
          condition: { $0.phase == .reinforce1st },
          actions: { state in
            if state.weatherCleared {
              [.perform1stAirborneReinforcement]
            } else {
              [.skipReinforce1st]
            }
          }
        )
      ],
      reduce: { state, action in
        switch action {
        case .perform1stAirborneReinforcement:
          state.strength[.allied1st] = DSix.sum(DSix.one, state.strength[.allied1st]!)
          return ([Log(msg: "Dropping reinforcements for 1st.")], [.advanceTurn, .setPhase(.battle)])
        case .skipReinforce1st:
          return ([Log(msg: "Unable to reinforce 1st.")], [.advanceTurn, .setPhase(.battle)])
        case .advanceTurn:
          state.alliesToAttack = state.alliesOnBoard.filter { state.opponentFacing(piece: $0) != nil }
          state.germansToReinforce = state.germansOnBoard
          state.turnNumber += 1
          return ([Log(msg: "Next turn.")], [])
        default:
          return nil
        }
      }
    )
  }

  static func reinforceGermansPage() -> ForEachPage<BattleCard.State, BattleCard.Piece> {
    ForEachPage(
      name: "Reinforce Germans",
      isActive: { state in state.phase == .reinforceGermans },
      items: { state in state.germansOnBoard },
      actionsFor: { _, piece in [.reinforceGermans(piece)] },
      itemFrom: { action in
        if case .reinforceGermans(let german) = action { return german }
        return nil
      },
      transitionAction: .setPhase(.advance),
      isPhaseEntry: { action in
        if case .setPhase(.reinforceGermans) = action { return true }
        return false
      },
      reduce: { state, action in
        guard case .reinforceGermans(let germanArmy) = action else { return nil }
        var logs = [Log]()
        if case let .onTrack(city) = state.position[germanArmy] {
          switch germanArmy {
          case .germanArnhem, .germanEindhoven, .germanGrave:
            state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
            logs.append(Log(msg: "+1 to \(germanArmy)"))
          case .germanNijmegen:
            if state.control[4] == .germans {
              state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
              logs.append(Log(msg: "+1 to \(germanArmy)"))
            } else {
              logs.append(Log(msg: "+0 to \(germanArmy) (Allies control Arnhem)"))
            }
          default:
            ()
          }
          switch state.opponentFacing(piece: germanArmy) {
          case .none:
            state.control[city] = BattleCard.Control.germans
          case .some(let ally):
            if DSix.greater(state.strength[germanArmy]!, state.strength[ally]!) {
              state.control[city] = BattleCard.Control.germans
            }
          }
          state.germansToReinforce.removeAll(where: { $0 == germanArmy })
        }
        return (logs, [])
      }
    )
  }

  static func battlePage() -> ForEachPage<BattleCard.State, BattleCard.Piece> {
    ForEachPage(
      name: "Battle",
      isActive: { $0.phase == .battle },
      items: { state in
        state.alliesOnBoard.filter { state.opponentFacing(piece: $0) != nil }
      },
      actionsFor: { _, piece in
        [.rollForAttack(piece), .rollForDefend(piece)]
      },
      itemFrom: { action in
        switch action {
        case .rollForAttack(let ally), .rollForDefend(let ally):
          return ally
        default:
          return nil
        }
      },
      transitionAction: .setPhase(.reinforceGermans),
      isPhaseEntry: { action in
        if case .setPhase(.battle) = action { return true }
        return false
      },
      reduce: { state, action in
        var logs = [Log]()
        switch action {
        case .rollForAttack(let army):
          let german = state.opponentFacing(piece: army)!
          let armyStrength = state.strength[army]!
          let germanStrength = state.strength[german]!
          let roll = DSix.roll()
          let (allyHit, germanHit, alliedControl) = BattleCard().attackCRT.result(DSix.compare(armyStrength, germanStrength), roll)
          state.strength[army]   = DSix.minus(state.strength[army]!,   allyHit, clamp: false)
          state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
          logs.append(Log(msg: "Attack roll was \(roll.rawValue): -\(allyHit.rawValue) to ally, -\(germanHit.rawValue) to german."))
          if alliedControl {
            if let city = state.position[army] {
              switch city {
              case .onTrack(let trackPos):
                logs.append(Log(msg: "Allies control \(BattleCardComponents().track.names[trackPos])."))
                state.control[trackPos] = BattleCard.Control.allies
              default:
                ()
              }
            }
          }
          state.alliesToAttack.removeAll(where: { $0 == army })
        case .rollForDefend(let army):
          let german = state.opponentFacing(piece: army)!
          let armyStrength = state.strength[army]!
          let germanStrength = state.strength[german]!
          let roll = DSix.roll()
          let (allyHit, germanHit) = BattleCard().defendCRT.result(DSix.compare(armyStrength, germanStrength), roll)
          state.strength[army]   = DSix.minus(state.strength[army]!,   allyHit, clamp: false)
          state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
          logs.append(Log(msg: "Defend roll was \(roll.rawValue): -\(allyHit.rawValue) to ally, -\(germanHit.rawValue) to german."))
          if DSix.greater(state.strength[german]!, state.strength[army]!) {
            if let city = state.position[army] {
              switch city {
              case .onTrack(let trackPos):
                state.control[trackPos] = BattleCard.Control.germans
                logs.append(Log(msg: "Germans control \(BattleCardComponents().track.names[trackPos])."))
              default:
                ()
              }
            }
          }
          state.alliesToAttack.removeAll(where: { $0 == army })
        default:
          return nil
        }
        return (logs, [])
      }
    )
  }

  static func airdropPage() -> ForEachPage<BattleCard.State, BattleCard.Piece> {
    ForEachPage(
      name: "Airdrop",
      isActive: { $0.phase == .airdrop },
      items: { _ in BattleCardComponents.Piece.allies() },
      actionsFor: { _, ally in [.airdrop(ally)] },
      itemFrom: { action in
        if case .airdrop(let ally) = action { return ally }
        return nil
      },
      transitionAction: .setPhase(.battle),
      isPhaseEntry: { action in
        if case .setPhase(.airdrop) = action { return true }
        return false
      },
      reduce: { state, action in
        guard case .airdrop(let ally) = action else { return nil }
        let roll = DSix.roll()
        let penalty = BattleCard().airdropPenalty(roll)
        state.strength[ally] = DSix.minus(state.strength[ally]!, penalty)
        state.alliesToAirdrop.removeAll(where: { $0 == ally })
        return ([Log(msg: "Airdrop roll for \(ally) was \(roll): -\(penalty) to strength")], [])
      }
    )
  }

  static func victoryPage() -> RulePage<BattleCard.State, BattleCard.Action> {
    RulePage(
      name: "Victory",
      rules: [
        GameRule(
          condition: { $0.position[.thirtycorps] == .onTrack(4) },
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

  static func lossPage() -> RulePage<BattleCard.State, BattleCard.Action> {
    RulePage(
      name: "Loss",
      rules: [
        GameRule(
          condition: { $0.turnNumber >= 7 },
          actions: { _ in [BattleCard.Action.declareLoss] }
        ),
        GameRule(
          condition: { state in
            state.alliesOnBoard.compactMap({ state.strength[$0] }).anySatisfy({ $0 == DSix.none })
          },
          actions: { _ in [BattleCard.Action.declareLoss] }
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

  static func game() -> ComposedGame<BattleCard.State> {
    oapply(
      pages: [
        setupPage(),
        airdropPage().asRulePage(),
        battlePage().asRulePage(),
        reinforceGermansPage().asRulePage(),
        advanceAllyPage(),
        checkWeatherPage(),
        reinforce1stPage()
      ],
      priorities: [
        victoryPage(),
        lossPage()
      ],
      initialState: {
        var state = BattleCard.State()
        state.history = [.setPhase(.setup)]
        return state
      },
      isTerminal: { $0.ended },
      phaseForAction: { action in
        if case .setPhase(let phase) = action { return phase }
        return nil
      }
    )
  }
}
