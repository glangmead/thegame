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
  @Option(help: "Whether to print out the UI") private var printUI: Bool = true
  @Option(help: "Where to print out the MCTS log") private var logFile: String = "gamertool.log"
  @Option(help: "Whether to show MCTS opinions") private var showAIHints: Bool = false
  var colwidths = [15, 10, 3, 10, 10, 10, 3, 20]

  mutating func run() throws {
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
        if printUI {
          print(formattedLine)
        }
      }
      print("")
      
      if let action = getAction(game: game, state: state, auto: numTrials > 0) {
        let logs = game.reduce(state: &state, action: action)
        if printUI {
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
          print("\(numLosses) losses, \(numWins) wins, \(numGames) games total.")
        }
        state = BattleCard.State()
      }
    }
  }
  
  func getAction(game: BattleCard, state: BattleCard.State, auto: Bool) -> BattleCard.Action? {
    let actions = game.allowedActions(state: state)
    let (aiAction, aiValue, aiCount) = treeSearch(game: game, state: state)
    let ratio = abs((aiValue + Float(aiCount)) / (2 * Float(aiCount)))
    
    if printUI {
      for (index, action) in actions.enumerated() {
        let hint = (showAIHints && (action == aiAction)) ? "" : ""
        let val  = (showAIHints && (action == aiAction)) ? "[⚛️  \(ratio.formatted(.percent.precision(.significantDigits(0...2)))) win rate (\(aiCount) trials)]" : ""
        print("\(index+1). \(hint)\(action.name) \(val)")
      }
    }
    
    if auto {
      return aiAction
    } else {
      let typed = readLine()!
      let typedNum = (Int(typed) ?? 1) - 1
      if typedNum < actions.count {
        return actions[typedNum]
      }
    }
    return nil
  }
  
  func treeSearch(game: BattleCard, state: BattleCard.State) -> (BattleCard.Action?, Float, Int) {
    let search = TreeSearch(state: state, reducer: game)
    let aiAction = search.recommendation(iters: numMCTSIters)
    if !logFile.isEmpty {
      var logStream: any TextOutputStream = LogDestination(path: logFile)
      //print("treeSearch from state \(state)", to: &logStream)
      search.rootNode.printTree(level: 0, to: &logStream)
    }
    var value: Float = 0.0
    var count: Int = 0
    if aiAction != nil {
      value = search.rootNode.children[aiAction!]?.valueSum ?? 0
      count = search.rootNode.children[aiAction!]?.visitCount ?? 0
    }
    return (aiAction, value, count)
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
