//
//  LoDComposedGameTests.swift
//  DynamicalSystems
//
//  Tests for LoD composed game (oapply): event phase, action phase, heroic phase, budget tracking, quest rewards, spell casting.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDComposedGameTests {

  // MARK: - Composed Game (oapply)

  @Test
  func composedGameInitialState() {
    // The composed game creates a valid initial state in the card phase.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    let state = game.newState()

    #expect(state.phase == .card)
    #expect(state.dayDrawPile.count == 20)
    #expect(state.nightDrawPile.count == 16)
    #expect(state.history.isEmpty)
  }

  @Test
  func composedGameAllowedActionsInCardPhase() {
    // In card phase, only drawCard is offered.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    let state = game.newState()

    let actions = game.allowedActions(state: state)
    #expect(actions == [.drawCard])
  }

  @Test
  func composedGameFullTurnCascade() {
    // Use card #2 (no event) so drawCard cascades: drawCard → advanceArmies → skipEvent.
    // Then player explicitly passes actions and heroics.
    // passHeroics cascades to performHousekeeping automatically.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    #expect(state.phase == .card)
    #expect(state.timePosition == 0)

    // Step 1: drawCard cascades through army and event (no-event card)
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.currentCard != nil)
    #expect(state.history.count == 3) // drawCard, advanceArmies, skipEvent

    // Step 2: pass actions → phase becomes heroic
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)
    #expect(state.history.count == 4)

    // Step 3: pass heroics → cascades to housekeeping → phase becomes card
    _ = game.reduce(into: &state, action: .passHeroics)
    #expect(state.phase == .card)
    #expect(state.history.count == 6) // +passHeroics, +performHousekeeping

    #expect(state.history[0] == .drawCard)
    #expect(state.history[1] == .advanceArmies(acidAttackDieRolls: [:]))
    #expect(state.history[2] == .skipEvent)
    #expect(state.history[3] == .passActions)
    #expect(state.history[4] == .passHeroics)
    #expect(state.history[5] == .performHousekeeping)
  }

  @Test
  func composedGameTimeAdvancesOverTurns() {
    // Card #3 ("All is Quiet") has no event, no advances, time: 1.
    // Safe for multiple turns without triggering breaches.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 5),
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    let initialTime = state.timePosition

    for _ in 0..<5 {
      let actions = game.allowedActions(state: state)
      #expect(actions.contains(.drawCard))
      _ = game.reduce(into: &state, action: .drawCard)
      _ = game.reduce(into: &state, action: .passActions)
      _ = game.reduce(into: &state, action: .passHeroics)
    }

    #expect(state.timePosition == initialTime + 5) // card3.time = 1 × 5 turns
    // 6 history entries per turn × 5 turns
    #expect(state.history.count == 30)
  }

  @Test
  func composedGameTerminalState() {
    // When the game ends and is acknowledged, no actions are offered.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.ended = true
    state.gameAcknowledged = true

    let actions = game.allowedActions(state: state)
    #expect(actions.isEmpty)
  }

  @Test
  func composedGameArmiesAdvance() {
    // Card #2 advances: gate, gate, west, east.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    let eastBefore = state.armyPosition[.east]!
    let westBefore = state.armyPosition[.west]!

    _ = game.reduce(into: &state, action: .drawCard)

    // Card #2 advances east and west (and gate twice)
    #expect(state.armyPosition[.east]! < eastBefore)
    #expect(state.armyPosition[.west]! < westBefore)
  }

  // MARK: - Event Phase Tests

  @Test
  func composedGameEventPhaseWithEvent() {
    // Card #1 has event "Catapult Shrapnel". After drawCard cascade stops at event phase,
    // the player must provide resolveEvent.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1] + LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // drawCard cascades: drawCard → advanceArmies. Stops because card has event.
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .event)

    // Rules should offer resolveEvent
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(where: { if case .resolveEvent = $0 { return true }; return false }))

    // Resolve with die roll 5 (no effect for Catapult Shrapnel)
    var resolution = LoD.EventResolution()
    resolution.dieRoll = 5
    _ = game.reduce(into: &state, action: .resolveEvent(resolution))
    #expect(state.phase == .action)
    // Defenders unchanged (roll 4-6 = no effect)
    #expect(state.defenders[.archers] == 2)
    #expect(state.defenders[.menAtArms] == 3)
  }

  @Test
  func composedGameEventCatapultShrapnelLoseDefender() {
    // Catapult Shrapnel roll 1 → lose archer.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .event)

    var resolution = LoD.EventResolution()
    resolution.dieRoll = 1
    _ = game.reduce(into: &state, action: .resolveEvent(resolution))
    #expect(state.defenders[.archers] == 1)
  }

  // MARK: - Action Phase Tests

  @Test
  func composedGameActionBudget() {
    // Card #2 has 4 actions, no event. With normal morale, budget = 4.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.actionBudget == 4)
    #expect(state.actionBudgetRemaining == 4)

    // Do a chant (priests > 0, costs 1 action point)
    _ = game.reduce(into: &state, action: .chant(dieRoll: 6))
    #expect(state.actionBudgetRemaining == 3)

    // Pass with budget remaining
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(.passActions))
  }

  @Test
  func composedGameActionBudgetExhausted() {
    // Use a card with 1 action point. After one action, only pass is offered.
    // Card #26 has 1 action point.
    let card26 = LoD.nightCards.first { $0.number == 26 }!
    // We need to be on a night time space to draw night cards.
    // Instead, just set up manually.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card26], // Put night card in day pile for test
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Card 26 has event "Council of Heroes", so we need to resolve it.
    _ = game.reduce(into: &state, action: .drawCard)

    // Card 26 has event, so we're in event phase
    if state.phase == .event {
      _ = game.reduce(into: &state, action: .resolveEvent(LoD.EventResolution()))
    }
    #expect(state.phase == .action)
    #expect(state.actionBudget == 1)

    // Do one chant
    _ = game.reduce(into: &state, action: .chant(dieRoll: 6))
    #expect(state.actionBudgetRemaining == 0)

    // Only pass should be offered
    let actions = game.allowedActions(state: state)
    #expect(actions == [.passActions])
  }

  @Test
  func composedGameMeleeAttack() {
    // Card #3: no event, no advances, 2 actions.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Move east army to melee range (space 2)
    state.armyPosition[.east] = 2

    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Melee attack on east with a strong roll
    // Card #3 has attack DRM -1, so roll 6 + (-1) = 5. Goblin str 2. 5 > 2 = hit.
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))

    // Army pushed back from space 2 to space 3
    #expect(state.armyPosition[.east]! == 3)
    #expect(state.actionBudgetRemaining == 1) // 2 - 1 = 1
  }

  @Test
  func composedGameRangedAttack() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Ranged attack on east army (at space 5 after advance)
    let eastPos = state.armyPosition[.east]!
    _ = game.reduce(into: &state, action: .rangedAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicBow: nil))

    // Roll 6 + card2 gate DRM (doesn't apply to east) vs goblin str 2 → hit
    #expect(state.armyPosition[.east]! > eastPos)
  }

  // MARK: - Heroic Phase Tests

  @Test
  func composedGameHeroicPhase() {
    // After passing actions, we enter heroic phase.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)
    #expect(state.heroicBudget == 2) // card 2 has heroics: 2
    #expect(state.heroicBudgetRemaining == 2)

    let actions = game.allowedActions(state: state)
    // Should offer moveHero, rally, passHeroics, etc.
    #expect(actions.contains(.passHeroics))
    #expect(actions.contains(where: { if case .moveHero = $0 { return true }; return false }))
    #expect(actions.contains(where: { if case .rally = $0 { return true }; return false }))
  }

  @Test
  func composedGameMoveHeroAndAttack() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Put east army at space 3 (melee range for warrior)
    state.armyPosition[.east] = 3

    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)

    // Move warrior to east track
    _ = game.reduce(into: &state, action: .moveHero(.warrior, .onTrack(.east)))
    #expect(state.heroLocation[.warrior] == .onTrack(.east))
    #expect(state.heroicBudgetRemaining == 1)

    // Heroic attack with warrior on east army
    _ = game.reduce(into: &state, action: .heroicAttack(.warrior, .east, dieRoll: 5))
    #expect(state.heroicBudgetRemaining == 0)

    // Budget exhausted → only pass offered
    let actions = game.allowedActions(state: state)
    #expect(actions == [.passHeroics])
  }

  @Test
  func composedGameRally() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.morale = .low

    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)

    // Rally with high roll → morale should raise
    _ = game.reduce(into: &state, action: .rally(dieRoll: 6))
    #expect(state.morale == .normal)
  }

  @Test
  func composedGameHeroicPassCascadesToHousekeeping() {
    // passHeroics should auto-cascade to performHousekeeping.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    _ = game.reduce(into: &state, action: .passHeroics)

    // Should be back to card phase after housekeeping
    #expect(state.phase == .card)
    // Time should have advanced by card's time value
    #expect(state.timePosition == card2.time)
  }

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
