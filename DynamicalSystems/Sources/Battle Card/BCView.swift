//
//  BCView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25
//

import SpriteKit
import SwiftUI

struct BCView: View {
    @State private var model: GameModel<BattleCard.State, BattleCard.Action>
    @State private var scene: GameScene<BattleCard.State, BattleCard.Action>
    @State private var cachedActions: [BattleCard.Action] = []
    private let graph: SiteGraph
    private let pieces: [GamePiece]

    init() {
        let graph = BCGraph.board()
        let game = BCPages.game()
        let model = GameModel(game: game, graph: graph)
        let config = BCSceneConfig.config()
        let scene = GameScene(
            model: model,
            config: config,
            size: CGSize(width: 250, height: 320)
        )
        scene.scaleMode = .aspectFit
        let pieces = BCPieceAdapter.pieces()

        self._model = State(initialValue: model)
        self._scene = State(initialValue: scene)
        self.graph = graph
        self.pieces = pieces

        let section = BCPieceAdapter.section(from: model.state, graph: graph)
        scene.syncState(pieces: pieces, section: section)
    }

    var body: some View {
        VStack(spacing: 0) {
            SpriteView(scene: scene)
                .frame(maxWidth: .infinity)
                .aspectRatio(250.0 / 320.0, contentMode: .fit)
            List {
                ForEach(cachedActions, id: \.self) { action in
                    Button(action.description) {
                        performAction(action)
                    }
                }
            }
        }
        .navigationTitle(model.state.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshActions() }
    }

    private func performAction(_ action: BattleCard.Action) {
        model.perform(action)
        refreshActions()
        let section = BCPieceAdapter.section(from: model.state, graph: graph)
        scene.syncState(pieces: pieces, section: section)
    }

    private func refreshActions() {
        cachedActions = model.allowedActions
    }
}

#Preview("Battle Card") {
    BCView()
}
