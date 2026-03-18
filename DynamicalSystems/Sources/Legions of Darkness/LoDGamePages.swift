//
//  LoDGamePages.swift
//  DynamicalSystems
//
//  Legions of Darkness — Card and Army phase RulePages.
//

import Foundation

extension LoD {

  // MARK: - Card Phase

  static var cardPage: RulePage<State, Action> {
    RulePage(
      name: "Card Phase",
      rules: [
        GameRule(
          condition: { $0.phase == .card },
          actions: { _ in [.drawCard] }
        )
      ],
      reduce: { state, action in
        guard case .drawCard = action else { return nil }
        state.drawCard()
        let logs = cardLogs(for: state.currentCard)
        return (logs, [.advanceArmies])
      }
    )
  }

  // MARK: - Card Log Formatting

  private static func cardLogs(for card: Card?) -> [Log] {
    guard let card else { return [Log(msg: "Drew card: none")] }
    var logs: [Log] = []
    let advances = card.advances.map(\.rawValue).joined(separator: ", ")
    logs.append(Log(msg: "Card #\(card.number): \(card.title) (\(card.deck.rawValue))"))
    logs.append(Log(msg: "  Advances: \(advances), Time: \(card.time)"))
    logs.append(Log(msg: "  Actions: \(card.actions), Heroics: \(card.heroics)"))
    if !card.actionDRMs.isEmpty {
      let drms = card.actionDRMs.map { "\($0.action.rawValue) \($0.value > 0 ? "+" : "")\($0.value)" }
      logs.append(Log(msg: "  Action DRMs: \(drms.joined(separator: ", "))"))
    }
    if !card.heroicDRMs.isEmpty {
      let drms = card.heroicDRMs.map { "\($0.action.rawValue) \($0.value > 0 ? "+" : "")\($0.value)" }
      logs.append(Log(msg: "  Heroic DRMs: \(drms.joined(separator: ", "))"))
    }
    if let event = card.event {
      logs.append(Log(msg: "  Event: \(event.title)"))
      logs.append(Log(msg: "    \(event.text)"))
    }
    if let quest = card.quest {
      logs.append(Log(msg: "  Quest: \(quest.title) (target \(quest.target))"))
      logs.append(Log(msg: "    \(quest.text)"))
      logs.append(Log(msg: "    Reward: \(quest.reward)"))
      if let penalty = quest.penalty {
        logs.append(Log(msg: "    Penalty: \(penalty)"))
      }
    }
    if let bloodyBattle = card.bloodyBattle {
      logs.append(Log(msg: "  Bloody battle: \(bloodyBattle.rawValue)"))
    }
    return logs
  }

  // MARK: - Army Phase

  static var armyPage: RulePage<State, Action> {
    RulePage(
      name: "Army Phase",
      rules: [
        // Bloody battle Gate tie — player chooses placement
        GameRule(
          condition: { $0.phase == .army && $0.pendingBloodyBattleChoices != nil },
          actions: { state in
            (state.pendingBloodyBattleChoices ?? []).map { .chooseBloodyBattle($0) }
          }
        )
      ],
      reduce: { state, action in
        // Handle bloody battle choice
        if case .chooseBloodyBattle(let slot) = action {
          state.bloodyBattleArmy = slot
          state.pendingBloodyBattleChoices = nil
          let logs = [Log(msg: "Bloody battle marker placed on \(slot)")]
          state.phase = state.currentCard?.event != nil ? .event : .action
          return (logs, [])
        }

        guard case .advanceArmies = action else { return nil }
        var logs: [Log] = []
        if let card = state.currentCard {
          for track in card.advances {
            let results = state.advanceArmyOnTrack(track)
            for result in results {
              logs.append(Log(msg: "Army advance on \(track): \(result)"))
              if case .advanced(let slot, _, let destination) = result,
                destination == 1,
                state.upgrades[slot.track] == .acid {
                state.acidEligibleSlots.insert(slot)
              }
            }
          }
        }
        state.phase = state.currentCard?.event != nil ? .event : .action
        return (logs, [])
      }
    )
  }

}
