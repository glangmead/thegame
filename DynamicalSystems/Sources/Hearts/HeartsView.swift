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
  @State private var showConfig = false
  @State var playerModes: [Hearts.Seat: PlayerMode] = [
    .north: .fastAI,
    .east: .fastAI,
    .south: .interactive,
    .west: .fastAI
  ]
  @State var aiTask: Task<Void, Never>?
  @State private var cameraScale: CGFloat = 1.0
  @State private var cameraPosition: CGPoint = .zero
  @Environment(\.horizontalSizeClass) private var sizeClass
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  private enum PanelTab: String, CaseIterable {
    case actions = "Actions"
    case log = "Log"
  }

  private var slots: [PlayerSlot<Hearts.Seat>] {
    let modes: [PlayerMode] = [.interactive, .fastAI, .slowAI]
    return Hearts.Seat.allCases.map {
      PlayerSlot(
        player: $0, label: $0.description,
        allowedModes: modes)
    }
  }

  init() {
    let defaultModes: [Hearts.Seat: PlayerMode] = [
      .north: .fastAI, .east: .fastAI,
      .south: .interactive, .west: .fastAI
    ]
    let config = Hearts.HeartsConfig(playerModes: defaultModes)
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
    scene.backgroundColor = SKColor(
      red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0)
    let pieces = HeartsPieceAdapter.pieces()

    self._model = State(initialValue: model)
    self._scene = State(initialValue: scene)
    self.graph = graph
    self.pieces = pieces

    let section = HeartsPieceAdapter.section(
      from: model.state, graph: graph)
    scene.syncState(
      pieces: pieces, section: section, siteHighlights: [:])
  }

  var body: some View {
    GeometryReader { geo in
      let isLandscape = geo.size.width > geo.size.height
      let layout = isLandscape
        ? AnyLayout(HStackLayout(spacing: 0))
        : AnyLayout(VStackLayout(spacing: 0))
      layout {
        SpriteView(scene: scene)
          .gesture(MagnifyGesture()
            .onChanged { value in
              let newScale = cameraScale / value.magnification
              scene.setZoom(scale: newScale)
            }
            .onEnded { value in
              cameraScale /= value.magnification
            }
          )
          .gesture(DragGesture()
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
          .frame(
            width: isLandscape
              ? geo.size.height : geo.size.width,
            height: isLandscape
              ? geo.size.height : geo.size.width
          )
        actionPanel
      }
    }
    .navigationTitle("Hearts")
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
        ForEach(
          Array(model.logs.enumerated()), id: \.offset
        ) { _, log in
          Text(log.msg)
            .font(.caption)
        }
      }
    }
  }

  private var actionList: some View {
    List {
      MCTSActionSection(
        model: model, actions: cachedActions
      ) { action in
        performAction(action)
      }
    }
  }

  private var statusBar: some View {
    HStack {
      Label(
        "Hand \(model.state.handNumber + 1)",
        systemImage: "suit.heart")
      Spacer()
      Label(
        "Trick \(model.state.turnNumber)",
        systemImage: "number")
      Spacer()
      Label(
        model.state.passDirection.description,
        systemImage: "arrow.left.arrow.right")
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
    model.perform(action)
  }

  private func syncScene() {
    let section = HeartsPieceAdapter.section(
      from: model.state, graph: graph)
    scene.syncState(
      pieces: pieces, section: section, siteHighlights: [:])
  }

  private func refreshActions() {
    let mode = playerModes[
      model.state.player, default: .interactive]
    let isTrickResolution =
      model.state.phase == .trickResolution
    guard mode == .interactive,
          !isTrickResolution,
          !model.isTerminal else {
      cachedActions = []
      return
    }
    cachedActions = model.allowedActions
  }

  private func resetGame() {
    aiTask?.cancel()
    let config = Hearts.HeartsConfig(
      playerModes: playerModes)
    let game = Hearts.composedGame(config: config)
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

#Preview("Hearts") {
  NavigationStack {
    HeartsView()
  }
}
