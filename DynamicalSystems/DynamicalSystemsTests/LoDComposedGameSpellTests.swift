//
//  LoDComposedGameSpellTests.swift
//  DynamicalSystems
//
//  Tests for LoD composed game: budget tracking, quest rewards, spell casting.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDComposedGameSpellTests {

  // MARK: - Budget Tracking Tests

  @Test
  func actionBudgetWithMoraleModifier() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Use card 2 (4 actions)
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    state.currentCard = card2

    // Normal morale → budget = 4
    state.morale = .normal
    #expect(state.actionBudget == 4)

    // High morale → budget = 5
    state.morale = .high
    #expect(state.actionBudget == 5)

    // Low morale → budget = 3
    state.morale = .low
    #expect(state.actionBudget == 3)
  }

  @Test
  func heroicBudgetFromCard() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    state.currentCard = card2
    #expect(state.heroicBudget == 2)

    // Card 26 has 3 heroics
    let card26 = LoD.nightCards.first { $0.number == 26 }!
    state.currentCard = card26
    #expect(state.heroicBudget == 3)
  }

  // MARK: - Quest Reward Tests (composed game)

  @Test
  func composedGameQuestRewardForlornHope() {
    // Card #3: Forlorn Hope quest (target > 6). Reward: advance time +1.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let timeBefore = state.timePosition
    // Roll 6 + action DRM 1 = 7 > 6 = success
    _ = game.reduce(into: &state, action: .questAction(dieRoll: 6, reward: LoD.QuestRewardParams()))
    #expect(state.timePosition == timeBefore + 1) // Forlorn Hope advances time
  }

  @Test
  func composedGameQuestRewardScrollsOfDead() {
    // Card #2: Scrolls of the Dead (target > 7). Reward: learn a chosen spell.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)

    // All spells start face-down
    #expect(state.spellStatus[.fireball] == .faceDown)

    // Roll 6 + action DRM 1 = 7. Need > 7, so this fails.
    var reward = LoD.QuestRewardParams()
    reward.chosenSpell = .fireball
    _ = game.reduce(into: &state, action: .questAction(dieRoll: 6, reward: reward))
    #expect(state.spellStatus[.fireball] == .faceDown) // still face-down (failed)

    // Try heroic: roll 6 + heroic DRM 2 = 8 > 7 = success
    _ = game.reduce(into: &state, action: .passActions)
    _ = game.reduce(into: &state, action: .questHeroic(dieRoll: 6, reward: reward))
    #expect(state.spellStatus[.fireball] == .known) // now known!
  }

  @Test
  func composedGameQuestFailureNoReward() {
    // Card #3: Forlorn Hope, roll too low = failure, time should not advance.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)

    let timeBefore = state.timePosition
    // Roll 2 + action DRM 1 = 3. Need > 6 = failure.
    _ = game.reduce(into: &state, action: .questAction(dieRoll: 2, reward: LoD.QuestRewardParams()))
    #expect(state.timePosition == timeBefore) // no time advance
  }

  // MARK: - Spell Casting Tests (composed game)

  @Test
  func composedGameCastFireball() {
    // Cast fireball during action phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Learn fireball and place an army in range
    state.spellStatus[.fireball] = .known
    state.armyPosition[.east] = 3

    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let arcaneBefore = state.arcaneEnergy

    // Cast fireball on east army, roll 5
    var params = LoD.SpellCastParams()
    params.targetSlot = .east
    params.dieRolls = [5]
    _ = game.reduce(into: &state, action: .castSpell(.fireball, heroic: false, params))

    // Fireball costs 1 arcane energy
    #expect(state.arcaneEnergy == arcaneBefore - 1)
    #expect(state.spellStatus[.fireball] == .cast)
    // Fireball: +2 DRM magical attack. Roll 5 + 2 = 7 > goblin str 2 = hit.
    #expect(state.armyPosition[.east]! > 3) // pushed back
    #expect(state.actionBudgetRemaining == 1) // used 1 of 2 action points
  }

  @Test
  func composedGameCastInspire() {
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 1,   // low arcane so divine is high
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.spellStatus[.inspire] = .known
    state.morale = .low

    _ = game.reduce(into: &state, action: .drawCard)

    // Cast Inspire (divine, cost 3)
    _ = game.reduce(into: &state, action: .castSpell(.inspire, heroic: false, LoD.SpellCastParams()))
    #expect(state.morale == .normal) // raised from low
    #expect(state.inspireDRMActive == true) // +1 DRM to all rolls
    #expect(state.spellStatus[.inspire] == .cast)
  }

  @Test
  func composedGameCastSpellOfferedWhenKnown() {
    // Verify castSpell appears in allowed actions only when spell is known + has energy.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    _ = game.reduce(into: &state, action: .drawCard)

    // No known spells → no cast actions
    let actionsNoSpells = game.allowedActions(state: state)
    #expect(!actionsNoSpells.contains(where: { if case .castSpell = $0 { return true }; return false }))

    // Learn fireball
    state.spellStatus[.fireball] = .known

    let actionsWithSpell = game.allowedActions(state: state)
    #expect(actionsWithSpell.contains(where: { if case .castSpell = $0 { return true }; return false }))
  }

  @Test
  func composedGameCastSpellInsufficientEnergy() {
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.spellStatus[.fireball] = .known
    state.arcaneEnergy = 0  // no energy

    _ = game.reduce(into: &state, action: .drawCard)

    // Fireball should NOT be offered (insufficient energy)
    let actions = game.allowedActions(state: state)
    #expect(!actions.contains(where: { if case .castSpell = $0 { return true }; return false }))
  }

}
