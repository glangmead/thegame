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
  @Option(help: "Number of trials to run") private var numTrials: Int = 0
  @Option(help: "Number of MCTS search iterations to run for each action") private var numMCTSIters: Int = 1
  @Option(help: "Number of MCTS rollouts to run for each iteration") private var numRollouts: Int = 1
  @Option(help: "Whether to print out the UI") private var interactive: Bool = true
  @Option(help: "Where to print out the MCTS log") private var logFile: String = ""
  @Option(help: "Whether to show MCTS opinions") private var showAIHints: Bool = false
  var colwidths = [15, 10, 3, 10, 10, 10, 3, 20]

  mutating func run() throws {
    if numTrials > 0 {
      interactive = false
    }
    let game = BattleCard()
    var state = BattleCard.State()
    var done = false
    var numWins = 0
    var numLosses = 0
    var numGames = 0
    while(!done) {
      // print state
      for stateLine in state.asText() {
        var formattedLine = ""
        for (index, piece) in stateLine.enumerated() {
          formattedLine.append(piece.padding(toLength: colwidths[index], withPad: " ", startingAt: 0))
        }
        if interactive {
          print(formattedLine)
        }
      }
      if interactive {
        print("")
      }
      
      if let action = getAction(game: game, state: state, auto: numTrials > 0) {
        let logs = game.reduce(state: &state, action: action)
        if interactive {
          for log in logs { print(log.msg) }
        }
      } else {
        numGames += 1
        if state.endedInDefeat {
          numLosses += 1
        }
        if state.endedInVictory {
          numWins += 1
        }
        if numGames >= numTrials {
          done = true
          let battingAverage = Float(numWins) / Float(numGames)
          print("\(numWins)\t\(numLosses)\t\(battingAverage.formatted(.number.precision(.significantDigits(4))))\t\(numMCTSIters)\t\(numRollouts)")
        }
        state = BattleCard.State()
      }
    }
  }
  
  func getAction(game: BattleCard, state: BattleCard.State, auto: Bool) -> BattleCard.Action? {
    let actions = game.allowedActions(state: state)
    let results = treeSearch(game: game, state: state)
    let ratio: ((Float, Float)) -> Float = { valCount in
      let val = valCount.0
      let count = valCount.1
      return val / (count > 0 ? count : 1)
    }

    let bestValue = results.values.map({ ratio($0) }).max() ?? 0
    let bestAction = results.keys.filter { action in
      ratio(results[action]!).near(bestValue)
    }.randomElement()
    if interactive {
      for (index, action) in actions.enumerated() {
        let hint = (showAIHints && (action == bestAction)) ? "🤖 " : "  "
        let val  = showAIHints ? "[⚛️  \(ratio(results[action]!).formatted(.percent.precision(.significantDigits(0...2)))) win rate (\(results[action]!.1.formatted()) trials)]" : ""
        print("\(index+1). \(hint)\(action.name) \(val)")
      }
    }
    
    if auto {
      return bestAction
    } else {
      let typed = readLine()!
      let typedNum = (Int(typed) ?? 1) - 1
      if typedNum < actions.count {
        return actions[typedNum]
      }
    }
    return nil
  }
  
  func treeSearch(game: BattleCard, state: BattleCard.State) -> [BattleCard.Action:(Float, Float)] {
    let search = OpenLoopMCTS(state: state, reducer: game)
    let results = search.recommendation(iters: numMCTSIters, numRollouts: numRollouts)
    if !logFile.isEmpty {
      var logStream: any TextOutputStream = LogDestination(path: logFile)
      //print("treeSearch from state \(state)", to: &logStream)
      search.printTree(to: &logStream)
    }
    return results
  }
}

final class LogDestination: TextOutputStream {
  private let path: String
  init(path: String) {
    self.path = path
  }
  
  func write(_ string: String) {
    if let data = string.data(using: .utf8), let fileHandle = FileHandle(forWritingAtPath: path) {
      defer {
        fileHandle.closeFile()
      }
      fileHandle.seekToEndOfFile()
      fileHandle.write(data)
    }
  }
}
