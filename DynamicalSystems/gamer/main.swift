//
//  main.swift
//  gamer
//
//  Created by Greg Langmead on 12/3/25.
//

import Foundation

let game = BattleCard()
var state = BattleCard.State()
var action: BattleCard.Action? = nil
var done = false
while(!done) {
  if let action = getAction(state: state) {
    BattleCard.reduce(state: &state, action: action)
  } else {
    done = true
  }
}

func getAction(state: BattleCard.State) -> BattleCard.Action? {
  let actions = BattleCard.allowedActions(state: state)
  for action in actions {
    print(action.name)
  }
  let typed = readLine()!
  let typedNum = Int(typed) ?? 0
  if typedNum < actions.count {
    return actions[typedNum]
  }
  return nil
}
