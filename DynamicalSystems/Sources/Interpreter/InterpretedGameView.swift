//
//  InterpretedGameView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/19/26.
//

import SwiftUI

struct InterpretedGameView: View {
  @State private var model: GameModel<InterpretedState, ActionValue>
  private let game: ComposedGame<InterpretedState>

  init(game: ComposedGame<InterpretedState>) {
    self.game = game
    let graph = SiteGraph()
    self._model = State(initialValue: GameModel(game: game, graph: graph))
  }

  var body: some View {
    List {
      if model.isTerminal {
        Section {
          Text(model.state.victory ? "Victory!" : "Defeat")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
          Button("New Game") {
            model.reset(with: game)
          }
        }
      }

      if !model.isTerminal {
        MCTSActionSection(
          model: model,
          actions: model.allowedActions,
          onAction: { action in
            model.perform(action)
          }
        )
      }

      Section("State") {
        ForEach(
          Array(model.state.counters.sorted(by: { $0.key < $1.key })),
          id: \.key
        ) { name, value in
          LabeledContent(name, value: "\(value)")
        }
        ForEach(
          Array(model.state.flags.sorted(by: { $0.key < $1.key })),
          id: \.key
        ) { name, value in
          LabeledContent(name, value: value ? "true" : "false")
        }
      }

      if !model.logs.isEmpty {
        Section("Log") {
          ForEach(Array(model.logs.enumerated()), id: \.offset) { _, log in
            Text(log.msg)
              .font(.caption)
          }
        }
      }
    }
    .navigationTitle(model.gameName)
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Sample game for the main menu

  static let sampleGameSource = """
  (game "Coin Flip"
    (players 1)
    (components
      (enum Phase {play done}))
    (state
      (counter score 0 10)
      (flag ended)
      (flag victory)
      (flag gameAcknowledged)
      (field phase Phase))
    (graph)
    (actions
      (action flipHeads)
      (action flipTails)
      (action acknowledge))
    (rules
      (phases {play done})
      (terminal (field gameAcknowledged))
      (page "Play"
        (rule (when (== phase play))
              (offer flipHeads flipTails))
        (reduce flipHeads
          (seq (increment score 1)
               (if (>= score 3)
                 (seq (endGame victory) (setPhase done))
                 (log "Tails, no points"))))
        (reduce flipTails
          (log "Tails, no points")))
      (priority "Victory"
        (rule (when (and victory (not gameAcknowledged)))
              (offer acknowledge))
        (reduce acknowledge
          (set gameAcknowledged true)))))
  """

  // swiftlint:disable:next force_try
  static let sampleGame = try! GameBuilder.build(from: sampleGameSource)
}

#Preview("Interpreted Game") {
  NavigationStack {
    InterpretedGameView(game: InterpretedGameView.sampleGame)
  }
}
