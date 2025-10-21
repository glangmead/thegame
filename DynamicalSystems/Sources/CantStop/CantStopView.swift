//
//  CantStopView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import ComposableArchitecture
import SwiftUI

struct CantStopView: View {
  let store: StoreOf<CantStop>
  
  var body: some View {
    Form {
      ForEach(Column.allCases, id: \.self) { col in
        if col != .none {
          ForEach(store.state.boardReport[col]!, id: \.self) { piece in
            let row = store.state.position[piece]!.row
            Text("\(col.name).\(row): \(piece.name)")
          }
        }
      }
      ForEach(Die.allCases, id: \.self) { die in
        let dieState = store.state.diceReport[die]!
        Text("\(die.name): \(dieState.name)")
      }
      ForEach(CantStop.allowedActions(state: store.state), id: \.self) { action in
        Button("\(action.name)") {
          store.send(action)
        }
      }
    }
  }
}

#Preview("Can't Stop™®") {
  CantStopView(store: Store(initialState: CantStop.State()) {
    CantStop()
  })
}
