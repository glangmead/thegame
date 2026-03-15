//
//  LoDView.swift
//  DynamicalSystems
//
//  Legions of Darkness — SwiftUI view with SpriteKit board and action list.
//

import SpriteKit
import SwiftUI

// swiftlint:disable type_body_length
struct LoDView: View {
  @State private var model: GameModel<LoD.State, LoD.Action>
  @State private var scene: GameScene<LoD.State, LoD.Action>
  @State private var cachedActions: [LoD.Action] = []
  @State private var showConfig = false
  @State private var playerModes: [LoD.Player: PlayerMode] = [
    .solo: .interactive
  ]
  @State private var aiTask: Task<Void, Never>?
  @State private var cameraScale: CGFloat = 1.0
  @State private var cameraPosition: CGPoint = .zero
  @State private var selectedTab: PanelTab = .actions
  @State private var boardMode: BoardMode = .abstract
  @State private var vassalScene: LoDVassalScene?
  @State private var vassalGraph: SiteGraph?
  @State private var vassalAvailable = false
  @Environment(\.horizontalSizeClass) private var sizeClass
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  private enum PanelTab: String, CaseIterable {
    case actions = "Actions"
    case board = "Board"
    case log = "Log"
  }

  private enum BoardMode {
    case abstract
    case vassal
  }

  private var slots: [PlayerSlot<LoD.Player>] {
    [PlayerSlot(
      player: .solo, label: "Solo",
      allowedModes: [.interactive, .fastAI, .slowAI])]
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
    self._cameraScale = State(initialValue: scene.cameraNode?.xScale ?? 1)
    self._cameraPosition = State(initialValue: scene.cameraNode?.position ?? .zero)

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
    .onAppear {
      refreshActions()
      let available = LoDVassalAssetLoader.isAvailable
      vassalAvailable = available
    }
    .onChange(of: model.state) {
      refreshActions()
      syncActiveScene()
      aiTask?.cancel()
      aiTask = scheduleAIMove(
        model: model,
        playerModes: playerModes,
        performAction: performAction
      )
    }
    .onDisappear { aiTask?.cancel() }
  }

  // swiftlint:disable:next function_body_length
  private func boardView(squareSize: CGFloat) -> some View {
    Group {
      switch boardMode {
      case .abstract:
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
      case .vassal:
        if let vScene = vassalScene {
          SpriteView(scene: vScene)
        } else {
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
        }
      }
    }
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
      actionList
      Divider()
      boardSummary
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
        boardSummary.tag(PanelTab.board)
        logList.tag(PanelTab.log)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
    }
  }

  // MARK: - Lists

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
      MCTSActionSection(
        model: model, actions: cachedActions,
        grouping: { $0.actionGroup },
        onAction: { performAction($0) }
      )
    }
  }

  private var boardSummary: some View {
    List {
      BoardSummarySections(
        graph: graph,
        pieces: pieces,
        section: LoDPieceAdapter.section(from: model.state, graph: graph))
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
      if vassalAvailable {
        Spacer()
        Button(boardMode == .abstract ? "Map" : "Grid") {
          toggleBoardMode()
        }
        .buttonStyle(.bordered)
        .font(.caption)
      }
    }
    .font(.caption.bold())
    .padding(.horizontal)
    .padding(.vertical, 6)
  }

  // MARK: - Logic

  private func performAction(_ action: LoD.Action) {
    model.perform(action)
  }

  private func syncActiveScene() {
    switch boardMode {
    case .abstract:
      let section = LoDPieceAdapter.section(from: model.state, graph: graph)
      let highlights = LoDPieceAdapter.siteHighlights(
        from: model.state, graph: graph)
      scene.syncState(
        pieces: pieces, section: section, siteHighlights: highlights)
    case .vassal:
      if let vScene = vassalScene, let vGraph = vassalGraph {
        let section = LoDPieceAdapter.section(from: model.state, graph: vGraph)
        vScene.syncState(pieces: pieces, section: section)
      }
    }
  }

  private func toggleBoardMode() {
    switch boardMode {
    case .abstract:
      if vassalScene == nil {
        guard let boardImage = LoDVassalAssetLoader.loadBoardImage() else {
          print("toggleBoardMode: loadBoardImage() returned nil")
          return
        }
        guard let sitesFile = LoDVassalAssetLoader.loadSites() else {
          print("toggleBoardMode: loadSites() returned nil, folder: \(String(describing: LoDVassalAssetLoader.moduleFolder))")
          return
        }
        let vScene = LoDVassalScene(boardImage: boardImage, sites: sitesFile)
        vassalScene = vScene
        vassalGraph = vScene.vassalGraph
      }
      boardMode = .vassal
      syncActiveScene()
    case .vassal:
      boardMode = .abstract
      syncActiveScene()
    }
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
    let game = LoD.composedGame(windsOfMagicArcane: 3)
    model.reset(with: game)
    cachedActions = []
    syncActiveScene()
    showConfig = false
    aiTask = scheduleAIMove(
      model: model,
      playerModes: playerModes,
      performAction: performAction
    )
  }
}
// swiftlint:enable type_body_length

#Preview("Legions of Darkness") {
  NavigationStack {
    LoDView()
  }
}
