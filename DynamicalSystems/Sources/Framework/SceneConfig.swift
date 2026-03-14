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

extension SiteAppearance {
  static func resolve(
    tags: Set<String>,
    from appearances: [String: SiteAppearance]
  ) -> SiteAppearance {
    var resolved = SiteAppearance()
    for tag in tags.sorted() {
      guard let appearance = appearances[tag] else { continue }
      if let value = appearance.fill { resolved.fill = value }
      if let value = appearance.stroke { resolved.stroke = value }
      if let value = appearance.lineWidth { resolved.lineWidth = value }
      if let value = appearance.cornerRadius { resolved.cornerRadius = value }
      if let value = appearance.padding { resolved.padding = value }
      if let value = appearance.shape { resolved.shape = value }
      if let value = appearance.labelStyle {
        resolved.labelStyle = resolved.labelStyle?.merging(with: value) ?? value
      }
      if let value = appearance.shadow {
        resolved.shadow = resolved.shadow?.merging(with: value) ?? value
      }
    }
    return resolved
  }

  static let defaultAppearances: [String: SiteAppearance] = [
    "header": SiteAppearance(
      shape: .label,
      labelStyle: LabelAppearance(size: 0.4, weight: .bold, color: "darkgray")),
    "invisible": SiteAppearance(shape: SiteShape.none),
    "crown": SiteAppearance(
      fill: "yellow", lineWidth: 2,
      labelStyle: LabelAppearance(
        size: 0.5, weight: .bold, color: "black", alignment: .center))
  ]
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
