//
//  BCSceneConfig.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

struct BCSceneConfig {
    static func config() -> SceneConfig {
        .container("battlecard", [
            .board(
                .columnar(heights: [4, 5, 4]),
                style: StyleConfig(stroke: "black", lineWidth: 1)
            ),
            .die(.labeledSquare)
        ])
    }
}
