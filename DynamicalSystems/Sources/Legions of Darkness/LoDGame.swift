//
//  LoDGame.swift
//  DynamicalSystems
//
//  Legions of Darkness — composedGame factory and victory/defeat priority pages.
//

import Foundation

extension LoD {

  // MARK: - Composed Game

  /// Map an action to the phase it transitions into, or nil to stay in current phase.
  private static func nextPhase(for action: Action) -> Phase? {
    switch action {
    case .drawCard: return .army
    case .advanceArmies: return .event
    case .skipEvent, .resolveEvent: return .action
    case .passActions: return .heroic
    case .passHeroics: return .housekeeping
    case .performHousekeeping: return .card
    default: return nil  // stay in current phase
    }
  }

  /// Create a composed game for the Greenskin Horde scenario.
  /// All RulePages are wired together via oapply.
  static func composedGame(
    windsOfMagicArcane: Int,
    heroes: [HeroType] = [.warrior, .wizard, .cleric],
    shuffledDayCards: [Card]? = nil,
    shuffledNightCards: [Card]? = nil
  ) -> ComposedGame<State> {
    oapply(
      pages: [cardPage, armyPage, eventPage, actionPage, heroicPage, paladinReactPage, housekeepingPage],
      priorities: [victoryPage, defeatPage],
      initialState: {
        var state = greenskinSetup(
          windsOfMagicArcane: windsOfMagicArcane,
          heroes: heroes
        )
        state.setupDecks(
          shuffledDayCards: shuffledDayCards,
          shuffledNightCards: shuffledNightCards
        )
        return state
      },
      isTerminal: { $0.gameAcknowledged },
      phaseForAction: { nextPhase(for: $0) }
    )
  }

  // MARK: - Victory / Defeat Priority Pages

  static var victoryPage: RulePage<State, Action> {
    RulePage(
      name: "Victory",
      rules: [
        GameRule(
          condition: { $0.ended && $0.victory },
          actions: { _ in [.claimVictory] }
        )
      ],
      reduce: { state, action in
        guard case .claimVictory = action else { return nil }
        state.gameAcknowledged = true
        return ([Log(msg: "Victory! The castle stands!")], [])
      }
    )
  }

  static var defeatPage: RulePage<State, Action> {
    RulePage(
      name: "Defeat",
      rules: [
        GameRule(
          condition: { $0.ended && !$0.victory },
          actions: { _ in [.declareLoss] }
        )
      ],
      reduce: { state, action in
        guard case .declareLoss = action else { return nil }
        state.gameAcknowledged = true
        return ([Log(msg: "Defeat! The castle has fallen.")], [])
      }
    )
  }
}
