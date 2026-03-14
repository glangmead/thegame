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

enum SiteShape: Codable, Equatable {
  case rect
  case label
  case none
}

enum FontWeight: String, Codable, Equatable {
  case regular, bold, semibold, light, medium, heavy
}

enum LabelAlignment: String, Codable, Equatable {
  case center, top, left, right
}

struct LabelAppearance: Codable, Equatable {
  var size: CGFloat?
  var weight: FontWeight?
  var color: String?
  var alignment: LabelAlignment?

  func merging(with other: LabelAppearance) -> LabelAppearance {
    LabelAppearance(
      size: other.size ?? size,
      weight: other.weight ?? weight,
      color: other.color ?? color,
      alignment: other.alignment ?? alignment
    )
  }
}

struct ShadowAppearance: Codable, Equatable {
  var offset: CGFloat
  var blur: CGFloat
  var color: String

  func merging(with other: ShadowAppearance) -> ShadowAppearance {
    other
  }
}

struct SiteAppearance: Codable, Equatable {
  var fill: String?
  var stroke: String?
  var lineWidth: CGFloat?
  var cornerRadius: CGFloat?
  var padding: CGFloat?
  var shape: SiteShape?
  var labelStyle: LabelAppearance?
  var shadow: ShadowAppearance?
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
