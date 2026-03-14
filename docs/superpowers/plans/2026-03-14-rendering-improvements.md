# Rendering Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tag-driven visual styling, track backgrounds, stacking policies, and camera zoom/pan to the generic SpriteKit rendering system.

**Architecture:** Four independent features built on the existing `GameScene`/`SiteGraph`/`SceneConfig` framework. SiteAppearance is foundational — track backgrounds build on it. Stacking and camera are independent. All changes are backward-compatible; existing games compile and render identically without modification.

**Tech Stack:** Swift 6.2, SpriteKit, SwiftUI, Swift Testing framework

**Spec:** `docs/superpowers/specs/2026-03-14-rendering-improvements-design.md`

**Test command:** `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`

**Lint command:** `/opt/homebrew/bin/swiftlint --path <file>`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `DynamicalSystems/Sources/Framework/SceneConfig.swift` | Modify | Add SiteAppearance, SiteShape, FontWeight, LabelAlignment, LabelAppearance, ShadowAppearance, StackPolicy types. Add `stacking:` to `.piece` case. |
| `DynamicalSystems/Sources/Framework/SiteGraph.swift` | Modify | Add `trackTags` field, `addTrack` convenience method. |
| `DynamicalSystems/Sources/Framework/GameScene.swift` | Modify | Add `appearances` table, `resolveAppearance`, rewrite `buildBoardSites`, add `buildTrackBackgrounds`, add camera setup/methods, extend `colorFromString`. |
| `DynamicalSystems/Sources/Framework/GameSceneSync.swift` | Modify | Update `stackingOffset` for policy dispatch, update `syncPieces` for badge logic. |
| `DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift` | Modify | Update `testSceneConfigCodable` for new `.piece` parameter. Add SiteAppearance resolution tests. |
| `DynamicalSystems/DynamicalSystemsTests/RenderingTests.swift` | Create | Tests for track backgrounds, stacking policies, camera bounds. |
| `DynamicalSystems/Sources/CantStop/CantStopView.swift` | Modify | Add zoom/pan gesture modifiers. |
| `DynamicalSystems/Sources/Malayan Campaign/MCView.swift` | Modify | Add zoom/pan gesture modifiers. |
| `DynamicalSystems/Sources/Battle Card/BCView.swift` | Modify | Add zoom/pan gesture modifiers. |
| `DynamicalSystems/Sources/Hearts/HeartsView.swift` | Modify | Add zoom/pan gesture modifiers. |
| `DynamicalSystems/Sources/Legions of Darkness/LoDView.swift` | Modify | Add zoom/pan gesture modifiers. |

---

## Chunk 1: SiteAppearance Types, Resolution, and Tests

### Task 1: Add appearance types to SceneConfig.swift

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/SceneConfig.swift`

- [ ] **Step 1: Add SiteShape enum after the existing CardShape enum (after line 43)**

```swift
enum SiteShape: Codable, Equatable {
  case rect
  case label
  case none
}
```

- [ ] **Step 2: Add FontWeight enum**

```swift
enum FontWeight: String, Codable, Equatable {
  case regular, bold, semibold, light, medium, heavy
}
```

- [ ] **Step 3: Add LabelAlignment enum**

```swift
enum LabelAlignment: String, Codable, Equatable {
  case center, top, left, right
}
```

- [ ] **Step 4: Add LabelAppearance struct with merging**

```swift
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
```

- [ ] **Step 5: Add ShadowAppearance struct**

```swift
struct ShadowAppearance: Codable, Equatable {
  var offset: CGFloat
  var blur: CGFloat
  var color: String

  func merging(with other: ShadowAppearance) -> ShadowAppearance {
    other
  }
}
```

- [ ] **Step 6: Add SiteAppearance struct**

```swift
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
```

- [ ] **Step 7: Run swiftlint and fix issues**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/SceneConfig.swift`

- [ ] **Step 8: Build to verify compilation**

Run: `xcodebuild build -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystems -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add DynamicalSystems/Sources/Framework/SceneConfig.swift
git commit -m "feat: add SiteAppearance types for tag-driven visual styling"
```

### Task 2: Add resolveAppearance to GameScene and write tests

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/GameScene.swift`
- Modify: `DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift`

- [ ] **Step 1: Write failing tests for SiteAppearance resolution**

Add to `DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift`, after the `SiteGraphTests` struct:

```swift
struct SiteAppearanceTests {
  @Test
  func testEmptyTagsReturnsEmptyAppearance() {
    let appearances: [String: SiteAppearance] = [
      "crown": SiteAppearance(fill: "yellow")
    ]
    let resolved = SiteAppearance.resolve(tags: [], from: appearances)
    #expect(resolved.fill == nil)
    #expect(resolved.shape == nil)
  }

  @Test
  func testSingleTagResolution() {
    let appearances: [String: SiteAppearance] = [
      "crown": SiteAppearance(fill: "yellow", lineWidth: 2)
    ]
    let resolved = SiteAppearance.resolve(tags: ["crown"], from: appearances)
    #expect(resolved.fill == "yellow")
    #expect(resolved.lineWidth == 2)
    #expect(resolved.stroke == nil)
  }

