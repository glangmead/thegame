//
//  LoDDeathAndDespairPage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Death and Despair multi-step sub-resolution page.
//

import Foundation

extension LoD {

  // MARK: - Death and Despair Sub-State

  struct DeathAndDespairState: Equatable, Hashable, Sendable {
    let dieRoll: Int
    var sacrificedHeroes: [HeroType] = []
    var sacrificedDefenders: [DefenderType] = []

    var totalSacrifices: Int { sacrificedHeroes.count + sacrificedDefenders.count }
    var remainingAdvance: Int { max(dieRoll - totalSacrifices, 0) }
  }

  // MARK: - Death and Despair Sub-Action

  enum DeathAndDespairAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Death and Despair"

    case sacrificeHero(HeroType)
    case sacrificeDefender(DefenderType)
    case commitAdvance(chosenSlot: ArmySlot?)

    var description: String {
      switch self {
      case .sacrificeHero(let hero):
        return "Wound \(hero.rawValue.capitalized) to reduce advance"
      case .sacrificeDefender(let defType):
        return "Lose \(defType) to reduce advance"
      case .commitAdvance(let slot):
        if let slot { return "Advance \(slot.rawValue.capitalized)" }
        return "Accept advance"
      }
    }
  }

  // MARK: - Death and Despair RulePage

  static var deathAndDespairPage: RulePage<State, Action> {
    RulePage(
      name: "Death and Despair",
      rules: [
        GameRule(
          condition: { $0.deathAndDespairState != nil },
          actions: { state in
            guard let ddState = state.deathAndDespairState else { return [] }
            var actions: [Action] = []

            // Sacrifice options (only if advance > 0)
            if ddState.remainingAdvance > 0 {
              for hero in state.livingHeroes
              where !state.heroWounded.contains(hero) && !ddState.sacrificedHeroes.contains(hero) {
                actions.append(.deathAndDespair(.sacrificeHero(hero)))
              }
              for defType in DefenderType.allCases {
                if let pos = state.defenderPosition[defType],
                   pos < defType.lastPosition,
                   !ddState.sacrificedDefenders.contains(defType) {
                  actions.append(.deathAndDespair(.sacrificeDefender(defType)))
                }
              }
            }

            // Commit advance (always available)
            if ddState.remainingAdvance > 0 {
              let farthestSlots = state.farthestArmySlots()
              if farthestSlots.count > 1 {
                for slot in farthestSlots {
                  actions.append(.deathAndDespair(.commitAdvance(chosenSlot: slot)))
                }
              } else {
                actions.append(.deathAndDespair(.commitAdvance(chosenSlot: farthestSlots.first)))
              }
            } else {
              actions.append(.deathAndDespair(.commitAdvance(chosenSlot: nil)))
            }

            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .deathAndDespair(let ddAction) = action else { return nil }
        guard var ddState = state.deathAndDespairState else { return nil }
        var logs: [Log] = []

        switch ddAction {
        case .sacrificeHero(let hero):
          state.woundHero(hero)
          ddState.sacrificedHeroes.append(hero)
          state.deathAndDespairState = ddState
          logs.append(Log(
            msg: "Death and Despair: wounded \(hero) (advance reduced to \(ddState.remainingAdvance))"
          ))

        case .sacrificeDefender(let defType):
          state.loseDefender(defType)
          ddState.sacrificedDefenders.append(defType)
          state.deathAndDespairState = ddState
          logs.append(Log(
            msg: "Death and Despair: lost \(defType) (advance reduced to \(ddState.remainingAdvance))"
          ))

        case .commitAdvance(let chosenSlot):
          let advances = ddState.remainingAdvance
          if advances > 0 {
            let farthest = state.farthestArmySlots()
            let targetSlot = chosenSlot ?? farthest.first
            if let slot = targetSlot {
              for _ in 0..<advances {
                let result = state.advanceArmy(slot)
                logs.append(Log(msg: "Death and Despair: \(result)"))
              }
            }
          }
          state.deathAndDespairState = nil
          logs.append(Log(msg: "Death and Despair resolved"))
        }

        return (logs, [])
      }
    )
  }
}

// MARK: - Farthest Army Helper

extension LoD.State {

  /// Return army slots with the highest position (farthest from castle).
  func farthestArmySlots() -> [LoD.ArmySlot] {
    var maxSpace = 0
    var result: [LoD.ArmySlot] = []
    for slot in LoD.ArmySlot.allCases {
      guard let pos = armyPosition[slot] else { continue }
      if pos > maxSpace {
        maxSpace = pos
        result = [slot]
      } else if pos == maxSpace {
        result.append(slot)
      }
    }
    return result
  }
}
