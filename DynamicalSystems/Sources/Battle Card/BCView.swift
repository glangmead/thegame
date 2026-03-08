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
    private let scene: GameScene<BattleCard.State, BattleCard.Action>
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
            size: CGSize(width: 400, height: 400)
        )
        let pieces = BCPieceAdapter.pieces()

        self._model = State(initialValue: model)
        self.scene = scene
        self.graph = graph
        self.pieces = pieces

        let section = BCPieceAdapter.section(from: model.state, graph: graph)
        scene.syncState(pieces: pieces, section: section)
    }

    private func performAction(_ action: BattleCard.Action) {
        model.perform(action)
        let section = BCPieceAdapter.section(from: model.state, graph: graph)
        scene.syncState(pieces: pieces, section: section)
    }

    var body: some View {
        NavigationStack {
            SpriteView(scene: scene)
                .frame(width: 400, height: 400)
            Form {
                ForEach(model.allowedActions, id: \.self) { action in
                    Button(action.description) {
                        performAction(action)
                    }
                }
            }
            .navigationTitle(model.state.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("Battle Card") {
    BCView()
}
