//
//  LoDPaladinRerollTests.swift
//  DynamicalSystems
//
//  Tests for LoD Paladin re-roll in composed game (rule 10.2).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDPaladinRerollTests {

  // MARK: - Paladin Re-roll (rule 10.2)

  @Test
  func paladinRerollOfferedAfterDieRollAction() {
    // After a die-roll action with Paladin alive, game enters paladinReact
    // and offers reroll/decline.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1  // melee range
    _ = game.reduce(into: &state, action: .drawCard)
    // Resolve Gate bloody battle tie if needed (card #3 has gate BB)
    if state.pendingBloodyBattleChoices != nil {
      _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
    }
    #expect(state.phase == .action)

    // Perform a melee attack — should enter paladinReact phase
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: nil)))
    }
    #expect(state.phase == .paladinReact)

    let allowed = game.allowedActions(state: state)
    let hasReroll = allowed.contains(where: { if case .paladinReroll = $0 { return true }; return false })
    let hasDecline = allowed.contains(where: { if case .declineReroll = $0 { return true }; return false })
    #expect(hasReroll)
    #expect(hasDecline)
  }

  @Test
  func paladinDeclineResolvesOriginalAction() {
    // Declining the re-roll resolves the original attack normally and returns to action phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1  // melee range
    _ = game.reduce(into: &state, action: .drawCard)

    // Attack with roll 6: card 3 attack DRM -1, so 6 + (-1) = 5 > goblin str 2 → hit
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: nil)))
    }
    #expect(state.phase == .paladinReact)
    // Army hasn't been pushed back yet (deferred)
    #expect(state.armyPosition[.east]! == 1)

    // Decline re-roll → resolve with stashed die roll 6
    _ = game.reduce(into: &state, action: .declineReroll)
    #expect(state.phase == .action)
    // Now army should be pushed back (hit resolved)
    #expect(state.armyPosition[.east]! == 2)
  }

  @Test
  func paladinRerollChangesResult() {
    // Re-rolling with a better die changes the attack result.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // Original roll 1 (natural 1 always fails). Army at space 1.
    LoD.$rollDie.withValue({ 1 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: nil)))
    }
    #expect(state.phase == .paladinReact)

    // Re-roll with 6: 6 + (-1) = 5 > 2 → hit
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .paladinReroll)
    }
    #expect(state.phase == .action)
    #expect(state.armyPosition[.east]! == 2)  // pushed back
    #expect(state.paladinRerollUsed == true)
  }

  @Test
  func paladinRerollUsedOnlyOnce() {
    // After using re-roll, second die-roll action resolves immediately (no react phase).
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1
    state.armyPosition[.west] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // First attack: enters paladinReact
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: nil)))
    }
    #expect(state.phase == .paladinReact)
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .paladinReroll)
    }
    #expect(state.paladinRerollUsed == true)

    // Second attack: should resolve immediately, no paladinReact
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .west,
          bloodyBattleDefender: nil, useMagicSword: nil)))
    }
    #expect(state.phase == .action)  // stays in action, not paladinReact
  }

  @Test
  func paladinRerollNotOfferedWhenDead() {
    // Dead Paladin → action resolves immediately, no react phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroDead.insert(.paladin)
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)
    // Resolve Gate bloody battle tie if needed (card #3 has gate BB)
    if state.pendingBloodyBattleChoices != nil {
      _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
    }

    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: nil)))
    }
    #expect(state.phase == .action)  // resolved immediately
    #expect(state.armyPosition[.east]! == 2)  // hit resolved
  }

  @Test
  func paladinRerollWorksForHeroicAttack() {
    // Paladin re-roll also works for heroic attacks.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroLocation[.paladin] = .onTrack(.east)
    state.armyPosition[.east] = 3
    _ = game.reduce(into: &state, action: .drawCard)
    // Resolve Gate bloody battle tie if needed (card #3 has gate BB)
    if state.pendingBloodyBattleChoices != nil {
      _ = game.reduce(into: &state, action: .chooseBloodyBattle(.gate1))
    }
    #expect(state.phase == .action)

    // Heroic attack: should enter paladinReact
    LoD.$rollDie.withValue({ 1 }) {
      _ = game.reduce(into: &state, action: .heroic(.heroicAttack(.paladin, .east)))
    }
    #expect(state.phase == .paladinReact)

    // Re-roll with 6: paladin combatDRM = 1, so 6 + 1 = 7 > goblin str 2 → hit
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .paladinReroll)
    }
    #expect(state.phase == .action)  // returns to action phase
    #expect(state.armyPosition[.east]! == 4)  // pushed back
  }

}
