//
//  HeartsComposedGameTests.swift
//  DynamicalSystems
//
//  Integration tests for Hearts composed game: full playthroughs,
//  phase transitions, follow-up cascading, game end.
//

import Testing
import Foundation

@MainActor
struct HeartsComposedGameTests {

  private func makeGame(
    scoreLimit: Int = 100,
    shuffledDeck: [Hearts.Card]? = nil
  ) -> ComposedGame<Hearts.State> {
    let allAI: [Hearts.Seat: PlayerMode] = [
      .north: .fastAI, .east: .fastAI,
      .south: .fastAI, .west: .fastAI
    ]
    let config = Hearts.HeartsConfig(
      playerModes: allAI, scoreLimit: scoreLimit)
    return Hearts.composedGame(
      config: config, shuffledDeck: shuffledDeck)
  }

  // MARK: - Initial State

  @Test
  func initialState_passingPhase() {
    let game = makeGame(shuffledDeck: Hearts.fullDeck)
    let state = game.newState()
    #expect(state.phase == .passing)
    #expect(state.handNumber == 0)
    #expect(state.passingState?.direction == .left)
  }

  @Test
  func allowedActions_inPassingPhase() {
    let game = makeGame(shuffledDeck: Hearts.fullDeck)
    let state = game.newState()
    let actions = game.allowedActions(state: state)
    // Should be selectPassCard for each card in current player's hand
    #expect(actions.count == 13)
    #expect(actions.allSatisfy {
      if case .selectPassCard = $0 { return true }
      return false
    })
  }

  // MARK: - Passing Phase Flow

  @Test
  func passingPhase_selectThreeThenConfirm() {
    let game = makeGame(shuffledDeck: Hearts.fullDeck)
    var state = game.newState()
    let hand = state.hands[state.player]!

    // Select 3 cards
    _ = game.reduce(into: &state, action: .selectPassCard(hand[0]))
    _ = game.reduce(into: &state, action: .selectPassCard(hand[1]))
    _ = game.reduce(into: &state, action: .selectPassCard(hand[2]))

    // Should now offer confirmPass
    let actions = game.allowedActions(state: state)
    #expect(actions.count == 1)
    #expect(actions.first == .confirmPass)

    _ = game.reduce(into: &state, action: .confirmPass)
    #expect(state.phase == .playing)
    #expect(state.passingState == nil)
  }

  // MARK: - Playing Phase

  @Test
  func playingPhase_firstTrickMustLead2OfClubs() {
    let game = makeGame(shuffledDeck: Hearts.fullDeck)
    var state = game.newState()

    // Skip to playing by doing a hold hand (hand 3)
    state.handNumber = 3
    state.phase = .playing
    state.passingState = nil
    state.player = state.holderOfTwoOfClubs
    state.turnNumber = 1

    let actions = game.allowedActions(state: state)
    #expect(actions == [.playCard(Hearts.twoOfClubs)])
  }

  // MARK: - Full Trick Cascade

  @Test
  func fullTrick_cascadesToResolveTrick() {
    let game = makeGame(shuffledDeck: Hearts.fullDeck)
    var state = game.newState()

    // Set up: skip to playing phase, trick 2 (so 2♣ constraint is gone)
    state.phase = .playing
    state.passingState = nil
    state.turnNumber = 2
    state.heartsBroken = true
    state.trickLeader = .north
    state.player = .north

    // Give each player one known card
    let cards: [Hearts.Seat: Hearts.Card] = [
      .north: Hearts.Card(suit: .clubs, rank: .ace),
      .east: Hearts.Card(suit: .clubs, rank: .king),
      .south: Hearts.Card(suit: .clubs, rank: .queen),
      .west: Hearts.Card(suit: .clubs, rank: .jack)
    ]
    for (seat, card) in cards where !(state.hands[seat]?.contains(card) ?? false) {
      state.hands[seat]?.append(card)
      state.hands[seat]?.sort()
    }

    // Play 4 cards
    _ = game.reduce(into: &state, action: .playCard(cards[.north]!))
    _ = game.reduce(into: &state, action: .playCard(cards[.east]!))
    _ = game.reduce(into: &state, action: .playCard(cards[.south]!))

    // Fourth card pauses in trickResolution
    let preTurn = state.turnNumber
    _ = game.reduce(into: &state, action: .playCard(cards[.west]!))
    #expect(state.phase == .trickResolution)
    #expect(state.currentTrick.count == 4)

    // Explicit resolve clears the trick
    _ = game.reduce(into: &state, action: .resolveTrick)
    #expect(state.currentTrick.isEmpty)
    #expect(state.player == .north) // A♣ wins
    #expect(state.turnNumber == preTurn + 1)
    #expect(state.phase == .playing) // back to playing for next trick
  }

  // MARK: - Full Hand to Score

  @Test
  func fullHand_13Tricks_cascadesToScoreHand() {
    let game = makeGame(scoreLimit: 200, shuffledDeck: Hearts.fullDeck)
    var state = game.newState()

    // Drive passing through composed game reduce
    let currentPlayer = state.player
    let hand = state.hands[currentPlayer]!
    _ = game.reduce(into: &state, action: .selectPassCard(hand[0]))
    _ = game.reduce(into: &state, action: .selectPassCard(hand[1]))
    _ = game.reduce(into: &state, action: .selectPassCard(hand[2]))

    _ = game.reduce(into: &state, action: .confirmPass)
    #expect(state.phase == .playing)

    // Play 13 tricks via allowedActions, resolving each trick explicitly
    var trickCount = 0
    while trickCount < 13 {
      let actions = game.allowedActions(state: state)
      if state.phase == .trickResolution {
        _ = game.reduce(into: &state, action: .resolveTrick)
        if state.phase == .handEnd || state.phase == .gameEnd {
          trickCount = 13
        } else {
          trickCount += 1
        }
        continue
      }
      guard let playAction = actions.first(where: {
        if case .playCard = $0 { return true }
        return false
      }) else { break }
      _ = game.reduce(into: &state, action: playAction)
    }

    // After 13 tricks, should have resolved through scoreHand
    let validPhases: [Hearts.Phase] = [.handEnd, .gameEnd]
    #expect(validPhases.contains(state.phase))
  }

  // MARK: - Game End Priority

  @Test
  func gameEndPage_firesAsPriority() {
    let game = makeGame(scoreLimit: 30, shuffledDeck: Hearts.fullDeck)
    var state = game.newState()
    state.ended = true
    state.endedInVictoryFor = [.south]
    state.endedInDefeatFor = [.north, .east, .west]
    state.phase = .gameEnd

    let actions = game.allowedActions(state: state)
    #expect(actions == [.declareWinner])

    _ = game.reduce(into: &state, action: .declareWinner)
    #expect(state.gameAcknowledged)

    // Terminal — no more actions
    let finalActions = game.allowedActions(state: state)
    #expect(finalActions.isEmpty)
  }

  // MARK: - Pass Direction Rotation

  @Test
  func passDirectionRotatesOverHands() {
    let game = makeGame(scoreLimit: 500, shuffledDeck: Hearts.fullDeck)
    var state = game.newState()
    #expect(state.passDirection == .left) // hand 0

    state.startNewHand(shuffledDeck: Hearts.fullDeck)
    #expect(state.passDirection == .right) // hand 1

    state.startNewHand(shuffledDeck: Hearts.fullDeck)
    #expect(state.passDirection == .across) // hand 2

    state.startNewHand(shuffledDeck: Hearts.fullDeck)
    #expect(state.passDirection == .none) // hand 3

    state.startNewHand(shuffledDeck: Hearts.fullDeck)
    #expect(state.passDirection == .left) // hand 4
  }

  // MARK: - AI vs AI Full Game

  @Test
  func allAI_fullGame_completesWithoutCrash() {
    let allAI: [Hearts.Seat: PlayerMode] = [
      .north: .fastAI, .east: .fastAI,
      .south: .fastAI, .west: .fastAI
    ]
    let config = Hearts.HeartsConfig(
      playerModes: allAI, scoreLimit: 50)
    let game = Hearts.composedGame(config: config)
    var state = game.newState()

    var moves = 0
    let maxMoves = 5000 // safety limit

    while !state.isTerminal && moves < maxMoves {
      let actions = game.allowedActions(state: state)
      guard let action = actions.first else { break }

      // For actions needing random data, provide it
      let resolvedAction: Hearts.Action
      switch action {
      case .startNewHand:
        resolvedAction = .startNewHand(
          shuffledDeck: Hearts.fullDeck.shuffled())
      default:
        resolvedAction = action
      }

      _ = game.reduce(into: &state, action: resolvedAction)
      moves += 1
    }

    #expect(state.ended)
    #expect(state.gameAcknowledged)
    #expect(!state.endedInVictoryFor.isEmpty)
  }

  // MARK: - MCTS from Passing Phase

  @Test
  func mctsFromPassingPhase_doesNotCrash() {
    let modes: [Hearts.Seat: PlayerMode] = [
      .north: .fastAI, .east: .fastAI,
      .south: .interactive, .west: .fastAI
    ]
    let config = Hearts.HeartsConfig(
      playerModes: modes, scoreLimit: 100)
    let game = Hearts.composedGame(
      config: config, shuffledDeck: Hearts.fullDeck)
    var state = game.newState()

    #expect(state.phase == .passing)

    // Manually simulate what MCTS does — step until empty actions
    var steps = 0
    while !state.isTerminal && steps < 500 {
      let actions = game.allowedActions(state: state)
      if actions.isEmpty {
        let msg = "Empty actions: step=\(steps) phase=\(state.phase) "
          + "player=\(state.player) trick=\(state.currentTrick.count) "
          + "turn=\(state.turnNumber) hand#=\(state.handNumber) ended=\(state.ended)"
        Issue.record("\(msg)")
        break
      }
      _ = game.reduce(into: &state, action: actions.randomElement()!)
      steps += 1
    }
  }

  // MARK: - MCTS Produces Legal Actions

  @Test
  func mctsProducesLegalActions() throws {
    let allAI: [Hearts.Seat: PlayerMode] = [
      .north: .fastAI, .east: .fastAI,
      .south: .fastAI, .west: .fastAI
    ]
    let config = Hearts.HeartsConfig(
      playerModes: allAI, scoreLimit: 100)
    let game = Hearts.composedGame(
      config: config, shuffledDeck: Hearts.fullDeck)
    var state = game.newState()

    // Skip to playing
    _ = game.reduce(into: &state, action: .selectPassCard(state.hands[state.player]![0]))
    _ = game.reduce(into: &state, action: .selectPassCard(state.hands[state.player]![1]))
    _ = game.reduce(into: &state, action: .selectPassCard(state.hands[state.player]![2]))
    _ = game.reduce(into: &state, action: .confirmPass)

    let search = OpenLoopMCTS(state: state, reducer: game)
    let results = try search.recommendation(iters: 50)
    #expect(!results.isEmpty)

    let legalActions = Set(game.allowedActions(state: state))
    for action in results.keys {
      #expect(legalActions.contains(action))
    }
  }
}
