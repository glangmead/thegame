//
//  LoDGamePagesQuest.swift
//  DynamicalSystems
//
//  Legions of Darkness — Quest rule page (action and heroic phase quests).
//

import Foundation

extension LoD {

  static var questPage: RulePage<State, Action> {
    RulePage(
      name: "Quest",
      rules: [
        // Action phase quest
        GameRule(
          condition: {
            $0.phase == .action && $0.actionBudgetRemaining > 0 && $0.currentCard?.quest != nil
          },
          actions: { _ in
            [.quest(.quest(isHeroic: false, dieRoll: 0, reward: QuestRewardParams()))]
          }
        ),
        // Heroic phase quest
        GameRule(
          condition: {
            $0.phase == .heroic && $0.heroicBudgetRemaining > 0 && $0.currentCard?.quest != nil
          },
          actions: { _ in
            [.quest(.quest(isHeroic: true, dieRoll: 0, reward: QuestRewardParams()))]
          }
        )
      ],
      reduce: { state, action in
        guard case .quest = action else { return nil }
        let phase: Phase = state.phase == .heroic ? .heroic : .action
        let logs = state.resolveDieRollWithPaladinCheck(action, phase: phase)
        return (logs, [])
      }
    )
  }
}
