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
