//
//  MCView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import SpriteKit
import SwiftUI

struct MCView: View {
  @State private var model: GameModel<MalayanCampaign.State, MalayanCampaign.Action>
  @State private var scene: GameScene<MalayanCampaign.State, MalayanCampaign.Action>
  @State private var cachedActions: [MalayanCampaign.Action] = []
  @State private var logs: [Log] = []
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  init() {
    let graph = MCGraph.board(cellSize: 75)
    let game = MCPages.game()
    let model = GameModel(game: game, graph: graph)
    let config = MCSceneConfig.config()
    let scene = GameScene(
      model: model,
      config: config,
      size: CGSize(width: 260, height: 420),
      cellSize: 50
    )
    scene.scaleMode = .aspectFit
    let pieces = MCPieceAdapter.pieces()

    self._model = State(initialValue: model)
    self._scene = State(initialValue: scene)
    self.graph = graph
    self.pieces = pieces

    let section = MCPieceAdapter.section(from: model.state, graph: graph)
    let highlights = MCPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  var body: some View {
    VStack(spacing: 0) {
      SpriteView(scene: scene)
        .frame(maxWidth: .infinity)
        .aspectRatio(260.0 / 420.0, contentMode: .fit)
      HStack {
        Label("Turn \(model.state.turnNumber)", systemImage: "calendar")
        Spacer()
        Label(model.state.phase.name, systemImage: "flag")
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

  private func performAction(_ action: MalayanCampaign.Action) {
    let newLogs = model.perform(action)
    logs = newLogs
    refreshActions()
    let section = MCPieceAdapter.section(from: model.state, graph: graph)
    let highlights = MCPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  private func refreshActions() {
    cachedActions = model.allowedActions
  }
}

#Preview("Malayan Campaign") {
  MCView()
}
