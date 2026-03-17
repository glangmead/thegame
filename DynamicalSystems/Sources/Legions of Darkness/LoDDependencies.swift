//
//  LoDDependencies.swift
//  DynamicalSystems
//
//  Legions of Darkness — @TaskLocal dependency injection for die rolls and random draws.
//

import Foundation

extension LoD {
  /// Roll a d6 (1–6). Override via `LoD.$rollDie.withValue` for deterministic tests.
  @TaskLocal static var rollDie: () -> Int = { Int.random(in: 1...6) }

  /// Draw a random spell from a pool. Override for deterministic tests.
  @TaskLocal static var drawRandomSpell: ([SpellType]) -> SpellType? = { $0.randomElement() }
}
