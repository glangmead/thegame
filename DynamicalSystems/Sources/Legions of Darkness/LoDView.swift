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
  @State private var selectedTab: PanelTab = .actions
  @Environment(\.horizontalSizeClass) private var sizeClass
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  private enum PanelTab: String, CaseIterable {
    case log = "Log"
    case actions = "Actions"
  }

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

  // MARK: - Panel

  private var actionPanel: some View {
    VStack(spacing: 0) {
      statusBar
      if sizeClass == .regular {
        ipadPanel
      } else {
        iphonePanel
      }
    }
  }

  private var ipadPanel: some View {
    HStack(spacing: 0) {
      logList
      Divider()
      actionList
    }
  }

  private var iphonePanel: some View {
    VStack(spacing: 0) {
      Picker("Panel", selection: $selectedTab) {
        ForEach(PanelTab.allCases, id: \.self) { tab in
          Text(tab.rawValue).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.vertical, 4)

      TabView(selection: $selectedTab) {
        logList.tag(PanelTab.log)
        actionList.tag(PanelTab.actions)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
    }
  }

  // MARK: - Lists

  private var logList: some View {
    List {
      Section("Log") {
        ForEach(Array(logs.enumerated()), id: \.offset) { _, log in
          Text(log.msg)
            .font(.caption)
        }
      }
    }
  }

  private var actionList: some View {
    List {
      MCTSActionSection(model: model, actions: cachedActions) { action in
        performAction(action)
      }
    }
  }

  // MARK: - Status

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

  // MARK: - Logic

  private func performAction(_ action: LoD.Action) {
    let newLogs = model.perform(action)
    logs.insert(contentsOf: newLogs, at: 0)
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
