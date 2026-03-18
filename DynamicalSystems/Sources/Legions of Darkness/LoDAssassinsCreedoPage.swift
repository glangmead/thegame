//
//  LoDAssassinsCreedoPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Assassin's Creedo event page (card #30).
//

import Foundation

extension LoD {

  enum AssassinsCreedoAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Event"

    case chooseHero(HeroType?)

    var description: String {
      switch self {
      case .chooseHero(let hero):
        if let hero { return "Target \(hero)" }
        return "No living heroes"
      }
    }
  }

  static var assassinsCreedoPage: RulePage<State, Action> {
    RulePage(
      name: "Assassin's Creedo",
      rules: [
        GameRule(
          condition: { $0.phase == .event && $0.currentCard?.number == 30 },
          actions: { state in
            let heroes = state.livingHeroes
            guard !heroes.isEmpty else {
              return [.assassinsCreedo(.chooseHero(nil))]
            }
            return heroes.map { .assassinsCreedo(.chooseHero($0)) }
          }
        )
      ],
      reduce: { state, action in
        guard case .assassinsCreedo(.chooseHero(let hero)) = action else { return nil }
        let dieRoll = LoD.rollDie()
        state.eventAssassinsCreedo(dieRoll: dieRoll, chosenHero: hero)
        state.phase = .action
        return ([Log(msg: "Assassin's Creedo: rolled \(dieRoll)")], [])
      }
    )
  }
}