  @Test
  func testUnknownTagIgnored() {
    let appearances: [String: SiteAppearance] = [
      "crown": SiteAppearance(fill: "yellow")
    ]
    let resolved = SiteAppearance.resolve(tags: ["unknown"], from: appearances)
    #expect(resolved.fill == nil)
  }

  @Test
  func testMultipleTagsCompose() {
    let appearances: [String: SiteAppearance] = [
      "base": SiteAppearance(fill: "gray", stroke: "black"),
      "highlight": SiteAppearance(fill: "yellow")
    ]
    // "base" < "highlight" alphabetically, so highlight's fill wins
    let resolved = SiteAppearance.resolve(tags: ["base", "highlight"], from: appearances)
    #expect(resolved.fill == "yellow")
    #expect(resolved.stroke == "black")
  }

  @Test
  func testLabelStyleMergesFieldByField() {
    let appearances: [String: SiteAppearance] = [
      "a": SiteAppearance(labelStyle: LabelAppearance(size: 0.4, weight: .bold)),
      "b": SiteAppearance(labelStyle: LabelAppearance(color: "red"))
    ]
    let resolved = SiteAppearance.resolve(tags: ["a", "b"], from: appearances)
    // "a" sets size and weight; "b" adds color without overwriting
    #expect(resolved.labelStyle?.size == 0.4)
    #expect(resolved.labelStyle?.weight == .bold)
    #expect(resolved.labelStyle?.color == "red")
  }

