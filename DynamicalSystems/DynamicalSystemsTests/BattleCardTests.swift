//
//  BattleCardTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 11/3/25.
//

import ComposableArchitecture
import Testing

@MainActor
struct BattleCardTests {
  @Test
  func gameplay() async {
    let store = TestStore(initialState: BattleCard.State()) {
      BattleCard()
    }
}
