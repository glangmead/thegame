//
//  HistoryTracking.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import Foundation

/// Protocol for game state that carries an action history and a cached phase.
///
/// The history is the source of truth for control flow (e.g., which items
/// have been processed in a ForEach phase). The phase is cached for
/// performance — it's checked on every rule evaluation.
protocol HistoryTracking {
    associatedtype Action: Hashable
    associatedtype Phase: Hashable

    var history: [Action] { get set }
    var phase: Phase { get set }
}
