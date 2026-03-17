//
//  LoDDeathAndDespairPageTests.swift
//  DynamicalSystems
//
//  Tests for LoD Death and Despair multi-step sub-resolution page.
//

import Testing
@testable import DynamicalSystems

struct LoDDeathAndDespairPageTests {

  private func setupForDeathAndDespair() -> (ComposedGame<LoD.State>, LoD.State) {
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    var state = game.newState()
    state.phase = .event
    state.currentCard = LoD.nightCards.first { $0.number == 29 }
    return (game, state)
  }

  @Test func eventTriggersSubResolution() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    #expect(state.deathAndDespairState != nil)
    #expect(state.deathAndDespairState?.dieRoll == 3)
  }

  @Test func offersSacrificeAndCommitActions() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    let actions = game.allowedActions(state: state)
    let ddActions = actions.filter {
      if case .deathAndDespair = $0 { return true }
      return false
    }
    #expect(!ddActions.isEmpty, "Should offer Death and Despair actions")
    let commits = ddActions.filter {
      if case .deathAndDespair(.commitAdvance) = $0 { return true }
      return false
    }
    #expect(!commits.isEmpty, "Should offer commit action")
  }

  @Test func sacrificeHeroReducesAdvance() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    _ = game.reduce(into: &state, action: .deathAndDespair(.sacrificeHero(.warrior)))
    #expect(state.deathAndDespairState?.remainingAdvance == 2)
    #expect(state.heroWounded.contains(.warrior))
  }

  @Test func sacrificeDefenderReducesAdvance() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    LoD.$rollDie.withValue({ 2 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    _ = game.reduce(into: &state, action: .deathAndDespair(.sacrificeDefender(.archers)))
    #expect(state.deathAndDespairState?.remainingAdvance == 1)
    let archerPos = state.defenderPosition[.archers] ?? 0
    #expect(archerPos == 1, "Archers should have lost one position")
  }

  @Test func commitAdvanceResolvesAndClearsState() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    LoD.$rollDie.withValue({ 2 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    _ = game.reduce(into: &state, action: .deathAndDespair(.commitAdvance(chosenSlot: nil)))
    #expect(state.deathAndDespairState == nil)
    #expect(!state.isInSubResolution)
  }

  @Test func zeroAdvanceSkipsSacrifice() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    _ = game.reduce(into: &state, action: .deathAndDespair(.sacrificeHero(.warrior)))
    _ = game.reduce(into: &state, action: .deathAndDespair(.sacrificeHero(.wizard)))
    _ = game.reduce(into: &state, action: .deathAndDespair(.sacrificeDefender(.archers)))
    let actions = game.allowedActions(state: state)
    let sacrifices = actions.filter {
      if case .deathAndDespair(.sacrificeHero) = $0 { return true }
      if case .deathAndDespair(.sacrificeDefender) = $0 { return true }
      return false
    }
    #expect(sacrifices.isEmpty, "No sacrifice options when advance is 0")
    let commits = actions.filter {
      if case .deathAndDespair(.commitAdvance) = $0 { return true }
      return false
    }
    #expect(commits.count == 1, "Should still offer commit when advance is 0")
  }

  @Test func commitWithChosenSlotAdvancesThatArmy() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    // Make east farthest
    state.armyPosition[.east] = 6
    state.armyPosition[.west] = 3
    LoD.$rollDie.withValue({ 2 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    _ = game.reduce(into: &state, action: .deathAndDespair(.commitAdvance(chosenSlot: nil)))
    // East was at 6, should advance 2 spaces to 4
    #expect(state.armyPosition[.east] == 4)
    #expect(state.deathAndDespairState == nil)
  }

  @Test func tiedFarthestArmiesOfferMultipleCommitOptions() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    // Set east and west at same position (farthest, tied)
    state.armyPosition[.east] = 6
    state.armyPosition[.west] = 6
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3
    state.armyPosition[.sky] = 4
    LoD.$rollDie.withValue({ 2 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    let actions = game.allowedActions(state: state)
    let commits = actions.filter {
      if case .deathAndDespair(.commitAdvance) = $0 { return true }
      return false
    }
    #expect(commits.count >= 2, "Tied farthest armies should produce multiple commit options")
  }

  @Test func isInSubResolutionBlocksOtherPages() {
    let setup = setupForDeathAndDespair()
    let game = setup.0
    var state = setup.1
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(into: &state, action: .resolveEvent(.init()))
    }
    let actions = game.allowedActions(state: state)
    for action in actions {
      switch action {
      case .deathAndDespair:
        break
      default:
        Issue.record("Unexpected action during sub-resolution: \(action)")
      }
    }
  }

  @Test func farthestArmySlotsFindsMaxPosition() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 6
    state.armyPosition[.west] = 4
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3
    state.armyPosition[.sky] = 6
    let farthest = state.farthestArmySlots()
    #expect(farthest.contains(.east))
    #expect(farthest.contains(.sky))
    #expect(farthest.count == 2)
  }
}
