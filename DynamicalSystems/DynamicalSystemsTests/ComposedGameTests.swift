//
//  ComposedGameTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Testing

// MARK: - ComposedGame / oapply Tests

struct ComposedGameTests {
    private static func makeCollectPage() -> RulePage<TestState, TestAction> {
        ForEachPage<TestState, String>(
            name: "Collect Items",
            isActive: { $0.phase == .collect },
            items: { _ in ["A", "B", "C"] },
            actionsFor: { _, item in [.collect(item)] },
            itemFrom: { action in
                if case .collect(let item) = action { return item }
                return nil
            },
            transitionAction: .setPhase(.score),
            isPhaseEntry: { action in
                if case .setPhase(.collect) = action { return true }
                return false
            },
            reduce: { state, action in
                if case .collect(let item) = action {
                    state.collected.append(item)
                    return ([Log(msg: "Collected \(item)")], [])
                }
                return nil
            }
        ).asRulePage()
    }

    private static func makeScorePage() -> RulePage<TestState, TestAction> {
        RulePage(
            name: "Score",
            rules: [
                GameRule(
                    condition: { $0.phase == .score },
                    actions: { _ in [.scoreItems] }
                )
            ],
            reduce: { state, action in
                if case .scoreItems = action {
                    state.score = state.collected.count * 10
                    return ([Log(msg: "Scored \(state.score) points")], [.setPhase(.done)])
                }
                return nil
            }
        )
    }

    private static func makeEndPage() -> RulePage<TestState, TestAction> {
        RulePage(
            name: "End",
            rules: [
                GameRule(
                    condition: { $0.phase == .done },
                    actions: { _ in [.endGame] }
                )
            ],
            reduce: { state, action in
                if case .endGame = action {
                    state.ended = true
                    return ([Log(msg: "Game over")], [])
                }
                return nil
            }
        )
    }

    private static func makeToyGame() -> ComposedGame<TestState> {
        oapply(
            pages: [makeCollectPage(), makeScorePage(), makeEndPage()],
            initialState: {
                var state = TestState()
                state.history = [.setPhase(.collect)]
                return state
            },
            isTerminal: { $0.ended },
            phaseForAction: { action in
                if case .setPhase(let phase) = action { return phase }
                return nil
            }
        )
    }

    @Test func initialStateOffersCollectActions() {
        let game = Self.makeToyGame()
        let state = game.newState()
        let actions = game.allowedActions(state: state)
        #expect(actions.contains(.collect("A")))
        #expect(actions.contains(.collect("B")))
        #expect(actions.contains(.collect("C")))
    }

    @Test func collectingItemsReducesRemaining() {
        let game = Self.makeToyGame()
        var state = game.newState()

        _ = game.reduce(into: &state, action: .collect("A"))
        let actions = game.allowedActions(state: state)
        #expect(!actions.contains(.collect("A")))
        #expect(actions.contains(.collect("B")))
        #expect(actions.contains(.collect("C")))
    }

    @Test func autoTransitionAfterAllCollected() {
        let game = Self.makeToyGame()
        var state = game.newState()

        _ = game.reduce(into: &state, action: .collect("A"))
        _ = game.reduce(into: &state, action: .collect("B"))
        _ = game.reduce(into: &state, action: .collect("C"))

        // Phase should auto-transition to .score via follow-up
        #expect(state.phase == .score)
        let actions = game.allowedActions(state: state)
        #expect(actions == [.scoreItems])
    }

    @Test func scorePhaseOffersScoring() {
        let game = Self.makeToyGame()
        var state = game.newState()

        _ = game.reduce(into: &state, action: .collect("A"))
        _ = game.reduce(into: &state, action: .collect("B"))
        _ = game.reduce(into: &state, action: .collect("C"))

        let actions = game.allowedActions(state: state)
        #expect(actions == [.scoreItems])
    }

    @Test func fullGamePlaythrough() {
        let game = Self.makeToyGame()
        var state = game.newState()

        _ = game.reduce(into: &state, action: .collect("B"))
        _ = game.reduce(into: &state, action: .collect("A"))
        _ = game.reduce(into: &state, action: .collect("C"))
        #expect(state.collected == ["B", "A", "C"])
        #expect(state.phase == .score)

        let logs = game.reduce(into: &state, action: .scoreItems)
        #expect(state.score == 30)
        #expect(logs.contains(Log(msg: "Scored 30 points")))
        #expect(state.phase == .done)

        _ = game.reduce(into: &state, action: .endGame)
        #expect(state.ended)
        #expect(game.allowedActions(state: state).isEmpty)
    }

    @Test func historyRecordsAllActions() {
        let game = Self.makeToyGame()
        var state = game.newState()

        _ = game.reduce(into: &state, action: .collect("A"))
        _ = game.reduce(into: &state, action: .collect("B"))

        #expect(state.history == [
            .setPhase(.collect),
            .collect("A"),
            .collect("B")
        ])
    }

    @Test func terminalStateReturnsNoActions() {
        let game = Self.makeToyGame()
        var state = game.newState()
        state.ended = true
        #expect(game.allowedActions(state: state).isEmpty)
    }

    @Test func priorityPagesOverrideNormalPages() {
        let priorityPage = RulePage<TestState, TestAction>(
            name: "Emergency",
            rules: [
                GameRule(
                    condition: { $0.collected.count >= 2 },
                    actions: { _ in [.endGame] }
                )
            ],
            reduce: { state, action in
                if case .endGame = action {
                    state.ended = true
                    return ([Log(msg: "Emergency end")], [])
                }
                return nil
            }
        )

        let game = oapply(
            pages: [Self.makeCollectPage()],
            priorities: [priorityPage],
            initialState: {
                var state = TestState()
                state.history = [.setPhase(.collect)]
                return state
            },
            isTerminal: { $0.ended },
            phaseForAction: { action in
                if case .setPhase(let phase) = action { return phase }
                return nil
            }
        )

        var state = game.newState()
        _ = game.reduce(into: &state, action: .collect("A"))
        _ = game.reduce(into: &state, action: .collect("B"))

        let actions = game.allowedActions(state: state)
        #expect(actions == [.endGame])
    }
}
