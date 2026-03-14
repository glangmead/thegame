# Rendering Improvements — Design Spec

**Date:** 2026-03-14
**Scope:** Four independent changes to the generic SpriteKit Site/Piece rendering system in `DynamicalSystems/Sources/Framework/`.

## Overview

The current rendering system produces unreadable output for complex games like Legions of Darkness: everything is tiny, regions blur together, pieces overflow their cells, and there's no zoom. These four changes address the problems in dependency order.

**Implementation order:** 1 → 2 → 3, 4 (3 and 4 are independent)

## 1. SiteAppearance — Tag-to-Visual Mapping

### Problem

`GameScene.buildBoardSites` has hardcoded if/else checks for three tag names ("header", "invisible", "crown"). Adding new visual behaviors requires editing GameScene. Tags compose (sites have `Set<String>`) but the visual system doesn't — each tag needs its own code branch.

### Design

**New types in `SceneConfig.swift`:**

```swift
struct SiteAppearance: Codable, Equatable {
  var fill: String?
  var stroke: String?
  var lineWidth: CGFloat?
  var cornerRadius: CGFloat?
  var padding: CGFloat?          // used by track bounding rects; ignored for individual sites
  var shape: SiteShape?
  var labelStyle: LabelAppearance?
  var shadow: ShadowAppearance?
}

enum SiteShape: Codable, Equatable {
  case rect
  case label
  case none
}

enum FontWeight: String, Codable, Equatable {
  case regular, bold, semibold, light, medium, heavy
  var uiWeight: UIFont.Weight {
    switch self {
    case .regular: .regular  case .bold: .bold  case .semibold: .semibold
    case .light: .light  case .medium: .medium  case .heavy: .heavy
    }
  }
}

enum LabelAlignment: String, Codable, Equatable {
  case center, top, left, right
}

struct LabelAppearance: Codable, Equatable {
  var size: CGFloat?
  var weight: FontWeight?
  var color: String?
  var alignment: LabelAlignment?

  /// Merge non-nil fields from `other` on top of `self`.
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

  /// Merge: `other` wins entirely (shadows don't partial-merge well).
  func merging(with other: ShadowAppearance) -> ShadowAppearance {
    other
  }
}
```

**Appearance table on GameScene:**

```swift
class GameScene<State, Action> {
  let appearances: [String: SiteAppearance]
  // ...
}
```

Passed at init, defaulting to:

```swift
static let defaultAppearances: [String: SiteAppearance] = [
  "header":    SiteAppearance(shape: .label,
                 labelStyle: LabelAppearance(size: 0.4, weight: .bold, color: "darkgray")),
  "invisible": SiteAppearance(shape: .none),
  "crown":     SiteAppearance(fill: "yellow", lineWidth: 2,
                 labelStyle: LabelAppearance(size: 0.5, weight: .bold, color: "black",
                                             alignment: .center)),
]
```

Games merge custom entries on top of defaults.

**Composition rule:** For a site with tags `["crown", "dropShadow"]`, iterate tags in sorted order, look up each in the appearance table, merge — each non-nil property overwrites the previous value.

**Resolution method on GameScene:**

```swift
func resolveAppearance(for tags: Set<String>) -> SiteAppearance {
  var resolved = SiteAppearance()
  for tag in tags.sorted() {
    guard let appearance = appearances[tag] else { continue }
    // merge scalar properties: non-nil overwrites
    if let v = appearance.fill { resolved.fill = v }
    if let v = appearance.stroke { resolved.stroke = v }
    if let v = appearance.lineWidth { resolved.lineWidth = v }
    if let v = appearance.cornerRadius { resolved.cornerRadius = v }
    if let v = appearance.padding { resolved.padding = v }
    if let v = appearance.shape { resolved.shape = v }
    // merge nested structs field-by-field
    if let v = appearance.labelStyle {
      resolved.labelStyle = resolved.labelStyle?.merging(with: v) ?? v
    }
    if let v = appearance.shadow {
      resolved.shadow = resolved.shadow?.merging(with: v) ?? v
    }
  }
  return resolved
}
```

**Changes to `buildBoardSites`:** The if/else chain for "header", "invisible", "crown" is replaced by:

