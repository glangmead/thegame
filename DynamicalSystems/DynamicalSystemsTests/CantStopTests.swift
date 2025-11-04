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
  func rules() async {
    var state = CantStop.State()
    state.dice[.die1] = .one
    state.dice[.die2] = .two
    state.dice[.die3] = CantStop.DSix.none
    state.dice[.die4] = CantStop.DSix.none
    #expect(CantStop.allowedActions(state: state) == [
      CantStop.Action.sequence([
        .assignDicePair(Pair<CantStop.Die>(fst: .die1, snd: .die2)),
        .progressColumn(.three)
      ])
    ])
  }
  
  @Test
  func gameplay() async {
    let store = TestStore(initialState: CantStop.State()) {
      CantStop()
    }
    
    await store.send(.pass) {
      $0.player = CantStop.Player.player2
    }
    
    await store.send(.forceRoll([.four, .four, .four, .four])) {
      $0.dice[.die1] = .four
      $0.dice[.die2] = .four
      $0.dice[.die3] = .four
      $0.dice[.die4] = .four
    }
    
    // sending a .sequence creates indirection, hence store.receives right after
    await store.send(.sequence([.assignDicePair(Pair<CantStop.Die>(fst: .die1, snd: .die2)), .progressColumn(.eight)])) {
      $0.dice[.die1] = CantStop.DSix.none
      $0.dice[.die2] = CantStop.DSix.none
      $0.assignedDicePair = CantStop.Column.eight
      $0.assignedDicePair = CantStop.Column.none
      $0.position[.white(.white1)] = CantStop.Position(col: .eight, row: 1)
    }
    
    await store.send(.assignDicePair(Pair<CantStop.Die>(fst: .die3, snd: .die4))) {
      $0.dice[.die3] = CantStop.DSix.none
      $0.dice[.die4] = CantStop.DSix.none
      $0.assignedDicePair = .eight
    }
    
    await store.send(.progressColumn(.eight)) {
      $0.assignedDicePair = CantStop.Column.none
      $0.position[.white(.white1)] = CantStop.Position(col: .eight, row: 2)
    }
    
    await store.send(.sequence([
      .progressColumn(.two),
      .progressColumn(.two),
      .progressColumn(.two),
      .progressColumn(.twelve),
      .progressColumn(.twelve),
      .progressColumn(.twelve),
    ])) {
      $0.position[.white(.white2)] = CantStop.Position(col: .two, row: 3)
      $0.position[.white(.white3)] = CantStop.Position(col: .twelve, row: 3)
    }
    
    await store.send(.pass) {
      $0.player = .player1
      $0.position[.placeholder(.player2, .two)]    = CantStop.Position(col: .two, row: 3)
      $0.position[.placeholder(.player2, .twelve)] = CantStop.Position(col: .twelve, row: 3)
      $0.position[.placeholder(.player2, .eight)]  = CantStop.Position(col: .eight, row: 2)
      $0.position[.white(.white1)] = CantStop.Position(col: .none, row: 0)
      $0.position[.white(.white2)] = CantStop.Position(col: .none, row: 0)
      $0.position[.white(.white3)] = CantStop.Position(col: .none, row: 0)
    }

    await store.send(.pass) {
      $0.player = .player2
    }
    
    await store.send(.sequence([
      .progressColumn(.eight),
      .progressColumn(.eight),
      .progressColumn(.eight),
      .progressColumn(.eight),
      .progressColumn(.eight),
      .progressColumn(.eight),
      .progressColumn(.eight),
      .progressColumn(.eight),
      .progressColumn(.eight),
    ])) {
      $0.position[.white(.white1)] = CantStop.Position(col: .eight, row: 11)
    }

    await store.send(.claimVictory) {
      $0.ended = true
    }
  }
}
