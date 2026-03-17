//
//  AutoRuleTests.swift
//  DynamicalSystems
//

import Testing

struct AutoRuleTests {

  @Test
  func autoRuleFiresWhenConditionMet() {
    var state = ARTestState(history: [], phase: .phaseA, counter: 0)
    let rule = AutoRule<ARTestState>(
      name: "increment",
      when: { $0.history.last == .act },
      apply: { state in
        state.counter += 1
        return [Log(msg: "incremented")]
      }
    )
    #expect(rule.when(state) == false)
    state.history.append(.act)
    #expect(rule.when(state) == true)
    let logs = rule.apply(&state)
    #expect(state.counter == 1)
    #expect(logs.count == 1)
  }

  @Test
  func autoRuleSkipsWhenConditionFalse() {
    var state = ARTestState(history: [], phase: .phaseA, counter: 0)
    let rule = AutoRule<ARTestState>(
      name: "increment",
      when: { $0.history.last == .act },
      apply: { state in
        state.counter += 1
        return [Log(msg: "incremented")]
      }
    )
    state.history.append(.other)
    #expect(rule.when(state) == false)
  }

  @Test
  func composedGameFiresAutoRulesAfterReduce() {
    let rule = AutoRule<ARTestState>(
      name: "increment",
      when: { $0.history.last == .act },
      apply: { state in
        state.counter += 1
        return [Log(msg: "incremented")]
      }
    )
    let game = oapply(
      gameName: "test",
      pages: [
        RulePage(
          name: "main",
          rules: [
            GameRule(condition: { _ in true }, actions: { _ in [.act] })
          ],
          reduce: { _, action in
            guard case .act = action else { return nil }
            return ([Log(msg: "acted")], [])
          }
        )
      ],
      autoRules: [rule],
      initialState: { ARTestState(history: [], phase: .phaseA, counter: 0) },
      isTerminal: { _ in false },
      phaseForAction: { _ in nil }
    )
    var state = game.newState()
    let logs = game.reduce(into: &state, action: .act)
    #expect(state.counter == 1)
    #expect(logs.contains { $0.msg == "incremented" })
  }

  @Test
  func autoRulesFireForFollowUpActions() {
    let rule = AutoRule<ARTestState>(
      name: "count-acts",
      when: { $0.history.last == .act },
      apply: { state in
        state.counter += 1
        return [Log(msg: "counted")]
      }
    )
    let game = oapply(
      gameName: "test",
      pages: [
        RulePage(
          name: "main",
          rules: [
            GameRule(condition: { _ in true }, actions: { _ in [.other] })
          ],
          reduce: { _, action in
            switch action {
            case .other:
              return ([Log(msg: "other")], [.act])
            case .act:
              return ([Log(msg: "acted")], [])
            }
          }
        )
      ],
      autoRules: [rule],
      initialState: { ARTestState(history: [], phase: .phaseA, counter: 0) },
      isTerminal: { _ in false },
      phaseForAction: { _ in nil }
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .other)
    // .other dispatches → auto-rules scan (history.last is .act from follow-up, so match).
    // Follow-up .act dispatches → auto-rules scan (match: counter += 1).
    // Back in .other's auto-rules: history.last is .act, so it fires again.
    // Total: counter == 2 (once for .act's scan, once for .other's scan).
    #expect(state.counter == 2)
  }

  @Test
  func autoRulesFireInOrder() {
    let rule1 = AutoRule<ARTestState>(
      name: "first",
      when: { $0.history.last == .act },
      apply: { state in
        state.counter += 10
        return [Log(msg: "first")]
      }
    )
    let rule2 = AutoRule<ARTestState>(
      name: "second",
      when: { $0.history.last == .act && $0.counter >= 10 },
      apply: { state in
        state.counter += 1
        return [Log(msg: "second")]
      }
    )
    let game = oapply(
      gameName: "test",
      pages: [
        RulePage(
          name: "main",
          rules: [
            GameRule(condition: { _ in true }, actions: { _ in [.act] })
          ],
          reduce: { _, action in
            guard case .act = action else { return nil }
            return ([Log(msg: "acted")], [])
          }
        )
      ],
      autoRules: [rule1, rule2],
      initialState: { ARTestState(history: [], phase: .phaseA, counter: 0) },
      isTerminal: { _ in false },
      phaseForAction: { _ in nil }
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .act)
    // rule1 sets counter to 10, rule2 sees counter >= 10 and adds 1.
    #expect(state.counter == 11)
  }

  @Test
  func noAutoRulesDefaultIsEmpty() {
    let game = oapply(
      gameName: "test",
      pages: [
        RulePage(
          name: "main",
          rules: [
            GameRule(condition: { _ in true }, actions: { _ in [.act] })
          ],
          reduce: { _, action in
            guard case .act = action else { return nil }
            return ([], [])
          }
        )
      ],
      initialState: { ARTestState(history: [], phase: .phaseA, counter: 0) },
      isTerminal: { _ in false },
      phaseForAction: { _ in nil }
    )
    var state = game.newState()
    let logs = game.reduce(into: &state, action: .act)
    #expect(state.counter == 0)
    #expect(logs.isEmpty)
  }
}

// MARK: - Test Helpers

private enum ARTestPhase: Hashable {
  case phaseA, phaseB
}

private enum ARTestAction: Hashable {
  case act, other
}

private struct ARTestState: HistoryTracking {
  var history: [ARTestAction]
  var phase: ARTestPhase
  var counter: Int
}
