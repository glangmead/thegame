//
//  BattleCardTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 11/3/25.
//

import ComposableArchitecture
import Testing

@MainActor
struct BattleCardTests {
  // MARK: - Airdrop

  @Test
  func testAirdrop() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.airdrop)]))

    let airdropPage = BCPages.airdropPage()
    let alliesToAirdrop = airdropPage.remaining(state)
    #expect(alliesToAirdrop.count == 3)

    state.history.append(.airdrop(BattleCard.Piece.allied1st))
    _ = airdropPage.reduce(&state, .airdrop(BattleCard.Piece.allied1st))
    let alliesToAirdrop2 = airdropPage.remaining(state)
    #expect(alliesToAirdrop2.count == 2)
  }

  // MARK: - Battle

  @Test
  func testAttack() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.battle)]))

    let battlePage = BCPages.battlePage()
    #expect(battlePage.remaining(state).count == 3)
    #expect(battlePage.asRulePage().allowedActions(state: state).count == 6)
    #expect(battlePage.asRulePage().allowedActions(state: state).contains(.rollForAttack(.allied1st)))

    state.history.append(.rollForAttack(BattleCard.Piece.allied1st))
    _ = battlePage.reduce(&state, .rollForAttack(BattleCard.Piece.allied1st))
    #expect(battlePage.remaining(state).count == 2)
    #expect(battlePage.asRulePage().allowedActions(state: state).count == 4)
    #expect(battlePage.asRulePage().allowedActions(state: state).contains(.rollForAttack(.allied101st)))
    #expect(!battlePage.asRulePage().allowedActions(state: state).contains(.rollForAttack(.allied1st)))
    #expect(!battlePage.asRulePage().allowedActions(state: state).contains(.rollForDefend(.allied1st)))
  }

  @Test
  func testDefend() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.battle)]))

    let battlePage = BCPages.battlePage()
    #expect(battlePage.remaining(state).count == 3)
    #expect(battlePage.asRulePage().allowedActions(state: state).count == 6)
    #expect(battlePage.asRulePage().allowedActions(state: state).contains(.rollForDefend(.allied1st)))

    state.history.append(.rollForDefend(BattleCard.Piece.allied1st))
    _ = battlePage.reduce(&state, .rollForDefend(BattleCard.Piece.allied1st))
    #expect(battlePage.remaining(state).count == 2)
    #expect(battlePage.asRulePage().allowedActions(state: state).count == 4)
    #expect(battlePage.asRulePage().allowedActions(state: state).contains(.rollForDefend(.allied101st)))
    #expect(!battlePage.asRulePage().allowedActions(state: state).contains(.rollForAttack(.allied1st)))
    #expect(!battlePage.asRulePage().allowedActions(state: state).contains(.rollForDefend(.allied1st)))
  }

  // MARK: - Setup

  @Test
  func testSetupPage() async {
    var state = BattleCard.State()
    let page = BCPages.setupPage()

    let actions = page.allowedActions(state: state)
    #expect(actions == [.initialize])

    _ = page.reduce(&state, .initialize)

    // Positions
    #expect(state.position[.thirtycorps] == .onTrack(0))
    #expect(state.position[.allied101st] == .onTrack(1))
    #expect(state.position[.allied82nd] == .onTrack(2))
    #expect(state.position[.allied1st] == .onTrack(4))
    #expect(state.position[.germanEindhoven] == .onTrack(1))
    #expect(state.position[.germanGrave] == .onTrack(2))
    #expect(state.position[.germanNijmegen] == .onTrack(3))
    #expect(state.position[.germanArnhem] == .onTrack(4))

    // Strengths
    #expect(state.strength[.allied101st] == .six)
    #expect(state.strength[.allied82nd] == .six)
    #expect(state.strength[.allied1st] == .five)
    #expect(state.strength[.germanEindhoven] == .two)
    #expect(state.strength[.germanGrave] == .two)
    #expect(state.strength[.germanNijmegen] == .one)
    #expect(state.strength[.germanArnhem] == .two)

    // Control and weather
    #expect(state.control[1] == .germans)
    #expect(state.control[2] == .germans)
    #expect(state.control[3] == .germans)
    #expect(state.control[4] == .germans)
    #expect(state.weather == .fog)
  }

  // MARK: - Reinforce Germans

  @Test
  func testReinforceGermansRemaining() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.reinforceGermans)]))

    let page = BCPages.reinforceGermansPage()
    #expect(page.remaining(state).count == 4)

    state.history.append(.reinforceGermans(.germanEindhoven))
    _ = page.reduce(&state, .reinforceGermans(.germanEindhoven))
    #expect(page.remaining(state).count == 3)
    #expect(!page.remaining(state).contains(.germanEindhoven))
  }

  @Test
  func testReinforceGermansStrength() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.reinforceGermans)]))

    let page = BCPages.reinforceGermansPage()

    // Eindhoven: 2 → 3
    state.history.append(.reinforceGermans(.germanEindhoven))
    _ = page.reduce(&state, .reinforceGermans(.germanEindhoven))
    #expect(state.strength[.germanEindhoven] == .three)

    // Grave: 2 → 3
    state.history.append(.reinforceGermans(.germanGrave))
    _ = page.reduce(&state, .reinforceGermans(.germanGrave))
    #expect(state.strength[.germanGrave] == .three)

    // Arnhem: 2 → 3
    state.history.append(.reinforceGermans(.germanArnhem))
    _ = page.reduce(&state, .reinforceGermans(.germanArnhem))
    #expect(state.strength[.germanArnhem] == .three)
  }

  @Test
  func testReinforceGermansNijmegenNoBonus() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.reinforceGermans)]))

    // Allies control Arnhem → Nijmegen gets no reinforcement
    state.control[4] = .allies

    let page = BCPages.reinforceGermansPage()
    state.history.append(.reinforceGermans(.germanNijmegen))
    _ = page.reduce(&state, .reinforceGermans(.germanNijmegen))
    #expect(state.strength[.germanNijmegen] == .one)
  }

  @Test
  func testReinforceGermansTransition() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.reinforceGermans)]))

    let page = BCPages.reinforceGermansPage()

    state.history.append(.reinforceGermans(.germanEindhoven))
    _ = page.reduce(&state, .reinforceGermans(.germanEindhoven))
    state.history.append(.reinforceGermans(.germanGrave))
    _ = page.reduce(&state, .reinforceGermans(.germanGrave))
    state.history.append(.reinforceGermans(.germanNijmegen))
    _ = page.reduce(&state, .reinforceGermans(.germanNijmegen))

    // Last item — should return transition follow-up
    state.history.append(.reinforceGermans(.germanArnhem))
    let result = page.asRulePage().reduce(&state, .reinforceGermans(.germanArnhem))
    #expect(result != nil)
    #expect(result!.1 == [.setPhase(.advance)])
  }

  // MARK: - Advance

  @Test
  func testAdvance30Corps() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.advance)]))

    // Allies control Eindhoven → 30 Corps can advance
    state.control[1] = .allies

    let page = BCPages.advanceAllyPage()
    let result = page.reduce(&state, .advance30Corps)

    #expect(state.position[.thirtycorps] == .onTrack(1))
    #expect(state.position[.germanEindhoven] == .offBoard)
    #expect(!state.germansOnBoard.contains(.germanEindhoven))
    // Follow-up should transition to weather
    #expect(result != nil)
    #expect(result!.1 == [.setPhase(.rollForWeather)])
  }

  @Test
  func testAdvanceAllies() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.advance)]))

    // Move 101st to Belgium (city 0) alongside 30 Corps
    state.position[.allied101st] = .onTrack(0)

    let page = BCPages.advanceAllyPage()
    _ = page.reduce(&state, .advanceAllies(.allied101st))

    // 101st should advance to Eindhoven (city 1)
    #expect(state.position[.allied101st] == .onTrack(1))
  }

  @Test
  func testAdvanceAlliesMerge() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.advance)]))

    // 101st at city 1, 82nd at city 2 — advance 101st onto 82nd
    state.strength[.allied101st] = .two
    state.strength[.allied82nd] = .three

    let page = BCPages.advanceAllyPage()
    _ = page.reduce(&state, .advanceAllies(.allied101st))

    // 101st merged into 82nd: 3 + 2 = 5
    #expect(state.position[.allied101st] == .offBoard)
    #expect(!state.alliesOnBoard.contains(.allied101st))
    #expect(state.strength[.allied82nd] == .five)
  }

  @Test
  func testSkipAdvance() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize, .setPhase(.advance)]))

    let page = BCPages.advanceAllyPage()
    let actions = page.allowedActions(state: state)
    #expect(actions.contains(.skipAdvance))

    let result = page.reduce(&state, .skipAdvance)
    #expect(result != nil)
    #expect(result!.0 == [Log(msg: "Can't advance into German control")])
    #expect(result!.1 == [.setPhase(.rollForWeather)])
  }

  // MARK: - Victory / Loss

  @Test
  func testVictoryCondition() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize]))

    state.position[.thirtycorps] = .onTrack(4)

    let page = BCPages.victoryPage()
    #expect(page.allowedActions(state: state) == [.claimVictory])

    _ = page.reduce(&state, .claimVictory)
    #expect(state.ended)
    #expect(state.endedInVictoryFor == [.solo])
  }

  @Test
  func testLossTurnLimit() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize]))

    state.turnNumber = 7

    let page = BCPages.lossPage()
    #expect(page.allowedActions(state: state) == [.declareLoss])

    _ = page.reduce(&state, .declareLoss)
    #expect(state.ended)
    #expect(state.endedInDefeatFor == [.solo])
  }

  @Test
  func testLossAllyDestroyed() async {
    var state = BattleCard.State()
    let game = BattleCard()
    _ = game.reduce(into: &state, action: .sequence([.initialize]))

    state.strength[.allied1st] = DSix.none

    let page = BCPages.lossPage()
    #expect(page.allowedActions(state: state) == [.declareLoss])
  }

  // MARK: - Composed Game

  @Test
  func testComposedGameInitialActions() async {
    let game = BCPages.game()
    let state = game.newState()
    let actions = game.allowedActions(state: state)
    #expect(actions == [.initialize])
  }
}
