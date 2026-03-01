# MelanCore Demo App

UIKit demo app for the MelanCore handwriting engine.

## Setup

Since Xcode project files (`.xcodeproj`) are binary and not git-friendly, only Swift source files are provided. Follow these steps to create the Xcode project and run the demo.

### 1. Create Xcode Project

1. **Xcode > File > New > Project**
2. Select **App** (iOS)
3. Interface: **Storyboard**, Language: **Swift**, Life Cycle: **UIKit App Delegate**
4. Save anywhere (e.g., `MelanDemo/`)

### 2. Remove Storyboard

1. Delete `Main.storyboard` from the project navigator
2. Open **Info.plist** (or target > Info):
   - Delete `Main storyboard file base name` key
   - Under `Application Scene Manifest > Scene Configuration > Window Application Session Role > Item 0`, delete `Storyboard Name`

### 3. Add Source Files

1. Drag all 4 Swift files from this `Demo/` folder into your Xcode project:
   - `AppDelegate.swift` (replace existing)
   - `SceneDelegate.swift` (replace existing)
   - `ViewController.swift` (replace existing)
   - `CanvasView.swift`
2. Make sure **Copy items if needed** is checked

### 4. Add MelanCore Package

1. **File > Add Package Dependencies...**
2. Choose **Add Local...** and select the `melan-swift/` directory (parent of this Demo folder)
3. Add `MelanCore` library to your app target

### 5. Run

1. Select an iOS Simulator (or device)
2. **Cmd+R** to build and run
3. Draw with your finger or Apple Pencil

## Features

- Pen / Highlighter / Eraser tools
- Color selection (black, red, blue)
- Stroke width (thin / thick)
- Undo / Redo
- Clear all
- Pinch to zoom
- Two-finger pan

---

# MelanCore 데모 앱

MelanCore 필기 엔진의 UIKit 데모 앱입니다.

## 설정 방법

Xcode 프로젝트 파일(`.xcodeproj`)은 바이너리라 git에 적합하지 않아 Swift 소스 파일만 제공합니다. 아래 절차에 따라 Xcode 프로젝트를 생성하고 데모를 실행하세요.

### 1. Xcode 프로젝트 생성

1. **Xcode > File > New > Project**
2. **App** (iOS) 선택
3. Interface: **Storyboard**, Language: **Swift**, Life Cycle: **UIKit App Delegate**
4. 원하는 위치에 저장 (예: `MelanDemo/`)

### 2. Storyboard 제거

1. 프로젝트 네비게이터에서 `Main.storyboard` 삭제
2. **Info.plist** (또는 타겟 > Info)에서:
   - `Main storyboard file base name` 키 삭제
   - `Application Scene Manifest > Scene Configuration > Window Application Session Role > Item 0` 아래 `Storyboard Name` 삭제

### 3. 소스 파일 추가

1. 이 `Demo/` 폴더의 Swift 파일 4개를 Xcode 프로젝트에 드래그:
   - `AppDelegate.swift` (기존 파일 교체)
   - `SceneDelegate.swift` (기존 파일 교체)
   - `ViewController.swift` (기존 파일 교체)
   - `CanvasView.swift`
2. **Copy items if needed** 체크 확인

### 4. MelanCore 패키지 추가

1. **File > Add Package Dependencies...**
2. **Add Local...** 선택 후 `melan-swift/` 디렉토리 (이 Demo 폴더의 상위) 선택
3. `MelanCore` 라이브러리를 앱 타겟에 추가

### 5. 실행

1. iOS 시뮬레이터 (또는 기기) 선택
2. **Cmd+R**로 빌드 및 실행
3. 손가락 또는 Apple Pencil로 필기
