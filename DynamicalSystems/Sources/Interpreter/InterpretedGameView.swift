//
//  InterpretedGameView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/19/26.
//

import SpriteKit
import SwiftUI

struct InterpretedGameView: View {
  @State private var model: GameModel<InterpretedState, ActionValue>
  @State private var scene: GameScene<InterpretedState, ActionValue>?
  @State private var cameraScale: CGFloat = 1.0
  @State private var cameraPosition: CGPoint = .zero
  private let game: ComposedGame<InterpretedState>
  private let hasBoard: Bool

  init(game: ComposedGame<InterpretedState>) {
    self.game = game
    let graph = game.graph
    let hasSites = !graph.sites.isEmpty
    self.hasBoard = hasSites
    let model = GameModel(game: game, graph: graph)
    self._model = State(initialValue: model)

    if hasSites {
      let trackHeights = graph.trackOrder.map {
        graph.tracks[$0]?.count ?? 0
      }
      let config: SceneConfig = .container(game.gameName, [
        .board(
          .columnar(heights: trackHeights),
          style: game.sceneStyle ?? StyleConfig(
            stroke: "black", lineWidth: 1
          )),
        .piece(.circle, color: .byPlayer)
      ])
      let numTracks = trackHeights.count
      let maxHeight = trackHeights.max() ?? 1
      let cellSize: CGFloat = 80
      let sceneW = CGFloat(numTracks) * cellSize + cellSize
      let sceneH = CGFloat(maxHeight) * cellSize + cellSize
      let scene = GameScene(
        model: model,
        config: config,
        size: CGSize(width: sceneW, height: sceneH),
        cellSize: cellSize
      )
      scene.scaleMode = .aspectFit
      self._scene = State(initialValue: scene)
      self._cameraScale = State(
        initialValue: scene.cameraNode?.xScale ?? 1
      )
      self._cameraPosition = State(
        initialValue: scene.cameraNode?.position ?? .zero
      )
      let adapter = InterpretedPieceAdapter(
        state: model.state,
        schema: model.state.schema,
        graph: graph,
        playerIndex: game.playerIndex,
        pieceDisplayNames: game.pieceDisplayNames
      )
      scene.syncState(
        pieces: adapter.pieces, section: adapter.section
      )
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      if hasBoard, let scene {
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
                x: cameraPosition.x
                  - value.translation.width * currentScale,
                y: cameraPosition.y
                  + value.translation.height * currentScale))
            }
            .onEnded { value in
              let currentScale = scene.cameraNode?.xScale ?? 1
              cameraPosition = CGPoint(
                x: cameraPosition.x
                  - value.translation.width * currentScale,
                y: cameraPosition.y
                  + value.translation.height * currentScale)
            }
          )
          .frame(maxWidth: .infinity)
          .aspectRatio(scene.size.width / scene.size.height, contentMode: .fit)
      }
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
          let names = game.pieceDisplayNames
          MCTSActionSection(
            model: model,
            actions: model.allowedActions,
            displayName: { $0.displayName { names[$0] } },
            onAction: { action in
              model.perform(action)
              syncScene()
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
            ForEach(
              Array(model.logs.enumerated()), id: \.offset
            ) { _, log in
              Text(log.msg)
                .font(.caption)
            }
          }
        }
      }
    }
    .navigationTitle(model.gameName)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { syncScene() }
    .onChange(of: model.state) { syncScene() }
  }

  // MARK: - Scene sync

  private func syncScene() {
    guard let scene else { return }
    let adapter = InterpretedPieceAdapter(
      state: model.state,
      schema: model.state.schema,
      graph: game.graph,
      playerIndex: game.playerIndex,
      pieceDisplayNames: game.pieceDisplayNames
    )
    scene.syncState(pieces: adapter.pieces, section: adapter.section)
  }

  // MARK: - Bundle loading

  static func loadBundleGame(
    _ name: String
  ) -> ComposedGame<InterpretedState> {
    guard let url = Bundle.main.url(
      forResource: name, withExtension: "game"
    ) else {
      fatalError("Missing resource: \(name).game")
    }
    // swiftlint:disable:next force_try
    let source = try! String(contentsOf: url)
    // swiftlint:disable:next force_try
    return try! GameBuilder.build(from: source)
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

#Preview("Interpreted Board Game") {
  NavigationStack {
    InterpretedGameView(
      game: InterpretedGameView.loadBundleGame("BattleCard")
    )
  }
}
