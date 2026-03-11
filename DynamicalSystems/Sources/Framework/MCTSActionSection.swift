//
//  MCTSActionSection.swift
//  DynamicalSystems
//
//  Shared SwiftUI section that runs OpenLoopMCTS in the background
//  and displays actions sorted by descending win ratio with stats.
//

import SwiftUI

/// Open the existential `any PlayableGame` so OpenLoopMCTS gets a concrete Reducer type.
private func mctsRecommendation<Game: PlayableGame>(
  state: Game.State, game: Game, iters: Int
) -> [Game.Action: (Float, Float)]
where Game.State: GameState & CustomStringConvertible,
      Game.Action: Hashable & Equatable & CustomStringConvertible {
  let search = OpenLoopMCTS(state: state, reducer: game)
  return search.recommendation(iters: iters)
}

struct MCTSActionSection<
  State: GameState & CustomStringConvertible,
  Action: Hashable & Equatable & CustomStringConvertible
>: View {
  let model: GameModel<State, Action>
  let actions: [Action]
  let onAction: (Action) -> Void

  @SwiftUI.State private var mctsStats: [Action: (Float, Float)] = [:]
  @SwiftUI.State private var mctsRunning = false
  @SwiftUI.State private var mctsTask: Task<Void, Never>?

  var body: some View {
    Section("Actions") {
      if mctsRunning {
        HStack(spacing: 6) {
          ProgressView()
            .controlSize(.small)
          Text("Thinking…")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      ForEach(sortedActions, id: \.self) { action in
        Button {
          onAction(action)
        } label: {
          HStack {
            Text(action.description)
            Spacer()
            if let (valueSum, visitCount) = mctsStats[action], visitCount > 0 {
              let pct = valueSum / visitCount * 100
              Text(String(format: "%.1f%% (%d)", pct, Int(visitCount)))
                .foregroundStyle(.secondary)
                .font(.caption)
            }
          }
        }
      }
    }
    .onAppear {
      if mctsStats.isEmpty && !mctsRunning {
        runMCTS()
      }
    }
    .onChange(of: actions) { runMCTS() }
  }

  private var sortedActions: [Action] {
    if mctsStats.isEmpty { return actions }
    return actions.sorted { actionA, actionB in
      let ratioA = mctsStats[actionA].map { $0.1 > 0 ? $0.0 / $0.1 : 0 } ?? 0
      let ratioB = mctsStats[actionB].map { $0.1 > 0 ? $0.0 / $0.1 : 0 } ?? 0
      return ratioA > ratioB
    }
  }

  private func runMCTS() {
    mctsTask?.cancel()
    mctsStats = [:]
    guard actions.count > 1, !model.state.ended else {
      mctsRunning = false
      return
    }
    mctsRunning = true
    nonisolated(unsafe) let state = model.state
    nonisolated(unsafe) let game = model.game
    mctsTask = Task {
      let results = await Task.detached {
        mctsRecommendation(state: state, game: game, iters: 1000)
      }.value
      if !Task.isCancelled {
        mctsStats = results
        mctsRunning = false
      }
    }
  }
}
