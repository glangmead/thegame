//
//  HeartsSceneConfig.swift
//  DynamicalSystems
//
//  Hearts — SceneConfig for green felt card table.
//

import Foundation

struct HeartsSceneConfig {
  static func config() -> SceneConfig {
    .container("hearts", [
      .board(
        .grid(rows: 12, cols: 12),
        style: StyleConfig(fill: "darkgreen", stroke: "darkgreen", lineWidth: 0)
      ),
      .card(.rectangle)
    ])
  }
}
