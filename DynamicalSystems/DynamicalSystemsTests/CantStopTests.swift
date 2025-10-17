//
//  CantStopTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/17/25.
//

import ComposableArchitecture
import Testing

@MainActor
struct CantStopTests {
  @Test
  func initialState() async {
    let store = TestStore(initialState: CantStop.State()) {
      CantStop()
    }
    await store.send(.pass) {
      $0.player = Player.twop(.player2)
    }
    await store.send(.rollDice) {
      $0.phase = .rolled
      $0.dice[.die1] = DSix.four
      $0.dice[.die2] = DSix.four
      $0.dice[.die3] = DSix.four
      $0.dice[.die4] = DSix.four
    }
    await store.send(.assignDicePair(Pair<Die>(fst: .die1, snd: .die2))) {
      $0.dice[.die1] = DSix.none
      $0.dice[.die2] = DSix.none
      $0.assignedDicePair = Column.eight
    }
    await store.send(.progressColumns) {
      $0.assignedDicePair = Column.none
      $0.position[.white1] = BoardSpot(col: Column.eight, row: 1)
    }
    await store.send(.assignDicePair(Pair<Die>(fst: .die3, snd: .die4))) {
      $0.dice[.die3] = DSix.none
      $0.dice[.die4] = DSix.none
      $0.assignedDicePair = Column.eight
    }
    await store.send(.progressColumns) {
      $0.assignedDicePair = Column.none
      $0.position[.white1] = BoardSpot(col: Column.eight, row: 2)
      $0.phase = .notRolled
    }
  }
}
