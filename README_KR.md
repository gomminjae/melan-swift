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

`MelanCanvas`는 권장 고수준 API입니다. `MelanEngine`을 래핑하여 콜백, Combine, AsyncStream으로 렌더 커맨드를 전달합니다 — `[RenderCommand]`를 직접 처리할 필요가 없습니다.

```swift
import MelanSwift

// 1. 캔버스 생성
let canvas = MelanCanvas.a4()

// 2. 브러시 설정
canvas.setBrush(BrushConfig(
    brushType: .pen,
    color: Color(r: 0, g: 0, b: 0, a: 1),
    baseWidth: 3.0,
    eraserMode: .stroke
))

// 3. 콜백으로 렌더 커맨드 수신
canvas.onRenderCommands = { commands in
    // 렌더링 레이어에 커맨드 적용 (CoreGraphics, Metal 등)
}

// 4. 상태 변화 관찰
canvas.onStateChanged = {
    print("canUndo: \(canvas.canUndo), canRedo: \(canvas.canRedo)")
}

// 5. 그리기
canvas.beginStroke(x: 100, y: 100, pressure: 0.5, timestamp: 0)
canvas.addPoint(x: 150, y: 120, pressure: 0.6, timestamp: 0.016)
canvas.endStroke()
```

## MelanCanvas API

`@MainActor` 클래스. 모든 mutation 메서드는 설정된 출력 채널(콜백 / Combine / AsyncStream)을 통해 `[RenderCommand]`를 전달합니다.

### 생성자

| 메서드 | 설명 |
|--------|------|
| `MelanCanvas(canvasSize:)` | 캔버스 크기 지정 생성 |
| `MelanCanvas.a4()` | A4 크기로 생성 (595×842pt) |

### 관찰 가능한 상태

| 프로퍼티 | 타입 | 설명 |
|----------|------|------|
| `canUndo` | `Bool` | 실행 취소 가능 여부 |
| `canRedo` | `Bool` | 다시 실행 가능 여부 |
| `hasSelection` | `Bool` | 올가미 선택 존재 여부 |
| `state` | `EngineState` | 전체 엔진 상태 스냅샷 |

### 그리기

| 메서드 | 설명 |
|--------|------|
| `setBrush(_:)` | 현재 브러시 설정 (커맨드 미발행) |
| `beginStroke(x:y:pressure:timestamp:)` | 새 스트로크 시작 |
| `addPoint(x:y:pressure:timestamp:)` | 현재 스트로크에 포인트 추가 |
| `endStroke()` | 현재 스트로크 종료 |

### 편집

| 메서드 | 설명 |
|--------|------|
| `undo()` | 실행 취소 |
| `redo()` | 다시 실행 |
| `clearAll()` | 전체 삭제 |

### 뷰포트

| 메서드 | 설명 |
|--------|------|
| `zoom(factor:focalX:focalY:)` | 핀치 줌 (초점 고정) |
| `pan(dx:dy:)` | 팬 이동 |
| `resetViewport()` | 줌·팬 초기화 |

### 올가미 선택

| 메서드 | 설명 |
|--------|------|
| `beginLasso(x:y:)` | 올가미 선택 시작 |
| `addLassoPoint(x:y:)` | 올가미 경로에 포인트 추가 |
| `endLasso()` | 올가미 선택 완료 |
| `cancelLasso()` | 올가미 선택 취소 |
| `beginLassoDrag(x:y:)` | 선택된 스트로크 드래그 시작 |
| `updateLassoDrag(x:y:)` | 드래그 위치 갱신 |
| `endLassoDrag()` | 드래그 종료 |
| `lassoDelete()` | 선택된 스트로크 삭제 |
| `lassoDuplicate()` | 선택된 스트로크 복제 |

### 렌더링 & 저장

| 메서드 | 설명 |
|--------|------|
| `fullRender()` | 전체 씬 재발행 (상태 변경 없음) |
| `save(format:) throws -> Data` | JSON 또는 Protobuf로 직렬화 |
| `load(data:) throws` | 데이터에서 복원 (전체 렌더 발행) |

### 출력 채널

#### 콜백

```swift
canvas.onRenderCommands = { commands in /* 렌더링 */ }
canvas.onStateChanged = { /* UI 갱신 */ }
```

#### Combine

```swift
import Combine

canvas.renderPublisher
    .sink { commands in /* 렌더링 */ }
    .store(in: &cancellables)

canvas.statePublisher
    .sink { state in /* UI 갱신 */ }
    .store(in: &cancellables)
```

#### AsyncStream

```swift
Task {
    for await commands in canvas.renderStream {
        // 렌더링
    }
}

Task {
    for await state in canvas.stateStream {
        // UI 갱신
    }
}
```

## UIKit 사용 예시

```swift
class DrawingView: UIView {
    let canvas = MelanCanvas.a4()

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)
        canvas.onRenderCommands = { [weak self] commands in
            // CoreGraphics로 커맨드 적용
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

## 저수준 API (MelanEngine)

고급 사용 사례를 위해 `MelanEngine`을 직접 사용할 수 있습니다. 각 메서드가 `[RenderCommand]`를 반환하며 직접 처리해야 합니다.

<details>
<summary>MelanEngine API 레퍼런스</summary>

### MelanEngine

스레드 세이프 — 모든 메서드를 어떤 스레드에서든 호출 가능합니다.

#### 생성자

| 메서드 | 설명 |
|--------|------|
| `MelanEngine(canvasSize:)` | 캔버스 크기 지정 생성 |
| `MelanEngine.newA4()` | A4 크기로 생성 (595×842pt) |

#### 메서드

| 메서드 | 반환 | 설명 |
|--------|------|------|
| `setBrush(config:)` | `Void` | 현재 브러시 설정 |
| `beginStroke(x:y:pressure:timestamp:)` | `[RenderCommand]` | 새 스트로크 시작 |
| `addPoint(x:y:pressure:timestamp:)` | `[RenderCommand]` | 포인트 추가 (증분 렌더) |
| `endStroke()` | `[RenderCommand]` | 스트로크 종료 (전체 재렌더) |
| `undo()` | `[RenderCommand]` | 실행 취소 |
| `redo()` | `[RenderCommand]` | 다시 실행 |
| `clearAll()` | `[RenderCommand]` | 전체 삭제 |
| `zoom(factor:focalX:focalY:)` | `[RenderCommand]` | 핀치 줌 |
| `pan(dx:dy:)` | `[RenderCommand]` | 팬 이동 |
| `resetViewport()` | `[RenderCommand]` | 줌·팬 초기화 |
| `fullRender()` | `[RenderCommand]` | 전체 씬 렌더 커맨드 |
| `getState()` | `EngineState` | 엔진 상태 조회 |
| `save(format:)` | `Data` | JSON 또는 Protobuf로 직렬화 |
| `load(data:)` | `Void` | 직렬화된 데이터에서 복원 |

</details>

### 타입

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

### 열거형

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

## 요구사항

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## 관련 레포

- [melan-core](https://github.com/gomminjae/melan-core) — Rust 엔진 소스 & 빌드 스크립트

## 라이선스

MIT License - [LICENSE](LICENSE) 참조
