//
//  LoDHarbingersPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Harbingers of Doom event page (card #11).
//

import Foundation

extension LoD {

  enum HarbingersAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Event"

    case chooseSlot(ArmySlot?)

    var description: String {
      switch self {
      case .chooseSlot(let slot):
        if let slot { return "Advance \(slot)" }
        return "Advance farthest army"
      }
    }
  }

  static var harbingersPage: RulePage<State, Action> {
    RulePage(
      name: "Harbingers of Doom",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 11 },
          actions: { state in
            let farthest = state.farthestArmySlots()
            if farthest.count > 1 {
              return farthest.map { .harbingers(.chooseSlot($0)) }
            }
            return [.harbingers(.chooseSlot(farthest.first))]
          }
        )
      ],
      reduce: { state, action in
        guard case .harbingers(.chooseSlot(let chosenSlot)) = action else { return nil }
        let results = state.eventHarbingers(chosenSlot: chosenSlot)
        state.phase = .action
        return (results.map { Log(msg: "Harbingers of Doom: \($0)") }, [])
      }
    )
  }
}
