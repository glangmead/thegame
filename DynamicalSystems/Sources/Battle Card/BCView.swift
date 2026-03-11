//
//  BCView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25
//

import SpriteKit
import SwiftUI

struct BCView: View {
  @State private var model: GameModel<BattleCard.State, BattleCard.Action>
  @State private var scene: GameScene<BattleCard.State, BattleCard.Action>
  @State private var cachedActions: [BattleCard.Action] = []
  @State private var logs: [Log] = []
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  init() {
    let graph = BCGraph.board(cellSize: 75)
    let game = BCPages.game()
    let model = GameModel(game: game, graph: graph)
    let config = BCSceneConfig.config()
    let scene = GameScene(
      model: model,
      config: config,
      size: CGSize(width: 260, height: 380),
      cellSize: 50
    )
    scene.scaleMode = .aspectFit
    let pieces = BCPieceAdapter.pieces()

    self._model = State(initialValue: model)
    self._scene = State(initialValue: scene)
    self.graph = graph
    self.pieces = pieces

    let section = BCPieceAdapter.section(from: model.state, graph: graph)
    let highlights = BCPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  var body: some View {
    VStack(spacing: 0) {
      SpriteView(scene: scene)
        .frame(maxWidth: .infinity)
        .aspectRatio(260.0 / 380.0, contentMode: .fit)
      HStack {
        Label("Turn \(model.state.turnNumber)", systemImage: "calendar")
        Spacer()
        Label(
          model.state.weather == .fog ? "Fog" : "Clear",
          systemImage: model.state.weather == .fog ? "cloud.fog" : "sun.max"
        )
      }
      .font(.subheadline.bold())
      .padding(.horizontal)
      .padding(.vertical, 6)
      List {
        if !logs.isEmpty {
          Section("Log") {
            ForEach(logs, id: \.msg) { log in
              Text(log.msg)
                .font(.caption)
            }
          }
        }
        MCTSActionSection(model: model, actions: cachedActions) { action in
          performAction(action)
        }
      }
    }
    .navigationTitle(model.state.name)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { refreshActions() }
  }

  private func performAction(_ action: BattleCard.Action) {
    let newLogs = model.perform(action)
    logs = newLogs
    refreshActions()
    let section = BCPieceAdapter.section(from: model.state, graph: graph)
    let highlights = BCPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  private func refreshActions() {
    cachedActions = model.allowedActions
  }
}

#Preview("Battle Card") {
  BCView()
}
