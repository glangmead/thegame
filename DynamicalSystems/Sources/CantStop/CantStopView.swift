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
  let aiMoveStr = "*"
  let notAIMoveStr = ""
  
  init(store: StoreOf<CantStop>) {
    self.store = store
    self.scene = CantStopScene(
      store: SharedReader(value: store),
      size: CGSize(width: 400, height: 300)
    )
  }
  
  var body: some View {
    NavigationStack {
      SpriteView(scene: scene)
        .frame(width: 400, height: 300)
      Form {
        ForEach(store.withState { CantStop().allowedActions(state: $0) }, id: \.self) { action in
          Button("\(action.name)") {
            store.send(action)
          }
        }
      }
      .navigationTitle("\(store.name): \(store.player)")
      .navigationBarTitleDisplayMode(.inline)
    }
    Button("Recheck rules") {
      _ = store.withState { CantStop().allowedActions(state: $0) }
    }
    Text("\(store.withState { CantStop().allowedActions(state: $0) }.count) actions available")
    
  }
}

#Preview("F My Luck") {
  CantStopView(store: Store(initialState: CantStop.State()) {
    CantStop()
  })
}
