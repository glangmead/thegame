import Testing
@testable import DynamicalSystems

struct LoDChainLightningTests {

  private func setupForChainLightning(heroic: Bool = false) -> (ComposedGame<LoD.State>, LoD.State) {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .action
    state.spellStatus[.chainLightning] = .known
    state.arcaneEnergy = 3
    if heroic {
      state.heroLocation[.wizard] = .onTrack(.east)
    }
    return (game, state)
  }

  @Test func castingChainLightningSetsUpSubResolution() {
    let setup = setupForChainLightning()
    let game = setup.0
    var state = setup.1
    let action = LoD.Action.magic(.castSpell(.chainLightning, heroic: false, .init()))
    _ = game.reduce(into: &state, action: action)
    #expect(state.chainLightningState != nil, "Should enter Chain Lightning sub-resolution")
    #expect(state.chainLightningState?.boltIndex == 0)
    #expect(state.arcaneEnergy == 0, "Energy should be spent")
  }

  @Test func subResolutionOffersTargetChoices() {
    let setup = setupForChainLightning()
    let game = setup.0
    var state = setup.1
    _ = game.reduce(into: &state, action: .magic(.castSpell(.chainLightning, heroic: false, .init())))
    let actions = game.allowedActions(state: state)
    let clActions = actions.filter {
      if case .chainLightning = $0 { return true }
      return false
    }
    #expect(!clActions.isEmpty, "Should offer Chain Lightning target choices")
    let nonCLActions = actions.filter {
      if case .chainLightning = $0 { return false }
      return true
    }
    #expect(nonCLActions.isEmpty, "No other actions during sub-resolution")
  }

  @Test func threeSequentialBoltsResolveAndClearState() {
    let setup = setupForChainLightning()
    let game = setup.0
    var state = setup.1
    state.armyPosition[.east] = 3
    state.armyPosition[.west] = 4
    _ = game.reduce(into: &state, action: .magic(.castSpell(.chainLightning, heroic: false, .init())))

    // Bolt 1
    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.east, dieRoll: 6)))
    #expect(state.chainLightningState?.boltIndex == 1)
    #expect(state.chainLightningState?.results.count == 1)

    // Bolt 2
    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.west, dieRoll: 6)))
    #expect(state.chainLightningState?.boltIndex == 2)

    // Bolt 3
    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.east, dieRoll: 6)))
    #expect(state.chainLightningState == nil, "Sub-resolution should be cleared after 3 bolts")
    #expect(!state.isInSubResolution)
  }

  @Test func heroicChainLightningUsesHigherDRMs() {
    let setup = setupForChainLightning(heroic: true)
    let game = setup.0
    var state = setup.1
    state.armyPosition[.east] = 3
    _ = game.reduce(into: &state, action: .magic(.castSpell(.chainLightning, heroic: true, .init())))

    #expect(state.chainLightningState != nil)
    #expect(state.chainLightningState?.heroic == true)
    // Heroic DRMs are +3, +2, +1
    #expect(state.chainLightningState?.drmsForCurrentBolt == 3)

    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.east, dieRoll: 6)))
    #expect(state.chainLightningState?.drmsForCurrentBolt == 2)

    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.east, dieRoll: 6)))
    #expect(state.chainLightningState?.drmsForCurrentBolt == 1)

    _ = game.reduce(into: &state, action: .chainLightning(.targetBolt(.east, dieRoll: 6)))
    #expect(state.chainLightningState == nil)
  }

  @Test func isInSubResolutionBlocksOtherPages() {
    let setup = setupForChainLightning()
    let game = setup.0
    var state = setup.1
    state.armyPosition[.east] = 3
    _ = game.reduce(into: &state, action: .magic(.castSpell(.chainLightning, heroic: false, .init())))

    // During sub-resolution, only chain lightning actions should be available
    let actions = game.allowedActions(state: state)
    for action in actions {
      switch action {
      case .chainLightning:
        break // expected
      default:
        Issue.record("Unexpected action during sub-resolution: \(action)")
      }
    }
  }
}
