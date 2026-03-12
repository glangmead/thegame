//
//  HeartsStateTests.swift
//  DynamicalSystems
//
//  Tests for Hearts state: deal, passing, legal plays, trick resolution,
//  scoring, shooting the moon, game end.
//

import Testing
import Foundation

@MainActor
// swiftlint:disable:next type_body_length
struct HeartsStateTests {

  // Deterministic deck: cards dealt round-robin (index % 4 = seat)
  private var testDeck: [Hearts.Card] { Hearts.fullDeck }

  private func makeState(
    scoreLimit: Int = 100,
    humanSeat: Hearts.Seat? = .south
  ) -> Hearts.State {
    let config = Hearts.HeartsConfig(
      humanSeat: humanSeat, scoreLimit: scoreLimit)
    return Hearts.State.newGame(config: config, shuffledDeck: testDeck)
  }

  // MARK: - Deal

  @Test
  func dealGivesEachPlayer13Cards() {
    let state = makeState()
    for seat in Hearts.Seat.allCases {
      #expect(state.hands[seat]?.count == 13)
    }
  }

  @Test
  func dealDistributesAll52Cards() {
    let state = makeState()
    let allCards = Hearts.Seat.allCases.flatMap { state.hands[$0] ?? [] }
    #expect(Set(allCards).count == 52)
  }

  @Test
  func initialPhaseIsPassing() {
    let state = makeState()
    // Hand 0 mod 4 = 0 → pass left
    #expect(state.phase == .passing)
    #expect(state.passingState?.direction == .left)
  }

  @Test
  func handsAreSorted() {
    let state = makeState()
    for seat in Hearts.Seat.allCases {
      let hand = state.hands[seat]!
      #expect(hand == hand.sorted())
    }
  }

  // MARK: - Passing

  @Test
  func passLeft_cardsGoToNextSeat() {
    var state = makeState()

    // Build AI passes: each AI passes their first 3 cards
    var aiPasses: [Hearts.Seat: [Hearts.Card]] = [:]
    for seat in Hearts.Seat.allCases where seat != .south {
      aiPasses[seat] = Array(state.hands[seat]!.prefix(3))
    }
    let humanCards = Array(state.hands[.south]!.prefix(3))

    let northBefore = state.hands[.north]!

    state.executePasses(humanCards: humanCards, aiPasses: aiPasses)

    // North passes left to East: East should have North's passed cards
    let northPassed = Array(northBefore.prefix(3))
    for card in northPassed {
      #expect(state.hands[.east]!.contains(card))
    }

    #expect(state.phase == .playing)
    #expect(state.passingState == nil)
  }

  @Test
  func passRight_cardsGoToPreviousSeat() {
    var state = makeState()
    state.handNumber = 1 // hand 1 mod 4 = 1 → right
    state.passingState = Hearts.State.PassingState(
      direction: .right)

    var aiPasses: [Hearts.Seat: [Hearts.Card]] = [:]
    for seat in Hearts.Seat.allCases where seat != .south {
      aiPasses[seat] = Array(state.hands[seat]!.prefix(3))
    }
    let humanCards = Array(state.hands[.south]!.prefix(3))

    let eastPassed = Array(state.hands[.east]!.prefix(3))

    state.executePasses(humanCards: humanCards, aiPasses: aiPasses)

    // East passes right (offset 3 → north): North gets East's cards
    for card in eastPassed {
      #expect(state.hands[.north]!.contains(card))
    }
  }

  // MARK: - Legal Plays

  @Test
  func firstTrickMustLead2OfClubs() {
    var state = makeState()
    // Skip passing
    var aiPasses: [Hearts.Seat: [Hearts.Card]] = [:]
    for seat in Hearts.Seat.allCases where seat != .south {
      aiPasses[seat] = Array(state.hands[seat]!.prefix(3))
    }
    let humanCards = Array(state.hands[.south]!.prefix(3))
    state.executePasses(humanCards: humanCards, aiPasses: aiPasses)

    state.player = state.holderOfTwoOfClubs
    state.turnNumber = 1
    let plays = state.legalPlays
    #expect(plays == [Hearts.twoOfClubs])
  }

