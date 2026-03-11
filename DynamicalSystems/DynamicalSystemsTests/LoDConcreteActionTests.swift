//
//  LoDConcreteActionTests.swift
//  DynamicalSystems
//
//  Tests for concrete spell action enumeration in magicPage.
//

import Testing
@testable import DynamicalSystems

@MainActor
struct LoDConcreteActionTests {

  /// Prepare a state in the action phase with a card drawn.
  private func actionPhaseState(windsOfMagicArcane: Int = 4) -> (LoD.State, ComposedGame<LoD.State>) {
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: windsOfMagicArcane,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    return (state, game)
  }

  // Rule 9.2.1: Fireball targets one army on wizard's track.
  @Test func fireballEnumeratesTargetSlots() {
    var (state, game) = actionPhaseState()
    state.spellStatus[.fireball] = .known
    state.arcaneEnergy = 1
    state.heroLocation[.wizard] = .onTrack(.east)
    let actions = game.allowedActions(state: state)
    let fireballActions = actions.filter {
      if case .magic(.castSpell(.fireball, heroic: false, let params)) = $0 {
        return params.targetSlot != nil
      }
      return false
    }
    #expect(!fireballActions.isEmpty, "Fireball should enumerate target slots")
  }

  // Rule 9.3.5: Normal Raise Dead — gain 2 different defenders OR return 1 dead hero.
  @Test func raiseDeadNormalEnumeratesCombinations() {
    var (state, game) = actionPhaseState()
    state.spellStatus[.raiseDead] = .known
    state.divineEnergy = 4
    state.heroDead = [.warrior]
    state.heroLocation[.warrior] = nil
    let actions = game.allowedActions(state: state)
    let rdActions = actions.filter {
      if case .magic(.castSpell(.raiseDead, heroic: false, _)) = $0 { return true }
      return false
    }
    // Should have: (archers,priests), (archers,menAtArms), (priests,menAtArms), (returnHero: warrior)
    #expect(rdActions.count >= 4, "Raise Dead should enumerate all valid combinations, got \(rdActions.count)")
  }

  // Rule 9.3.3: Heroic Divine Wrath — 2 attacks on different targets.
  @Test func divineWrathHeroicEnumeratesTargetPairs() {
    var (state, game) = actionPhaseState()
    state.spellStatus[.divineWrath] = .known
    state.divineEnergy = 3
    state.heroLocation[.cleric] = .onTrack(.east)
    let actions = game.allowedActions(state: state)
    let dwHeroicActions = actions.filter {
      if case .magic(.castSpell(.divineWrath, heroic: true, let params)) = $0 {
        return params.targetSlots.count == 2
      }
      return false
    }
    #expect(!dwHeroicActions.isEmpty, "Heroic Divine Wrath should enumerate target pairs")
  }

  // Rule 9.3.1: Cure Wounds normal heals 1 wounded hero, heroic heals up to 2.
  @Test func cureWoundsEnumeratesHeroChoices() {
    var (state, game) = actionPhaseState()
    state.spellStatus[.cureWounds] = .known
    state.divineEnergy = 1
    state.heroWounded = [.warrior, .wizard]
    let actions = game.allowedActions(state: state)
    let cwActions = actions.filter {
      if case .magic(.castSpell(.cureWounds, heroic: false, let params)) = $0 {
        return !params.heroes.isEmpty
      }
      return false
    }
    #expect(cwActions.count >= 2, "Cure Wounds should enumerate wounded hero choices")
  }

  // Rule 9.3.2: Mass Heal normal gains 1 defender, heroic gains up to 2 different.
  @Test func massHealEnumeratesDefenderTypes() {
    var (state, game) = actionPhaseState()
    state.spellStatus[.massHeal] = .known
    state.divineEnergy = 2
    let actions = game.allowedActions(state: state)
    let mhActions = actions.filter {
      if case .magic(.castSpell(.massHeal, heroic: false, let params)) = $0 {
        return !params.defenders.isEmpty
      }
      return false
    }
    // 3 defender types -> 3 choices for normal
    #expect(mhActions.count >= 3, "Mass Heal should enumerate defender type choices")
  }

  // MARK: - Event Resolution Enumeration

  // Card #33: Deserters — lose 2 defenders OR reduce morale (if not Low).
  @Test func desertersEnumeratesPaths() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 4)
    state.phase = .event
    state.currentCard = LoD.nightCards.first { $0.number == 33 }
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    let actions = game.allowedActions(state: state)
    let eventActions = actions.filter {
      if case .resolveEvent = $0 { return true }
      return false
    }
    // Should have: (archers+priests), (archers+menAtArms), (priests+menAtArms),
    // (menAtArms+menAtArms), (archers+archers), (priests+priests), (morale loss)
    #expect(eventActions.count >= 4, "Deserters should enumerate all paths, got \(eventActions.count)")
  }

  // Card #36: Bump in the Night — advance Sky 1 OR distribute 2 advances among non-sky armies.
  @Test func bumpInTheNightEnumeratesDistributions() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 4)
    state.phase = .event
    state.currentCard = LoD.nightCards.first { $0.number == 36 }
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    let actions = game.allowedActions(state: state)
    let eventActions = actions.filter {
      if case .resolveEvent = $0 { return true }
      return false
    }
    // Sky path + distribution paths (2 to one army, or 1+1 to two armies)
    #expect(eventActions.count >= 2, "Bump in the Night should enumerate distributions")
  }

  // Card #24: Bloody Handprints — on 1-3 kill hero (wounded first), on 4-6 wound hero.
  @Test func bloodyHandprintsEnumeratesHeroChoices() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 4)
    state.phase = .event
    state.currentCard = LoD.nightCards.first { $0.number == 24 }
    let game = LoD.composedGame(windsOfMagicArcane: 4)
    let actions = game.allowedActions(state: state)
    let eventActions = actions.filter {
      if case .resolveEvent(let res) = $0 { return res.chosenHero != nil }
      return false
    }
    // With 3 heroes alive (warrior, wizard, cleric), should enumerate hero choices
    #expect(eventActions.count >= 3, "Bloody Handprints should enumerate hero choices")
  }
}
