//
//  CantStopView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import ComposableArchitecture
import SpriteKit
import SwiftUI

struct CantStopView: View {
  var store: StoreOf<CantStop>
  var scene: SKScene
  var aiPlayer: CantStopRandomPlayer
  let aiMoveStr = "*"
  let notAIMoveStr = ""
  
  init(store: StoreOf<CantStop>) {
    self.store = store
    self.scene = CantStopScene(
      store: SharedReader(value: store),
      size: CGSize(width: 400, height: 300)
    )
    // TODO: Where can I find a CantStop()
    self.aiPlayer = CantStopRandomPlayer(state: store.state, game: CantStop())
  }
  
  var body: some View {
    NavigationStack {
      SpriteView(scene: scene)
        .frame(width: 400, height: 300)
      Form {
        ForEach(CantStop().allowedActions(state: store.state), id: \.self) { action in
          Button("\(action.name)") {
//          Button("\(action.name) \(aiPlayer.chooseAction(state: store.state, game: CantStop()) == action ? aiMoveStr : notAIMoveStr)") {
            store.send(action)
          }
        }
      }
      .navigationTitle("\(store.state.name): \(store.state.player.name)")
      .navigationBarTitleDisplayMode(.inline)
    }
    Button("Recheck rules") {
      let _ = CantStop().allowedActions(state: store.state)
    }
    Text("\(CantStop().allowedActions(state: store.state).count) actions available")
    
  }
}

#Preview("F My Luck") {
  CantStopView(store: Store(initialState: CantStop.State()) {
    CantStop()
  })
}
