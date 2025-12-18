//
//  main.swift
//  gamer
//
//  Created by Greg Langmead on 12/3/25.
//

import Foundation

let colwidths = [15, 10, 3, 10, 10, 10, 3, 20]

let game = BattleCard()
var state = BattleCard.State()
var action: BattleCard.Action? = nil
var done = false
while(!done) {
  if let action = getAction(state: state) {
    let logs = BattleCard.reduce(state: &state, action: action)
    for log in logs { print(log.msg) }
  } else {
    done = true
  }
}

func getAction(state: BattleCard.State) -> BattleCard.Action? {
  let actions = BattleCard.allowedActions(state: state)
  for stateLine in state.asText() {
    var formattedLine = ""
    for (index, piece) in stateLine.enumerated() {
      formattedLine.append(piece.padding(toLength: colwidths[index], withPad: " ", startingAt: 0))
    }
    print(formattedLine)
  }
  for (index, action) in actions.enumerated() {
    print("\(index+1). \(action.name)")
  }
  let typed = readLine()!
  let typedNum = (Int(typed) ?? 1) - 1
  if typedNum < actions.count {
    return actions[typedNum]
  }
  return nil
}
