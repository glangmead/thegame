//
//  LoDHeroDRMTests.swift
//  DynamicalSystems
//
//  Tests for LoD hero DRMs: Heroic Attack DRM, Ranger Quest DRM, Rogue Build DRM, Rogue Free Move.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDHeroDRMTests {

  // MARK: - Heroic Attack DRM from Cards (#8, rule 7.0)

  @Test
  func heroicAttackAppliesCardDRM() {
    // Card with heroicDRM for attack +1 → heroic attack should include it.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)
    // Use a card that has heroicDRMs for attacks
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 2, heroics: 1,
      actionDRMs: [], heroicDRMs: [LoD.CardDRM(action: .attack, track: nil, value: 1)],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    state.currentCard = card

    let drm = state.totalHeroicAttackDRM(hero: .warrior, slot: .east)
    // Warrior combatDRM (2) + card heroicDRM attack (1) + inspire (0) = 3
    #expect(drm == 3)
  }

  @Test
  func heroicAttackCardDRMTrackSpecific() {
    // Card heroicDRM restricted to east track doesn't apply to west.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.west)
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 2, heroics: 1,
      actionDRMs: [], heroicDRMs: [LoD.CardDRM(action: .attack, track: .east, value: 2)],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    state.currentCard = card

    let drm = state.totalHeroicAttackDRM(hero: .warrior, slot: .west)
    // Warrior combatDRM (2) + card heroicDRM (0, wrong track) = 2
    #expect(drm == 2)
  }

  // MARK: - Ranger Quest DRM (rule 10.3)

  @Test
  func rangerQuestDRM() {
    // Ranger alive → +1 quest DRM. Dead → 0.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .ranger]
    )
    #expect(state.questDRM() == 1)

    state.heroDead.insert(.ranger)
    #expect(state.questDRM() == 0)
  }

  @Test
  func rangerQuestDRMNotInPlay() {
    // Ranger not in hero roster → 0.
    let state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.questDRM() == 0)
  }

  // MARK: - Rogue Build DRM (rule 10.4)

  @Test
  func rogueBuildDRM() {
    // Rogue alive → totalBuildDRM includes +1.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue]
    )
    // No card DRMs, no inspire → just Rogue +1
    #expect(state.totalBuildDRM() == 1)
  }

  @Test
  func rogueBuildDRMNotWhenDead() {
    // Rogue dead → no build bonus.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue]
    )
    state.heroDead.insert(.rogue)
    #expect(state.totalBuildDRM() == 0)
  }

  // MARK: - Rogue Free Move (rule 10.4)

  @Test
  func rogueFreeMoveOfferedInActionPhase() {
    // Rogue alive → rogueMove actions offered during action phase without costing action points.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let allowed = game.allowedActions(state: state)
    // Should include rogueMove options
    let rogueMoves = allowed.filter {
      if case .rogueMove = $0 { return true }
      return false
    }
    #expect(rogueMoves.count > 0)
  }

  @Test
  func rogueFreeMoveDoesNotCostActionPoint() {
    // Using rogueMove should not decrement the action budget.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let budgetBefore = state.actionBudgetRemaining
    _ = game.reduce(into: &state, action: .rogueMove(.onTrack(.east)))
    #expect(state.actionBudgetRemaining == budgetBefore) // No action consumed
    #expect(state.heroLocation[.rogue] == .onTrack(.east))
  }

  @Test
  func rogueFreeMoveNotOfferedWhenDead() {
    // Rogue dead → no rogueMove offered.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroDead.insert(.rogue)
    _ = game.reduce(into: &state, action: .drawCard)

    let allowed = game.allowedActions(state: state)
    let rogueMoves = allowed.filter {
      if case .rogueMove = $0 { return true }
      return false
    }
    #expect(rogueMoves.count == 0)
  }

}
