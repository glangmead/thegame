//
//  CantStopSceneConfig.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

struct CantStopSceneConfig {
  static func config() -> SceneConfig {
    .container("cantstop", [
      .board(
        .columnar(heights: [4, 6, 8, 10, 12, 14, 12, 10, 8, 6, 4]),
        style: StyleConfig(stroke: "black", lineWidth: 1)
      ),
      .piece(.circle, color: .byPlayer),
      .scaled(.container("dice", [.die(.labeledSquare)]), factor: 2)
    ])
  }
}
