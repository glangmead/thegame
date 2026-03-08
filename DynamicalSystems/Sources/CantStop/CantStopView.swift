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
  private let scene: GameScene<CantStop.State, CantStop.Action>
  private let graph: SiteGraph
  private let pieces: [GamePiece]

  init() {
    let graph = CantStopGraph.board()
    let game = CantStopPages.game()
    let model = GameModel(game: game, graph: graph)
    let config = CantStopSceneConfig.config()
    let scene = GameScene(
      model: model,
      config: config,
      size: CGSize(width: 600, height: 500)
    )
    let pieces = CantStopPieceAdapter.pieces()

    self._model = State(initialValue: model)
    self.scene = scene
    self.graph = graph
    self.pieces = pieces

    // Initial sync
    let section = CantStopPieceAdapter.section(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section)
  }

  var body: some View {
    NavigationStack {
      SpriteView(scene: scene)
        .frame(width: 600, height: 500)
      Form {
        ForEach(model.allowedActions, id: \.self) { action in
          Button(action.description) {
            performAction(action)
          }
        }
      }
      .navigationTitle("\(model.state.name): \(model.state.player)")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func performAction(_ action: CantStop.Action) {
    model.perform(action)
    let section = CantStopPieceAdapter.section(from: model.state, graph: graph)
    scene.syncState(pieces: pieces, section: section)
  }
}

#Preview("F My Luck") {
  CantStopView()
}
