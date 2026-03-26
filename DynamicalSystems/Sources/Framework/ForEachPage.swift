//
//  ForEachPage.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Foundation

/// A meta-rule that handles "process each item exactly once, in any order,
/// then transition to the next phase."
///
/// Remaining items are derived from the action history — no stored tracking
/// queue needed. This replaces patterns like `alliesToAttack`, `alliesToAirdrop`,
/// and `germansToReinforce` in Battle Card.
struct ForEachPage<State: HistoryTracking, Item: Hashable> {
  let name: String

  /// Is this page's phase currently active?
  let isActive: (State) -> Bool

  /// Compute what items need processing from the current board state.
  let items: (State) -> [Item]

  /// What actions to offer for a given remaining item.
  let actionsFor: (State, Item) -> [State.Action]

  /// Extract the item being processed from an action (nil = not my action).
  let itemFrom: (State.Action) -> Item?

  /// The action to emit as a follow-up when all items are done.
  let transitionAction: State.Action

  /// Identifies the action that marks entry into this phase (used as the
  /// boundary when scanning history for completed items).
  let isPhaseEntry: (State.Action) -> Bool

  /// Domain logic: how this action changes state. Returns nil if not
  /// this page's action. On success, returns logs and follow-up actions.
  let reduce: (inout State, State.Action) -> ([Log], [State.Action])?
}

extension ForEachPage {
  /// Derive remaining items by scanning history backwards from the end
  /// to the most recent phase-entry action.
  func remaining(_ state: State) -> [Item] {
    var done = Set<Item>()
    for action in state.history.reversed() {
      if isPhaseEntry(action) { break }
      if let item = itemFrom(action) { done.insert(item) }
    }
    return items(state).filter { !done.contains($0) }
  }

  /// Convert to a RulePage for use with `oapply`.
  ///
  /// When the last item is processed, the transition action is automatically
  /// appended as a follow-up — no separate rule needed.
  func asRulePage() -> RulePage<State, State.Action> {
    let page = self
    return RulePage(
      name: name,
      rules: [
        // Single rule: compute remaining() once, branch on empty/non-empty.
        GameRule(
          condition: { state in page.isActive(state) },
          actions: { state in
            let rem = page.remaining(state)
            if rem.isEmpty {
              return [page.transitionAction]
            }
            return rem.flatMap { page.actionsFor(state, $0) }
          }
        )
      ],
      reduce: { state, action in
        guard let (logs, followUps) = page.reduce(&state, action) else { return nil }
        var allFollowUps = followUps
        if page.remaining(state).isEmpty {
          allFollowUps.append(page.transitionAction)
        }
        return (logs, allFollowUps)
      }
    )
  }
}
