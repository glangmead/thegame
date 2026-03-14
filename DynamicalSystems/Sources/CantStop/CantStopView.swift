//
//  CantStopView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import SpriteKit
import SwiftUI

struct CantStopView: View {
  @State private var model: GameModel<CantStop.State, CantStop.Action>
  @State private var scene: GameScene<CantStop.State, CantStop.Action>
  @State private var cachedActions: [CantStop.Action] = []
  @State private var showConfig = false
  @State private var playerModes: [CantStop.Player: PlayerMode] = [
    .player1: .interactive,
    .player2: .fastAI,
    .player3: .excluded,
    .player4: .excluded
  ]
  @State private var aiTask: Task<Void, Never>?
  private let graph: SiteGraph
  @State private var pieces: [GamePiece]

  private var slots: [PlayerSlot<CantStop.Player>] {
    let base: [PlayerMode] = [.interactive, .fastAI, .slowAI]
    return [
      PlayerSlot(player: .player1, label: "Player 1", allowedModes: base),
      PlayerSlot(player: .player2, label: "Player 2", allowedModes: base),
      PlayerSlot(
        player: .player3, label: "Player 3",
        allowedModes: base + [.excluded]),
      PlayerSlot(
        player: .player4, label: "Player 4",
        allowedModes: base + [.excluded])
    ]
  }

  init() {
    let graph = CantStopGraph.board(cellSize: 25)
    let game = CantStopPages.game()
    let model = GameModel(game: game, graph: graph)
    let config = CantStopSceneConfig.config()
    let scene = GameScene(
      model: model,
      config: config,
      size: CGSize(width: 350, height: 400),
      cellSize: 20
    )
    scene.scaleMode = .aspectFit
    let pieces = CantStopPieceAdapter.pieces()

    self._model = State(initialValue: model)
    self._scene = State(initialValue: scene)
    self.graph = graph
    self._pieces = State(initialValue: pieces)

    let section = CantStopPieceAdapter.section(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section)
  }

  var body: some View {
    VStack(spacing: 0) {
      SpriteView(scene: scene)
        .frame(maxWidth: .infinity)
        .aspectRatio(350.0 / 400.0, contentMode: .fit)
      List {
        MCTSActionSection(model: model, actions: cachedActions) { action in
          performAction(action)
        }
      }
    }
    .navigationTitle("\(model.state.name): \(model.state.player)")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showConfig = true
        } label: {
          Image(systemName: "gearshape")
        }
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

  private func performAction(_ action: CantStop.Action) {
    model.perform(action)
  }

  private func syncScene() {
    let section = CantStopPieceAdapter.section(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section)
  }

  private func refreshActions() {
    let mode = playerModes[model.state.player, default: .interactive]
    guard mode == .interactive, !model.isTerminal else {
      cachedActions = []
      return
    }
    cachedActions = model.allowedActions
  }

  private func resetGame() {
    aiTask?.cancel()
    let activePlayers = CantStop.Player.allCases.filter {
      playerModes[$0, default: .excluded] != .excluded
    }
    let game = CantStopPages.game(players: activePlayers)
    model.reset(with: game)
    cachedActions = []

    let config = CantStopSceneConfig.config()
    let newScene = GameScene(
      model: model,
      config: config,
      size: CGSize(width: 350, height: 400),
      cellSize: 20
    )
    newScene.scaleMode = .aspectFit
    pieces = CantStopPieceAdapter.pieces()
    let section = CantStopPieceAdapter.section(from: model.state, graph: graph)
    newScene.syncState(pieces: pieces, section: section)
    scene = newScene

    showConfig = false
  }
}

#Preview("F My Luck") {
  NavigationStack {
    CantStopView()
  }
}
