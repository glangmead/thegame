//
//  BCView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import ComposableArchitecture
import SwiftUI

struct BattleCardView: View {
  let store: StoreOf<BattleCard>
  
  var body: some View {
  }
}

#Preview("Battle Card Market Garden") {
  BattleCardView(store: Store(initialState: BattleCard.State()) {
    BattleCard()
  })
}
