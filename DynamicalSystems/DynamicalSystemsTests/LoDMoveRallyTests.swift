//
//  LoDMoveRallyTests.swift
//  DynamicalSystems
//
//  Tests for LoD player actions: Move Hero, Rally.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDMoveRallyTests {

  // MARK: - Move Hero (rule 7.1)

  @Test
  func moveHeroToTrack() {
    // Move Warrior from reserves to East track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.heroLocation[.warrior] == .reserves)

    state.moveHero(.warrior, to: .onTrack(.east))
    #expect(state.heroLocation[.warrior] == .onTrack(.east))
  }

  @Test
  func moveHeroBetweenTracks() {
    // Move hero from one track to another.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)

    state.moveHero(.warrior, to: .onTrack(.west))
    #expect(state.heroLocation[.warrior] == .onTrack(.west))
  }

  @Test
  func moveHeroBackToReserves() {
    // Move hero from a track back to reserves.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)

    state.moveHero(.warrior, to: .reserves)
    #expect(state.heroLocation[.warrior] == .reserves)
  }

  // MARK: - Rally (rule 7.4)

  @Test
  func rallySuccess() {
    // Roll 5 > 4 → raise morale one step.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)

    let success = state.rally(dieRoll: 5)
    #expect(success)
    #expect(state.morale == .high)
  }

  @Test
  func rallyFailure() {
    // Roll 4 ≤ 4 → fails.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 4)
    #expect(!success)
    #expect(state.morale == .normal)
  }

  @Test
  func rallyNaturalOneFails() {
    // Natural 1 always fails even with DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 1, drm: 10)
    #expect(!success)
    #expect(state.morale == .normal)
  }

  @Test
  func rallyWithDRM() {
    // Paladin +1 rally DRM. Roll 4 + DRM 1 = 5 > 4 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 4, drm: 1)
    #expect(success)
    #expect(state.morale == .high)
  }

  @Test
  func paladinInReservesGivesRallyDRM() {
    // Rule 10.2: Paladin adds +1 rally DRM regardless of location
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3, heroes: [.warrior, .paladin, .cleric])
    state.heroLocation[.paladin] = .reserves
    let drm = state.totalRallyDRM()
    #expect(drm == 1, "Paladin should give +1 rally DRM even from reserves")
  }

  @Test
  func rallyMoraleCapped() {
    // Morale already high → stays high.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high

    let success = state.rally(dieRoll: 6)
    #expect(success)
    #expect(state.morale == .high)
  }

}
