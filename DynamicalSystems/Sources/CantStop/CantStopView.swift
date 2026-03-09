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
    private let graph: SiteGraph
    private let pieces: [GamePiece]

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
        self.pieces = pieces

        let section = CantStopPieceAdapter.section(from: model.state, graph: graph)
        scene.syncState(pieces: pieces, section: section)
    }

    var body: some View {
        VStack(spacing: 0) {
            SpriteView(scene: scene)
                .frame(maxWidth: .infinity)
                .aspectRatio(350.0 / 400.0, contentMode: .fit)
            List {
                ForEach(cachedActions, id: \.self) { action in
                    Button(action.description) {
                        performAction(action)
                    }
                }
            }
        }
        .navigationTitle("\(model.state.name): \(model.state.player)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshActions() }
    }

    private func performAction(_ action: CantStop.Action) {
        model.perform(action)
        refreshActions()
        let section = CantStopPieceAdapter.section(from: model.state, graph: graph)
        scene.syncState(pieces: pieces, section: section)
    }

    private func refreshActions() {
        cachedActions = model.allowedActions
    }
}

#Preview("F My Luck") {
  CantStopView()
}