  @Test
  func testDefaultAppearancesReplicateExistingBehavior() {
    let defaults = SiteAppearance.defaultAppearances
    let header = SiteAppearance.resolve(tags: ["header"], from: defaults)
    #expect(header.shape == .label)
    #expect(header.labelStyle?.weight == .bold)

    let invisible = SiteAppearance.resolve(tags: ["invisible"], from: defaults)
    #expect(invisible.shape == .none)

    let crown = SiteAppearance.resolve(tags: ["crown"], from: defaults)
    #expect(crown.fill == "yellow")
    #expect(crown.lineWidth == 2)
    #expect(crown.labelStyle?.alignment == .center)
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/SiteAppearanceTests 2>&1 | tail -10`
Expected: FAIL — `resolve` and `defaultAppearances` don't exist yet

- [ ] **Step 3: Add static resolve method and defaultAppearances to SiteAppearance**

In `DynamicalSystems/Sources/Framework/SceneConfig.swift`, add to `SiteAppearance`:

```swift
extension SiteAppearance {
  static func resolve(
    tags: Set<String>,
    from appearances: [String: SiteAppearance]
  ) -> SiteAppearance {
    var resolved = SiteAppearance()
    for tag in tags.sorted() {
      guard let appearance = appearances[tag] else { continue }
      if let v = appearance.fill { resolved.fill = v }
      if let v = appearance.stroke { resolved.stroke = v }
      if let v = appearance.lineWidth { resolved.lineWidth = v }
      if let v = appearance.cornerRadius { resolved.cornerRadius = v }
      if let v = appearance.padding { resolved.padding = v }
      if let v = appearance.shape { resolved.shape = v }
      if let v = appearance.labelStyle {
        resolved.labelStyle = resolved.labelStyle?.merging(with: v) ?? v
      }
      if let v = appearance.shadow {
        resolved.shadow = resolved.shadow?.merging(with: v) ?? v
      }
    }
    return resolved
  }

  static let defaultAppearances: [String: SiteAppearance] = [
    "header": SiteAppearance(
      shape: .label,
      labelStyle: LabelAppearance(size: 0.4, weight: .bold, color: "darkgray")),
    "invisible": SiteAppearance(shape: .none),
    "crown": SiteAppearance(
      fill: "yellow", lineWidth: 2,
      labelStyle: LabelAppearance(
        size: 0.5, weight: .bold, color: "black", alignment: .center)),
  ]
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/SiteAppearanceTests 2>&1 | tail -10`
Expected: All 6 tests PASS

- [ ] **Step 5: Run swiftlint on both changed files**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/SceneConfig.swift && /opt/homebrew/bin/swiftlint --path DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift`

- [ ] **Step 6: Commit**

```bash
git add DynamicalSystems/Sources/Framework/SceneConfig.swift DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift
git commit -m "feat: add SiteAppearance.resolve with composition and default appearances"
```

### Task 3: Add appearances parameter to GameScene, extend colorFromString

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/GameScene.swift`

- [ ] **Step 1: Add appearances property and update init (lines 36-61)**

Add after `cellSize` property (line 37):

```swift
let appearances: [String: SiteAppearance]
```

Update init signature (line 49) to:

```swift
init(
  model: GameModel<State, Action>,
  config: SceneConfig,
  size: CGSize,
  cellSize: CGFloat = 30,
  appearances: [String: SiteAppearance] = SiteAppearance.defaultAppearances
) {
```

Store it: `self.appearances = appearances` before `super.init`.

- [ ] **Step 2: Add FontWeight.uiWeight computed property**

In `GameScene.swift`, add an extension (needed for rendering, since `UIFont` is imported here but not in SceneConfig.swift):

```swift
extension FontWeight {
  var uiWeight: UIFont.Weight {
    switch self {
    case .regular: .regular
    case .bold: .bold
    case .semibold: .semibold
    case .light: .light
    case .medium: .medium
    case .heavy: .heavy
    }
  }
}
```

- [ ] **Step 3: Extend colorFromString (line 269) with new colors and hex support**

Add cases to the switch in `colorFromString`:

```swift
case "darkgray", "darkgrey":
  return .darkGray
case "steelblue":
  return SKColor(red: 0.27, green: 0.51, blue: 0.71, alpha: 1.0)
case "burlywood":
  return SKColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1.0)
case "saddlebrown":
  return SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
```

Add hex support after the switch's `default:` case:

```swift
default:
  if name.hasPrefix("#"), name.count == 7,
     let hex = UInt32(name.dropFirst(), radix: 16) {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return SKColor(red: r, green: g, blue: b, alpha: 1.0)
  }
  return nil
```

- [ ] **Step 4: Rewrite buildBoardSites (lines 122-189) to use resolved appearances**

Replace the entire method body with:

```swift
private func buildBoardSites(style: StyleConfig?, parent: SKNode) {
  let defaultStroke = colorFromString(style?.stroke) ?? .black
  let defaultFill = colorFromString(style?.fill) ?? .clear
  let defaultLineWidth = CGFloat(style?.lineWidth ?? 1)
  let defaultFontSize = cellSize * 0.35

  for siteID in model.graph.sites.keys.sorted(by: { $0.raw < $1.raw }) {
    guard let site = model.graph.sites[siteID] else { continue }

    let resolved = SiteAppearance.resolve(tags: site.tags, from: appearances)
    let shape = resolved.shape ?? .rect

    switch shape {
    case .none:
      let node = SKNode()
      node.position = site.position
      node.name = siteID.description
      parent.addChild(node)
      siteNodes[siteID] = node

    case .label:
      let ls = resolved.labelStyle
      let labelNode = SKLabelNode(text: site.label ?? "")
      labelNode.applySystemFont(
        size: cellSize * (ls?.size ?? 0.4),
        weight: ls?.weight?.uiWeight ?? .bold,
        color: colorFromString(ls?.color) ?? .darkGray)
      labelNode.horizontalAlignmentMode = .left
      labelNode.verticalAlignmentMode = .center
      labelNode.position = CGPoint(
        x: site.position.x,
        y: site.position.y + cellSize / 2)
      labelNode.name = "header_\(siteID.raw)"
      parent.addChild(labelNode)
      siteNodes[siteID] = labelNode

    case .rect:
      let fill = colorFromString(resolved.fill) ?? defaultFill
      let stroke = colorFromString(resolved.stroke) ?? defaultStroke
      let lineWidth = resolved.lineWidth ?? defaultLineWidth
      let cornerRadius = resolved.cornerRadius ?? 0

      let node: SKShapeNode
      if cornerRadius > 0 {
        node = SKShapeNode(
          rect: CGRect(x: 0, y: 0, width: cellSize, height: cellSize),
          cornerRadius: cornerRadius)
      } else {
        node = SKShapeNode(
          rect: CGRect(x: 0, y: 0, width: cellSize, height: cellSize))
      }
      node.strokeColor = stroke
      node.fillColor = fill
      node.lineWidth = lineWidth
      node.position = site.position
      node.name = siteID.description
      parent.addChild(node)
      siteNodes[siteID] = node

      if fill != defaultFill {
        baseFillColors[siteID] = fill
      }

      // Shadow
      if let shadow = resolved.shadow {
        let shadowNode = SKShapeNode(
          rect: CGRect(x: 0, y: 0, width: cellSize, height: cellSize),
          cornerRadius: cornerRadius)
        shadowNode.fillColor = colorFromString(shadow.color) ?? .black
        shadowNode.strokeColor = .clear
        shadowNode.alpha = 0.3
        shadowNode.position = CGPoint(x: shadow.offset, y: -shadow.offset)
        shadowNode.zPosition = -1
        node.addChild(shadowNode)
      }

      // Site label
      if let label = site.label {
        let ls = resolved.labelStyle
        let labelNode = SKLabelNode(text: label)
        let fontSize = cellSize * (ls?.size ?? 0.35)
        let weight = ls?.weight?.uiWeight ?? .regular
        let color = colorFromString(ls?.color) ?? .darkGray
        let alignment = ls?.alignment ?? .top
        labelNode.applySystemFont(size: fontSize, weight: weight, color: color)
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = alignment == .center ? .center : .top
        labelNode.position = alignment == .center
          ? CGPoint(x: cellSize / 2, y: cellSize / 2)
          : CGPoint(x: cellSize / 2, y: cellSize - 2)
        labelNode.name = "siteLabel_\(siteID.raw)"
        node.addChild(labelNode)
      }
    }
  }
}
```

- [ ] **Step 5: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/GameScene.swift`

- [ ] **Step 6: Build and run all existing tests to verify backward compatibility**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`
Expected: All tests pass (existing behavior preserved by default appearances)

- [ ] **Step 7: Commit**

```bash
git add DynamicalSystems/Sources/Framework/GameScene.swift
git commit -m "feat: rewrite buildBoardSites to use SiteAppearance resolution

Replaces hardcoded header/invisible/crown tag checks with
appearance table lookup. Extends colorFromString with new
named colors and hex support."
```

---

## Chunk 2: Track Tags and Track Backgrounds

### Task 4: Add trackTags to SiteGraph with tests

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/SiteGraph.swift`
- Modify: `DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift`

- [ ] **Step 1: Write failing test for addTrack**

Add to `SiteGraphTests` in `FrameworkGraphTests.swift`:

```swift
@Test
func testAddTrackWithTags() {
  var graph = SiteGraph()
  let s0 = graph.addSite(position: CGPoint(x: 0, y: 0))
  let s1 = graph.addSite(position: CGPoint(x: 1, y: 0))
  graph.addTrack("east", sites: [s0, s1], tags: ["trackBg", "dropShadow"])

  #expect(graph.tracks["east"]?.count == 2)
  #expect(graph.trackTags["east"] == ["trackBg", "dropShadow"])
}

@Test
func testAddTrackWithoutTags() {
  var graph = SiteGraph()
  let s0 = graph.addSite(position: CGPoint(x: 0, y: 0))
  graph.addTrack("time", sites: [s0])

  #expect(graph.tracks["time"]?.count == 1)
  #expect(graph.trackTags["time"] == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/SiteGraphTests/testAddTrackWithTags -only-testing:DynamicalSystemsTests/SiteGraphTests/testAddTrackWithoutTags 2>&1 | tail -10`
Expected: FAIL — `addTrack` and `trackTags` don't exist

- [ ] **Step 3: Add trackTags and addTrack to SiteGraph**

In `DynamicalSystems/Sources/Framework/SiteGraph.swift`, add after `tracks` field (line 52):

```swift
var trackTags: [String: Set<String>] = [:]
```

Add method after `connect` (after line 72):

```swift
mutating func addTrack(_ name: String, sites: [SiteID], tags: Set<String> = []) {
  tracks[name] = sites
  if !tags.isEmpty { trackTags[name] = tags }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/SiteGraphTests 2>&1 | tail -10`
Expected: All SiteGraphTests pass

- [ ] **Step 5: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/SiteGraph.swift`

- [ ] **Step 6: Commit**

```bash
git add DynamicalSystems/Sources/Framework/SiteGraph.swift DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift
git commit -m "feat: add trackTags and addTrack convenience to SiteGraph"
```

### Task 5: Add buildTrackBackgrounds to GameScene

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/GameScene.swift`
- Create: `DynamicalSystems/DynamicalSystemsTests/RenderingTests.swift`

- [ ] **Step 1: Write failing test for track background rendering**

Create `DynamicalSystems/DynamicalSystemsTests/RenderingTests.swift`:

```swift
import CoreGraphics
import Foundation
import SpriteKit
import Testing

// Reuse TrivialState/TrivialAction/TrivialGame from FrameworkGraphTests
// or define minimal stubs here.

private struct StubState: GameState, CustomStringConvertible {
  typealias Phase = Int
  typealias Piece = Int
  typealias PiecePosition = Int
  typealias Player = Int
  typealias Position = Int
  var name: String { "Stub" }
  var player: Int = 0
  var players: [Int] = [0]
  var ended: Bool = false
  var endedInVictoryFor: [Int] = []
  var endedInDefeatFor: [Int] = []
  var position: [Int: Int] = [:]
  var stepCount: Int = 0
  var description: String { "stub" }
}

private enum StubAction: Hashable, CustomStringConvertible {
  case noop
  var description: String { "noop" }
}

private struct StubGame: PlayableGame {
  var gameName: String { "Stub" }
  func isTerminal(state: StubState) -> Bool { state.ended }
  func newState() -> StubState { StubState() }
  func allowedActions(state: StubState) -> [StubAction] { [] }
  func reduce(into state: inout StubState, action: StubAction) -> [Log] { [] }
}

struct RenderingTests {
  @Test @MainActor
  func testTrackBackgroundCreated() {
    var graph = SiteGraph()
    let s0 = graph.addSite(position: CGPoint(x: 0, y: 0))
    let s1 = graph.addSite(position: CGPoint(x: 30, y: 0))
    let s2 = graph.addSite(position: CGPoint(x: 60, y: 0))
    graph.addTrack("east", sites: [s0, s1, s2], tags: ["trackBg"])

    let game = StubGame()
    let model = GameModel(game: game, graph: graph)
    let appearances = SiteAppearance.defaultAppearances.merging([
      "trackBg": SiteAppearance(fill: "steelblue", cornerRadius: 6, padding: 4)
    ]) { _, new in new }

    let scene = GameScene(
      model: model,
      config: .container("test", [
        .board(.grid(rows: 1, cols: 3), style: nil),
        .piece(.circle, color: .byPlayer)
      ]),
      size: CGSize(width: 200, height: 200),
      cellSize: 30,
      appearances: appearances
    )

    // Find the track background node
    let boardNode = scene.childNode(withName: "board")
    let bgNode = boardNode?.childNode(withName: "trackBg_east")
    #expect(bgNode != nil)
    #expect((bgNode as? SKShapeNode)?.fillColor != .clear)
    #expect(bgNode?.zPosition == -1)
  }
}
```

- [ ] **Step 2: Add RenderingTests.swift to test target**

The test target uses `membershipExceptions` in `project.pbxproj`. Add the new file.
Check if file-system-synchronized groups auto-discover test files; if not, add manually.

- [ ] **Step 3: Run test to verify it fails**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/RenderingTests/testTrackBackgroundCreated 2>&1 | tail -10`
Expected: FAIL — `buildTrackBackgrounds` doesn't exist, no node named `trackBg_east`

- [ ] **Step 4: Implement buildTrackBackgrounds in GameScene**

Add method to `GameScene` after `buildBoardSites`:

```swift
private func buildTrackBackgrounds(parent: SKNode) {
  for (trackName, tags) in model.graph.trackTags {
    guard let siteIDs = model.graph.tracks[trackName],
          !siteIDs.isEmpty else { continue }

    let resolved = SiteAppearance.resolve(tags: tags, from: appearances)
    let padding = resolved.padding ?? 4

    // Compute bounding rect from member sites
    var rect = CGRect.null
    for siteID in siteIDs {
      guard let site = model.graph.sites[siteID] else { continue }
      let frame = CGRect(
        origin: site.position,
        size: CGSize(width: cellSize, height: cellSize))
      rect = rect.union(frame)
    }
    guard !rect.isNull else { continue }

    // Inflate by padding
    let inflated = rect.insetBy(dx: -padding, dy: -padding)
    let cornerRadius = resolved.cornerRadius ?? 0

    let bgNode = SKShapeNode(rect: inflated, cornerRadius: cornerRadius)
    bgNode.fillColor = colorFromString(resolved.fill) ?? .clear
    bgNode.strokeColor = colorFromString(resolved.stroke) ?? .clear
    bgNode.lineWidth = resolved.lineWidth ?? 0
    bgNode.zPosition = -1
    bgNode.name = "trackBg_\(trackName)"

    // Shadow
    if let shadow = resolved.shadow {
      let shadowNode = SKShapeNode(rect: inflated, cornerRadius: cornerRadius)
      shadowNode.fillColor = colorFromString(shadow.color) ?? .black
      shadowNode.strokeColor = .clear
      shadowNode.alpha = 0.3
      shadowNode.position = CGPoint(x: shadow.offset, y: -shadow.offset)
      shadowNode.zPosition = -2
      parent.addChild(shadowNode)
    }

    parent.addChild(bgNode)
  }
}
```

- [ ] **Step 5: Call buildTrackBackgrounds in buildScene, inside the `.board` case (line 82)**

Change the `.board` case to:

```swift
case .board(_, let style):
  let boardNode = SKNode()
  boardNode.name = "board"
  parent.addChild(boardNode)
  buildTrackBackgrounds(parent: boardNode)
  buildBoardSites(style: style, parent: boardNode)
  return boardNode
```

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/RenderingTests 2>&1 | tail -10`
Expected: PASS

- [ ] **Step 7: Run all tests for backward compatibility**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`
Expected: All tests pass

- [ ] **Step 8: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/GameScene.swift`

- [ ] **Step 9: Commit**

```bash
git add DynamicalSystems/Sources/Framework/GameScene.swift DynamicalSystems/DynamicalSystemsTests/RenderingTests.swift
git commit -m "feat: add track background rendering via trackTags and SiteAppearance"
```

---

## Chunk 3: Stacking Policy

### Task 6: Add StackPolicy and update SceneConfig.piece

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/SceneConfig.swift`
- Modify: `DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift`

- [ ] **Step 1: Add StackPolicy enum to SceneConfig.swift**

After `SiteAppearance` extension:

```swift
enum StackPolicy: Codable, Equatable {
  case fan
  case vertical
  case badge
}
```

- [ ] **Step 2: Add stacking parameter to .piece case**

Change line 16 from:

```swift
case piece(PieceShape, color: ColorRule)
```

to:

```swift
case piece(PieceShape, color: ColorRule, stacking: StackPolicy = .fan)
```

- [ ] **Step 3: Update testSceneConfigCodable in FrameworkGraphTests.swift**

The existing test (line 223) encodes a config with `.piece(.circle, color: .byPlayer)`. The auto-synthesized Codable now includes the `stacking` field. Update the test to explicitly include it:

```swift
@Test
func testSceneConfigCodable() throws {
  let config: SceneConfig = .container("cantstop", [
    .board(.columnar(heights: [3, 5, 7]), style: StyleConfig(stroke: "black")),
    .container("dice", [.die(.labeledSquare)]),
    .piece(.circle, color: .byPlayer, stacking: .fan)
  ])

  let data = try JSONEncoder().encode(config)
  let decoded = try JSONDecoder().decode(SceneConfig.self, from: data)
  #expect(decoded == config)
}
```

- [ ] **Step 4: Fix all existing .piece references to compile**

Search for `.piece(` in all scene config files. They should still compile with the default parameter, but verify:

Run: `xcodebuild build -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystems -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Run swiftlint and tests**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/SceneConfig.swift`
Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add DynamicalSystems/Sources/Framework/SceneConfig.swift DynamicalSystems/DynamicalSystemsTests/FrameworkGraphTests.swift
git commit -m "feat: add StackPolicy enum and stacking parameter on SceneConfig.piece"
```

### Task 7: Wire stacking policy through PieceLayout and stackingOffset

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/GameScene.swift`
- Modify: `DynamicalSystems/Sources/Framework/GameSceneSync.swift`
- Modify: `DynamicalSystems/DynamicalSystemsTests/RenderingTests.swift`

- [ ] **Step 1: Write failing tests for stacking policies**

Add to `RenderingTests.swift`:

```swift
@Test @MainActor
func testStackingOffsetFanReturnsHorizontalSpread() {
  let scene = makeStubScene()
  let sitePieces: [SiteID: [Int]] = [SiteID(0): [1, 2, 3]]
  let offset = scene.stackingOffset(
    pieceID: 2, at: SiteID(0), sitePieces: sitePieces, policy: .fan)
  #expect(offset.y == 0)
  #expect(offset.x != 0)
}

@Test @MainActor
func testStackingOffsetVerticalReturnsYOffset() {
  let scene = makeStubScene()
  let sitePieces: [SiteID: [Int]] = [SiteID(0): [1, 2, 3]]
  let offset = scene.stackingOffset(
    pieceID: 2, at: SiteID(0), sitePieces: sitePieces, policy: .vertical)
  #expect(offset.x == 0)
  #expect(offset.y != 0)
}

@Test @MainActor
func testStackingOffsetBadgeReturnsZero() {
  let scene = makeStubScene()
  let sitePieces: [SiteID: [Int]] = [SiteID(0): [1, 2, 3]]
  let offset = scene.stackingOffset(
    pieceID: 3, at: SiteID(0), sitePieces: sitePieces, policy: .badge)
  #expect(offset == .zero)
}
```

(The `makeStubScene()` helper creates a minimal `GameScene` using `StubGame`. Add it as a private helper in `RenderingTests`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/RenderingTests 2>&1 | tail -10`
Expected: FAIL — `stackingOffset` doesn't accept `policy:` yet

- [ ] **Step 3: Update PieceLayout to include stacking (GameScene.swift line 43-46)**

```swift
struct PieceLayout {
  let parent: SKNode
  let scale: CGFloat
  let stacking: StackPolicy
}
```

- [ ] **Step 4: Update buildScene .piece case (line 92-93) to store stacking**

```swift
case .piece(_, color: _, stacking: let stacking):
  pieceLayouts["token"] = PieceLayout(
    parent: parent, scale: accumulatedScale, stacking: stacking)
  return parent
```

Also update `.die` and `.card` cases to use default `.fan`:

```swift
case .die:
  pieceLayouts["die"] = PieceLayout(
    parent: parent, scale: accumulatedScale, stacking: .fan)
  return parent
case .card:
  pieceLayouts["card"] = PieceLayout(
    parent: parent, scale: accumulatedScale, stacking: .fan)
  return parent
```

- [ ] **Step 5: Update stackingOffset in GameSceneSync.swift (lines 145-157) to dispatch on policy**

```swift
func stackingOffset(
  pieceID: Int, at site: SiteID,
  sitePieces: [SiteID: [Int]],
  scale: CGFloat = 1,
  policy: StackPolicy = .fan
) -> CGPoint {
  guard let group = sitePieces[site], group.count > 1,
        let index = group.firstIndex(of: pieceID) else {
    return .zero
  }
  let count = group.count
  switch policy {
  case .fan:
    let spacing = cellSize * 0.7 * scale
    let totalWidth = spacing * CGFloat(count - 1)
    let xOffset = CGFloat(index) * spacing - totalWidth / 2
    return CGPoint(x: xOffset, y: 0)
  case .vertical:
    let spacing = cellSize * 0.3 * scale
    let yOffset = CGFloat(index) * spacing
    return CGPoint(x: 0, y: yOffset)
  case .badge:
    return .zero
  }
}
```

- [ ] **Step 6: Update movePiece call (line 126-127) to pass policy**

In `movePiece` method, add policy parameter:

```swift
private func movePiece(
  _ node: SKNode, id pieceID: Int, to site: SiteID,
  sitePieces: [SiteID: [Int]], duration: TimeInterval,
  scale: CGFloat = 1, policy: StackPolicy = .fan
) {
  guard let dest = siteNodes[site] else { return }
  let offset = stackingOffset(
    pieceID: pieceID, at: site, sitePieces: sitePieces,
    scale: scale, policy: policy)
  // ... rest unchanged
}
```

Update all `movePiece` call sites in `syncPieces` to pass `layout?.stacking ?? .fan`.

- [ ] **Step 7: Add badge visibility logic to syncPieces**

In `syncPieces`, after the `movePiece` call for `.at` and `.dieShowing` cases, add badge handling:

```swift
// Badge stacking: hide all but last piece, show count badge
let stacking = layout?.stacking ?? .fan
if stacking == .badge, let group = sitePieces[site], group.count > 1 {
  let isLast = group.last == piece.id
  node.alpha = isLast ? 1 : 0
  if isLast {
    updateBadge(on: node, count: group.count)
  }
} else {
  removeBadge(from: node)
}
```

Add helper methods to `GameScene` (or the extension):

```swift
private func updateBadge(on node: SKNode, count: Int) {
  let badgeName = "stackBadge"
  if let existing = node.childNode(withName: badgeName) as? SKShapeNode {
    if let label = existing.childNode(withName: "badgeLabel") as? SKLabelNode {
      label.updateSystemText("\(count)")
    }
    return
  }
  let radius = cellSize * 0.15
  let badge = SKShapeNode(circleOfRadius: radius)
  badge.fillColor = .red
  badge.strokeColor = .white
  badge.lineWidth = 1
  badge.name = badgeName
  badge.position = CGPoint(x: radius * 2, y: radius * 2)
  badge.zPosition = 10

  let label = SKLabelNode(text: "\(count)")
  label.applySystemFont(size: radius * 1.2, weight: .bold, color: .white)
  label.horizontalAlignmentMode = .center
  label.verticalAlignmentMode = .center
  label.name = "badgeLabel"
  badge.addChild(label)
  node.addChild(badge)
}

private func removeBadge(from node: SKNode) {
  node.childNode(withName: "stackBadge")?.removeFromParent()
}
```

- [ ] **Step 8: Run swiftlint on both files**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/GameScene.swift && /opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/GameSceneSync.swift`

- [ ] **Step 9: Build and run all tests**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`
Expected: All pass (default `.fan` preserves existing behavior)

- [ ] **Step 10: Commit**

```bash
git add DynamicalSystems/Sources/Framework/GameScene.swift DynamicalSystems/Sources/Framework/GameSceneSync.swift
git commit -m "feat: implement stacking policy dispatch with fan, vertical, and badge modes"
```

---

## Chunk 4: Camera Zoom and Pan

### Task 8: Add camera setup to GameScene

**Files:**
- Modify: `DynamicalSystems/Sources/Framework/GameScene.swift`
- Modify: `DynamicalSystems/DynamicalSystemsTests/RenderingTests.swift`

- [ ] **Step 1: Write failing tests for camera setup**

Add to `RenderingTests.swift`:

```swift
@Test @MainActor
func testBoardBoundsCoversAllSites() {
  let scene = makeStubScene()
  let bounds = scene.boardBounds()
  #expect(!bounds.isNull)
  #expect(bounds.width > 0)
  #expect(bounds.height > 0)
}

@Test @MainActor
func testSetupCameraSetsCameraNode() {
  let scene = makeStubScene()
  #expect(scene.cameraNode != nil)
  #expect(scene.camera != nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/RenderingTests 2>&1 | tail -10`
Expected: FAIL — `boardBounds()` and `cameraNode` don't exist yet

- [ ] **Step 3: Add camera properties after pieceLayouts (line 47)**

```swift
var cameraNode: SKCameraNode?
private var minScale: CGFloat = 0.3
private var maxScale: CGFloat = 3.0
```

- [ ] **Step 4: Add camera methods after syncState (end of file)**

```swift
// MARK: - Camera

func boardBounds() -> CGRect {
  guard !siteNodes.isEmpty else { return .zero }
  var rect = CGRect.null
  for (_, node) in siteNodes {
    let frame = CGRect(
      origin: node.position,
      size: CGSize(width: cellSize, height: cellSize))
    rect = rect.union(frame)
  }
  return rect
}

func setupCamera() {
  let cam = SKCameraNode()
  addChild(cam)
  camera = cam
  cameraNode = cam
  zoomToFit()
}

func zoomToFit() {
  guard let cam = cameraNode else { return }
  let bounds = boardBounds()
  guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return }
  let scaleX = size.width / bounds.width
  let scaleY = size.height / bounds.height
  let fitScale = min(scaleX, scaleY) * 0.9
  cam.setScale(1 / fitScale)
  cam.position = CGPoint(x: bounds.midX, y: bounds.midY)
}

func setZoom(scale: CGFloat) {
  guard let cam = cameraNode else { return }
  cam.setScale(max(minScale, min(maxScale, scale)))
}

func setCameraPosition(_ position: CGPoint) {
  cameraNode?.position = position
}
```

- [ ] **Step 5: Call setupCamera at end of init**

After the `buildScene` call (line 60), add:

```swift
setupCamera()
```

**Note:** This adds a camera to ALL games unconditionally. The `zoomToFit()` call with a 0.9 factor means boards will appear at 90% of the previous fill size (a slight margin). This is intentional — the camera enables zoom/pan for all games, and the margin prevents edge-to-edge clipping. If any game looks wrong, adjust `zoomToFit`'s margin factor.

- [ ] **Step 6: Run tests to verify camera tests pass**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests/RenderingTests 2>&1 | tail -10`
Expected: Camera tests PASS

- [ ] **Step 7: Run swiftlint**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/GameScene.swift`

- [ ] **Step 8: Build and run all tests**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`
Expected: All pass

- [ ] **Step 9: Commit**

```bash
git add DynamicalSystems/Sources/Framework/GameScene.swift DynamicalSystems/DynamicalSystemsTests/RenderingTests.swift
git commit -m "feat: add SKCameraNode with zoom-to-fit and zoom/pan methods"
```

### Task 9: Add SwiftUI gesture modifiers to all game views

**Files:**
- Modify: `DynamicalSystems/Sources/CantStop/CantStopView.swift` (line 65)
- Modify: `DynamicalSystems/Sources/Malayan Campaign/MCView.swift` (line 55)
- Modify: `DynamicalSystems/Sources/Battle Card/BCView.swift` (line 55)
- Modify: `DynamicalSystems/Sources/Hearts/HeartsView.swift` (line 81)
- Modify: `DynamicalSystems/Sources/Legions of Darkness/LoDView.swift` (lines 120, 123, 125)

- [ ] **Step 1: Add camera state properties and gesture modifiers to CantStopView**

Add state properties to the view struct:

```swift
@State private var cameraScale: CGFloat = 1.0
@State private var cameraPosition: CGPoint = .zero
```

Wrap the `SpriteView(scene: scene)` call (line 65) with gesture modifiers:

```swift
SpriteView(scene: scene)
  .gesture(MagnifyGesture()
    .onChanged { value in
      let newScale = cameraScale / value.magnification
      scene.setZoom(scale: newScale)
    }
    .onEnded { value in
      cameraScale = cameraScale / value.magnification
    }
  )
  .gesture(DragGesture()
    .onChanged { value in
      let s = scene.cameraNode?.xScale ?? 1
      scene.setCameraPosition(CGPoint(
        x: cameraPosition.x - value.translation.width * s,
        y: cameraPosition.y + value.translation.height * s))
    }
    .onEnded { value in
      let s = scene.cameraNode?.xScale ?? 1
      cameraPosition = CGPoint(
        x: cameraPosition.x - value.translation.width * s,
        y: cameraPosition.y + value.translation.height * s)
    }
  )
```

Initialize `cameraScale` and `cameraPosition` from the scene after setup. Add to the view's `onAppear` or after scene creation in `init()`:

```swift
// After scene is created in init:
cameraScale = scene.cameraNode?.xScale ?? 1
cameraPosition = scene.cameraNode?.position ?? .zero
```

Note: since these are `@State` and the scene is created in `init`, set the initial values using `_cameraScale = State(initialValue: ...)` pattern.

- [ ] **Step 2: Apply same pattern to MCView, BCView, HeartsView**

Each view follows the same pattern: add `@State` properties, wrap `SpriteView` with gesture modifiers. The gesture code is identical across all views.

- [ ] **Step 3: Apply to LoDView**

LoDView has three `SpriteView` calls in `boardView(squareSize:)`. Apply gestures to each one. The `vassalScene` (`LoDVassalScene`) is a different scene type — `setZoom`/`setCameraPosition` methods need to exist on it too, or the gestures should only apply to the `GameScene`-based boards.

For the `.abstract` case: apply gestures to `SpriteView(scene: scene)`.
For the `.vassal` case: apply gestures to `SpriteView(scene: vScene)` — `LoDVassalScene` inherits from `SKScene`, not `GameScene`, so it needs its own camera setup. For now, only apply gestures to the abstract board; vassal board can be added later.

- [ ] **Step 4: Run swiftlint on all modified view files**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/CantStop/CantStopView.swift && /opt/homebrew/bin/swiftlint --path "DynamicalSystems/Sources/Malayan Campaign/MCView.swift" && /opt/homebrew/bin/swiftlint --path "DynamicalSystems/Sources/Battle Card/BCView.swift" && /opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Hearts/HeartsView.swift && /opt/homebrew/bin/swiftlint --path "DynamicalSystems/Sources/Legions of Darkness/LoDView.swift"`

- [ ] **Step 5: Build and run all tests**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -20`
Expected: All pass

- [ ] **Step 6: Manual test — launch app in simulator, verify zoom/pan works on at least one game**

Use the ios-simulator-skill to launch the app and navigate to a game. Pinch-zoom and drag should work on the SpriteView board area.

- [ ] **Step 7: Commit**

```bash
git add DynamicalSystems/Sources/CantStop/CantStopView.swift \
  "DynamicalSystems/Sources/Malayan Campaign/MCView.swift" \
  "DynamicalSystems/Sources/Battle Card/BCView.swift" \
  DynamicalSystems/Sources/Hearts/HeartsView.swift \
  "DynamicalSystems/Sources/Legions of Darkness/LoDView.swift"
git commit -m "feat: add pinch-zoom and drag-to-pan gestures on all game boards"
```

---

## Chunk 5: Final Verification

### Task 10: Full test suite and cleanup

- [ ] **Step 1: Run the complete test suite**

Run: `xcodebuild test -project DynamicalSystems/DynamicalSystems.xcodeproj -scheme DynamicalSystemsTests -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -only-testing:DynamicalSystemsTests 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 2: Run swiftlint on all changed framework files**

Run: `/opt/homebrew/bin/swiftlint --path DynamicalSystems/Sources/Framework/`

- [ ] **Step 3: Visual verification — launch LoD in simulator and screenshot**

Verify the board renders correctly with default appearances (should look identical to before these changes, since no game has opted in to new features yet).
