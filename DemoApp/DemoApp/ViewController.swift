import UIKit
import MelanSwift

final class ViewController: UIViewController {

    private let canvasView = CanvasView()
    private let toolbar = UIToolbar()

    // 현재 브러시 상태
    private var currentBrushType: BrushType = .pen
    private var currentColor = Color(r: 0, g: 0, b: 0, a: 1)
    private var currentWidth: Double = 2.0
    private var currentEraserMode: EraserMode = .partial

    private var isLassoActive = false

    // 하이라이트용 참조
    private var penButton: UIBarButtonItem!
    private var highlighterButton: UIBarButtonItem!
    private var eraserButton: UIBarButtonItem!
    private var lassoButton: UIBarButtonItem!
    private var lassoDeleteButton: UIBarButtonItem!
    private var lassoCopyButton: UIBarButtonItem!
    private var undoButton: UIBarButtonItem!
    private var redoButton: UIBarButtonItem!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayout()
        setupToolbar()
        setupGestures()
        applyBrush()
        updateToolbarState()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.backgroundColor = .systemBackground

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(canvasView)

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),

            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        canvasView.canvas.onStateChanged = { [weak self] in
            self?.updateToolbarState()
        }
    }

    // MARK: - Toolbar

    private func setupToolbar() {
        penButton = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain, target: self, action: #selector(penTapped))
        penButton.menu = makeWidthMenu(for: .pen)
        penButton.preferredMenuElementOrder = .fixed

        highlighterButton = UIBarButtonItem(
            image: UIImage(systemName: "highlighter"),
            style: .plain, target: self, action: #selector(highlighterTapped))
        highlighterButton.menu = makeWidthMenu(for: .highlighter)
        highlighterButton.preferredMenuElementOrder = .fixed

        eraserButton = UIBarButtonItem(
            image: UIImage(systemName: "eraser"),
            style: .plain, target: self, action: #selector(eraserTapped))
        eraserButton.menu = makeEraserMenu()
        eraserButton.preferredMenuElementOrder = .fixed

        lassoButton = UIBarButtonItem(
            image: UIImage(systemName: "lasso"),
            style: .plain, target: self, action: #selector(lassoTapped))

        lassoDeleteButton = UIBarButtonItem(
            image: UIImage(systemName: "trash.circle"),
            style: .plain, target: self, action: #selector(lassoDeleteTapped))
        lassoDeleteButton.tintColor = .systemRed

        lassoCopyButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.square.on.square"),
            style: .plain, target: self, action: #selector(lassoCopyTapped))
        lassoCopyButton.tintColor = .systemGreen

        let blackBtn = colorButton(.black, action: #selector(blackTapped))
        let redBtn = colorButton(.systemRed, action: #selector(redTapped))
        let blueBtn = colorButton(.systemBlue, action: #selector(blueTapped))

        undoButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.backward"),
            style: .plain, target: self, action: #selector(undoTapped))
        redoButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.forward"),
            style: .plain, target: self, action: #selector(redoTapped))

        let clearBtn = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain, target: self, action: #selector(clearTapped))
        clearBtn.tintColor = .systemRed

        let flex = { UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil) }
        let fix = { () -> UIBarButtonItem in
            let item = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
            item.width = 2
            return item
        }

        toolbar.items = [
            penButton, fix(), highlighterButton, fix(), eraserButton, fix(), lassoButton,
            flex(),
            blackBtn, fix(), redBtn, fix(), blueBtn,
            flex(),
            lassoDeleteButton, fix(), lassoCopyButton,
            flex(),
            undoButton, fix(), redoButton,
            flex(),
            clearBtn,
        ]
    }

    private func makeWidthMenu(for brushType: BrushType) -> UIMenu {
        let presets: [(String, Double)] = [
            ("가늘게 (1pt)", 1.0),
            ("보통 (2pt)", 2.0),
            ("굵게 (4pt)", 4.0),
            ("매우 굵게 (8pt)", 8.0),
        ]

        let actions = presets.map { (title, width) in
            UIAction(
                title: title,
                state: currentWidth == width ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                self.currentWidth = width
                self.currentBrushType = brushType
                self.applyBrush()
                self.updateToolbarState()
                self.refreshWidthMenus()
            }
        }

        return UIMenu(title: "굵기 선택", children: actions)
    }

    private func makeEraserMenu() -> UIMenu {
        let modeActions = [
            UIAction(
                title: "부분 지우개",
                image: UIImage(systemName: "eraser.line.dashed"),
                state: currentEraserMode == .partial ? .on : .off
            ) { [weak self] _ in
                self?.currentEraserMode = .partial
                self?.currentBrushType = .eraser
                self?.isLassoActive = false
                self?.canvasView.isLassoMode = false
                self?.applyBrush()
                self?.updateToolbarState()
                self?.refreshWidthMenus()
            },
            UIAction(
                title: "획 지우개",
                image: UIImage(systemName: "eraser"),
                state: currentEraserMode == .stroke ? .on : .off
            ) { [weak self] _ in
                self?.currentEraserMode = .stroke
                self?.currentBrushType = .eraser
                self?.isLassoActive = false
                self?.canvasView.isLassoMode = false
                self?.applyBrush()
                self?.updateToolbarState()
                self?.refreshWidthMenus()
            },
        ]
        let modeMenu = UIMenu(title: "지우개 모드", options: .displayInline, children: modeActions)

        let widthPresets: [(String, Double)] = [
            ("가늘게 (1pt)", 1.0),
            ("보통 (2pt)", 2.0),
            ("굵게 (4pt)", 4.0),
            ("매우 굵게 (8pt)", 8.0),
        ]
        let widthActions = widthPresets.map { (title, width) in
            UIAction(
                title: title,
                state: currentWidth == width ? .on : .off
            ) { [weak self] _ in
                guard let self else { return }
                self.currentWidth = width
                self.currentBrushType = .eraser
                self.isLassoActive = false
                self.canvasView.isLassoMode = false
                self.applyBrush()
                self.updateToolbarState()
                self.refreshWidthMenus()
            }
        }
        let widthMenu = UIMenu(title: "굵기 선택", options: .displayInline, children: widthActions)

        return UIMenu(children: [modeMenu, widthMenu])
    }

    private func refreshWidthMenus() {
        penButton.menu = makeWidthMenu(for: .pen)
        highlighterButton.menu = makeWidthMenu(for: .highlighter)
        eraserButton.menu = makeEraserMenu()
    }

    private func colorButton(_ color: UIColor, action: Selector) -> UIBarButtonItem {
        let btn = UIBarButtonItem(
            image: UIImage(systemName: "circle.fill"),
            style: .plain, target: self, action: action)
        btn.tintColor = color
        return btn
    }

    // MARK: - Gestures

    private func setupGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        canvasView.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        canvasView.addGestureRecognizer(pan)
    }

    // MARK: - Tool Actions

    @objc private func penTapped() {
        currentBrushType = .pen
        isLassoActive = false
        canvasView.isLassoMode = false
        applyBrush()
        updateToolbarState()
    }

    @objc private func highlighterTapped() {
        currentBrushType = .highlighter
        isLassoActive = false
        canvasView.isLassoMode = false
        applyBrush()
        updateToolbarState()
    }

    @objc private func eraserTapped() {
        currentBrushType = .eraser
        isLassoActive = false
        canvasView.isLassoMode = false
        applyBrush()
        updateToolbarState()
    }

    @objc private func lassoTapped() {
        isLassoActive = true
        canvasView.isLassoMode = true
        canvasView.isEraserMode = false
        updateToolbarState()
    }

    @objc private func lassoDeleteTapped() {
        canvasView.canvas.lassoDelete()
        canvasView.refreshBuffer()
    }

    @objc private func lassoCopyTapped() {
        canvasView.canvas.lassoDuplicate()
        canvasView.refreshBuffer()
    }

    // MARK: - Color Actions

    @objc private func blackTapped() {
        currentColor = Color(r: 0, g: 0, b: 0, a: 1)
        applyBrush()
    }

    @objc private func redTapped() {
        currentColor = Color(r: 0.9, g: 0.2, b: 0.2, a: 1)
        applyBrush()
    }

    @objc private func blueTapped() {
        currentColor = Color(r: 0.2, g: 0.4, b: 0.9, a: 1)
        applyBrush()
    }

    // MARK: - Edit Actions

    @objc private func undoTapped() {
        canvasView.canvas.undo()
        canvasView.refreshBuffer()
    }

    @objc private func redoTapped() {
        canvasView.canvas.redo()
        canvasView.refreshBuffer()
    }

    @objc private func clearTapped() {
        canvasView.canvas.clearAll()
        canvasView.refreshBuffer()
    }

    // MARK: - Gesture Handlers

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let center = gesture.location(in: canvasView)
        canvasView.canvas.zoom(
            factor: Double(gesture.scale),
            focalX: Double(center.x),
            focalY: Double(center.y)
        )
        canvasView.refreshBuffer()
        gesture.scale = 1.0
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let translation = gesture.translation(in: canvasView)
        canvasView.canvas.pan(
            dx: Double(translation.x),
            dy: Double(translation.y)
        )
        canvasView.refreshBuffer()
        gesture.setTranslation(.zero, in: canvasView)
    }

    // MARK: - Helpers

    private func applyBrush() {
        // 다른 도구로 전환 시 기존 선택 해제
        if canvasView.canvas.hasSelection {
            canvasView.canvas.cancelLasso()
            canvasView.refreshBuffer()
        }

        var alpha: Float = 1.0
        var width = currentWidth

        switch currentBrushType {
        case .highlighter:
            alpha = 0.3
            width = max(width * 3, 8)
        case .eraser:
            width = max(width * 3, 10)
        case .pen:
            break
        }

        let color = Color(r: currentColor.r, g: currentColor.g,
                          b: currentColor.b, a: alpha)
        let eraserMode: EraserMode = currentBrushType == .eraser ? currentEraserMode : .stroke
        let config = BrushConfig(brushType: currentBrushType,
                                 color: color, baseWidth: width,
                                 eraserMode: eraserMode)
        canvasView.canvas.setBrush(config)

        canvasView.isEraserMode = currentBrushType == .eraser
        canvasView.isLassoMode = isLassoActive
        if currentBrushType == .eraser {
            canvasView.eraserRadius = CGFloat(width / 2.0)
        }
    }

    private func updateToolbarState() {
        undoButton.isEnabled = canvasView.canvas.canUndo
        redoButton.isEnabled = canvasView.canvas.canRedo

        let active = UIColor.systemBlue
        let inactive = UIColor.gray
        penButton.tintColor = (!isLassoActive && currentBrushType == .pen) ? active : inactive
        highlighterButton.tintColor = (!isLassoActive && currentBrushType == .highlighter) ? active : inactive
        eraserButton.tintColor = (!isLassoActive && currentBrushType == .eraser) ? active : inactive
        lassoButton.tintColor = isLassoActive ? active : inactive

        lassoDeleteButton.isEnabled = canvasView.canvas.hasSelection
        lassoCopyButton.isEnabled = canvasView.canvas.hasSelection
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 필기 중에는 줌/팬 제스처 차단
        return !canvasView.isStrokeActive
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // 핀치 + 팬 동시 인식 허용
        return true
    }
}
