[English](README.md) | [한국어](README_KR.md)

# MelanCore

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS_15+-blue.svg)](https://developer.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

[Melan-Core](https://github.com/gomminjae/melan-core) Rust 필기 엔진의 Swift 패키지. UniFFI를 통해 고성능 Rust 엔진을 네이티브 Swift API로 제공합니다.

## 설치

### Swift Package Manager

Xcode에서 추가:

```
File → Add Package Dependencies → https://github.com/gomminjae/melan-swift.git
```

또는 `Package.swift`에 추가:

```swift
dependencies: [
    .package(url: "https://github.com/gomminjae/melan-swift.git", branch: "main")
]
```

## 빠른 시작

```swift
import MelanCore

// 1. 엔진 생성
let engine = MelanEngine.newA4()

// 2. 브러시 설정
engine.setBrush(BrushConfig(
    brushType: .pen,
    color: Color(r: 0, g: 0, b: 0, a: 1),
    baseWidth: 3.0
))

// 3. 스트로크 그리기
let _ = engine.beginStroke(x: 100, y: 100, pressure: 0.5, timestamp: 0)
let cmds = engine.addPoint(x: 150, y: 120, pressure: 0.6, timestamp: 0.016)
let finalCmds = engine.endStroke()

// 4. RenderCommand를 CoreGraphics로 렌더링
for cmd in finalCmds {
    switch cmd {
    case .clear(let r, let g, let b, let a):
        // 배경 채우기
    case .drawVariableWidthPath(let segments, let r, let g, let b, let a, let isEraser):
        // 베지어 세그먼트 그리기
    default:
        break
    }
}
```

## API 레퍼런스

### MelanEngine

메인 엔진 클래스. 스레드 세이프 — 모든 메서드를 어떤 스레드에서든 호출 가능합니다.

#### 생성자

| 메서드 | 설명 |
|--------|------|
| `MelanEngine(canvasSize:)` | 캔버스 크기 지정 생성 |
| `MelanEngine.newA4()` | A4 크기로 생성 (595×842pt) |

#### 그리기

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `setBrush(config:)` | `Void` | 현재 브러시 설정 |
| `beginStroke(x:y:pressure:timestamp:)` | `[RenderCommand]` | 새 스트로크 시작 |
| `addPoint(x:y:pressure:timestamp:)` | `[RenderCommand]` | 포인트 추가 (증분 렌더) |
| `endStroke()` | `[RenderCommand]` | 스트로크 종료 (전체 재렌더) |

#### 편집

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `undo()` | `[RenderCommand]` | 실행 취소 |
| `redo()` | `[RenderCommand]` | 다시 실행 |
| `clearAll()` | `[RenderCommand]` | 전체 삭제 |

#### 뷰포트

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `zoom(factor:focalX:focalY:)` | `[RenderCommand]` | 핀치 줌 (초점 고정) |
| `pan(dx:dy:)` | `[RenderCommand]` | 팬 이동 |
| `resetViewport()` | `[RenderCommand]` | 줌·팬 초기화 |

#### 상태 & 저장

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `fullRender()` | `[RenderCommand]` | 전체 씬 렌더 명령 |
| `getState()` | `EngineState` | 엔진 상태 조회 |
| `save(format:)` | `Data` | JSON 또는 Protobuf로 직렬화 |
| `load(data:)` | `Void` | 직렬화된 데이터에서 복원 |

### 타입

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

### 열거형

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

## UIKit 사용 예시

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
        // RenderCommand를 CGContext로 렌더링
        setNeedsDisplay()
    }
}
```

## 요구사항

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## 관련 레포

- [melan-core](https://github.com/gomminjae/melan-core) — Rust 엔진 소스 & 빌드 스크립트

## 라이선스

MIT License - [LICENSE](LICENSE) 참조
