//
//  LoDCombatTests.swift
//  DynamicalSystems
//
//  Tests for LoD combat: Battle Resolution, Gate Targeting, Hero Combat Properties, Heroic Attack, Hero Wounding, Upgrade Attack DRMs, Bloody Battle, Paladin Re-roll, Turn Reset.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDCombatTests {

  // MARK: - Battle Resolution (rule 8.0)

  @Test
  func attackHitPushesBack() {
    // Rule 8.0: Modified roll > army strength pushes army back one space.
    // Goblin (strength 2) at East space 3. Roll 4 > 2 → hit, pushed to 4.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 3, pushedTo: 4))
    #expect(state.armyPosition[.east] == 4)
  }

  @Test
  func attackMiss() {
    // Rule 8.0: Modified roll ≤ strength = miss. Goblin (2) at East 3. Roll 2 ≤ 2.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 2)
    #expect(result == .miss(.east))
    #expect(state.armyPosition[.east] == 3) // unchanged
  }

  @Test
  func naturalOneAlwaysFails() {
    // Rules: Natural roll of 1 always fails, even with large DRM.
    // Goblin (2) at East 2. Roll 1 + DRM 10 would be 11, but natural 1 = fail.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 1, drm: 10)
    #expect(result == .naturalOneFail(.east))
    #expect(state.armyPosition[.east] == 2) // unchanged
  }

  @Test
  func meleeRequiresRedSpace() {
    // Rule 8.0: Melee attack only on red-tinted (melee range) spaces.
    // Goblin at East 5 (blue) → can't melee.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 6)
    #expect(result == .targetNotInMeleeRange)
  }

  @Test
  func rangedCanTargetAnySpace() {
    // Rule 8.0: Ranged attacks can target armies on any space (red or blue).
    // Goblin (2) at East 5 (blue). Roll 4 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(on: .east, attackType: .ranged, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 5, pushedTo: 6))
  }

  @Test
  func rangedCannotTargetTerror() {
    // Rule 4.2: Terror track is melee-only — no ranged attacks permitted.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.terror] = 2

    let result = state.resolveAttack(on: .terror, attackType: .ranged, dieRoll: 6)
    #expect(result == .targetNotInRange)
  }

  @Test
  func attackNotOnBoard() {
    // Attack on an army not on the board.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.terror] == nil)

    let result = state.resolveAttack(on: .terror, attackType: .melee, dieRoll: 6)
    #expect(result == .targetNotOnBoard)
  }

  @Test
  func attackWithDRM() {
    // DRMs add to die roll. Orc (strength 3) at Gate 2. Roll 2 + DRM 2 = 4 > 3 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2

    let result = state.resolveAttack(on: .gate1, attackType: .melee, dieRoll: 2, drm: 2)
    #expect(result == .hit(.gate1, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalIgnoresNegativeDRMInMelee() {
    // Rules: Magical attacks in melee range ignore negative DRMs.
    // Goblin (2) at East 2 (melee range). Roll 3, DRM -2 → effective DRM 0.
    // Modified roll = 3 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(
      on: .east, attackType: .melee, dieRoll: 3, drm: -2, isMagical: true
    )
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalKeepsPositiveDRM() {
    // Magical attack in melee range with positive DRM — DRM is kept.
    // Goblin (2) at East 2. Roll 2, DRM +1 → modified 3 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(
      on: .east, attackType: .melee, dieRoll: 2, drm: 1, isMagical: true
    )
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalAtRangeKeepsNegativeDRM() {
    // Magical attack NOT in melee range — negative DRM still applies.
    // Goblin (2) at East 5 (ranged only). Roll 3, DRM -2 → modified 1 ≤ 2 → miss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(
      on: .east, attackType: .ranged, dieRoll: 3, drm: -2, isMagical: true
    )
    #expect(result == .miss(.east))
  }

  @Test
  func hitCannotPushPastMaxSpace() {
    // Army already at max space — push has nowhere to go, stays at max.
    // Goblin (2) at East 6. Roll 4 > 2 → hit, pushed to min(7, 6) = 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.east] == 6)

    let result = state.resolveAttack(on: .east, attackType: .ranged, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 6, pushedTo: 6))
    #expect(state.armyPosition[.east] == 6)
  }

  // MARK: - Gate Targeting (rules 4.1.1, 8.1.2)

  @Test
  func gateTargetClosest() {
    // Only the closest (lowest space) Gate army can be targeted.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 4

    let targets = state.gateAttackTargets()
    #expect(targets == [.gate1]) // gate1 at 2 is closer
  }

  @Test
  func gateTargetTiedChoose() {
    // Rule 8.1.2: Both armies on same space → player can choose either.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3

    let targets = state.gateAttackTargets()
    #expect(targets.count == 2)
    #expect(targets.contains(.gate1))
    #expect(targets.contains(.gate2))
  }

  @Test
  func gateTargetOneAbsent() {
    // One Gate army not on board → the other is the only target.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = nil

    let targets = state.gateAttackTargets()
    #expect(targets == [.gate1])
  }

  // MARK: - Hero Combat Properties (Player Aid)

  @Test
  func heroCombatDRMs() {
    // Warrior gets +2, all others get +1.
    #expect(LoD.HeroType.warrior.combatDRM == 2)
    #expect(LoD.HeroType.wizard.combatDRM == 1)
    #expect(LoD.HeroType.ranger.combatDRM == 1)
    #expect(LoD.HeroType.rogue.combatDRM == 1)
    #expect(LoD.HeroType.paladin.combatDRM == 1)
    #expect(LoD.HeroType.cleric.combatDRM == 1)
  }

  @Test
  func heroAttackTypes() {
    // Warrior, Rogue, Paladin are melee. Wizard, Ranger, Cleric are ranged.
    #expect(!LoD.HeroType.warrior.isRangedCombatant)
    #expect(LoD.HeroType.wizard.isRangedCombatant)
    #expect(LoD.HeroType.ranger.isRangedCombatant)
    #expect(!LoD.HeroType.rogue.isRangedCombatant)
    #expect(!LoD.HeroType.paladin.isRangedCombatant)
    #expect(LoD.HeroType.cleric.isRangedCombatant)
  }

  @Test
  func heroWoundImmunity() {
    // Warrior (armored) and Ranger (agile) are immune to wounding in combat.
    #expect(LoD.HeroType.warrior.isWoundImmuneInCombat)
    #expect(LoD.HeroType.ranger.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.wizard.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.rogue.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.paladin.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.cleric.isWoundImmuneInCombat)
  }

  // MARK: - Heroic Attack (rule 7.0)

  @Test
  func heroicAttackHit() {
    // Warrior (+2 melee) attacks Goblin (strength 2) at East space 2.
    // Roll 2 + DRM 2 = 4 > 2 → hit, pushed to 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 2)
    let result = try! outcome.get()
    #expect(result.attackResult == .hit(.east, pushedFrom: 2, pushedTo: 3))
    #expect(!result.heroWounded)
    #expect(!result.heroKilled)
  }

  @Test
  func heroicAttackMiss() {
    // Rogue (+1 melee) attacks Orc (strength 3) at Gate space 2.
    // Roll 2 + DRM 1 = 3 ≤ 3 → miss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2
    state.heroLocation[.rogue] = .onTrack(.gate)

    let outcome = state.resolveHeroicAttack(hero: .rogue, on: .gate1, dieRoll: 2)
    let result = try! outcome.get()
    #expect(result.attackResult == .miss(.gate1))
    #expect(!result.heroWounded)
  }

  @Test
  func heroicAttackNaturalOneWoundsHero() {
    // Rule 7.0: Natural 1 on heroic attack fails AND wounds non-immune hero.
    // Wizard (+1 ranged) attacks Goblin at East 5. Roll 1 → fail + wound.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 1)
    let result = try! outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(result.heroWounded)
    #expect(!result.heroKilled)
    #expect(state.heroWounded.contains(.wizard))
  }

  @Test
  func heroicAttackNaturalOneDoesNotWoundImmune() {
    // Warrior (armored) and Ranger (agile) are immune to wounding in combat.
    // Warrior attacks Goblin at East 2. Roll 1 → fail but NOT wounded.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 1)
    let result = try! outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(!result.heroWounded)
    #expect(!result.heroKilled)
    #expect(!state.heroWounded.contains(.warrior))
  }

  @Test
  func heroicAttackSecondWoundKillsHero() {
    // Already-wounded hero rolls natural 1 → killed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)
    state.heroWounded.insert(.wizard) // already wounded

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 1)
    let result = try! outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(!result.heroWounded) // not "newly wounded" — killed instead
    #expect(result.heroKilled)
    #expect(state.heroDead.contains(.wizard))
    #expect(!state.heroWounded.contains(.wizard))
    #expect(state.heroLocation[.wizard] == nil) // removed from play
  }

  @Test
  func heroicAttackRangedHero() {
    // Wizard (+1 ranged) can target blue spaces. Goblin (2) at East 5.
    // Roll 3 + DRM 1 = 4 > 2 → hit, pushed to 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 3)
    let result = try! outcome.get()
    #expect(result.attackResult == .hit(.east, pushedFrom: 5, pushedTo: 6))
  }

  @Test
  func heroicAttackMeleeHeroCannotReachBlueSpace() {
    // Warrior (melee) cannot target army at East 5 (blue/ranged-only space).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 6)
    let result = try! outcome.get()
    #expect(result.attackResult == .targetNotInMeleeRange)
    #expect(!result.heroWounded) // no wound on validation failure
  }

  @Test
  func heroicAttackRequiresSameTrack() {
    // Rule 7.3: Hero must be on the same track as the target army.
    // Warrior on East track cannot attack army on West track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .west, dieRoll: 6)
    #expect(outcome == .failure(.heroOnWrongTrack))
  }

  @Test
  func heroicAttackRequiresTrackAssignment() {
    // Hero in reserves cannot make heroic attacks.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    // Warrior is in reserves (default from setup)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 6)
    #expect(outcome == .failure(.heroOnWrongTrack))
  }

  @Test
  func heroicAttackHeroNotInPlay() {
    // Hero not in game (e.g. Ranger not in Greenskin default roster).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let outcome = state.resolveHeroicAttack(hero: .ranger, on: .east, dieRoll: 6)
    #expect(outcome == .failure(.heroNotOnTrack))
  }

  // MARK: - Hero Wounding

  @Test
  func woundHealthyHero() {
    // Wound a healthy hero → becomes wounded.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.heroWounded.contains(.wizard))

    state.woundHero(.wizard)
    #expect(state.heroWounded.contains(.wizard))
    #expect(!state.heroDead.contains(.wizard))
  }

  @Test
  func woundWoundedHeroKills() {
    // Wound an already-wounded hero → killed, removed from play.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.wizard)

    state.woundHero(.wizard)
    #expect(state.heroDead.contains(.wizard))
    #expect(!state.heroWounded.contains(.wizard))
    #expect(state.heroLocation[.wizard] == nil)
  }

  // MARK: - Upgrade Attack DRMs (rule 6.3)

  @Test
  func upgradeGreaseDRM() {
    // Grease is a breach-prevention mechanic, NOT a DRM (rule 6.3).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease

    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
    #expect(state.upgradeDRM(on: .east, attackType: .ranged) == 0)
  }

  @Test
  func upgradeOilDRM() {
    // Oil: +1 DRM to melee or ranged against army in space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.west] = .oil

    #expect(state.upgradeDRM(on: .west, attackType: .melee) == 1)
    #expect(state.upgradeDRM(on: .west, attackType: .ranged) == 1)
  }

  @Test
  func upgradeLavaDRM() {
    // Lava: +2 DRM to melee only against army in space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.gate] = .lava

    #expect(state.upgradeDRM(on: .gate, attackType: .melee) == 2)
    #expect(state.upgradeDRM(on: .gate, attackType: .ranged) == 0) // melee only
  }

  @Test
  func upgradeAcidNoDRM() {
    // Acid: free attack, not a DRM bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .acid

    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
    #expect(state.upgradeDRM(on: .east, attackType: .ranged) == 0)
  }

  @Test
  func upgradeNoneNoDRM() {
    // No upgrade on track → 0 DRM.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
  }

  // MARK: - Bloody Battle (Player Aid: Markers)

  @Test
  func bloodyBattleFirstAttackCostsDefender() {
    // First attack against army with bloody battle marker costs 1 defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(shouldLose)
    #expect(state.bloodyBattlePaidThisTurn)
  }

  @Test
  func bloodyBattleSecondAttackNoCost() {
    // After paying once, subsequent attacks this turn don't cost a defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east
    state.bloodyBattlePaidThisTurn = true // already paid

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(!shouldLose)
  }

  @Test
  func bloodyBattleWrongArmy() {
    // Attacking a different army than the one with the marker — no cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east

    let shouldLose = state.checkBloodyBattle(attacking: .west)
    #expect(!shouldLose)
  }

  @Test
  func bloodyBattleNoMarker() {
    // No bloody battle marker on any army — no cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.bloodyBattleArmy == nil)

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(!shouldLose)
  }

  // MARK: - Paladin Re-roll (Player Aid: Paladin — holy)

  @Test
  func paladinCanReroll() {
    // Paladin alive and in play, not used yet → can re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    #expect(state.canPaladinReroll)

    state.usePaladinReroll()
    #expect(!state.canPaladinReroll)
  }

  @Test
  func paladinCannotRerollWhenDead() {
    // Dead Paladin cannot re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.heroDead.insert(.paladin)
    state.heroLocation.removeValue(forKey: .paladin)

    #expect(!state.canPaladinReroll)
  }

  @Test
  func paladinCannotRerollWhenNotInPlay() {
    // Paladin not in hero roster → cannot re-roll.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3) // default: warrior, wizard, cleric
    #expect(!state.canPaladinReroll) // no paladin
  }

  @Test
  func paladinRerollResetsEachTurn() {
    // After turn reset, Paladin can re-roll again.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.usePaladinReroll()
    #expect(!state.canPaladinReroll)

    state.resetTurnTracking()
    #expect(state.canPaladinReroll)
  }

  // MARK: - Turn Reset (housekeeping)

  @Test
  func turnResetClearsPerTurnState() {
    // Reset clears bloody battle payment and Paladin re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.bloodyBattlePaidThisTurn = true
    state.paladinRerollUsed = true

    state.resetTurnTracking()
    #expect(!state.bloodyBattlePaidThisTurn)
    #expect(!state.paladinRerollUsed)
  }

}
