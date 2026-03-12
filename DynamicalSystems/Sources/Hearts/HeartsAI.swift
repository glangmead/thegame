//
//  HeartsAI.swift
//  DynamicalSystems
//
//  Hearts — AI turn scheduling, separated to avoid preview thunk issues.
//

import SwiftUI

extension HeartsView {
  var isAITurn: Bool {
    guard !model.state.ended else { return false }
    if model.state.phase == .trickResolution { return true }
    let humanSeat = model.state.config.humanSeat
    if humanSeat == nil { return true }
    return model.state.player != humanSeat
  }

  func scheduleAIIfNeeded() {
    guard isAITurn else { return }

    let delay = model.state.phase == .trickResolution
      ? 1.0
      : model.state.config.aiDelaySeconds

    aiTask?.cancel()
    aiTask = Task { @MainActor in
      try? await Task.sleep(
        nanoseconds: UInt64(delay * 1_000_000_000))
      guard !Task.isCancelled else { return }

      let actions = model.allowedActions
      guard !actions.isEmpty else { return }

      let bestAction: Hearts.Action
      if actions.count == 1 {
        bestAction = actions[0]
      } else {
        nonisolated(unsafe) let state = model.state
        nonisolated(unsafe) let game = model.game
        let results = await Task.detached {
          mctsRecommendation(state: state, game: game, iters: 500)
        }.value

        if Task.isCancelled { return }

        let ratio: ((Float, Float)) -> Float = { $0.0 / max($0.1, 1) }
        bestAction = results.max(by: { ratio($0.value) < ratio($1.value) })?.key
          ?? actions.randomElement()!
      }

      performAction(bestAction)
    }
  }
}
