//
//  HeartsGame.swift
//  DynamicalSystems
//
//  Hearts — composedGame() factory wiring pages via oapply.
//

import Foundation

extension Hearts {

  private static func nextPhase(for action: Action) -> Phase? {
    switch action {
    case .selectPassCard, .confirmPass: return .passing
    case .playCard: return .playing
    case .resolveTrick: return .trickResolution
    case .scoreHand, .startNewHand: return .handEnd
    case .declareWinner: return .gameEnd
    }
  }

  static func composedGame(
    config: HeartsConfig = HeartsConfig(),
    shuffledDeck: [Card]? = nil
  ) -> ComposedGame<State> {
    oapply(
      gameName: gameName,
      pages: [passingPage, singlePlayPage, trickPage, handPage],
      priorities: [gameEndPage],
      initialState: {
        let deck = shuffledDeck ?? fullDeck.shuffled()
        return State.newGame(config: config, shuffledDeck: deck)
      },
      isTerminal: { $0.ended && $0.gameAcknowledged },
      isRolloutTerminal: { $0.phase == .handEnd || $0.phase == .gameEnd },
      phaseForAction: { nextPhase(for: $0) },
      stateEvaluator: heartsEvaluator
    )
  }
}