1. Call `resolveAppearance(for: site.tags)` to get merged appearance
2. If `resolved.shape == .none` → create empty `SKNode` (invisible)
3. If `resolved.shape == .label` → create `SKLabelNode` using `resolved.labelStyle`
4. Otherwise → create `SKShapeNode(rect:cornerRadius:)` using resolved fill/stroke/lineWidth
5. If `resolved.shadow` is non-nil → add shadow via `SKEffectNode` or manual shadow shape
6. The board-level `StyleConfig` provides fallback values for sites with no tag matches

**baseFillColors:** After resolving the appearance and creating the shape node, if `resolved.fill` is non-nil, store `colorFromString(resolved.fill)` in `baseFillColors[siteID]`. This preserves the highlight/restore mechanism in `updateSiteHighlights`.

**colorFromString:** Extend to handle all color names used in appearances. Add at minimum: `"darkgray"`, `"steelblue"`, `"burlywood"`, `"saddlebrown"`. Consider also supporting hex strings (e.g. `"#8B4513"`) for arbitrary colors.

**Changes to existing code:**
- `GameScene.init` — new `appearances:` parameter with default value
- `buildBoardSites` — rewritten to use resolved appearances; stores resolved fill in `baseFillColors`
- `colorFromString` — extended with new color names
- `SceneConfig.swift` — new types added (SiteAppearance, SiteShape, FontWeight, LabelAlignment, LabelAppearance, ShadowAppearance)
- Existing games — no changes needed; default appearances replicate current behavior exactly

### Shadow rendering note

SpriteKit has no built-in drop shadow on `SKShapeNode`. Two options:
- **`SKEffectNode` with CIFilter** — wrap the shape in an effect node with a Gaussian blur. Correct but can hurt performance if overused.
- **Manual shadow shape** — draw a second `SKShapeNode` offset and blurred beneath the main one. Cheaper, less accurate.

Start with manual shadow shape. Switch to `SKEffectNode` only if the visual quality is insufficient.

## 2. Track Backgrounds — Visual Grouping via Track Tags

### Problem

Tracks (east army track, time track, card area, etc.) have no visual boundary. All sites render identically regardless of which logical region they belong to. The board reads as a flat spreadsheet.

### Design

**New field on SiteGraph:**

```swift
struct SiteGraph {
  var sites: [SiteID: Site] = [:]
  var tracks: [String: [SiteID]] = [:]
  var trackTags: [String: Set<String>] = [:]  // new
  // ...
}
```

**Convenience method:**

```swift
mutating func addTrack(_ name: String, sites: [SiteID], tags: Set<String> = []) {
  tracks[name] = sites
  if !tags.isEmpty { trackTags[name] = tags }
}
```

**Rendering in GameScene — new `buildTrackBackgrounds` method:**

Called before `buildBoardSites`, adds background shapes at `zPosition = -1`:

1. For each track in `model.graph.trackTags`, look up the track's tags in the `appearances` table using the same `resolveAppearance(for:)` method
2. Compute bounding rect: union of all member sites' frames (position + cellSize)
3. Inflate by `resolved.padding ?? 4` on each side
4. Create `SKShapeNode(rect:cornerRadius:)` with resolved fill/stroke/shadow
5. Add to board node at `zPosition = -1`

**Uses SiteAppearance, not a separate type.** The `padding` field on SiteAppearance is primarily for track backgrounds (inflating the bounding rect). For individual sites, `padding` is ignored.

**Example usage in a graph builder:**

```swift
graph.addTrack("east", sites: eastSites, tags: ["trackBg"])
// ...
let appearances = [
  "trackBg": SiteAppearance(fill: "steelblue", cornerRadius: 6, padding: 4),
]
```

Result: a rounded blue rectangle drawn behind the east track's gray cells.

**Limitation:** Bounding rect is axis-aligned. L-shaped or non-convex track layouts will get an enclosing rectangle that may cover unrelated sites. All current tracks are linear, so this is not a problem in practice.

## 3. Stacking Policy — Piece Overflow Handling

### Problem

When multiple pieces share a site, `stackingOffset` fans them horizontally. At 3+ pieces with small cell sizes, pieces overflow into adjacent cells and become unreadable.

