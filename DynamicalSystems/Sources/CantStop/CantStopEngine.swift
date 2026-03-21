//
//  CantStop.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

import Foundation

struct CantStop {

  enum Action: Hashable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    case pass
    case bust
    case claimVictory
    case rollDice
    case forceRoll([DSix])
    case assignDicePair(Pair<Die>)
    case progressColumn(Column)
    case progressColumns([Column])
    case sequence([Action])
    case setPhase(Phase)

    var name: String {
      description
    }

    var debugDescription: String {
      description
    }

    var description: String {
      switch self {
      case .assignDicePair:
        return ""
      case .sequence(let actions):
        let name = actions.compactMap { $0.name.isEmpty ? nil : $0.name }
          .joined(separator: " and ")
        return "\(name)"
      case .progressColumn(let col):
        return "\(col.rawValue)"
      case .progressColumns(let cols):
        return cols.map { "\($0.rawValue)" }.joined(separator: " and ")
      case .rollDice:
        return "Roll dice"
      case .claimVictory:
        return "Claim victory!"
      case .pass:
        return "Pass"
      case .bust:
        return "Busted: Pass"
      case .forceRoll(let dice):
        return "Roll \(dice)"
      case .setPhase(let phase):
        return "Set phase \(phase)"
      }
    }
  }

  func newState() -> State {
    State()
  }

  func allowedActions(state: State) -> [Action] {
    CantStopPages.game().allowedActions(state: state)
  }

  static func twod6_total(_ dice: Pair<DSix>) -> Column {
    let col = Column(rawValue: dice.fst.rawValue + dice.snd.rawValue) ?? .none
    return col
  }
}
