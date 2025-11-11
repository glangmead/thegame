//
//  CantStopView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import ComposableArchitecture
import SpriteKit
import SwiftUI

// A simple game scene with falling boxes
struct CantStopView: View {
  var store: StoreOf<CantStop>
  
  var scene: SKScene
  
  init(store: StoreOf<CantStop>) {
    self.store = store
    self.scene = CantStopScene(
      state: SharedReader(value: store.state),
      size: CGSize(width: 400, height: 300)
    )
  }
  
  var body: some View {
    NavigationStack {
      Button("Recheck rules") {
        let _ = CantStop.allowedActions(state: store.state)
      }
      Text("\(CantStop.allowedActions(state: store.state).count) actions available")
      
      SpriteView(scene: scene)
        .frame(width: 400, height: 300)
      
      Form {
        ForEach(CantStop.Column.allCases, id: \.self) { col in
          if col != .none {
            ForEach(store.state.boardReport[col]!, id: \.self) { piece in
              let row = store.state.position[piece]!.row
              if row > 0 {
                Text("\(col.name).\(row): \(piece.name)")
                  .fontWeight(row == CantStop.colHeights()[col]! ? .bold : .regular)
              }
            }
          }
        }
        ForEach(CantStop.Die.allCases, id: \.self) { die in
          let dieState = store.state.diceReport[die]!
          Text("\(die.name): \(dieState.name)")
        }
        ForEach(CantStop.allowedActions(state: store.state), id: \.self) { action in
          Button("\(action.name)") {
            store.send(action)
          }
        }
      }
      .navigationTitle("F My Luck: \(store.state.player.name)")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview("F My Luck") {
  CantStopView(store: Store(initialState: CantStop.State()) {
    CantStop()
  })
}
