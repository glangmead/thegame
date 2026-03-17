//
//  LoDSpecialRulesItemsTests.swift
//  DynamicalSystems
//
//  Tests for LoD special rules: Magic Items, Acid Upgrade, Paladin Re-roll.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDSpecialRulesItemsTests {

  // MARK: - Magic Items (rule 9.2)

  @Test
  func magicSwordBeforeRollAdds2DRM() {
    // Magic Sword used before rolling gives +2 DRM to melee attack.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.magicSwordState = LoD.MagicItemState()
    state.armyPosition[.east] = 1 // melee range
    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 1 normally always fails. With +2 DRM from sword and card DRM:
    // Card 3 has attack DRM -1. So: roll 3 + (-1) + 2 = 4. Goblin str 2. 4 > 2 = hit.
    let eastPosBefore = state.armyPosition[.east]!
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: .before)))
    }
    // Should have hit — army retreated
    #expect(state.armyPosition[.east]! > eastPosBefore)
    // Sword consumed
    #expect(state.magicSwordState == nil)
  }

  @Test
  func magicSwordAfterRollAdds1DRM() {
    // Magic Sword used after seeing roll gives +1 DRM.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.magicSwordState = LoD.MagicItemState()
    state.armyPosition[.east] = 1

    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 3 + card DRM (-1) + sword after (+1) = 3. Goblin str 2. 3 > 2 = hit.
    let eastPosBefore = state.armyPosition[.east]!
    LoD.$rollDie.withValue({ 3 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: .after)))
    }
    #expect(state.armyPosition[.east]! > eastPosBefore)
    #expect(state.magicSwordState == nil)
  }

  @Test
  func magicBowBeforeRollAdds2DRM() {
    // Magic Bow used before rolling gives +2 DRM to ranged attack.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.magicBowState = LoD.MagicItemState()
    _ = game.reduce(into: &state, action: .drawCard)

    let eastPosBefore = state.armyPosition[.east]!
    // Roll 1 always fails regardless of DRM (natural 1 rule)
    // Use roll 2 instead: roll 2 + bow before (+2) = 4. Goblin str 2. 4 > 2 = hit.
    LoD.$rollDie.withValue({ 2 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.rangedAttack(
          .east,
          bloodyBattleDefender: nil, useMagicBow: .before)))
    }
    #expect(state.armyPosition[.east]! > eastPosBefore)
    #expect(state.magicBowState == nil)
  }

  @Test
  func magicItemNotConsumedWhenNotHeld() {
    // Trying to use magic sword when not held: no bonus, no crash.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.magicSwordState = nil
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 2 + card DRM (-1) + no sword = 1. 1 is natural fail anyway, but the point
    // is it shouldn't crash.
    LoD.$rollDie.withValue({ 2 }) {
      _ = game.reduce(
        into: &state,
        action: .combat(.meleeAttack(
          .east,
          bloodyBattleDefender: nil, useMagicSword: .before)))
    }
    #expect(state.magicSwordState == nil)
  }

  // MARK: - Acid Upgrade Free Attack (rule 6.3)

  @Test
  func acidUpgradeFreeAttackOnAdvance() {
    // Army advancing to space 1 on acid-upgraded track gets a free ranged attack.
    // Test through composed game: inject acid die roll via advanceArmies action.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2  // Will advance to 1
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    // Manually invoke advanceArmies with acid die roll = 6 (goblin str 2, 6 > 2 = hit)
    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .advanceArmies)
    }

    // After acid attack hit, army should be pushed back from 1 to 2
    #expect(state.armyPosition[.east]! == 2)
  }

  @Test
  func acidUpgradeNoAttackWithoutDieRoll() {
    // Army advancing to space 1 on acid track but no die roll provided → no attack.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    // advanceArmies with no acid die rolls
    _ = game.reduce(into: &state, action: .advanceArmies)

    // Without die roll, army just stays at space 1 (no free attack)
    #expect(state.armyPosition[.east]! == 1)
  }

  @Test
  func acidUpgradeNoAttackOnOtherSpaces() {
    // Army advancing to space 3 (not 1) on acid track → no free attack.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 4  // Will advance to 3
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    LoD.$rollDie.withValue({ 6 }) {
      _ = game.reduce(into: &state, action: .advanceArmies)
    }

    // Should just advance normally to space 3 — acid only triggers at space 1
    #expect(state.armyPosition[.east]! == 3)
  }

}
