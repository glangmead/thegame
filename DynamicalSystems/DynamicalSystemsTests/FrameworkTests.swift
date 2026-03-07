//
//  FrameworkTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Testing

// MARK: - Test Types

enum TestPhase: Hashable {
    case collect
    case score
    case done
}

enum TestAction: Hashable {
    case collect(String)
    case scoreItems
    case setPhase(TestPhase)
    case endGame
}

struct TestState: HistoryTracking {
    var history: [TestAction] = []
    var phase: TestPhase = .collect
    var collected: [String] = []
    var score: Int = 0
    var ended: Bool = false
}

// MARK: - GameRule Tests

struct GameRuleTests {
    @Test func conditionEvaluates() {
        let rule = GameRule<TestState, TestAction>(
            condition: { $0.phase == .collect },
            actions: { _ in [.collect("A"), .collect("B")] }
        )
        let state = TestState()
        #expect(rule.condition(state))
        #expect(rule.actions(state) == [.collect("A"), .collect("B")])
    }

    @Test func conditionRejects() {
        let rule = GameRule<TestState, TestAction>(
            condition: { $0.phase == .score },
            actions: { _ in [.scoreItems] }
        )
        let state = TestState() // phase == .collect
        #expect(!rule.condition(state))
    }
}

// MARK: - RulePage Tests

struct RulePageTests {
    @Test func actionsFromRules() {
        let page = RulePage<TestState, TestAction>(
            name: "Collect",
            rules: [
                GameRule(
                    condition: { $0.phase == .collect },
                    actions: { _ in [.collect("A"), .collect("B")] }
                )
            ],
            reduce: { state, action in
                if case .collect(let item) = action {
                    state.collected.append(item)
                    return [Log(msg: "Collected \(item)")]
                }
                return nil
            }
        )

        let state = TestState()
        let actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions == [.collect("A"), .collect("B")])
    }

    @Test func reduceMutatesState() {
        let page = RulePage<TestState, TestAction>(
            name: "Collect",
            rules: [],
            reduce: { state, action in
                if case .collect(let item) = action {
                    state.collected.append(item)
                    return [Log(msg: "Collected \(item)")]
                }
                return nil
            }
        )

        var state = TestState()
        let logs = page.reduce(&state, .collect("X"))
        #expect(logs == [Log(msg: "Collected X")])
        #expect(state.collected == ["X"])
    }

    @Test func reduceReturnsNilForUnknownAction() {
        let page = RulePage<TestState, TestAction>(
            name: "Collect",
            rules: [],
            reduce: { _, action in
                if case .collect = action { return [Log(msg: "ok")] }
                return nil
            }
        )

        var state = TestState()
        let result = page.reduce(&state, .endGame)
        #expect(result == nil)
    }
}

// MARK: - ForEachPage Tests

