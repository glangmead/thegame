//
//  LoDView.swift
//  DynamicalSystems
//
//  Legions of Darkness — SwiftUI view with SpriteKit board and action list.
//

import SpriteKit
import SwiftUI

struct LoDView: View {
  @State private var model: GameModel<LoD.State, LoD.Action>
  @State private var scene: GameScene<LoD.State, LoD.Action>
  @State private var cachedActions: [LoD.Action] = []
  @State private var logs: [Log] = []
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  init() {
    let graph = LoDGraph.board(cellSize: 30)
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    let model = GameModel(game: game, graph: graph)
    let config = LoDSceneConfig.config()
    let scene = GameScene(
      model: model,
      config: config,
      size: CGSize(width: 480, height: 480),
      cellSize: 30
    )
    scene.scaleMode = .aspectFit
    let pieces = LoDPieceAdapter.pieces()

    self._model = State(initialValue: model)
    self._scene = State(initialValue: scene)
    self.graph = graph
    self.pieces = pieces

    let section = LoDPieceAdapter.section(from: model.state, graph: graph)
    let highlights = LoDPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  var body: some View {
    GeometryReader { geo in
      let isLandscape = geo.size.width > geo.size.height
      let layout = isLandscape
        ? AnyLayout(HStackLayout(spacing: 0))
        : AnyLayout(VStackLayout(spacing: 0))
      layout {
        boardView(squareSize: isLandscape ? geo.size.height : geo.size.width)
        actionPanel
      }
    }
    .navigationTitle("Legions of Darkness")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { refreshActions() }
  }

  private func boardView(squareSize: CGFloat) -> some View {
    SpriteView(scene: scene)
      .frame(width: squareSize, height: squareSize)
  }

  private var actionPanel: some View {
    VStack(spacing: 0) {
      statusBar
      List {
        if !logs.isEmpty {
          Section("Log") {
            ForEach(logs, id: \.msg) { log in
              Text(log.msg)
                .font(.caption)
            }
          }
        }
        Section("Actions") {
          ForEach(cachedActions, id: \.self) { action in
            Button(action.description) {
              performAction(action)
            }
          }
        }
      }
    }
  }

  private var statusBar: some View {
    HStack {
      Label(model.state.phase.rawValue.capitalized, systemImage: "flag")
      Spacer()
      Label("Time \(model.state.timePosition)/15", systemImage: "clock")
      Spacer()
      Label("Morale: \(model.state.morale.rawValue.capitalized)", systemImage: "heart")
    }
    .font(.caption.bold())
    .padding(.horizontal)
    .padding(.vertical, 6)
  }

  private func performAction(_ action: LoD.Action) {
    let newLogs = model.perform(action)
    logs = newLogs
    refreshActions()
    let section = LoDPieceAdapter.section(from: model.state, graph: graph)
    let highlights = LoDPieceAdapter.siteHighlights(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: highlights)
  }

  private func refreshActions() {
    cachedActions = model.allowedActions
  }
}

#Preview("Legions of Darkness") {
  NavigationStack {
    LoDView()
  }
}
