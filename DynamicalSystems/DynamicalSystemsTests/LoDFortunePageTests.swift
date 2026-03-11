//
//  LoDFortunePageTests.swift
//  DynamicalSystems
//
//  Tests for LoD Fortune multi-step sub-resolution page.
//

import Testing
@testable import DynamicalSystems

struct LoDFortunePageTests {

  private func setupForFortune(heroic: Bool = false) -> (ComposedGame<LoD.State>, LoD.State) {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .action
    state.spellStatus[.fortune] = .known
    state.arcaneEnergy = 4
    if heroic {
      state.heroLocation[.wizard] = .onTrack(.east)
    }
    return (game, state)
  }

  @Test func castingFortuneSetsUpSubResolution() {
    var (game, state) = setupForFortune()
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: false, .init())))
    #expect(state.fortuneState != nil, "Should enter Fortune sub-resolution")
    #expect(state.fortuneState?.heroic == false)
    #expect(state.arcaneEnergy == 0, "Energy should be spent")
    #expect(state.fortuneState?.drawnCards.count ?? 0 > 0, "Should have drawn cards")
  }

  @Test func normalFortuneOffersReorderChoices() {
    var (game, state) = setupForFortune()
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: false, .init())))
    let actions = game.allowedActions(state: state)
    let fortuneActions = actions.filter {
      if case .fortune(.chooseOrder) = $0 { return true }
      return false
    }
    // 3 cards -> 6 permutations
    #expect(
      fortuneActions.count == 6,
      "Normal Fortune should offer 6 reorder permutations, got \(fortuneActions.count)"
    )
  }

  @Test func heroicFortuneOffersDiscardFirst() {
    var (game, state) = setupForFortune(heroic: true)
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: true, .init())))
    let actions = game.allowedActions(state: state)
    let discardActions = actions.filter {
      if case .fortune(.discardCard) = $0 { return true }
      if case .fortune(.skipDiscard) = $0 { return true }
      return false
    }
    // 3 discard choices + 1 skip = 4
    #expect(
      discardActions.count == 4,
      "Heroic Fortune should offer 3 discards + skip, got \(discardActions.count)"
    )
  }

  @Test func heroicDiscardThenReorder() {
    var (game, state) = setupForFortune(heroic: true)
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: true, .init())))
    // Discard card 0
    _ = game.reduce(into: &state, action: .fortune(.discardCard(0)))
    #expect(state.fortuneState?.discardedIndex == 0)
    let actions = game.allowedActions(state: state)
    let reorderActions = actions.filter {
      if case .fortune(.chooseOrder) = $0 { return true }
      return false
    }
    // 2 remaining cards -> 2 permutations
    #expect(
      reorderActions.count == 2,
      "After discard, should offer 2 reorder permutations, got \(reorderActions.count)"
    )
  }

  @Test func skipDiscardThenReorder() {
    var (game, state) = setupForFortune(heroic: true)
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: true, .init())))
    // Skip discard
    _ = game.reduce(into: &state, action: .fortune(.skipDiscard))
    #expect(state.fortuneState?.discardedIndex == -1)
    let actions = game.allowedActions(state: state)
    let reorderActions = actions.filter {
      if case .fortune(.chooseOrder) = $0 { return true }
      return false
    }
    // 3 cards -> 6 permutations
    #expect(
      reorderActions.count == 6,
      "After skip discard, should offer 6 reorder permutations, got \(reorderActions.count)"
    )
  }

  @Test func reorderAppliesAndClearsState() {
    var (game, state) = setupForFortune()
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: false, .init())))
    // Choose order [2, 1, 0] (reverse)
    _ = game.reduce(into: &state, action: .fortune(.chooseOrder([2, 1, 0])))
    #expect(state.fortuneState == nil, "Fortune sub-resolution should be cleared after reorder")
    #expect(!state.isInSubResolution)
  }

  @Test func heroicDiscardAndReorderApplies() {
    var (game, state) = setupForFortune(heroic: true)
    let originalPeek = state.fortunePeek()
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: true, .init())))
    // Discard card 1 (middle)
    _ = game.reduce(into: &state, action: .fortune(.discardCard(1)))
    // Reorder remaining [0, 2] as [2, 0]
    _ = game.reduce(into: &state, action: .fortune(.chooseOrder([2, 0])))
    #expect(state.fortuneState == nil)
    #expect(!state.isInSubResolution)
    // Check that the deck was modified: top card should be original[2], then original[0]
    let pile = state.drawsFromDayDeck ? state.dayDrawPile : state.nightDrawPile
    #expect(pile[0] == originalPeek[2])
    #expect(pile[1] == originalPeek[0])
  }
}
