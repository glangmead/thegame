//
//  LoDSceneConfig.swift
//  DynamicalSystems
//
//  Legions of Darkness — SceneConfig for default rendering.
//

import Foundation

struct LoDSceneConfig {
  static func config() -> SceneConfig {
    .container("legions", [
      .board(
        .grid(rows: 15, cols: 16),
        style: StyleConfig(stroke: "black", lineWidth: 1)
      ),
      .piece(.circle, color: .byPlayer),
      .card(.rectangle)
    ])
  }
}
