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

```swift
import MelanCore

// 1. Create engine
let engine = MelanEngine.newA4()

// 2. Set brush
engine.setBrush(BrushConfig(
    brushType: .pen,
    color: Color(r: 0, g: 0, b: 0, a: 1),
    baseWidth: 3.0
))

// 3. Draw a stroke
let _ = engine.beginStroke(x: 100, y: 100, pressure: 0.5, timestamp: 0)
let cmds = engine.addPoint(x: 150, y: 120, pressure: 0.6, timestamp: 0.016)
let finalCmds = engine.endStroke()

// 4. Render commands with CoreGraphics
for cmd in finalCmds {
    switch cmd {
    case .clear(let r, let g, let b, let a):
        // fill background
    case .drawVariableWidthPath(let segments, let r, let g, let b, let a, let isEraser):
        // draw Bézier segments
    default:
        break
    }
}
```

## API Reference

### MelanEngine

The main engine class. Thread-safe — all methods can be called from any thread.

#### Constructors

| Method | Description |
|--------|-------------|
| `MelanEngine(canvasSize:)` | Create with custom canvas size |
| `MelanEngine.newA4()` | Create with A4 size (595×842pt) |

#### Drawing

| Method | Returns | Description |
|--------|---------|-------------|
| `setBrush(config:)` | `Void` | Set current brush |
| `beginStroke(x:y:pressure:timestamp:)` | `[RenderCommand]` | Start a new stroke |
| `addPoint(x:y:pressure:timestamp:)` | `[RenderCommand]` | Add point (incremental) |
| `endStroke()` | `[RenderCommand]` | End stroke (full re-render) |

#### Editing

| Method | Returns | Description |
|--------|---------|-------------|
| `undo()` | `[RenderCommand]` | Undo last action |
| `redo()` | `[RenderCommand]` | Redo last undone action |
| `clearAll()` | `[RenderCommand]` | Clear all strokes |

#### Viewport

| Method | Returns | Description |
|--------|---------|-------------|
| `zoom(factor:focalX:focalY:)` | `[RenderCommand]` | Pinch zoom around focal point |
| `pan(dx:dy:)` | `[RenderCommand]` | Pan canvas |
| `resetViewport()` | `[RenderCommand]` | Reset zoom & pan |

#### State & Persistence

| Method | Returns | Description |
|--------|---------|-------------|
| `fullRender()` | `[RenderCommand]` | Get full scene render commands |
| `getState()` | `EngineState` | Query engine state |
| `save(format:)` | `Data` | Serialize to JSON or Protobuf |
| `load(data:)` | `Void` | Restore from serialized data |

### Types

```swift
struct Color        { r: Float, g: Float, b: Float, a: Float }
struct CanvasSize    { width: Double, height: Double }
struct BrushConfig   { brushType: BrushType, color: Color, baseWidth: Double }
struct EngineState   { strokeCount: UInt32, canUndo: Bool, canRedo: Bool,
                       scale: Double, offsetX: Double, offsetY: Double,
                       activeLayerId: String }
struct PathSegment   { p0X, p0Y, cp1X, cp1Y, cp2X, cp2Y, p3X, p3Y,
                       startWidth, endWidth: Double }
```

### Enums

```swift
enum BrushType      { case pen, highlighter, eraser }
enum SaveFormat     { case json, protobuf }
enum MelanCoreError { case formatError(msg: String) }

enum RenderCommand {
    case clear(r:g:b:a:)
    case saveState
    case restoreState
    case setTransform(scale:translateX:translateY:)
    case drawVariableWidthPath(segments:r:g:b:a:isEraser:)
}
```

## Usage with UIKit

```swift
class DrawingView: UIView {
    let engine = MelanEngine.newA4()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pt = touch.location(in: self)
        let cmds = engine.beginStroke(
            x: Double(pt.x), y: Double(pt.y),
            pressure: Double(touch.force / touch.maximumPossibleForce),
            timestamp: event?.timestamp ?? 0
        )
        apply(cmds)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let pt = touch.location(in: self)
        let cmds = engine.addPoint(
            x: Double(pt.x), y: Double(pt.y),
            pressure: Double(touch.force / touch.maximumPossibleForce),
            timestamp: event?.timestamp ?? 0
        )
        apply(cmds)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let cmds = engine.endStroke()
        apply(cmds)
    }

    private func apply(_ commands: [RenderCommand]) {
        // Render commands to CGContext
        setNeedsDisplay()
    }
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
