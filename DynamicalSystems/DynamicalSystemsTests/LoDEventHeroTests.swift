//
//  LoDEventHeroTests.swift
//  DynamicalSystems
//
//  Tests for LoD hero, morale, energy, and miscellaneous events (rule 5.0).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDEventHeroTests {

  // -- Acts of Valor (card #8) --

  @Test
  func actsOfValorWoundForBonus() {
    // Wound all unwounded heroes → +1 attack DRM this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.eventAttackDRMBonus == 0)
    state.eventActsOfValor(woundHeroes: true)
    #expect(state.heroWounded.contains(.warrior))
    #expect(state.heroWounded.contains(.wizard))
    #expect(state.heroWounded.contains(.cleric))
    #expect(state.eventAttackDRMBonus == 1)
  }

  @Test
  func actsOfValorDecline() {
    // Choose not to wound → no bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventActsOfValor(woundHeroes: false)
    #expect(state.heroWounded.isEmpty)
    #expect(state.eventAttackDRMBonus == 0)
  }

  // -- Bloody Handprints (card #24) --

  @Test
  func bloodyHandprintsKill() {
    // Roll 1-3: kill a Hero (wounded first).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.warrior) // wounded → must be killed first
    state.eventBloodyHandprints(dieRoll: 2, chosenHero: .warrior)
    #expect(state.heroDead.contains(.warrior))
    #expect(!state.heroWounded.contains(.warrior))
    #expect(state.heroLocation[.warrior] == nil)
  }

  @Test
  func bloodyHandprintsWound() {
    // Roll 4-6: wound a Hero (player choice).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventBloodyHandprints(dieRoll: 5, chosenHero: .wizard)
    #expect(state.heroWounded.contains(.wizard))
    #expect(!state.heroDead.contains(.wizard))
  }

  // -- Council of Heroes (card #26) --

  @Test
  func councilOfHeroes() {
    // Return all living heroes to Reserves. Wounded heroes cannot act.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)
    state.heroLocation[.wizard] = .onTrack(.west)
    // cleric already in reserves

    state.eventCouncilOfHeroes()
    #expect(state.heroLocation[.warrior] == .reserves)
    #expect(state.heroLocation[.wizard] == .reserves)
    #expect(state.heroLocation[.cleric] == .reserves)
    #expect(state.woundedHeroesCannotAct)
  }

  // -- Midnight Magic (card #27) / By the Light of the Moon (card #32) --

  @Test
  func midnightMagicLow() {
    // Roll 1-3: +1 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 2)
    #expect(state.arcaneEnergy == min(before + 1, 6))
  }

  @Test
  func midnightMagicHigh() {
    // Roll 4-6: +2 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane = 1+2 = 3
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 5)
    #expect(state.arcaneEnergy == min(before + 2, 6))
  }

  // -- Assassin's Creedo (card #30) --

  @Test
  func assassinsCreedoKill() {
    // Roll 1-3: kill a Hero of your choice.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAssassinsCreedo(dieRoll: 2, chosenHero: .cleric)
    #expect(state.heroDead.contains(.cleric))
    #expect(state.heroLocation[.cleric] == nil)
  }

  @Test
  func assassinsCreedoBonus() {
    // Roll 4-6: +1 attack DRM this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAssassinsCreedo(dieRoll: 5)
    #expect(state.eventAttackDRMBonus == 1)
  }

  // -- In the Pale Moonlight (card #31) --

  @Test
  func paleMoonlight() {
    // -1 divine, +1 arcane, lose one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane 5, divine 5
    let arcBefore = state.arcaneEnergy
    let divBefore = state.divineEnergy
    state.eventPaleMoonlight()
    #expect(state.arcaneEnergy == min(arcBefore + 1, 6))
    #expect(state.divineEnergy == divBefore - 1)
    #expect(state.defenderPosition[.priests] == 1) // moved one space
    #expect(state.defenderValue(for: .priests) == 2) // track [2,2,1,0]: still 2
  }

  // -- By the Light of the Moon (card #32) — same as Midnight Magic --

  @Test
  func byLightOfMoon() {
    // Uses same method as Midnight Magic. Roll 4-6: +2 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane = 3
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 6)
    #expect(state.arcaneEnergy == min(before + 2, 6))
  }

}