### Design

**New enum:**

```swift
enum StackPolicy: Codable, Equatable {
  case fan       // current behavior: horizontal spread
  case vertical  // stack upward with slight offset
  case badge     // show topmost piece + count label
}
```

**Configured on SceneConfig's piece case:**

```swift
case piece(PieceShape, color: ColorRule, stacking: StackPolicy = .fan)
```

Default `.fan` preserves current behavior. Per-piece-kind: tokens might fan while cards keep their existing layout.

**Codable note:** Adding `stacking:` to `.piece`'s associated values changes the auto-synthesized `Codable` encoding. `SceneConfig` conforms to `Codable` but is never persisted — all values are constructed in code. A custom `init(from:)` that defaults `stacking` to `.fan` when the key is absent would be defensive; alternatively, accept the wire-format break since nothing depends on it.

**Stored in PieceLayout:**

```swift
struct PieceLayout {
  let parent: SKNode
  let scale: CGFloat
  let stacking: StackPolicy  // new
}
```

**Changes to `stackingOffset`:**

Gains a `policy` parameter and dispatches:

- `.fan` — current code unchanged (horizontal spread, `cellSize * 0.7` spacing)
- `.vertical` — same math but offset in y instead of x, tighter spacing (`cellSize * 0.3`) so pieces visibly overlap vertically
- `.badge` — returns `.zero` for the last piece in the group (centered). For all other pieces, returns an offscreen position or they are hidden.

**Changes to `syncPieces` for `.badge`:**

When stacking policy is `.badge` and a site has N > 1 pieces:
- Only the last piece in the group is visible (alpha = 1)
- Other pieces get alpha = 0
- A badge `SKShapeNode` (red circle) with `SKLabelNode` (white count text) is lazily created and attached to the visible piece node. Sized at `cellSize * 0.3`, positioned at top-right of the piece.
- When count drops to 1, badge is removed.

**Changes to existing code:**
- `SceneConfig.piece` — new `stacking:` parameter with default
- `GameScene.buildScene` — stores stacking policy in `PieceLayout`
- `stackingOffset` — dispatches on policy
- `syncPieces` — handles badge visibility logic
- Existing games — no changes needed (default `.fan` matches current behavior)

## 4. Camera — Zoom and Pan

### Problem

The entire game board is rendered at a fixed scale. Complex games like LoD are unreadably small on iPad. There's no way to zoom in on a region of interest.

### Design

**Camera setup in GameScene:**

```swift
var cameraNode: SKCameraNode?
private var minScale: CGFloat = 0.3   // max zoom in
private var maxScale: CGFloat = 3.0   // max zoom out

func setupCamera() {
  let cam = SKCameraNode()
  addChild(cam)
  camera = cam
  cameraNode = cam
  zoomToFit()
}

/// Compute board bounds from siteNodes (not calculateAccumulatedFrame,
/// which would include the camera node and any non-board children).
func boardBounds() -> CGRect {
  guard !siteNodes.isEmpty else { return .zero }
  var rect = CGRect.null
  for (_, node) in siteNodes {
    let frame = CGRect(origin: node.position,
                       size: CGSize(width: cellSize, height: cellSize))
    rect = rect.union(frame)
  }
  return rect
}

func zoomToFit() {
  guard let cam = cameraNode else { return }
  let bounds = boardBounds()
  guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return }
  let scaleX = size.width / bounds.width
  let scaleY = size.height / bounds.height
  let fitScale = min(scaleX, scaleY) * 0.9  // 10% margin
  cam.setScale(1 / fitScale)
  cam.position = CGPoint(x: bounds.midX, y: bounds.midY)
}

/// Set camera scale absolutely (not as a delta). Called with the
/// cumulative magnification from MagnifyGesture relative to startScale.
func setZoom(scale: CGFloat) {
  guard let cam = cameraNode else { return }
  cam.setScale(max(minScale, min(maxScale, scale)))
}

/// Set camera position absolutely. Called with cumulative translation
/// from DragGesture applied to startPosition.
func setCameraPosition(_ position: CGPoint) {
  cameraNode?.position = position
}
```

**SwiftUI gesture handling:**

