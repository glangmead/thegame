//
//  LoDCardAndQuestTests.swift
//  DynamicalSystems
//
//  Tests for LoD cards, decks, victory/defeat, quests, fortune spell, housekeeping, magic items.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDCardAndQuestTests {

  // MARK: - Victory / Defeat (rule 11.0)

  @Test
  func outcomeOngoing() {
    // Fresh game is ongoing.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.outcome == .ongoing)
    #expect(!state.ended)
    #expect(!state.victory)
  }

  @Test
  func victoryOnFinalTwilight() {
    // Rule 11.0: Survive until end of Final Twilight turn → victory.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 15

    state.checkVictory()
    #expect(state.ended)
    #expect(state.victory)
    #expect(state.outcome == .victory)
  }

  @Test
  func noVictoryBeforeFinalTwilight() {
    // Not yet at Final Twilight → checkVictory does nothing.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 14

    state.checkVictory()
    #expect(!state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .ongoing)
  }

  @Test
  func victoryBlockedByPriorDefeat() {
    // If already defeated, checkVictory does not override.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 15
    state.ended = true // defeated before reaching victory check
    state.victory = false

    state.checkVictory()
    #expect(state.ended)
    #expect(!state.victory) // still defeated
  }

  @Test
  func defeatByBreachOutcome() {
    // Army enters castle through existing breach → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.breaches.insert(.east)

    _ = state.advanceArmy(.east) // army enters castle
    #expect(state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .defeatBreached)
  }

  @Test
  func defeatByBarricadeBreakOutcome() {
    // Army breaks through barricade → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.barricades.insert(.east) // Goblin strength 2

    _ = state.advanceArmy(.east, dieRoll: 2) // 2 ≤ 2 → barricade breaks
    #expect(state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .defeatBreached)
  }

  @Test
  func defeatByAllDefendersLostOutcome() {
    // All defenders reduced to 0 → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 1

    state.loseDefender(.priests)
    #expect(state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .defeatAllDefendersLost)
  }

  @Test
  func partialDefenderLossNotDefeat() {
    // Some defenders remain → game continues.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 2

    state.loseDefender(.priests)
    #expect(!state.ended)
    #expect(state.outcome == .ongoing)
    #expect(state.defenders[.priests] == 1)
  }

  // MARK: - Card Data Model

  @Test
  func cardCount() {
    // 36 cards total: 20 day, 16 night.
    let allCards = LoD.allCards
    #expect(allCards.count == 36)
    #expect(LoD.dayCards.count == 20)
    #expect(LoD.nightCards.count == 16)
  }

  @Test
  func dayCardProperties() {
    // Card #1: "Over the Walls!" — day card, advances West + East,
    // 3 actions, 1 heroic, event "Catapult Shrapnel", no quest, 0 time.
    let card = LoD.allCards.first { $0.number == 1 }!
    #expect(card.title == "Over the Walls!")
    #expect(card.deck == .day)
    #expect(card.advances == [.west, .east])
    #expect(card.actions == 3)
    #expect(card.heroics == 1)
    #expect(card.actionDRMs.isEmpty)
    #expect(card.heroicDRMs.isEmpty)
    #expect(card.event != nil)
    #expect(card.event?.title == "Catapult Shrapnel")
    #expect(card.quest == nil)
    #expect(card.time == 0)
    #expect(card.bloodyBattle == nil)
  }

  @Test
  func nightCardProperties() {
    // Card #21: "Nightmares" — night card, advances all 5 tracks,
    // 3 actions, 3 heroics, +1 attack DRM on terror, 2 time icons.
    let card = LoD.allCards.first { $0.number == 21 }!
    #expect(card.title == "Nightmares")
    #expect(card.deck == .night)
    #expect(card.advances == [.east, .west, .sky, .terror, .gate])
    #expect(card.actions == 3)
    #expect(card.heroics == 3)
    #expect(card.actionDRMs.count == 1)
    #expect(card.actionDRMs[0].action == .attack)
    #expect(card.actionDRMs[0].track == .terror)
    #expect(card.actionDRMs[0].value == 1)
    #expect(card.event == nil)
    #expect(card.quest == nil)
    #expect(card.time == 2)
    #expect(card.bloodyBattle == nil)
  }

  @Test
  func cardWithQuest() {
    // Card #2 has quest "Scrolls of the Dead", target 7.
    let card = LoD.allCards.first { $0.number == 2 }!
    #expect(card.quest != nil)
    #expect(card.quest?.title == "Scrolls of the Dead")
    #expect(card.quest?.target == 7)
  }

  @Test
  func cardWithBloodyBattle() {
    // Card #3 has bloody battle on gate track.
    let card = LoD.allCards.first { $0.number == 3 }!
    #expect(card.bloodyBattle == .gate)
  }

  @Test
  func cardGlobalDRM() {
    // Card #3 has global -1 attack DRM (no track restriction).
    let card = LoD.allCards.first { $0.number == 3 }!
    #expect(card.actionDRMs.count == 1)
    #expect(card.actionDRMs[0].action == .attack)
    #expect(card.actionDRMs[0].track == nil)
    #expect(card.actionDRMs[0].value == -1)
  }

  @Test
  func cardTrackSpecificDRM() {
    // Card #2 has +1 attack DRM on gate track only.
    let card = LoD.allCards.first { $0.number == 2 }!
    #expect(card.actionDRMs.count == 1)
    #expect(card.actionDRMs[0].action == .attack)
    #expect(card.actionDRMs[0].track == .gate)
    #expect(card.actionDRMs[0].value == 1)
  }

  @Test
  func cardHeroicDRM() {
    // Card #3 has +1 rally DRM in heroicDRMs.
    let card = LoD.allCards.first { $0.number == 3 }!
    #expect(card.heroicDRMs.count == 1)
    #expect(card.heroicDRMs[0].action == .rally)
    #expect(card.heroicDRMs[0].value == 1)
  }

  @Test
  func cardQuestWithPenalty() {
    // Card #15 has quest "Last Ditch Efforts" with a penalty.
    let card = LoD.allCards.first { $0.number == 15 }!
    #expect(card.quest?.title == "Last Ditch Efforts")
    #expect(card.quest?.target == 6)
    #expect(card.quest?.penalty == "Reduce Morale by one")
  }

}
