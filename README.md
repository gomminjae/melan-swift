[English](README.md) | [한국어](README_KR.md)

# MelanCore

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS_15+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Swift Package for the [Melan-Core](https://github.com/gomminjae/melan-core) handwriting engine. Provides a native Swift API backed by a high-performance Rust engine via UniFFI.

## Installation

### Swift Package Manager

Add this repository in Xcode:

```
File → Add Package Dependencies → https://github.com/gomminjae/melan-swift.git
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/gomminjae/melan-swift.git", branch: "main")
]
```

## Quick Start

`MelanCanvas` is the recommended high-level API. It wraps `MelanEngine` and delivers render commands via callbacks, Combine, or AsyncStream — no manual `[RenderCommand]` handling needed.

```swift
import MelanSwift

// 1. Create canvas
let canvas = MelanCanvas.a4()

// 2. Set brush
canvas.setBrush(BrushConfig(
    brushType: .pen,
    color: Color(r: 0, g: 0, b: 0, a: 1),
    baseWidth: 3.0,
    eraserMode: .stroke
))

// 3. Receive render commands via callback
canvas.onRenderCommands = { commands in
    // Apply commands to your rendering layer (CoreGraphics, Metal, etc.)
}

// 4. Observe state changes
canvas.onStateChanged = {
    print("canUndo: \(canvas.canUndo), canRedo: \(canvas.canRedo)")
}

// 5. Draw
canvas.beginStroke(x: 100, y: 100, pressure: 0.5, timestamp: 0)
canvas.addPoint(x: 150, y: 120, pressure: 0.6, timestamp: 0.016)
canvas.endStroke()
```

## MelanCanvas API

`@MainActor` class. All mutation methods deliver `[RenderCommand]` through the configured output channels (callback / Combine / AsyncStream).

### Constructors

| Method | Description |
|--------|-------------|
| `MelanCanvas(canvasSize:)` | Create with custom canvas size |
| `MelanCanvas.a4()` | Create with A4 size (595×842pt) |

### Observable State

| Property | Type | Description |
|----------|------|-------------|
| `canUndo` | `Bool` | Whether undo is available |
| `canRedo` | `Bool` | Whether redo is available |
| `hasSelection` | `Bool` | Whether a lasso selection exists |
| `state` | `EngineState` | Full engine state snapshot |

### Drawing

| Method | Description |
|--------|-------------|
| `setBrush(_:)` | Set current brush (no commands emitted) |
| `beginStroke(x:y:pressure:timestamp:)` | Start a new stroke |
| `addPoint(x:y:pressure:timestamp:)` | Add point to current stroke |
| `endStroke()` | End current stroke |

### Editing

| Method | Description |
|--------|-------------|
| `undo()` | Undo last action |
| `redo()` | Redo last undone action |
| `clearAll()` | Clear all strokes |

### Viewport

| Method | Description |
|--------|-------------|
| `zoom(factor:focalX:focalY:)` | Pinch zoom around focal point |
| `pan(dx:dy:)` | Pan canvas |
| `resetViewport()` | Reset zoom & pan |

### Lasso Selection

| Method | Description |
|--------|-------------|
| `beginLasso(x:y:)` | Start lasso selection |
| `addLassoPoint(x:y:)` | Add point to lasso path |
| `endLasso()` | Complete lasso selection |
| `cancelLasso()` | Cancel lasso selection |
| `beginLassoDrag(x:y:)` | Start dragging selected strokes |
| `updateLassoDrag(x:y:)` | Update drag position |
| `endLassoDrag()` | End drag |
| `lassoDelete()` | Delete selected strokes |
| `lassoDuplicate()` | Duplicate selected strokes |

### Rendering & Persistence

| Method | Description |
|--------|-------------|
| `fullRender()` | Re-emit full scene (no state change) |
| `save(format:) throws -> Data` | Serialize to JSON or Protobuf |
| `load(data:) throws` | Restore from data (emits full render) |

### Output Channels

#### Callbacks

```swift
canvas.onRenderCommands = { commands in /* render */ }
canvas.onStateChanged = { /* update UI */ }
```

#### Combine

```swift
import Combine

canvas.renderPublisher
    .sink { commands in /* render */ }
    .store(in: &cancellables)

canvas.statePublisher
    .sink { state in /* update UI */ }
    .store(in: &cancellables)
```

#### AsyncStream

```swift
Task {
    for await commands in canvas.renderStream {
        // render
    }
}

Task {
    for await state in canvas.stateStream {
        // update UI
    }
}
```

## Usage with UIKit

```swift
class DrawingView: UIView {
    let canvas = MelanCanvas.a4()

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        canvas.onRenderCommands = { [weak self] commands in
            // Apply commands to CGContext
            self?.setNeedsDisplay()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pt = touch.location(in: self)
        canvas.beginStroke(
            x: Double(pt.x), y: Double(pt.y),
            pressure: Double(touch.force / touch.maximumPossibleForce),
            timestamp: event?.timestamp ?? 0
        )
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pt = touch.location(in: self)
        canvas.addPoint(
            x: Double(pt.x), y: Double(pt.y),
            pressure: Double(touch.force / touch.maximumPossibleForce),
            timestamp: event?.timestamp ?? 0
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        canvas.endStroke()
    }
}
```

## Low-Level API (MelanEngine)

For advanced use cases, you can use `MelanEngine` directly. Each method returns `[RenderCommand]` that you must process manually.

<details>
<summary>MelanEngine API Reference</summary>

### MelanEngine

Thread-safe — all methods can be called from any thread.

#### Constructors

| Method | Description |
|--------|-------------|
| `MelanEngine(canvasSize:)` | Create with custom canvas size |
| `MelanEngine.newA4()` | Create with A4 size (595×842pt) |

#### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `setBrush(config:)` | `Void` | Set current brush |
| `beginStroke(x:y:pressure:timestamp:)` | `[RenderCommand]` | Start a new stroke |
| `addPoint(x:y:pressure:timestamp:)` | `[RenderCommand]` | Add point (incremental) |
| `endStroke()` | `[RenderCommand]` | End stroke (full re-render) |
| `undo()` | `[RenderCommand]` | Undo last action |
| `redo()` | `[RenderCommand]` | Redo last undone action |
| `clearAll()` | `[RenderCommand]` | Clear all strokes |
| `zoom(factor:focalX:focalY:)` | `[RenderCommand]` | Pinch zoom |
| `pan(dx:dy:)` | `[RenderCommand]` | Pan canvas |
| `resetViewport()` | `[RenderCommand]` | Reset zoom & pan |
| `fullRender()` | `[RenderCommand]` | Full scene render commands |
| `getState()` | `EngineState` | Query engine state |
| `save(format:)` | `Data` | Serialize to JSON or Protobuf |
| `load(data:)` | `Void` | Restore from serialized data |

</details>

### Types

```swift
struct Color        { r: Float, g: Float, b: Float, a: Float }
struct CanvasSize    { width: Double, height: Double }
struct BrushConfig   { brushType: BrushType, color: Color, baseWidth: Double,
                       eraserMode: EraserMode }
struct EngineState   { strokeCount: UInt32, canUndo: Bool, canRedo: Bool,
                       scale: Double, offsetX: Double, offsetY: Double,
                       activeLayerId: String, hasSelection: Bool,
                       selectionMinX/MinY/MaxX/MaxY: Double }
struct PathSegment   { p0X, p0Y, cp1X, cp1Y, cp2X, cp2Y, p3X, p3Y,
                       startWidth, endWidth: Double }
```

### Enums

```swift
enum BrushType      { case pen, highlighter, eraser }
enum EraserMode     { case stroke, partial }
enum SaveFormat     { case json, protobuf }
enum MelanCoreError { case formatError(msg: String) }

enum RenderCommand {
    case clear(r:g:b:a:)
    case saveState
    case restoreState
    case setTransform(scale:translateX:translateY:)
    case drawVariableWidthPath(segments:r:g:b:a:isEraser:)
    case drawClosedPath(points:r:g:b:a:lineWidth:)
    case drawRect(minX:minY:maxX:maxY:r:g:b:a:lineWidth:)
}
```

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Related

- [melan-core](https://github.com/gomminjae/melan-core) — Rust engine source & build scripts

## License

MIT License - see [LICENSE](LICENSE)
