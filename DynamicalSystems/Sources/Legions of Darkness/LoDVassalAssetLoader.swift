//
//  LoDVassalAssetLoader.swift
//  DynamicalSystems
//
//  Legions of Darkness -- Loads Vassal module images from iCloud Documents.
//

import Foundation
import CoreGraphics
import UIKit

struct LoDVassalAssetLoader {

  // MARK: - Sites JSON model

  struct SiteEntry: Codable {
    let id: String
    let label: String
    let group: String
    // swiftlint:disable:next identifier_name
    let x: Int
    // swiftlint:disable:next identifier_name
    let y: Int
    let width: Int
    let height: Int
    let siteID: Int?
    let value: Int?
  }

  struct SitesFile: Codable {
    // swiftlint:disable:next identifier_name
    let _notes: String?
    let imageWidth: Int
    let imageHeight: Int
    let sites: [SiteEntry]
  }

  // MARK: - iCloud folder

  /// Root of the Vassal module in iCloud Documents.
  static var moduleFolder: URL? {
    FileManager.default
      .url(forUbiquityContainerIdentifier: "iCloud.com.langmead.DynamicalSystems")?
      .appendingPathComponent("Documents/Legions_of_Darkness_1.0")
  }

  /// Whether the module folder exists and contains `images/Main Map.jpg`.
  static var isAvailable: Bool {
    guard let folder = moduleFolder else { return false }
    return FileManager.default.fileExists(
      atPath: folder.appendingPathComponent("images/Main Map.jpg").path
    )
  }

  // MARK: - Image loading

  /// Load an image from the module's images/ subfolder.
  static func loadImage(named filename: String) -> UIImage? {
    guard let folder = moduleFolder else { return nil }
    let url = folder.appendingPathComponent("images/\(filename)")
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return UIImage(contentsOfFile: url.path)
  }

  /// Load the board background image.
  static func loadBoardImage() -> UIImage? {
    loadImage(named: "Main Map.jpg")
  }

  // MARK: - Sites data

  /// Parse sites.json from the module folder.
  static func loadSites() -> SitesFile? {
    guard let folder = moduleFolder else { return nil }
    let url = folder.appendingPathComponent("sites.json")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(SitesFile.self, from: data)
  }

  // MARK: - Piece image mapping

  /// Map GamePiece ID to Vassal image filename.
  static let pieceImageNames: [Int: String] = [
    0: "Goblin.jpg",
    1: "Goblin.jpg",
    2: "Orc.jpg",
    3: "Orc.jpg",
    4: "Dragon.jpg",
    5: "Troll.jpg",
    10: "Warrior Front.png",
    11: "Wizard Front.png",
    12: "Ranger Front.png",
    13: "Rogue Front.png",
    14: "Paladin Front.png",
    15: "Cleric Front.png",
    20: "Moral +1.png",
    21: "Day:Night.png",
    22: "Defender Marker.png",
    23: "Defender Marker1.png",
    24: "Defender Marker2.png",
    25: "Arcane.png",
    26: "Divine.png",
    27: "Bloody Front.png",
    28: "Slow.png"
  ]

  /// Load the image for a specific piece, returning nil if unavailable.
  static func loadPieceImage(for pieceID: Int) -> UIImage? {
    guard let filename = pieceImageNames[pieceID] else { return nil }
    return loadImage(named: filename)
  }
}
