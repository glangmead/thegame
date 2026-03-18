//
//  LoDBumpInTheNightPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Bump in the Night event page (card #36).
//

import Foundation

extension LoD {

  enum BumpInTheNightAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Event"

    case advanceSky
    case advanceOthers([ArmySlot])

    var description: String {
      switch self {
      case .advanceSky: return "Advance Sky army"
      case .advanceOthers(let slots): return "Advance \(slots)"
      }
    }
  }

  static var bumpInTheNightPage: RulePage<State, Action> {
    RulePage(
      name: "Bump in the Night",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 36 },
          actions: { state in
            var actions: [Action] = []
            actions.append(.bumpInTheNight(.advanceSky))
            let nonSkySlots = ArmySlot.allCases.filter {
              $0.track != .sky && state.armyPosition[$0] != nil
            }
            for slot in nonSkySlots {
              actions.append(.bumpInTheNight(.advanceOthers([slot, slot])))
            }
            for first in 0..<nonSkySlots.count {
              for second in (first + 1)..<nonSkySlots.count {
                actions.append(.bumpInTheNight(
                  .advanceOthers([nonSkySlots[first], nonSkySlots[second]])))
              }
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .bumpInTheNight(let sub) = action else { return nil }
        let results: [State.AdvanceResult]
        switch sub {
        case .advanceSky:
          results = state.eventBumpInTheNight(advanceSky: true)
        case .advanceOthers(let slots):
          results = state.eventBumpInTheNight(advanceSky: false, otherAdvances: slots)
        }
        state.phase = .action
        return (results.map { Log(msg: "Bump in the Night: \($0)") }, [])
      }
    )
  }
}
