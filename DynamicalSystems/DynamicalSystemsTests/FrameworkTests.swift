//
//  FrameworkTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import CoreGraphics
import Foundation
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
                    return ([Log(msg: "Collected \(item)")], [])
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
                    return ([Log(msg: "Collected \(item)")], [])
                }
                return nil
            }
        )

        var state = TestState()
        let result = page.reduce(&state, .collect("X"))
        #expect(result?.0 == [Log(msg: "Collected X")])
        #expect(state.collected == ["X"])
    }

    @Test func reduceReturnsNilForUnknownAction() {
        let page = RulePage<TestState, TestAction>(
            name: "Collect",
            rules: [],
            reduce: { _, action in
                if case .collect = action { return ([Log(msg: "ok")], []) }
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
                    return ([Log(msg: "Collected \(item)")], [])
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

        let actions = page.allowedActions(state: state)
        #expect(actions.contains(.collect("A")))
        #expect(actions.contains(.collect("B")))
        #expect(actions.contains(.collect("C")))
        #expect(!actions.contains(.setPhase(.score)))
    }

    @Test func transitionIsFollowUpWhenAllDone() {
        let forEach = Self.makeCollectPage()
        let page = forEach.asRulePage()

        var state = TestState()
        state.history = [
            .setPhase(.collect),
            .collect("A"),
            .collect("B"),
            .collect("C"),
        ]

        // Collecting the last item should return the transition as a follow-up
        let result = page.reduce(&state, .collect("C"))
        #expect(result != nil)
        let (_, followUps) = result!
        #expect(followUps == [.setPhase(.score)])
    }

    @Test func noFollowUpWhenItemsRemain() {
        let forEach = Self.makeCollectPage()
        let page = forEach.asRulePage()

        var state = TestState()
        state.history = [.setPhase(.collect)]

        let result = page.reduce(&state, .collect("A"))
        #expect(result != nil)
        let (_, followUps) = result!
        #expect(followUps.isEmpty)
    }

    @Test func rulesInactiveInWrongPhase() {
        let forEach = Self.makeCollectPage()
        let page = forEach.asRulePage()

        var state = TestState()
        state.phase = .done
        state.history = [.setPhase(.done)]

        let actions = page.allowedActions(state: state)
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
                    return ([Log(msg: "Collected \(item)")], [])
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

        let actions = page.allowedActions(state: state)
        #expect(actions.count == 4)

        // Collecting all items should produce transition follow-up
        state.history = [
            .setPhase(.collect),
            .collect("A"), .collect("B"), .collect("C"), .collect("D")
        ]
        let result = page.reduce(&state, .collect("D"))
        #expect(result != nil)
        #expect(result!.1 == [.setPhase(.score)])
    }

    @Test func budgetExactlyLimitsActions() {
        let budgeted = Self.makeBudgetedPage(budget: .exactly(2))
        let page = budgeted.asRulePage()

        var state = TestState()
        state.history = [.setPhase(.collect)]

        let actions = page.allowedActions(state: state)
        #expect(actions.count == 4)

        // After 2 actions, budget exhausted → transition follow-up
        state.history = [
            .setPhase(.collect),
            .collect("A"), .collect("B")
        ]
        let result = page.reduce(&state, .collect("B"))
        #expect(result != nil)
        #expect(result!.1 == [.setPhase(.score)])
    }

    @Test func budgetAtMostOffersPassAfterFirstAction() {
        let budgeted = Self.makeBudgetedPage(
            budget: .atMost(3),
            passAction: .setPhase(.score)
        )
        let page = budgeted.asRulePage()

        var state = TestState()
        state.history = [.setPhase(.collect)]

        var actions = page.allowedActions(state: state)
        #expect(!actions.contains(.setPhase(.score)))
        #expect(actions.count == 4)

        state.history = [.setPhase(.collect), .collect("A")]
        actions = page.allowedActions(state: state)
        #expect(actions.contains(.setPhase(.score)))
        #expect(actions.contains(.collect("B")))

        // After 3 actions, budget exhausted → transition follow-up
        state.history = [
            .setPhase(.collect),
            .collect("A"), .collect("B"), .collect("C")
        ]
        let result = page.reduce(&state, .collect("C"))
        #expect(result != nil)
        #expect(result!.1 == [.setPhase(.score)])
    }
}

// MARK: - GameModel Test Types

private struct TrivialState: GameState, CustomStringConvertible {
    typealias Phase = Int
    typealias Piece = Int
    typealias PiecePosition = Int
    typealias Player = Int
    typealias Position = Int

    var name: String { "Trivial" }
    var player: Int = 0
    var players: [Int] = [0]
    var ended: Bool = false
    var endedInVictoryFor: [Int] = []
    var endedInDefeatFor: [Int] = []
    var position: [Int: Int] = [:]
    var stepCount: Int = 0
    var description: String { "step=\(stepCount)" }
}

private enum TrivialAction: Hashable, CustomStringConvertible {
    case step
    var description: String { "step" }
}

private struct TrivialGame: PlayableGame {
    func newState() -> TrivialState { TrivialState() }
    func allowedActions(state: TrivialState) -> [TrivialAction] {
        state.ended ? [] : [.step]
    }
    func reduce(into state: inout TrivialState, action: TrivialAction) -> [Log] {
        state.stepCount += 1
        if state.stepCount >= 3 { state.ended = true }
        return []
    }
}

// MARK: - SiteGraph Tests

struct SiteGraphTests {
    @Test
    func testDirectionOpposites() {
        #expect(Direction.next.opposite == .previous)
        #expect(Direction.previous.opposite == .next)
        #expect(Direction.top.opposite == .bottom)
        #expect(Direction.north.opposite == .south)
        #expect(Direction.northwest.opposite == .southeast)
    }

    @Test
    func testSiteGraphBasic() {
        let s0 = SiteID(0)
        let s1 = SiteID(1)
        var graph = SiteGraph()
        graph.addSite(id: s0, position: CGPoint(x: 0, y: 0))
        graph.addSite(id: s1, position: CGPoint(x: 1, y: 0))
        graph.connect(s0, to: s1, direction: .next)

        #expect(graph.sites.count == 2)
        #expect(graph.sites[s0]?.adjacency[.next] == s1)
        #expect(graph.sites[s1]?.adjacency[.previous] == s0)
    }

    @Test
    func testSiteCursor() {
        var graph = SiteGraph()
        let s0 = graph.addSite(position: CGPoint(x: 0, y: 0))
        let s1 = graph.addSite(position: CGPoint(x: 0, y: 1))
        let s2 = graph.addSite(position: CGPoint(x: 0, y: 2))
        graph.connect(s0, to: s1, direction: .next)
        graph.connect(s1, to: s2, direction: .next)

        let cursor = graph.site(s0)
        #expect(cursor.next?.id == s1)
        #expect(cursor.next?.next?.id == s2)
        #expect(cursor.next?.next?.next == nil)
        #expect(cursor.next?.next?.previous?.id == s1)
        #expect(graph.site(s2).top == nil)
    }

    @Test
    func testColumnarGenerator() {
        let graph = SiteGraph.columnar(heights: [3, 2])

        #expect(graph.sites.count == 5)
        #expect(graph.tracks.count == 2)
        #expect(graph.tracks["col0"]?.count == 3)
        #expect(graph.tracks["col1"]?.count == 2)

        let col0Bottom = graph.tracks["col0"]![0]
        let cursor = graph.site(col0Bottom)
        #expect(cursor.next != nil)
        #expect(cursor.next?.next != nil)
        #expect(cursor.next?.next?.next == nil)

        let col0Top = graph.tracks["col0"]![2]
        #expect(graph.site(col0Bottom).top?.id == col0Top)
        #expect(graph.site(col0Top).bottom?.id == col0Bottom)
    }

    @Test
    func testCrossTrackAdjacency() {
        let graph = SiteGraph.parallelTracks(
            names: ["allied", "road", "german"],
            length: 3,
            crossDirections: true
        )

        #expect(graph.tracks.count == 3)
        #expect(graph.tracks["allied"]?.count == 3)
        #expect(graph.tracks["road"]?.count == 3)
        #expect(graph.tracks["german"]?.count == 3)

        let alliedSite0 = graph.tracks["allied"]![0]
        let roadSite0 = graph.tracks["road"]![0]
        let germanSite0 = graph.tracks["german"]![0]

        #expect(graph.sites[alliedSite0]?.adjacency[.custom("road")] == roadSite0)
        #expect(graph.sites[alliedSite0]?.adjacency[.custom("german")] == germanSite0)
        #expect(graph.sites[germanSite0]?.adjacency[.custom("allied")] == alliedSite0)

        let alliedSite1 = graph.tracks["allied"]![1]
        #expect(graph.site(alliedSite0).next?.id == alliedSite1)
    }

    @Test
    func testSiteCursorCustomDirection() {
        let graph = SiteGraph.parallelTracks(
            names: ["allied", "road", "german"],
            length: 2,
            crossDirections: true
        )
        let alliedSite0 = graph.tracks["allied"]![0]
        let germanSite0 = graph.tracks["german"]![0]

        let cursor = graph.site(alliedSite0)
        #expect(cursor.adjacent(.custom("german"))?.id == germanSite0)

        let germanSite1 = graph.tracks["german"]![1]
        #expect(cursor.adjacent(.custom("german"))?.next?.id == germanSite1)
    }

    @Test
    func testPieceAndPieceValue() {
        let token = GamePiece(id: 0, kind: .token)
        let die = GamePiece(id: 1, kind: .die(sides: 6))

        let s0 = SiteID(0)
        let s1 = SiteID(1)

        var section: GameSection = [:]
        section[token] = .at(s0)
        section[die] = .dieShowing(face: 4, at: s1)

        #expect(section[token] == .at(s0))
        #expect(section[die] == .dieShowing(face: 4, at: s1))
        #expect(section[token]?.site == s0)
        #expect(section[die]?.site == s1)
    }

    @Test
    func testSectionPiecesAt() {
        let p0 = GamePiece(id: 0, kind: .token, owner: PlayerID(0))
        let p1 = GamePiece(id: 1, kind: .token, owner: PlayerID(1))
        let p2 = GamePiece(id: 2, kind: .die(sides: 6), owner: PlayerID(0))
        let s0 = SiteID(0)
        let s1 = SiteID(1)

        let section: GameSection = [
            p0: .at(s0),
            p1: .at(s0),
            p2: .dieShowing(face: 3, at: s1),
        ]

        #expect(section.piecesAt(s0).count == 2)
        #expect(section.piecesAt(s1).count == 1)
        #expect(section.piecesAt(SiteID(99)).isEmpty)
        #expect(section.pieceAt(s1) == p2)
    }

    @Test
    func testGraphAwareSectionQuery() {
        // Simulate BattleCard: 2-city board with allied/german tracks
        let graph = SiteGraph.parallelTracks(
            names: ["allied", "german"],
            length: 2,
            crossDirections: true
        )
        let alliedSite0 = graph.tracks["allied"]![0]
        let germanSite0 = graph.tracks["german"]![0]

        let ally = GamePiece(id: 0, kind: .die(sides: 6), owner: PlayerID(0))
        let german = GamePiece(id: 1, kind: .die(sides: 6), owner: PlayerID(1))

        let section: GameSection = [
            ally: .dieShowing(face: 5, at: alliedSite0),
            german: .dieShowing(face: 2, at: germanSite0),
        ]

        // Find piece across the custom direction from ally's site (opponentFacing pattern)
        let oppositeSite = graph.site(alliedSite0).adjacent(.custom("german"))!.id
        let opponent = section.pieceAt(oppositeSite)
        #expect(opponent == german)
    }

    @Test
    func testSceneConfigCodable() throws {
        let config: SceneConfig = .container("cantstop", [
            .board(.columnar(heights: [3, 5, 7]), style: StyleConfig(stroke: "black")),
            .container("dice", [.die(.labeledSquare)]),
            .piece(.circle, color: .byPlayer),
        ])

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(SceneConfig.self, from: data)
        #expect(decoded == config)
    }

    @Test
    func testGameModelBasic() {
        let graph = SiteGraph.columnar(heights: [3])
        let game = TrivialGame()
        let model = GameModel(game: game, graph: graph)

        #expect(!model.state.ended)
        #expect(model.allowedActions.count == 1)

        model.perform(.step)
        #expect(model.state.stepCount == 1)

        model.perform(.step)
        model.perform(.step)
        #expect(model.state.ended)
        #expect(model.allowedActions.isEmpty)
    }
}
