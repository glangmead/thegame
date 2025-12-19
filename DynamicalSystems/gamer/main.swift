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
  @Option(help: "Whether to print out the UI") private var printUI: Bool = true
  var colwidths = [15, 10, 3, 10, 10, 10, 3, 20]

  mutating func run() throws {
    let game = BattleCard()
    var state = BattleCard.State()
    var done = false
    var numWins = 0
    var numLosses = 0
    var numGames = 0
    while(!done) {
      if let action = getAction(game: game, state: state, auto: numTrials > 1) {
        let logs = game.reduce(state: &state, action: action)
        if printUI {
          for log in logs { print(log.msg) }
        }
      } else {
        numGames += 1
        if numGames >= numTrials {
          done = true
        }
        if state.endedInDefeat {
          numLosses += 1
        }
        if state.endedInVictory {
          numWins += 1
        }
        print("\(numLosses) losses, \(numWins) wins, \(numGames) games total.")
        state = BattleCard.State()
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
      if printUI {
        print(formattedLine)
      }
    }
    if printUI {
      for (index, action) in actions.enumerated() {
        print("\(index+1). \(action.name)")
      }
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
