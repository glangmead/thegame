//
//  LoDFortunePage.swift
//  DynamicalSystems
//
//  Legions of Darkness — Fortune multi-step sub-resolution page.
//

import Foundation

extension LoD {

  // MARK: - Fortune Sub-State

  struct FortuneState: Equatable, Hashable, Sendable {
    let heroic: Bool
    var drawnCards: [Card]
    var discardedIndex: Int?  // heroic only: which card was discarded (-1 = chose not to discard)

    var awaitingDiscard: Bool { heroic && discardedIndex == nil }
    var cardsToReorder: [Card] {
      if let idx = discardedIndex, idx >= 0 {
        return drawnCards.enumerated().compactMap { $0.offset == idx ? nil : $0.element }
      }
      return drawnCards
    }
  }

  // MARK: - Fortune Sub-Action

  enum FortuneAction: ActionGroup, Hashable, CustomStringConvertible {
    static let groupName = "Fortune"

    case discardCard(Int)       // heroic: choose which of the 3 to discard (index 0-2)
    case skipDiscard            // heroic: opt not to discard
    case chooseOrder([Int])     // final reorder (indices into drawnCards)

    var description: String {
      switch self {
      case .discardCard(let idx): return "Discard card \(idx + 1)"
      case .skipDiscard: return "Keep all cards"
      case .chooseOrder(let order): return "Reorder: \(order)"
      }
    }
  }

  // MARK: - Fortune RulePage

  static var fortunePage: RulePage<State, Action> {
    RulePage(
      name: "Fortune",
      rules: [
        // Heroic: first offer discard/skip choices
        GameRule(
          condition: { $0.fortuneState?.awaitingDiscard == true },
          actions: { state in
            guard let fState = state.fortuneState else { return [] }
            var actions: [Action] = []
            for idx in 0..<fState.drawnCards.count {
              actions.append(.fortune(.discardCard(idx)))
            }
            actions.append(.fortune(.skipDiscard))
            return actions
          }
        ),
        // After discard decision (or normal cast): offer all permutations of reorder
        GameRule(
          condition: { state in
            guard let fState = state.fortuneState else { return false }
            return !fState.awaitingDiscard
          },
          actions: { state in
            guard let fState = state.fortuneState else { return [] }
            let indices = Array(0..<fState.drawnCards.count)
            let validIndices: [Int]
            if let idx = fState.discardedIndex, idx >= 0 {
              validIndices = indices.filter { $0 != idx }
            } else {
              validIndices = indices
            }
            return permutations(of: validIndices).map { .fortune(.chooseOrder($0)) }
          }
        )
      ],
      reduce: { state, action in
        guard case .fortune(let fortuneAction) = action else { return nil }
        guard var fState = state.fortuneState else { return nil }
        var logs: [Log] = []

        switch fortuneAction {
        case .discardCard(let idx):
          fState.discardedIndex = idx
          state.fortuneState = fState
          logs.append(Log(msg: "Fortune: discarded card \(idx + 1)"))

        case .skipDiscard:
          fState.discardedIndex = -1
          state.fortuneState = fState
          logs.append(Log(msg: "Fortune: keeping all cards"))

        case .chooseOrder(let order):
          let discardIdx = fState.discardedIndex.flatMap { $0 >= 0 ? $0 : nil }
          state.applyFortune(newOrder: order, discardIndex: discardIdx)
          state.fortuneState = nil
          logs.append(Log(msg: "Fortune: reordered deck"))
        }

        return (logs, [])
      }
    )
  }

  // MARK: - Permutation Helper

  static func permutations(of elements: [Int]) -> [[Int]] {
    if elements.count <= 1 { return [elements] }
    var result: [[Int]] = []
    for (idx, element) in elements.enumerated() {
      var remaining = elements
      remaining.remove(at: idx)
      for var perm in permutations(of: remaining) {
        perm.insert(element, at: 0)
        result.append(perm)
      }
    }
    return result
  }
}
