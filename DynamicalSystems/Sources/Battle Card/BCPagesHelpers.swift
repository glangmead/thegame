//
//  BCPagesHelpers.swift
//  DynamicalSystems
//
//  Battle Card — ForEachPage helpers (split from BCPages for type_body_length).
//

import Foundation

extension BCPages {

  // swiftlint:disable:next cyclomatic_complexity
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
        }
        return (logs, [])
      }
    )
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
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
          let (allyHit, germanHit, alliedControl) = BattleCard()
            .attackCRT.result(DSix.compare(armyStrength, germanStrength), roll)
          state.strength[army]   = DSix.minus(state.strength[army]!, allyHit, clamp: false)
          state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
          logs.append(Log(msg: "Attack roll was \(roll.rawValue): " +
            "-\(allyHit.rawValue) to ally, -\(germanHit.rawValue) to german."))
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
        case .rollForDefend(let army):
          let german = state.opponentFacing(piece: army)!
          let armyStrength = state.strength[army]!
          let germanStrength = state.strength[german]!
          let roll = DSix.roll()
          let (allyHit, germanHit) = BattleCard().defendCRT.result(DSix.compare(armyStrength, germanStrength), roll)
          state.strength[army]   = DSix.minus(state.strength[army]!, allyHit, clamp: false)
          state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
          logs.append(Log(msg: "Defend roll was \(roll.rawValue): " +
            "-\(allyHit.rawValue) to ally, -\(germanHit.rawValue) to german."))
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
        return ([Log(msg: "Airdrop roll for \(ally) was \(roll): -\(penalty) to strength")], [])
      }
    )
  }
}
