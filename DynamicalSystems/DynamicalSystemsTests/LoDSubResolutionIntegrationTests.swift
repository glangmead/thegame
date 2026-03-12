import Testing
@testable import DynamicalSystems

struct LoDSubResolutionIntegrationTests {

  // MARK: - Chain Lightning Integration

  @Test func chainLightningFullFlowInComposedGame() {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .action
    state.spellStatus[.chainLightning] = .known
    state.arcaneEnergy = 3
    state.armyPosition[.east] = 3
    state.armyPosition[.west] = 4

    // Cast Chain Lightning
    _ = game.reduce(into: &state, action: .magic(.castSpell(.chainLightning, heroic: false, .init())))
    #expect(state.isInSubResolution)
    #expect(state.chainLightningState != nil)

    // During sub-resolution, only CL actions available
    let midActions = game.allowedActions(state: state)
    #expect(midActions.allSatisfy { if case .chainLightning = $0 { return true }; return false })

    // Resolve 3 bolts
    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.east, dieRoll: 5)))
    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.west, dieRoll: 4)))
    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.east, dieRoll: 3)))

    // Sub-resolution cleared, back to action phase
    #expect(!state.isInSubResolution)
    #expect(state.phase == .action)

    // Normal actions should be available again
    let postActions = game.allowedActions(state: state)
    let hasCombat = postActions.contains { if case .combat = $0 { return true }; return false }
    let hasPass = postActions.contains { if case .endPlayerTurn = $0 { return true }; return false }
    #expect(hasCombat || hasPass, "Normal actions should resume after sub-resolution")
  }

  // MARK: - Fortune Integration

  @Test func fortuneNormalFlowInComposedGame() {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .action
    state.spellStatus[.fortune] = .known
    state.arcaneEnergy = 4

    // Cast Fortune (normal)
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: false, .init())))
    #expect(state.isInSubResolution)
    #expect(state.fortuneState != nil)
    #expect(state.fortuneState?.heroic == false)

    // Should offer reorder choices (not discard, since non-heroic)
    let actions = game.allowedActions(state: state)
    let reorders = actions.filter { if case .fortune(.chooseOrder) = $0 { return true }; return false }
    #expect(!reorders.isEmpty, "Should offer reorder choices")

    // Choose an order
    _ = game.reduce(into: &state, action: .fortune(.chooseOrder([2, 1, 0])))
    #expect(!state.isInSubResolution)
    #expect(state.phase == .action)
  }

  @Test func fortuneHeroicFlowInComposedGame() {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .action
    state.spellStatus[.fortune] = .known
    state.arcaneEnergy = 4
    state.heroLocation[.wizard] = .onTrack(.east)

    // Cast Fortune (heroic)
    _ = game.reduce(into: &state, action: .magic(.castSpell(.fortune, heroic: true, .init())))
    #expect(state.fortuneState?.heroic == true)

    // Should offer discard choices first
    let discardActions = game.allowedActions(state: state)
    let discards = discardActions.filter {
      if case .fortune(.discardCard) = $0 { return true }
      return false
    }
    #expect(!discards.isEmpty, "Heroic Fortune should offer discard choices first")

    // Discard card 1
    _ = game.reduce(into: &state, action: .fortune(.discardCard(1)))

    // Now should offer reorder of remaining 2
    let reorderActions = game.allowedActions(state: state)
    let reorders = reorderActions.filter {
      if case .fortune(.chooseOrder) = $0 { return true }
      return false
    }
    #expect(reorders.count == 2, "After discard, 2 permutations of 2 remaining cards")

    // Choose order
    if let firstReorder = reorders.first {
      _ = game.reduce(into: &state, action: firstReorder)
    }
    #expect(!state.isInSubResolution)
  }

  // MARK: - Death and Despair Integration

  @Test func deathAndDespairFullFlowInComposedGame() {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .event
    state.currentCard = LoD.nightCards.first { $0.number == 29 }

    // Trigger event
    _ = game.reduce(into: &state, action: .resolveEvent(.init(dieRoll: 4)))
    #expect(state.isInSubResolution)
    #expect(state.deathAndDespairState != nil)
    #expect(state.deathAndDespairState?.dieRoll == 4)

    // Phase should have transitioned to action (event -> action), but sub-resolution blocks normal pages
    #expect(state.phase == .action)

    // Sacrifice a hero to reduce advance
    _ = game.reduce(into: &state, action: .deathAndDespair(.sacrificeHero(.warrior)))
    #expect(state.deathAndDespairState?.remainingAdvance == 3)
    #expect(state.heroWounded.contains(.warrior))

    // Sacrifice a defender
    _ = game.reduce(into: &state, action: .deathAndDespair(.sacrificeDefender(.archers)))
    #expect(state.deathAndDespairState?.remainingAdvance == 2)

    // Commit the remaining advance
    _ = game.reduce(into: &state, action: .deathAndDespair(.commitAdvance(chosenSlot: nil)))
    #expect(!state.isInSubResolution)
    #expect(state.phase == .action)
  }

  // MARK: - MCTS Smoke Test

  @Test func mctsNavigatesChainLightningSubResolution() {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .action
    state.spellStatus[.chainLightning] = .known
    state.arcaneEnergy = 3

    // Put the game into sub-resolution
    _ = game.reduce(into: &state, action: .magic(.castSpell(.chainLightning, heroic: false, .init())))
    #expect(state.isInSubResolution)

    // Simulate what MCTS would do: random playout from sub-resolution
    var playoutState = state
    var steps = 0
    let maxSteps = 100
    while steps < maxSteps {
      let actions = game.allowedActions(state: playoutState)
      if actions.isEmpty { break }
      guard let action = actions.randomElement() else { break }
      _ = game.reduce(into: &playoutState, action: action)
      steps += 1
      if !playoutState.isInSubResolution { break }
    }
    #expect(
      !playoutState.isInSubResolution,
      "MCTS playout should escape sub-resolution within \(maxSteps) steps"
    )
  }
}
