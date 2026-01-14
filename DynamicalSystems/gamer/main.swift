//
//  main.swift
//  gamer
//
//  Created by Greg Langmead on 12/3/25.
//

import ArgumentParser
import ComposableArchitecture
import Foundation

GamerTool.main()

enum Games: String, Codable, ExpressibleByArgument {
  case CantStop = "CantStop"
  case BattleCard = "BattleCard"
}

struct GamerTool: ParsableCommand {
  @Option(help: "Number of trials to run") private var numTrials: Int = 0
  @Option(help: "Number of MCTS search iterations to run for each action") private var numMCTSIters: Int = 1
  @Option(help: "Number of MCTS rollouts to run for each iteration") private var numRollouts: Int = 1
  @Option(help: "Whether to print out the UI") private var interactive: Bool = true
  @Option(help: "Where to print out the MCTS log") private var logFile: String = ""
  @Option(help: "Whether to show MCTS opinions") private var showAIHints: Bool = false
  @Option(help: "Which game to play") private var game: Games

  mutating func run() throws {
    do {
      switch game {
      case .CantStop:
        var gameRunner = GameRunner<CantStop.State, CantStop.Action>(
          reducer: CantStop(),
          numTrials: numTrials,
          numMCTSIters: numMCTSIters,
          numRollouts: numRollouts,
          interactive: interactive,
          logFile: logFile,
          showAIHints: showAIHints
        )
        try gameRunner.run()
      case .BattleCard:
        var gameRunner = GameRunner<BattleCard.State, BattleCard.Action>(
          reducer: BattleCard(),
          numTrials: numTrials,
          numMCTSIters: numMCTSIters,
          numRollouts: numRollouts,
          interactive: interactive,
          logFile: logFile,
          showAIHints: showAIHints
        )
        try gameRunner.run()
      }
    }
  }
}

struct GameRunner<
  State: GameState & TextTableAble & CustomStringConvertible,
  Action: Hashable & Equatable & CustomStringConvertible
>{
  private var numTrials: Int = 0
  private var numMCTSIters: Int = 1
  private var numRollouts: Int = 1
  private var interactive: Bool = true
  private var logFile: String = ""
  private var showAIHints: Bool = false
  private var reducer: any LookaheadReducer<State, Action>
  
  var colwidths: [Int]

  init(
    reducer: some LookaheadReducer<State, Action>,
    numTrials: Int,
    numMCTSIters: Int,
    numRollouts: Int,
    interactive: Bool,
    logFile: String,
    showAIHints: Bool,
    colwidths: [Int] = [10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
  ){
    self.reducer = reducer
    self.numTrials = numTrials
    self.numMCTSIters = numMCTSIters
    self.numRollouts = numRollouts
    self.interactive = interactive
    self.logFile = logFile
    self.showAIHints = showAIHints
    self.colwidths = colwidths
  }
  
  mutating func run() throws {
    var stdout = StandardOutput()
    if numTrials > 0 {
      interactive = false
    }
    var state = reducer.newState()
    let player = state.player
    var done = false
    var numWins = 0
    var numLosses = 0
    var numGames = 0
    while(!done) {
      // print state
      state.printTable(to: &stdout)
      if interactive {
        print("")
      }
      
      if let action = getAction(state: state, auto: numTrials > 0) {
        let logs = reducer.reduce(into: &state, action: action)
        if interactive {
          for log in logs { print(log.msg) }
        }
      } else {
        numGames += 1
        if state.endedInDefeatFor.contains(where: {$0 == player}) {
          numLosses += 1
        }
        if state.endedInVictoryFor.contains(where: {$0 == player}) {
          numWins += 1
        }
        let battingAverage = Float(numWins) / Float(numGames)
        if numGames >= numTrials {
          done = true
        }
        print("\(numWins)\t\(numLosses)\t\(battingAverage.formatted(.number.precision(.significantDigits(4))))\t\(numMCTSIters)\t\(numRollouts)")
        state = reducer.newState()
      }
    }
  }
  
  func getAction(state: State, auto: Bool) -> Action? {
    let actions = reducer.allowedActions(state: state)
    let results = treeSearch(state: state)
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
        print("\(index+1). \(hint)\(action.description) \(val)")
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
  
  func treeSearch(state: State) -> [Action:(Float, Float)] {
    let search = OpenLoopMCTS(state: state, reducer: reducer)
    let results = search.recommendation(iters: numMCTSIters, numRollouts: numRollouts)
    if !logFile.isEmpty {
      var logStream: any TextOutputStream = LogDestination(path: logFile)
      //print("treeSearch from state \(state)", to: &logStream)
      search.printTree(to: &logStream)
    }
    return results
  }
}
