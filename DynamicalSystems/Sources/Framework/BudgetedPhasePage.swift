//
//  BudgetedPhasePage.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Foundation

/// How many actions a phase permits before transitioning.
enum Budget {
  /// Must process every item (ForEach semantics).
  case all
  /// Must take exactly K actions.
  case exactly(Int)
  /// Up to K actions; may pass early.
  case atMost(Int)
}

/// A generalization of ForEachPage that constrains how many actions you take
/// before transitioning.
///
/// - `budget: .all` is equivalent to ForEachPage
/// - `budget: .exactly(K)` requires exactly K actions
/// - `budget: .atMost(K)` allows up to K actions with an optional early pass
struct BudgetedPhasePage<State: HistoryTracking, Item: Hashable> {
  let name: String
  let budget: Budget

  let isActive: (State) -> Bool
  let items: (State) -> [Item]
  let actionsFor: (State, Item) -> [State.Action]
  let itemFrom: (State.Action) -> Item?
  let transitionAction: State.Action

  /// Action to offer when the player may pass early (`.atMost` budget).
  /// Nil for `.all` and `.exactly` budgets.
  let passAction: State.Action?

  let isPhaseEntry: (State.Action) -> Bool
  let reduce: (inout State, State.Action) -> ([Log], [State.Action])?
}

extension BudgetedPhasePage {
  /// Derive remaining items by scanning history backwards.
  func remaining(_ state: State) -> [Item] {
    var done = Set<Item>()
    for action in state.history.reversed() {
      if isPhaseEntry(action) { break }
      if let item = itemFrom(action) { done.insert(item) }
    }
    return items(state).filter { !done.contains($0) }
  }

  /// Count actions taken since the last phase entry.
  func actionsTaken(_ state: State) -> Int {
    var count = 0
    for action in state.history.reversed() {
      if isPhaseEntry(action) { break }
      if itemFrom(action) != nil { count += 1 }
    }
    return count
  }

  /// Whether the budget has been exhausted.
  func budgetExhausted(_ state: State) -> Bool {
    switch budget {
    case .all:
      return remaining(state).isEmpty
    case .exactly(let limit), .atMost(let limit):
      return actionsTaken(state) >= limit
    }
  }

  /// Convert to a RulePage for use with `oapply`.
  ///
  /// When the budget is exhausted, the transition action is automatically
  /// appended as a follow-up — no separate rule needed.
  func asRulePage() -> RulePage<State, State.Action> {
    let page = self
    return RulePage(
      name: name,
      rules: [
        // Offer actions when budget is not exhausted
        GameRule(
          condition: { state in
            page.isActive(state) && !page.budgetExhausted(state)
          },
          actions: { state in
            var actions = page.remaining(state).flatMap {
              page.actionsFor(state, $0)
            }
            // For .atMost budgets, offer pass when:
            // - at least one action was taken, OR
            // - no items remain (nothing to do, skip the phase)
            if case .atMost = page.budget,
             page.actionsTaken(state) > 0 || page.remaining(state).isEmpty,
             let pass = page.passAction {
              actions.append(pass)
            }
            return actions
          }
        )
      ],
      reduce: { state, action in
        guard let (logs, followUps) = page.reduce(&state, action) else { return nil }
        var allFollowUps = followUps
        if page.budgetExhausted(state) || page.remaining(state).isEmpty {
          allFollowUps.append(page.transitionAction)
        }
        return (logs, allFollowUps)
      }
    )
  }
}