  @Test
  func mustFollowSuit() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    state.heartsBroken = true

    // Set up: south has both clubs and hearts
    state.hands[.south] = [
      Hearts.Card(suit: .clubs, rank: .three),
      Hearts.Card(suit: .clubs, rank: .king),
      Hearts.Card(suit: .hearts, rank: .five)
    ]
    state.currentTrick = [
      Hearts.TrickPlay(
        seat: .north,
        card: Hearts.Card(suit: .clubs, rank: .ace))
    ]
    state.player = .south

    let plays = state.legalPlays
    // Must follow clubs
    #expect(plays.count == 2)
    #expect(plays.allSatisfy { $0.suit == .clubs })
  }

  @Test
  func voidInSuit_canPlayAnything() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    state.heartsBroken = true

    state.hands[.south] = [
      Hearts.Card(suit: .hearts, rank: .five),
      Hearts.Card(suit: .diamonds, rank: .king)
    ]
    state.currentTrick = [
      Hearts.TrickPlay(
        seat: .north,
        card: Hearts.Card(suit: .clubs, rank: .ace))
    ]
    state.player = .south

    let plays = state.legalPlays
    #expect(plays.count == 2)
  }

  @Test
  func firstTrick_voidInSuit_noPenaltyCards() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 1

    // South has no clubs, but has hearts and Q♠
    state.hands[.south] = [
      Hearts.Card(suit: .hearts, rank: .five),
      Hearts.queenOfSpades,
      Hearts.Card(suit: .diamonds, rank: .king)
    ]
    state.currentTrick = [
      Hearts.TrickPlay(
        seat: .north,
        card: Hearts.twoOfClubs)
    ]
    state.player = .south

    let plays = state.legalPlays
    // Only non-penalty cards allowed
    #expect(plays == [Hearts.Card(suit: .diamonds, rank: .king)])
  }

  @Test
  func firstTrick_onlyPenaltyCards_canPlayThem() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 1

    state.hands[.south] = [
      Hearts.Card(suit: .hearts, rank: .five),
      Hearts.queenOfSpades
    ]
    state.currentTrick = [
      Hearts.TrickPlay(
        seat: .north,
        card: Hearts.twoOfClubs)
    ]
    state.player = .south

    let plays = state.legalPlays
    #expect(plays.count == 2)
  }

  @Test
  func cannotLeadHeartsUnbroken() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    state.heartsBroken = false
    state.currentTrick = []

    state.hands[.south] = [
      Hearts.Card(suit: .clubs, rank: .three),
      Hearts.Card(suit: .hearts, rank: .five)
    ]
    state.player = .south

    let plays = state.legalPlays
    #expect(plays == [Hearts.Card(suit: .clubs, rank: .three)])
  }

  @Test
  func canLeadHeartsIfOnlyHaveHearts() {
    var state = makeState()
    state.phase = .playing
    state.turnNumber = 2
    state.heartsBroken = false
    state.currentTrick = []

    state.hands[.south] = [
      Hearts.Card(suit: .hearts, rank: .five),
      Hearts.Card(suit: .hearts, rank: .king)
    ]
    state.player = .south

    let plays = state.legalPlays
    #expect(plays.count == 2)
  }

  // MARK: - Trick Resolution

  @Test
  func trickWinner_highestOfLedSuit() {
    var state = makeState()
    state.currentTrick = [
      Hearts.TrickPlay(seat: .north, card: Hearts.Card(suit: .clubs, rank: .five)),
      Hearts.TrickPlay(seat: .east, card: Hearts.Card(suit: .clubs, rank: .king)),
      Hearts.TrickPlay(seat: .south, card: Hearts.Card(suit: .clubs, rank: .two)),
      Hearts.TrickPlay(seat: .west, card: Hearts.Card(suit: .clubs, rank: .ace))
    ]
    #expect(state.trickWinner == .west)
  }

  @Test
  func trickWinner_offSuitDoesNotWin() {
    var state = makeState()
    state.currentTrick = [
      Hearts.TrickPlay(seat: .north, card: Hearts.Card(suit: .clubs, rank: .five)),
      Hearts.TrickPlay(seat: .east, card: Hearts.Card(suit: .hearts, rank: .ace)),
      Hearts.TrickPlay(seat: .south, card: Hearts.Card(suit: .clubs, rank: .king)),
      Hearts.TrickPlay(seat: .west, card: Hearts.Card(suit: .diamonds, rank: .ace))
    ]
    // Highest club wins (K♣ = south), not the off-suit aces
    #expect(state.trickWinner == .south)
  }

  @Test
  func resolveTrick_setsWinnerAsLeader() {
    var state = makeState()
    state.turnNumber = 1
    state.currentTrick = [
      Hearts.TrickPlay(seat: .north, card: Hearts.Card(suit: .clubs, rank: .five)),
      Hearts.TrickPlay(seat: .east, card: Hearts.Card(suit: .clubs, rank: .king)),
      Hearts.TrickPlay(seat: .south, card: Hearts.Card(suit: .clubs, rank: .two)),
      Hearts.TrickPlay(seat: .west, card: Hearts.Card(suit: .clubs, rank: .ace))
    ]
    state.resolveTrick()

    #expect(state.trickLeader == .west)
    #expect(state.player == .west)
    #expect(state.currentTrick.isEmpty)
    #expect(state.tricksTaken[.west]?.count == 1)
    #expect(state.turnNumber == 2)
  }

  @Test
  func resolveTrick_breaksHearts() {
    var state = makeState()
    state.turnNumber = 2
    state.heartsBroken = false
    state.currentTrick = [
      Hearts.TrickPlay(seat: .north, card: Hearts.Card(suit: .clubs, rank: .five)),
      Hearts.TrickPlay(seat: .east, card: Hearts.Card(suit: .hearts, rank: .two)),
      Hearts.TrickPlay(seat: .south, card: Hearts.Card(suit: .clubs, rank: .king)),
      Hearts.TrickPlay(seat: .west, card: Hearts.Card(suit: .clubs, rank: .ace))
    ]
    state.resolveTrick()
    #expect(state.heartsBroken)
  }

  // MARK: - Scoring

  @Test
  func scoreHand_heartsPenalty() {
    var state = makeState()
    // North won a trick with 2 hearts
    state.tricksTaken[.north] = [[
      Hearts.Card(suit: .hearts, rank: .two),
      Hearts.Card(suit: .hearts, rank: .three),
      Hearts.Card(suit: .clubs, rank: .five),
      Hearts.Card(suit: .diamonds, rank: .king)
    ]]
    state.tricksTaken[.east] = []
    state.tricksTaken[.south] = []
    state.tricksTaken[.west] = []

    state.scoreCurrentHand()
    #expect(state.handPenalties[.north] == 2)
    #expect(state.cumulativeScores[.north] == 2)
  }

  @Test
  func scoreHand_queenOfSpades() {
    var state = makeState()
    state.tricksTaken[.east] = [[
      Hearts.queenOfSpades,
      Hearts.Card(suit: .clubs, rank: .five),
      Hearts.Card(suit: .clubs, rank: .six),
      Hearts.Card(suit: .clubs, rank: .seven)
    ]]
    state.tricksTaken[.north] = []
    state.tricksTaken[.south] = []
    state.tricksTaken[.west] = []

    state.scoreCurrentHand()
    #expect(state.handPenalties[.east] == 13)
  }

  @Test
  func scoreHand_jackOfDiamonds_minus10() {
    var state = makeState()
    state.tricksTaken[.south] = [[
      Hearts.jackOfDiamonds,
      Hearts.Card(suit: .hearts, rank: .two),
      Hearts.Card(suit: .clubs, rank: .five),
      Hearts.Card(suit: .clubs, rank: .six)
    ]]
    state.tricksTaken[.north] = []
    state.tricksTaken[.east] = []
    state.tricksTaken[.west] = []

    state.scoreCurrentHand()
    // 1 heart (1 pt) + J♦ (-10) = -9
    #expect(state.handPenalties[.south] == -9)
  }

  @Test
  func scoreHand_shootingTheMoon() {
    var state = makeState()
    // North won all 13 hearts + Q♠
    let allHearts = Hearts.Card.Rank.allCases.map {
      Hearts.Card(suit: .hearts, rank: $0)
    }
    // Distribute across tricks (doesn't matter how, just needs all hearts + Q♠)
    let trick1 = Array(allHearts.prefix(4))
    let trick2 = Array(allHearts.dropFirst(4).prefix(4))
    let trick3 = Array(allHearts.dropFirst(8).prefix(4))
    var trick4 = [allHearts[12], Hearts.queenOfSpades]
    // Pad tricks to 4 cards with non-penalty fillers
    trick4.append(contentsOf: [
      Hearts.Card(suit: .clubs, rank: .two),
      Hearts.Card(suit: .clubs, rank: .three)
    ])
    let allPenaltyCards = [trick1, trick2, trick3, trick4]

    state.tricksTaken[.north] = allPenaltyCards
    state.tricksTaken[.east] = []
    state.tricksTaken[.south] = []
    state.tricksTaken[.west] = []

    state.scoreCurrentHand()
    #expect(state.handPenalties[.north] == 0)
    #expect(state.handPenalties[.east] == 26)
    #expect(state.handPenalties[.south] == 26)
    #expect(state.handPenalties[.west] == 26)
  }

  @Test
  func scoreHand_gameEndsAtScoreLimit() {
    var state = makeState(scoreLimit: 30)
    state.cumulativeScores[.north] = 25
    state.tricksTaken[.north] = [[
      Hearts.Card(suit: .hearts, rank: .two),
      Hearts.Card(suit: .hearts, rank: .three),
      Hearts.Card(suit: .hearts, rank: .four),
      Hearts.Card(suit: .hearts, rank: .five),
      Hearts.Card(suit: .hearts, rank: .six),
      Hearts.Card(suit: .hearts, rank: .seven)
    ]]
    state.tricksTaken[.east] = []
    state.tricksTaken[.south] = []
    state.tricksTaken[.west] = []

    state.scoreCurrentHand()
    // 25 + 6 = 31 >= 30
    #expect(state.ended)
    // South has lowest score (0), so wins
    #expect(state.endedInVictoryFor.contains(.south))
    #expect(state.endedInDefeatFor.contains(.north))
  }

  @Test
  func scoreHand_tiedWinnersShareVictory() {
    var state = makeState(scoreLimit: 30)
    state.cumulativeScores = [.north: 25, .east: 0, .south: 0, .west: 10]
    state.tricksTaken[.north] = [[
      Hearts.Card(suit: .hearts, rank: .two),
      Hearts.Card(suit: .hearts, rank: .three),
      Hearts.Card(suit: .hearts, rank: .four),
      Hearts.Card(suit: .hearts, rank: .five),
      Hearts.Card(suit: .hearts, rank: .six),
      Hearts.Card(suit: .hearts, rank: .seven)
    ]]
    state.tricksTaken[.east] = []
    state.tricksTaken[.south] = []
    state.tricksTaken[.west] = []

    state.scoreCurrentHand()
    // East and South tied at 0
    #expect(state.endedInVictoryFor.contains(.east))
    #expect(state.endedInVictoryFor.contains(.south))
    #expect(state.endedInVictoryFor.count == 2)
  }

  // MARK: - New Hand

  @Test
  func startNewHand_incrementsHandNumber() {
    var state = makeState()
    let newDeck = Hearts.fullDeck.shuffled()
    state.startNewHand(shuffledDeck: newDeck)
    #expect(state.handNumber == 1)
    // Hand 1 → pass right
    #expect(state.passingState?.direction == .right)
  }

  @Test
  func startNewHand_resetsHeartsBroken() {
    var state = makeState()
    state.heartsBroken = true
    state.startNewHand(shuffledDeck: Hearts.fullDeck)
    #expect(!state.heartsBroken)
  }

  @Test
  func holdHand_skipsPassingPhase() {
    var state = makeState()
    // Hand 3 → no pass
    state.handNumber = 2 // will become 3 after startNewHand
    state.startNewHand(shuffledDeck: Hearts.fullDeck)
    #expect(state.handNumber == 3)
    #expect(state.phase == .playing)
    #expect(state.passingState == nil)
    #expect(state.turnNumber == 1)
  }
}
