//
//  BCEngine.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import ComposableArchitecture
import Foundation

@Reducer
struct BattleCard: LookaheadReducer {
  enum Action: Hashable, Equatable, Sendable {
    case roll
  }
  
  enum Rule {
    
  }
  
  static func rules() -> [Rule] {
    return []
  }

  static func allowedActions(state: State) -> [Action] {
    return []
  }
  
  static func reduce(state: inout State, action: Action) {
  }

  var body: some Reducer<State, Action> {
    Reduce { st, act in
      BattleCard.reduce(state: &st, action: act)
      return .none
    }
  }
}
