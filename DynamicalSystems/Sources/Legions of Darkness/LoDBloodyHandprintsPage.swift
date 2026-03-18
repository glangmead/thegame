//
//  LoDBloodyHandprintsPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Bloody Handprints event page (card #24).
//

import Foundation

extension LoD {

  enum BloodyHandprintsAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Event"

    case chooseHero(HeroType)
    case noHeroes

    var description: String {
      switch self {
      case .chooseHero(let hero): return "Choose \(hero)"
      case .noHeroes: return "No living heroes"
      }
    }
  }

  static var bloodyHandprintsPage: RulePage<State, Action> {
    RulePage(
      name: "Bloody Handprints",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 24 },
          actions: { state in
            let heroes = state.livingHeroes
            guard !heroes.isEmpty else {
              return [.bloodyHandprints(.noHeroes)]
            }
            return heroes.map { .bloodyHandprints(.chooseHero($0)) }
          }
        )
      ],
      reduce: { state, action in
        guard case .bloodyHandprints(let sub) = action else { return nil }
        var logs: [Log] = []
        switch sub {
        case .chooseHero(let hero):
          let dieRoll = LoD.rollDie()
          state.eventBloodyHandprints(dieRoll: dieRoll, chosenHero: hero)
          logs.append(Log(msg: "Bloody Handprints: rolled \(dieRoll), hero \(hero)"))
        case .noHeroes:
          logs.append(Log(msg: "Bloody Handprints: no living heroes"))
        }
        state.phase = .action
        return (logs, [])
      }
    )
  }
}
