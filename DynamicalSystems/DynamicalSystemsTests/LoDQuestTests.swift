//
//  LoDQuestTests.swift
//  DynamicalSystems
//
//  Tests for LoD quest mechanics, quest rewards, and magic items.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDQuestTests {

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

}
