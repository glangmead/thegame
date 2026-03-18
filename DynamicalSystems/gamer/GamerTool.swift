//
//  GamerTool.swift
//  gamer
//
//  Created by Greg Langmead on 12/3/25.
//

import ArgumentParser
import Foundation

enum Games: String, Codable, ExpressibleByArgument {
  case cantStop = "CantStop"
  case battleCard = "BattleCard"
  case BCMC = "MalayanCampaign"
  case legionsOfDarkness = "LegionsOfDarkness"
  case hearts = "Hearts"
}

@main
struct GamerTool: AsyncParsableCommand {
  @Option(help: "Number of trials to run") private var numTrials: Int = 0
  @Option(help: "Number of MCTS search iterations to run for each action") private var numMCTSIters: Int = 1
  @Option(help: "Number of MCTS rollouts to run for each iteration") private var numRollouts: Int = 1
  @Option(help: "Whether to print out the UI") private var interactive: Bool = true
  @Option(help: "Where to print out the MCTS log") private var logFile: String = ""
  @Option(help: "Whether to show MCTS opinions") private var showAIHints: Bool = false
  @Option(help: "Which game to play") private var game: Games

  // swiftlint:disable:next function_body_length
  mutating func run() async throws {
    switch game {
    case .cantStop:
      var gameRunner = GameRunner(
        reducer: CantStopPages.game(),
        numTrials: numTrials,
        numMCTSIters: numMCTSIters,
        numRollouts: numRollouts,
        interactive: interactive,
        logFile: logFile,
        showAIHints: showAIHints
      )
      await gameRunner.run()
    case .battleCard:
      var gameRunner = GameRunner(
        reducer: BCPages.game(),
        numTrials: numTrials,
        numMCTSIters: numMCTSIters,
        numRollouts: numRollouts,
        interactive: interactive,
        logFile: logFile,
        showAIHints: showAIHints
      )
      await gameRunner.run()
    case .BCMC:
      var gameRunner = GameRunner(
        reducer: MCPages.game(),
        numTrials: numTrials,
        numMCTSIters: numMCTSIters,
        numRollouts: numRollouts,
        interactive: interactive,
        logFile: logFile,
        showAIHints: showAIHints
      )
      await gameRunner.run()
    case .legionsOfDarkness:
      var gameRunner = GameRunner(
        reducer: LoD.composedGame(windsOfMagicArcane: 3),
        numTrials: numTrials,
        numMCTSIters: numMCTSIters,
        numRollouts: numRollouts,
        interactive: interactive,
        logFile: logFile,
        showAIHints: showAIHints
      )
      await gameRunner.run()
    case .hearts:
      var gameRunner = GameRunner(
        reducer: Hearts.composedGame(
          config: Hearts.HeartsConfig(playerModes: [
            .north: .fastAI, .east: .fastAI,
            .south: .fastAI, .west: .fastAI
          ])),
        numTrials: numTrials,
        numMCTSIters: numMCTSIters,
        numRollouts: numRollouts,
        interactive: interactive,
        logFile: logFile,
        showAIHints: showAIHints
      )
      await gameRunner.run()
    }
  }
}

struct GameRunner<
  Reducer: PlayableGame & Sendable
