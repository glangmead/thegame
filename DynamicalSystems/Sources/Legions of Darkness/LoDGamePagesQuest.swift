//
//  LoDGamePagesQuest.swift
//  DynamicalSystems
//
//  Legions of Darkness — Quest rule page (action and heroic quests in unified player turn).
//

import Foundation

extension LoD {

  static var questPage: RulePage<State, Action> {
    RulePage(
      name: "Quest",
      rules: [
        GameRule(
          condition: {
            $0.phase == .action && $0.currentCard?.quest != nil && !$0.isInSubResolution
              && ($0.actionBudgetRemaining > 0 || $0.heroicBudgetRemaining > 0)
          },
          actions: { state in
            var actions: [Action] = []
            // Action-point spending: +1 DRM per point (rule 7.0)
            let maxAction = state.actionBudgetRemaining
            for pts in 1...max(1, maxAction) {
              actions.append(.quest(.quest(
                isHeroic: false, reward: QuestRewardParams(), pointsSpent: pts)))
            }
            // Heroic-point spending: +2 DRM per point (rule 7.0)
            let maxHeroic = state.heroicBudgetRemaining
            for pts in 1...max(1, maxHeroic) {
              actions.append(.quest(.quest(
                isHeroic: true, reward: QuestRewardParams(), pointsSpent: pts)))
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard case .quest = action else { return nil }
        let logs = state.resolveDieRollWithPaladinCheck(action, phase: .action)
        return (logs, [])
      }
    )
  }
}
