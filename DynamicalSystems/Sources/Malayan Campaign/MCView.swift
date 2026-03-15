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
  @State private var showConfig = false
  @State private var playerModes: [MalayanCampaign.Player: PlayerMode] = [
    .solo: .interactive
  ]
  @State private var aiTask: Task<Void, Never>?
  @State private var cameraScale: CGFloat = 1.0
  @State private var cameraPosition: CGPoint = .zero
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  private var slots: [PlayerSlot<MalayanCampaign.Player>] {
    [PlayerSlot(
      player: .solo, label: "Solo",
      allowedModes: [.interactive, .fastAI, .slowAI])]
  }

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
    self._cameraScale = State(initialValue: scene.cameraNode?.xScale ?? 1)
    self._cameraPosition = State(initialValue: scene.cameraNode?.position ?? .zero)

    let section = MCPieceAdapter.section(from: model.state, graph: graph)
    let highlights = MCPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  var body: some View {
    VStack(spacing: 0) {
      SpriteView(scene: scene)
        .simultaneousGesture(MagnifyGesture()
          .onChanged { value in
            let newScale = cameraScale / value.magnification
            scene.setZoom(scale: newScale)
          }
          .onEnded { value in
            cameraScale /= value.magnification
          }
        )
        .simultaneousGesture(DragGesture()
          .onChanged { value in
            let currentScale = scene.cameraNode?.xScale ?? 1
            scene.setCameraPosition(CGPoint(
              x: cameraPosition.x - value.translation.width * currentScale,
              y: cameraPosition.y + value.translation.height * currentScale))
          }
          .onEnded { value in
            let currentScale = scene.cameraNode?.xScale ?? 1
            cameraPosition = CGPoint(
              x: cameraPosition.x - value.translation.width * currentScale,
              y: cameraPosition.y + value.translation.height * currentScale)
          }
        )
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
        MCTSActionSection(model: model, actions: cachedActions) { action in
          performAction(action)
        }
        BoardSummarySections(
          graph: graph,
          pieces: pieces,
          section: MCPieceAdapter.section(from: model.state, graph: graph))
        if !model.logs.isEmpty {
          Section("Log") {
            ForEach(model.logs, id: \.msg) { log in
              Text(log.msg)
                .font(.caption)
            }
          }
        }
      }
    }
    .navigationTitle(model.gameName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showConfig = true
        } label: {
          Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings") // [VERIFY]
      }
    }
    .sheet(isPresented: $showConfig) {
      PlayerConfigSheet(
        slots: slots,
        modes: $playerModes,
        onStart: resetGame
      )
    }
    .onAppear { refreshActions() }
    .onChange(of: model.state) {
      refreshActions()
      syncScene()
      aiTask?.cancel()
      aiTask = scheduleAIMove(
        model: model,
        playerModes: playerModes,
        performAction: performAction
      )
    }
    .onDisappear { aiTask?.cancel() }
  }

  private func performAction(_ action: MalayanCampaign.Action) {
    model.perform(action)
  }

  private func syncScene() {
    let section = MCPieceAdapter.section(from: model.state, graph: graph)
    let highlights = MCPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  private func refreshActions() {
    let mode = playerModes[
      model.state.player, default: .interactive]
    guard mode == .interactive, !model.isTerminal else {
      cachedActions = []
      return
    }
    cachedActions = model.allowedActions
  }

  private func resetGame() {
    aiTask?.cancel()
    let game = MCPages.game()
    model.reset(with: game)
    cachedActions = []
    syncScene()
    showConfig = false
    aiTask = scheduleAIMove(
      model: model,
      playerModes: playerModes,
      performAction: performAction
    )
  }
}

#Preview("Malayan Campaign") {
  NavigationStack {
    MCView()
  }
}