> where
  Reducer.State: GameState & TextTableAble & CustomStringConvertible & Sendable,
  Reducer.Action: Hashable & Equatable & CustomStringConvertible & Sendable {

  typealias State = Reducer.State
  typealias Action = Reducer.Action

  private var numTrials: Int = 0
  private var numMCTSIters: Int = 1
  private var numRollouts: Int = 1
  private var interactive: Bool = true
  private var logFile: String = ""
  private var showAIHints: Bool = false
  private var reducer: Reducer

  var colwidths: [Int]

  init(
    reducer: Reducer,
    numTrials: Int,
    numMCTSIters: Int,
    numRollouts: Int,
    interactive: Bool,
    logFile: String,
    showAIHints: Bool,
    colwidths: [Int] = [10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]
  ) {
    self.reducer = reducer
    self.numTrials = numTrials
    self.numMCTSIters = numMCTSIters
    self.numRollouts = numRollouts
    self.interactive = interactive
    self.logFile = logFile
    self.showAIHints = showAIHints
    self.colwidths = colwidths
  }

  mutating func run() async {
    if numTrials > 0 {
      interactive = false
      await runParallelTrials()
    } else {
      runInteractive()
    }
  }

  private func runParallelTrials() async {
    let player = reducer.newState().player
    let trialCount = numTrials
    let iters = numMCTSIters
    let rollouts = numRollouts
    let reducer = self.reducer

    let cores = ProcessInfo.processInfo.activeProcessorCount
    print("Running \(trialCount) trials across \(cores) cores "
      + "(\(iters) MCTS iters)...")
    fflush(stdout)

    var numWins = 0
    var numLosses = 0
    var numGames = 0

    // Limit in-flight tasks to core count so the for-await loop
    // gets a thread to print progress between completions.
    await withTaskGroup(of: (won: Bool, lost: Bool, String).self) { group in
      var launched = 0
      for _ in 0..<min(trialCount, cores) {
        group.addTask {
          playOneTrial(reducer: reducer, player: player, iters: iters, rollouts: rollouts)
        }
        launched += 1
      }
      for await (won, lost, table) in group {
        if launched < trialCount {
          group.addTask {
            playOneTrial(reducer: reducer, player: player, iters: iters, rollouts: rollouts)
          }
          launched += 1
        }
        if won { numWins += 1 }
        if lost { numLosses += 1 }
        numGames += 1
        print(table)
        let avg = (Float(numWins) / Float(numGames)).formatted(
          .number.precision(.significantDigits(4)))
        print("\(numWins)\t\(numLosses)\t\(avg)\t\(iters)\t\(rollouts)"
          + "\t(\(numGames)/\(trialCount))")
        fflush(stdout)
      }
    }
  }

  private mutating func runInteractive() {
    var stdout = StandardOutput()
    var state = reducer.newState()
    let player = state.player
    var done = false
    var numWins = 0
    var numLosses = 0
    var numGames = 0
    while !done {
      state.printTable(to: &stdout)
      print("")

      if let action = getAction(state: state, auto: false) {
        let logs = reducer.reduce(into: &state, action: action)
        for log in logs { print(log.msg) }
      } else {
        numGames += 1
        if state.endedInDefeatFor.contains(player) {
          numLosses += 1
        }
        if state.endedInVictoryFor.contains(player) {
          numWins += 1
        }
        if numGames >= numTrials && numTrials > 0 {
          done = true
        }
        let avg = (Float(numWins) / Float(numGames)).formatted(
          .number.precision(.significantDigits(4)))
        print("\(numWins)\t\(numLosses)\t\(avg)\t\(numMCTSIters)\t\(numRollouts)")
        state = reducer.newState()
      }
    }
  }

  func getAction(state: State, auto: Bool) -> Action? {
    let actions = reducer.allowedActions(state: state)
    guard !actions.isEmpty else { return nil }
    if actions.count == 1 { return actions[0] }

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
        let val: String
        if showAIHints {
          let pct = ratio(results[action]!).formatted(
            .percent.precision(.significantDigits(0...2)))
          let cnt = results[action]!.1.formatted()
          val = "[  \(pct) win rate (\(cnt) trials)]"
        } else {
          val = ""
        }
        print("\(index+1). \(hint)\(action.description) \(val)")
      }
    }

    if auto {
      return bestAction ?? actions.first
    } else {
      let typed = readLine()!
      let typedNum = (Int(typed) ?? 1) - 1
      if typedNum < actions.count {
        return actions[typedNum]
      }
    }
    return nil
  }

  func treeSearch(state: State) -> [Action: (Float, Float)] {
    let search = OpenLoopMCTS(state: state, reducer: reducer)
    let results = (try? search.recommendation(iters: numMCTSIters, numRollouts: numRollouts)) ?? [:]
    if !logFile.isEmpty {
      var logStream: any TextOutputStream = LogDestination(path: logFile)
      search.printTree(to: &logStream)
    }
    return results
  }
}

/// Play one complete game, returning win/loss result.
/// Free function so it can be called from a `TaskGroup.addTask` closure.
private func playOneTrial<Reducer: PlayableGame & Sendable>(
  reducer: Reducer,
  player: Reducer.State.Player,
  iters: Int,
  rollouts: Int
) -> (won: Bool, lost: Bool, table: String)
where Reducer.State: GameState & TextTableAble & Sendable & CustomStringConvertible,
      Reducer.Action: Hashable & Equatable & CustomStringConvertible {
  var state = reducer.newState()
  while !reducer.isTerminal(state: state) {
    let actions = reducer.allowedActions(state: state)
    guard !actions.isEmpty else { break }
    let action: Reducer.Action
    if actions.count == 1 {
      action = actions[0]
    } else {
      do {
        let search = OpenLoopMCTS(state: state, reducer: reducer)
        let results = try search.recommendation(iters: iters, numRollouts: rollouts)
        let ratio: ((Float, Float)) -> Float = { val in
          val.0 / (val.1 > 0 ? val.1 : 1)
        }
        let bestValue = results.values.map({ ratio($0) }).max() ?? 0
        let bestAction = results.keys.filter { key in
          ratio(results[key]!).near(bestValue)
        }.randomElement()
        action = bestAction ?? actions[0]
      } catch {
        var tableString = ""
        state.printTable(to: &tableString)
        action = actions[0]
      }
    }
    _ = reducer.reduce(into: &state, action: action)
  }
  var tableString = ""
  state.printTable(to: &tableString)
  return (
    won: state.endedInVictoryFor.contains(player),
    lost: state.endedInDefeatFor.contains(player),
    table: tableString
  )
}
