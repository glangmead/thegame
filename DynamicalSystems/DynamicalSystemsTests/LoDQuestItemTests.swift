//
//  LoDQuestItemTests.swift
//  DynamicalSystems
//
//  Tests for LoD magic items from quest rewards.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDQuestItemTests {

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
