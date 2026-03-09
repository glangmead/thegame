//
//  MCSceneConfig.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

struct MCSceneConfig {
  static func config() -> SceneConfig {
    .container("malayan", [
      .board(
        .columnar(heights: [5, 8, 5]),
        style: StyleConfig(stroke: "black", lineWidth: 1)
      ),
      .die(.labeledSquare)
    ])
  }
}
