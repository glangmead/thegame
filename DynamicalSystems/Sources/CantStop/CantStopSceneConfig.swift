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
        .columnar(heights: [3, 5, 7, 9, 11, 13, 11, 9, 7, 5, 3]),
        style: StyleConfig(stroke: "black", lineWidth: 1)
      ),
      .container("dice", [.die(.labeledSquare)]),
      .piece(.circle, color: .byPlayer)
    ])
  }
}
