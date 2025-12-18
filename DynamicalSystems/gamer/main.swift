//
//  main.swift
//  gamer
//
//  Created by Greg Langmead on 12/3/25.
//

import ArgumentParser
import Foundation

GamerTool.main()

struct GamerTool: ParsableCommand {
  @Option(help: "Number of trials to run") private var numTrials: Int = 1
  var colwidths = [15, 10, 3, 10, 10, 10, 3, 20]

  mutating func run() throws {
    let game = BattleCard()
    var state = BattleCard.State()
    var done = false
    while(!done) {
      if let action = getAction(game: game, state: state, auto: numTrials > 1) {
        let logs = game.reduce(state: &state, action: action)
        for log in logs { print(log.msg) }
      } else {
        done = true
      }
    }
  }
  
  func getAction(game: BattleCard, state: BattleCard.State, auto: Bool) -> BattleCard.Action? {
    let actions = game.allowedActions(state: state)
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
    if auto {
      return actions.randomElement()
    } else {
      let typed = readLine()!
      let typedNum = (Int(typed) ?? 1) - 1
      if typedNum < actions.count {
        return actions[typedNum]
      }
    }
    return nil
  }
}
