//
//  LoDDesertersPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Deserters in the Dark event page (card #33).
//

import Foundation

extension LoD {

  enum DesertersAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Event"

    case loseTwoDefenders(DefenderType, DefenderType)
    case loseMorale

    var description: String {
      switch self {
      case .loseTwoDefenders(let first, let second): return "Lose \(first) and \(second)"
      case .loseMorale: return "Reduce morale"
      }
    }
  }

  static var desertersPage: RulePage<State, Action> {
    RulePage(
      name: "Deserters",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 33 },
          actions: { state in
            var actions: [Action] = []
            let types = DefenderType.allCases
            for first in 0..<types.count {
              for second in first..<types.count {
                actions.append(.deserters(.loseTwoDefenders(types[first], types[second])))
              }
            }
            if state.morale != .low {
              actions.append(.deserters(.loseMorale))
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .deserters(let sub) = action else { return nil }
        switch sub {
        case .loseTwoDefenders(let first, let second):
          state.eventDeserters(loseTwoDefenders: (first, second))
        case .loseMorale:
          state.eventDeserters(loseTwoDefenders: nil)
        }
        state.phase = .action
        return ([Log(msg: "Deserters in the Dark")], [])
      }
    )
  }
}
