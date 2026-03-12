//
//  MCTSActionSection.swift
//  DynamicalSystems
//
//  Shared SwiftUI section that runs OpenLoopMCTS in the background
//  and displays actions sorted by descending win ratio with stats.
//

import SwiftUI

/// Open the existential `any PlayableGame` so OpenLoopMCTS gets a concrete Reducer type.
func mctsRecommendation<Game: PlayableGame>(
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
  let grouping: ((Action) -> String)?

  @SwiftUI.State private var mctsStats: [Action: (Float, Float)] = [:]
  @SwiftUI.State private var mctsRunning = false
  @SwiftUI.State private var mctsTask: Task<Void, Never>?

  init(
    model: GameModel<State, Action>,
    actions: [Action],
    grouping: ((Action) -> String)? = nil,
    onAction: @escaping (Action) -> Void
  ) {
    self.model = model
    self.actions = actions
    self.grouping = grouping
    self.onAction = onAction
  }

  var body: some View {
    if let grouping {
      groupedBody(grouping: grouping)
    } else {
      flatBody
    }
  }

  // MARK: - Flat (ungrouped) rendering

  @ViewBuilder
  private var flatBody: some View {
    Section("Actions") {
      mctsProgressRow
      ForEach(sortedActions, id: \.self) { action in
        actionButton(action)
      }
    }
    .onAppear { startMCTSIfNeeded() }
    .onChange(of: actions) { runMCTS() }
  }

  // MARK: - Grouped rendering

  @ViewBuilder
  private func groupedBody(grouping: (Action) -> String) -> some View {
    let groups = groupedActions(grouping: grouping)
    ForEach(groups, id: \.name) { group in
      Section(group.name) {
        if group === groups.first {
          mctsProgressRow
        }
        ForEach(group.actions, id: \.self) { action in
          actionButton(action)
        }
      }
    }
    .onAppear { startMCTSIfNeeded() }
    .onChange(of: actions) { runMCTS() }
  }

  // MARK: - Shared components

  @ViewBuilder
  private var mctsProgressRow: some View {
    if mctsRunning {
      HStack(spacing: 6) {
        ProgressView()
          .controlSize(.small)
        Text("Thinking…")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private func actionButton(_ action: Action) -> some View {
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

  // MARK: - Sorting and grouping

  private var sortedActions: [Action] {
    if mctsStats.isEmpty { return actions }
    return actions.sorted { actionA, actionB in
      let ratioA = mctsStats[actionA].map { $0.1 > 0 ? $0.0 / $0.1 : 0 } ?? 0
      let ratioB = mctsStats[actionB].map { $0.1 > 0 ? $0.0 / $0.1 : 0 } ?? 0
      return ratioA > ratioB
    }
  }

  private func groupedActions(grouping: (Action) -> String) -> [ActionGroupEntry<Action>] {
    let sorted = sortedActions
    var seen: [String: Int] = [:]
    var groups: [ActionGroupEntry<Action>] = []
    for action in sorted {
      let name = grouping(action)
      if let idx = seen[name] {
        groups[idx].actions.append(action)
      } else {
        seen[name] = groups.count
        groups.append(ActionGroupEntry(name: name, actions: [action]))
      }
    }
    return groups
  }

  // MARK: - MCTS

  private func startMCTSIfNeeded() {
    if mctsStats.isEmpty && !mctsRunning {
      runMCTS()
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

/// A group of actions under a section name, used for grouped rendering.
private class ActionGroupEntry<Action: Hashable>: Identifiable {
  let name: String
  var actions: [Action]
  var id: String { name }
  init(name: String, actions: [Action]) {
    self.name = name
    self.actions = actions
  }
}
