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

  // MARK: - Deck Management (rule 3.0)

  @Test
  func deckSetupCardCounts() {
    // After setup, day draw pile has 20 cards, night has 16, discards empty.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks()
    #expect(state.dayDrawPile.count == 20)
    #expect(state.nightDrawPile.count == 16)
    #expect(state.dayDiscardPile.isEmpty)
    #expect(state.nightDiscardPile.isEmpty)
  }

  @Test
  func noCurrentCardAfterSetup() {
    // No card drawn yet after setup.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks()
    #expect(state.currentCard == nil)
  }

  @Test
  func drawFromDayOnDaySpace() {
    // On a day space (position 1), draw from day deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1 // day space

    let card = state.drawCard()
    #expect(card != nil)
    #expect(card!.deck == .day)
    #expect(state.currentCard == card)
    #expect(state.dayDrawPile.count == 19)
    #expect(state.nightDrawPile.count == 16) // unchanged
  }

  @Test
  func drawFromDayOnDawnSpace() {
    // Dawn spaces also draw from the day deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 0 // First Dawn

    let card = state.drawCard()
    #expect(card!.deck == .day)
  }

  @Test
  func drawFromNightOnNightSpace() {
    // On a night space (position 4), draw from night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 4 // night space

    let card = state.drawCard()
    #expect(card != nil)
    #expect(card!.deck == .night)
    #expect(state.currentCard == card)
    #expect(state.nightDrawPile.count == 15)
    #expect(state.dayDrawPile.count == 20) // unchanged
  }

  @Test
  func drawFromNightOnTwilightSpace() {
    // Twilight spaces draw from the night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 3 // first twilight

    let card = state.drawCard()
    #expect(card!.deck == .night)
  }

  @Test
  func drawSetsCurrentCard() {
    // After drawing, currentCard is set to the drawn card.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let card = state.drawCard()
    #expect(state.currentCard == card)
    #expect(card!.number == LoD.dayCards[0].number)
  }

  @Test
  func drawReducesPile() {
    // Drawing removes the top card from the draw pile.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    _ = state.drawCard()
    #expect(state.dayDrawPile.count == 19)
    _ = state.drawCard()
    #expect(state.dayDrawPile.count == 18)
  }

  @Test
  func drawDiscardsPreviousCard() {
    // Drawing a new card discards the previous current card.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let first = state.drawCard()!
    let second = state.drawCard()!
    #expect(second != first)
    #expect(state.currentCard == second)
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == first)
  }

  @Test
  func drawReshufflesWhenEmpty() {
    // Rule 3.0: When draw pile is empty, discard pile is reshuffled back in.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Set up with just 1 day card so the pile empties quickly.
    let oneCard = [LoD.dayCards[0]]
    state.setupDecks(shuffledDayCards: oneCard, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    // Draw the only card.
    let first = state.drawCard()!
    #expect(state.dayDrawPile.isEmpty)

    // Draw again — should reshuffle discard back into draw pile.
    // Use deterministic reshuffle order.
    let card = state.drawCard(reshuffleOrder: [first])
    #expect(card == first) // same card reshuffled back
    #expect(state.dayDiscardPile.isEmpty) // discard was moved to draw pile
  }

  // MARK: - Fortune Spell (arcane, cost 4)

  @Test
  func fortunePeekShowsTopCards() {
    // Peek at the top 3 cards of the current deck without modifying state.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1 // day space → day deck

    let peeked = state.fortunePeek()
    #expect(peeked.count == 3)
    #expect(peeked[0] == LoD.dayCards[0])
    #expect(peeked[1] == LoD.dayCards[1])
    #expect(peeked[2] == LoD.dayCards[2])
    // Deck should be unchanged
    #expect(state.dayDrawPile.count == 20)
  }

  @Test
  func fortuneNormalReorders() {
    // Normal Fortune: look at top 3, put them back in a new order.
    // Reorder [0,1,2] → [2,0,1].
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let original = state.fortunePeek()
    state.applyFortune(newOrder: [2, 0, 1])

    #expect(state.dayDrawPile.count == 20) // no cards removed
    #expect(state.dayDrawPile[0] == original[2])
    #expect(state.dayDrawPile[1] == original[0])
    #expect(state.dayDrawPile[2] == original[1])
    #expect(state.dayDiscardPile.isEmpty) // nothing discarded
  }

  @Test
  func fortuneHeroicDiscardsOne() {
    // Heroic Fortune: discard 1, put remaining 2 back in chosen order.
    // Discard index 1, keep [0, 2] in order [2, 0].
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let original = state.fortunePeek()
    state.applyFortune(newOrder: [2, 0], discardIndex: 1)

    #expect(state.dayDrawPile.count == 19) // 20 - 3 + 2 = 19
    #expect(state.dayDrawPile[0] == original[2])
    #expect(state.dayDrawPile[1] == original[0])
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == original[1]) // middle card discarded
  }

  @Test
  func fortuneOperatesOnNightDeck() {
    // On a night time space, Fortune operates on the night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 4 // night space

    let peeked = state.fortunePeek()
    #expect(peeked[0] == LoD.nightCards[0])

    state.applyFortune(newOrder: [1, 0, 2])
    #expect(state.nightDrawPile[0] == LoD.nightCards[1])
    #expect(state.nightDrawPile[1] == LoD.nightCards[0])
    #expect(state.dayDrawPile.count == 20) // day deck untouched
  }

  // MARK: - Housekeeping (rule 3.0 step 5)

  @Test
  func housekeepingAdvancesTime() {
    // Housekeeping advances time by the current card's time value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Use a card with time = 1
    let timeCard = LoD.allCards.first { $0.time == 1 }!
    state.currentCard = timeCard
    #expect(state.timePosition == 0)

    state.performHousekeeping()
    #expect(state.timePosition == 1)
  }

  @Test
  func housekeepingZeroTimeNoAdvance() {
    // Card with time = 0 doesn't advance the time marker.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let zeroTimeCard = LoD.allCards.first { $0.time == 0 }!
    state.currentCard = zeroTimeCard
    #expect(state.timePosition == 0)

    state.performHousekeeping()
    #expect(state.timePosition == 0)
  }

  @Test
  func housekeepingResetsTurnEffects() {
    // Housekeeping resets all per-turn tracking.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let card = LoD.allCards.first { $0.time == 0 }!
    state.currentCard = card
    state.noMeleeThisTurn = true
    state.eventAttackDRMBonus = 1
    state.woundedHeroesCannotAct = true
    state.inspireDRMActive = true
    state.paladinRerollUsed = true
    state.bloodyBattlePaidThisTurn = true

    state.performHousekeeping()
    #expect(!state.noMeleeThisTurn)
    #expect(state.eventAttackDRMBonus == 0)
    #expect(!state.woundedHeroesCannotAct)
    #expect(!state.inspireDRMActive)
    #expect(!state.paladinRerollUsed)
    #expect(!state.bloodyBattlePaidThisTurn)
  }

  @Test
  func housekeepingChecksVictory() {
    // If time reaches Final Twilight (position 15), housekeeping triggers victory.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 14 // one space before final twilight
    let timeCard = LoD.allCards.first { $0.time == 1 }!
    state.currentCard = timeCard

    state.performHousekeeping()
    #expect(state.timePosition == 15)
    #expect(state.outcome == .victory)
  }

  @Test
  func housekeepingNoCardNoOp() {
    // No current card → housekeeping does nothing.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.currentCard = nil

    state.performHousekeeping()
    #expect(state.timePosition == 0) // unchanged
  }

  @Test
  func defeatByTerrorDefenderLoss() {
    // Terror/Sky army at space 1 causes defender loss. If that empties all
    // defenders → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.terror] = 1
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 1

    // Terror tries to advance past space 1 → defenderLoss result
    let result = state.advanceArmy(.terror)
    #expect(result == .defenderLoss)
    // The advanceArmy itself doesn't auto-trigger loseDefender — the caller does.
    // But the state should still be ongoing until the defender is actually lost.
    #expect(state.outcome == .ongoing)

    // Caller acts on the defenderLoss result:
    state.loseDefender(.priests)
    #expect(state.outcome == .defeatAllDefendersLost)
  }

  // MARK: - Quest Attempt Mechanic

  @Test
  func questAttemptActionSuccess() {
    // Action attempt: +1 DRM. Quest target 6. Roll 6 + 1 = 7 > 6 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1
    state.drawCard() // draw a card so currentCard is set
    // Find a card with a target-6 quest
    let questCard = LoD.allCards.first { $0.quest?.target == 6 }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: false, dieRoll: 6)
    #expect(result == .success)
  }

  @Test
  func questAttemptHeroicSuccess() {
    // Heroic attempt: +2 DRM. Quest target 7. Roll 6 + 2 = 8 > 7 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest?.target == 7 }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: true, dieRoll: 6)
    #expect(result == .success)
  }

  @Test
  func questAttemptFailure() {
    // Action attempt: +1 DRM. Quest target 6. Roll 5 + 1 = 6 ≤ 6 → failure.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest?.target == 6 }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: false, dieRoll: 5)
    #expect(result == .failure)
  }

  @Test
  func questAttemptNaturalOneFails() {
    // Natural 1 always fails, even with large DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest != nil }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: true, dieRoll: 1, additionalDRM: 10)
    #expect(result == .naturalOneFail)
  }

  @Test
  func questAttemptWithRangerDRM() {
    // Ranger adds +1 quest DRM. Target 6, roll 4 + 1 (action) + 1 (ranger) = 6 ≤ 6 → fail.
    // Roll 5 + 1 + 1 = 7 > 6 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest?.target == 6 }!
    state.currentCard = questCard

    let fail = state.attemptQuest(isHeroic: false, dieRoll: 4, additionalDRM: 1)
    #expect(fail == .failure)

    let success = state.attemptQuest(isHeroic: false, dieRoll: 5, additionalDRM: 1)
    #expect(success == .success)
  }

  @Test
  func questAttemptNoQuest() {
    // No quest on current card → .noQuest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let noQuestCard = LoD.allCards.first { $0.quest == nil }!
    state.currentCard = noQuestCard

    let result = state.attemptQuest(isHeroic: false, dieRoll: 6)
    #expect(result == .noQuest)
  }

  // MARK: - Quest Rewards

  @Test
  func questForlornHopeAdvancesTime() {
    // Forlorn Hope reward: advance time marker +1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.timePosition == 0)

    state.questForlornHope()
    #expect(state.timePosition == 1)
  }

  @Test
  func questScrollsOfDeadRevealsSpell() {
    // Scrolls of the Dead reward: chosen spell becomes known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.chainLightning] == .faceDown)

    state.questScrollsOfDead(chosenSpell: .chainLightning)
    #expect(state.spellStatus[.chainLightning] == .known)
  }

  @Test
  func questScrollsOfDeadIgnoresNonFaceDown() {
    // Can't reveal an already-known or cast spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known

    state.questScrollsOfDead(chosenSpell: .fireball)
    #expect(state.spellStatus[.fireball] == .known) // unchanged
  }

  @Test
  func questManastonesGainsEnergy() {
    // Manastones reward: +1 arcane, +1 divine.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let arcaneBefore = state.arcaneEnergy
    let divineBefore = state.divineEnergy

    state.questManastones()
    #expect(state.arcaneEnergy == min(arcaneBefore + 1, 6))
    #expect(state.divineEnergy == min(divineBefore + 1, 6))
  }

  @Test
  func questMagicBowGivesItem() {
    // Arrows of the Dead reward: gain Magic Bow.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicBow)

    state.questMagicBow()
    #expect(state.hasMagicBow)
  }

  @Test
  func questPutForthCallGainsDefender() {
    // Put Forth the Call reward: +1 defender of choice.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.archers] = 1

    state.questPutForthCall(defender: .archers)
    #expect(state.defenders[.archers] == 2)
  }

  @Test
  func questPutForthCallCapped() {
    // Defender cannot exceed max value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenders[.archers] == 2) // already at max

    state.questPutForthCall(defender: .archers)
    #expect(state.defenders[.archers] == 2) // stays at max
  }

  @Test
  func questLastDitchEffortsAddsHero() {
    // Last Ditch Efforts reward: add an unselected hero to reserves.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.heroLocation[.ranger] == nil) // not in play

    state.questLastDitchEfforts(hero: .ranger)
    #expect(state.heroLocation[.ranger] == .reserves)
  }

  @Test
  func questLastDitchPenaltyLowersMorale() {
    // Last Ditch Efforts penalty: reduce morale by one.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)

    state.questLastDitchPenalty()
    #expect(state.morale == .low)
  }

  @Test
  func questVorpalBladeGivesItem() {
    // The Vorpal Blade reward: gain Magic Sword.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicSword)

    state.questVorpalBlade()
    #expect(state.hasMagicSword)
  }

  @Test
  func questPillarsOfEarthRetreatsArmy() {
    // Pillars of the Earth reward: retreat one army (except Sky) two spaces.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    state.questPillarsOfEarth(slot: .east)
    #expect(state.armyPosition[.east] == 5) // retreated from 3 to 5
  }

  @Test
  func questPillarsOfEarthRetreatCapped() {
    // Retreat capped at maxSpace (6 for East).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    state.questPillarsOfEarth(slot: .east)
    #expect(state.armyPosition[.east] == 6) // capped at max
  }

  @Test
  func questPillarsOfEarthCannotTargetSky() {
    // Sky army excluded from Pillars of the Earth.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 3

    state.questPillarsOfEarth(slot: .sky)
    #expect(state.armyPosition[.sky] == 3) // unchanged
  }

  @Test
  func questMirrorOfMoonGainsArcane() {
    // Save the Mirror of the Moon reward: +2 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.arcaneEnergy = 3

    state.questMirrorOfMoon()
    #expect(state.arcaneEnergy == 5)
  }

  @Test
  func questMirrorOfMoonCapped() {
    // Arcane energy capped at 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.arcaneEnergy = 5

    state.questMirrorOfMoon()
    #expect(state.arcaneEnergy == 6) // capped
  }

  @Test
  func questProphecyRevealedDiscardsOne() {
    // Prophecy Revealed: reveal top 3 Day cards, discard one, put rest back.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    let topThree = Array(state.dayDrawPile.prefix(3))

    state.questProphecyRevealed(discardIndex: 1) // discard the middle card
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == topThree[1]) // middle card discarded
    #expect(state.dayDrawPile.count == 19) // 20 - 3 + 2 = 19
    // The first and third cards should be back on top
    #expect(state.dayDrawPile[0] == topThree[0])
    #expect(state.dayDrawPile[1] == topThree[2])
  }

  // MARK: - Magic Items (quest rewards)

  @Test
  func useMagicSwordBefore() {
    // Magic Sword before melee: +2 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicSword = true

    let drm = state.useMagicSword(timing: .before)
    #expect(drm == 2)
    #expect(!state.hasMagicSword)
  }

  @Test
  func useMagicSwordAfter() {
    // Magic Sword after melee: +1 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicSword = true

    let drm = state.useMagicSword(timing: .after)
    #expect(drm == 1)
    #expect(!state.hasMagicSword)
  }

  @Test
  func useMagicSwordNotHeld() {
    // No Magic Sword → 0 DRM, nothing consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicSword)

    let drm = state.useMagicSword(timing: .before)
    #expect(drm == 0)
  }

  @Test
  func useMagicBowBefore() {
    // Magic Bow before ranged: +2 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicBow = true

    let drm = state.useMagicBow(timing: .before)
    #expect(drm == 2)
    #expect(!state.hasMagicBow)
  }

  @Test
  func useMagicBowAfter() {
    // Magic Bow after ranged: +1 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicBow = true

    let drm = state.useMagicBow(timing: .after)
    #expect(drm == 1)
    #expect(!state.hasMagicBow)
  }

  @Test
  func useMagicBowNotHeld() {
    // No Magic Bow → 0 DRM, nothing consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicBow)

    let drm = state.useMagicBow(timing: .before)
    #expect(drm == 0)
  }

}