struct ForEachPageTests {
    private static func makeCollectPage() -> ForEachPage<TestState, String> {
        ForEachPage(
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
                    return [Log(msg: "Collected \(item)")]
                }
                return nil
            }
        )
    }

    @Test func remainingAllItems() {
        let forEach = Self.makeCollectPage()
        var state = TestState()
        state.history = [.setPhase(.collect)]
        #expect(forEach.remaining(state) == ["A", "B", "C"])
    }

    @Test func remainingAfterOneCollected() {
        let forEach = Self.makeCollectPage()
        var state = TestState()
        state.history = [.setPhase(.collect), .collect("A")]
        #expect(forEach.remaining(state) == ["B", "C"])
    }

    @Test func remainingAfterAllCollected() {
        let forEach = Self.makeCollectPage()
        var state = TestState()
        state.history = [
            .setPhase(.collect),
            .collect("A"),
            .collect("B"),
            .collect("C")
        ]
        #expect(forEach.remaining(state).isEmpty)
    }

    @Test func remainingResetsOnNewPhaseEntry() {
        let forEach = Self.makeCollectPage()
        var state = TestState()
        state.history = [
            .setPhase(.collect),
            .collect("A"),
            .collect("B"),
            .setPhase(.collect)
        ]
        #expect(forEach.remaining(state) == ["A", "B", "C"])
    }

    @Test func rulesOfferActionsForRemainingItems() {
        let forEach = Self.makeCollectPage()
        let page = forEach.asRulePage()

        var state = TestState()
        state.history = [.setPhase(.collect)]

        let actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions.contains(.collect("A")))
        #expect(actions.contains(.collect("B")))
        #expect(actions.contains(.collect("C")))
        #expect(!actions.contains(.setPhase(.score)))
    }

    @Test func rulesOfferTransitionWhenAllDone() {
        let forEach = Self.makeCollectPage()
        let page = forEach.asRulePage()

        var state = TestState()
        state.history = [
            .setPhase(.collect),
            .collect("A"),
            .collect("B"),
            .collect("C")
        ]

        let actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions == [.setPhase(.score)])
    }

    @Test func rulesInactiveInWrongPhase() {
        let forEach = Self.makeCollectPage()
        let page = forEach.asRulePage()

        var state = TestState()
        state.phase = .done
        state.history = [.setPhase(.done)]

        let actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions.isEmpty)
    }
}

// MARK: - BudgetedPhasePage Tests

struct BudgetedPhasePageTests {
    private static func makeBudgetedPage(
        budget: Budget,
        passAction: TestAction? = nil
    ) -> BudgetedPhasePage<TestState, String> {
        BudgetedPhasePage(
            name: "Limited Collect",
            budget: budget,
            isActive: { $0.phase == .collect },
            items: { _ in ["A", "B", "C", "D"] },
            actionsFor: { _, item in [.collect(item)] },
            itemFrom: { action in
                if case .collect(let item) = action { return item }
                return nil
            },
            transitionAction: .setPhase(.score),
            passAction: passAction,
            isPhaseEntry: { action in
                if case .setPhase(.collect) = action { return true }
                return false
            },
            reduce: { state, action in
                if case .collect(let item) = action {
                    state.collected.append(item)
                    return [Log(msg: "Collected \(item)")]
                }
                return nil
            }
        )
    }

    @Test func budgetAllActsLikeForEach() {
        let budgeted = Self.makeBudgetedPage(budget: .all)
        let page = budgeted.asRulePage()

        var state = TestState()
        state.history = [.setPhase(.collect)]

        var actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions.count == 4)

        state.history = [
            .setPhase(.collect),
            .collect("A"), .collect("B"), .collect("C"), .collect("D")
        ]
        actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions == [.setPhase(.score)])
    }

    @Test func budgetExactlyLimitsActions() {
        let budgeted = Self.makeBudgetedPage(budget: .exactly(2))
        let page = budgeted.asRulePage()

        var state = TestState()
        state.history = [.setPhase(.collect)]

        var actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions.count == 4)

        state.history = [
            .setPhase(.collect),
            .collect("A"), .collect("B")
        ]
        actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions == [.setPhase(.score)])
    }

    @Test func budgetAtMostOffersPassAfterFirstAction() {
        let budgeted = Self.makeBudgetedPage(
            budget: .atMost(3),
            passAction: .setPhase(.score)
        )
        let page = budgeted.asRulePage()

        var state = TestState()
        state.history = [.setPhase(.collect)]

        var actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(!actions.contains(.setPhase(.score)))
        #expect(actions.count == 4)

        state.history = [.setPhase(.collect), .collect("A")]
        actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions.contains(.setPhase(.score)))
        #expect(actions.contains(.collect("B")))

        state.history = [
            .setPhase(.collect),
            .collect("A"), .collect("B"), .collect("C")
        ]
        actions = page.rules.flatMap {
            $0.condition(state) ? $0.actions(state) : []
        }
        #expect(actions == [.setPhase(.score)])
    }
}
