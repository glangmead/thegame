//
//  SceneConfig.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

enum SceneConfig: Codable, Equatable {
  // Board geometry
  case columnar(heights: [Int])
  case grid(rows: Int, cols: Int)

  // Component visuals
  case piece(PieceShape, color: ColorRule)
  case die(DieShape)
  case card(CardShape)

  // Composition — array order = z-order (back to front)
  indirect case container(String, [SceneConfig])
  indirect case board(SceneConfig, style: StyleConfig?)

  // Layout overrides
  // swiftlint:disable:next identifier_name
  indirect case positioned(SceneConfig, x: Float, y: Float)
  indirect case scaled(SceneConfig, factor: Float)
}

enum PieceShape: Codable, Equatable {
  case circle
  case square
  case image(String)
}

enum DieShape: Codable, Equatable {
  case labeledSquare
  case pipped
}

enum CardShape: Codable, Equatable {
  case rectangle
}

enum ColorRule: Codable, Equatable {
  case byPlayer
  case fixed(String)
  case byTag(String)
}

struct StyleConfig: Codable, Equatable {
  var fill: String?
  var stroke: String?
  var lineWidth: Float?
  var labelFont: String?
}
