//
//  HeartsView.swift
//  DynamicalSystems
//
//  Hearts — SwiftUI view with SpriteKit card table and action panel.
//

import SpriteKit
import SwiftUI

struct HeartsView: View {
  @State var model: GameModel<Hearts.State, Hearts.Action>
  @State private var scene: GameScene<Hearts.State, Hearts.Action>
  @State private var cachedActions: [Hearts.Action] = []
  @State private var selectedTab: PanelTab = .actions
  @State var aiTask: Task<Void, Never>?
  @Environment(\.horizontalSizeClass) private var sizeClass
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  private enum PanelTab: String, CaseIterable {
    case actions = "Actions"
    case log = "Log"
  }

  init(config: Hearts.HeartsConfig = Hearts.HeartsConfig()) {
    let graph = HeartsGraph.board(cellSize: 30)
    let game = Hearts.composedGame(config: config)
    let model = GameModel(game: game, graph: graph)
    let sceneConfig = HeartsSceneConfig.config()
    let scene = GameScene(
      model: model,
      config: sceneConfig,
      size: CGSize(width: 360, height: 360),
      cellSize: 30
    )
    scene.scaleMode = .aspectFit
    scene.backgroundColor = SKColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0)
    let pieces = HeartsPieceAdapter.pieces()

    self._model = State(initialValue: model)
    self._scene = State(initialValue: scene)
    self.graph = graph
    self.pieces = pieces

    let section = HeartsPieceAdapter.section(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: [:])
  }

  var body: some View {
    GeometryReader { geo in
      let isLandscape = geo.size.width > geo.size.height
      let layout = isLandscape
        ? AnyLayout(HStackLayout(spacing: 0))
        : AnyLayout(VStackLayout(spacing: 0))
      layout {
        SpriteView(scene: scene)
          .frame(
            width: isLandscape ? geo.size.height : geo.size.width,
            height: isLandscape ? geo.size.height : geo.size.width
          )
        actionPanel
      }
    }
    .navigationTitle("Hearts")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { refreshActions() }
    .onDisappear { aiTask?.cancel() }
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
      actionList
      Divider()
      logList
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
        actionList.tag(PanelTab.actions)
        logList.tag(PanelTab.log)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
    }
  }

  private var logList: some View {
    List {
      Section("Log") {
        ForEach(Array(model.logs.enumerated()), id: \.offset) { _, log in
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

  private var statusBar: some View {
    HStack {
      Label("Hand \(model.state.handNumber + 1)", systemImage: "suit.heart")
      Spacer()
      Label("Trick \(model.state.turnNumber)", systemImage: "number")
      Spacer()
      Label(model.state.passDirection.description, systemImage: "arrow.left.arrow.right")
      Spacer()
      if model.state.heartsBroken {
        Label("Broken", systemImage: "heart.fill")
          .foregroundStyle(.red)
      }
    }
    .font(.caption.bold())
    .padding(.horizontal)
    .padding(.vertical, 6)
  }

  // MARK: - Logic

  func performAction(_ action: Hearts.Action) {
    // Intercept confirmPass: populate AI pass selections
    let resolved: Hearts.Action
    if case .confirmPass = action {
      var aiPasses: [Hearts.Seat: [Hearts.Card]] = [:]
      for seat in Hearts.Seat.allCases where seat != model.state.config.humanSeat {
        aiPasses[seat] = Array(model.state.hands[seat]?.prefix(3) ?? [])
      }
      resolved = .confirmPass(aiPasses: aiPasses)
    } else {
      resolved = action
    }

    model.perform(resolved)
    refreshActions()
    syncScene()
    scheduleAIIfNeeded()
  }

  private func syncScene() {
    let section = HeartsPieceAdapter.section(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section, siteHighlights: [:])
  }

  private func refreshActions() {
    let isAIPlayTurn = model.state.phase == .playing
      && model.state.player != model.state.config.humanSeat
    let isTrickResolution = model.state.phase == .trickResolution
    cachedActions = (isAIPlayTurn || isTrickResolution) ? [] : model.allowedActions
  }

}

#Preview("Hearts") {
  NavigationStack {
    HeartsView(config: Hearts.HeartsConfig(humanSeat: .south))
  }
}