Gestures are attached to the `SpriteView` in the SwiftUI view layer. Both `MagnifyGesture` and `DragGesture` report **cumulative** values (not per-frame deltas), so we store the starting state and apply the cumulative value to it.

```swift
// State in the SwiftUI view
@State private var cameraScale: CGFloat = 1.0
@State private var cameraPosition: CGPoint = .zero

// ...

SpriteView(scene: scene)
  .gesture(MagnifyGesture()
    .onChanged { value in
      // value.magnification is cumulative (starts at 1.0)
      // Divide startScale by magnification: pinch-out (magnification > 1) zooms in
      let newScale = cameraScale / value.magnification
      scene.setZoom(scale: newScale)
    }
    .onEnded { value in
      cameraScale = cameraScale / value.magnification
    }
  )
  .gesture(DragGesture()
    .onChanged { value in
      // value.translation is cumulative from gesture start
      let currentScale = scene.cameraNode?.xScale ?? 1
      scene.setCameraPosition(CGPoint(
        x: cameraPosition.x - value.translation.width * currentScale,
        y: cameraPosition.y + value.translation.height * currentScale
      ))
    }
    .onEnded { value in
      let currentScale = scene.cameraNode?.xScale ?? 1
      cameraPosition = CGPoint(
        x: cameraPosition.x - value.translation.width * currentScale,
        y: cameraPosition.y + value.translation.height * currentScale
      )
    }
  )
```

This follows the pattern from the referenced SO answer — capture gestures at the SwiftUI level, call scene methods. No `@objc`, no `UIGestureRecognizerDelegate`.

**`setupCamera()` is called at the end of `GameScene.init`**, after `buildScene` completes. The `boardBounds()` method computes bounds from `siteNodes` directly rather than `calculateAccumulatedFrame()`, avoiding inclusion of the camera node itself.

**Changes to existing code:**
- `GameScene` — new properties (`cameraNode`, scale bounds), new methods (`setupCamera`, `zoomToFit`, `zoom`, `pan`)
- `GameScene.init` — calls `setupCamera()` at end
- Each game's SwiftUI view — adds `.gesture()` modifiers on `SpriteView`
- No changes to any game logic or scene config

### Interaction notes

**Touch handling:** `GameScene` currently has no `touchesBegan`/`touchesMoved` overrides. All game interaction goes through SwiftUI action buttons, so there is no touch conflict with SwiftUI gestures. If SpriteKit touch handling is added later, the gesture approach may need to move to UIKit gesture recognizers via `didMove(to:)` to avoid conflicts.

**Scroll interaction:** In game views where the `SpriteView` sits alongside a scrollable `List` (action list, log), the `DragGesture` on the `SpriteView` will intercept drags that start on the board. This is the desired behavior — dragging the board pans, the list scrolls separately. Test on device to confirm no conflicts with `SpriteView`'s internal touch responder chain.

## Files Changed

| File | Changes |
|------|---------|
| `Framework/SceneConfig.swift` | Add SiteAppearance, SiteShape, LabelAppearance, ShadowAppearance. Add `stacking:` to `.piece` case. |
| `Framework/SiteGraph.swift` | Add `trackTags` field, `addTrack` convenience method. |
| `Framework/GameScene.swift` | Add `appearances` table, `resolveAppearance`, rewrite `buildBoardSites`, add `buildTrackBackgrounds`, add camera setup/methods. |
| `Framework/GameSceneSync.swift` | Update `stackingOffset` for policy dispatch, update `syncPieces` for badge logic. |
| Game views (LoDView, etc.) | Add `.gesture()` modifiers for zoom/pan. |
| Game scene configs | No changes required (defaults preserve current behavior). |

## Migration

All changes are backward-compatible. Existing games compile and render identically without modification. New visual features are opt-in via appearance tables, track tags, stacking policy, and gesture modifiers.

## Out of Scope

- Container axis/spacing/auto-layout (not needed; visual grouping achieved via track backgrounds)
- Texture fills (solid colors only; can be added later by extending `fill` to accept image names)
- Hex or circular site shapes (can be added to `SiteShape` later)
- Constraint-based layout
- Multi-board composition (single SiteGraph per scene)
