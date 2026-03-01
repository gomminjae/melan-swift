import UIKit
import MelanCore

final class ViewController: UIViewController {

    private let canvasView = CanvasView()
    private let toolbar = UIToolbar()

    // 현재 브러시 상태
    private var currentBrushType: BrushType = .pen
    private var currentColor = Color(r: 0, g: 0, b: 0, a: 1)
    private var currentWidth: Double = 2.0

    // 하이라이트용 참조
    private var penButton: UIBarButtonItem!
    private var highlighterButton: UIBarButtonItem!
    private var eraserButton: UIBarButtonItem!
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

        canvasView.onStateChanged = { [weak self] in
            self?.updateToolbarState()
        }
    }

    // MARK: - Toolbar

    private func setupToolbar() {
        penButton = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain, target: self, action: #selector(penTapped))
        highlighterButton = UIBarButtonItem(
            image: UIImage(systemName: "highlighter"),
            style: .plain, target: self, action: #selector(highlighterTapped))
        eraserButton = UIBarButtonItem(
            image: UIImage(systemName: "eraser"),
            style: .plain, target: self, action: #selector(eraserTapped))

        let blackBtn = colorButton(.black, action: #selector(blackTapped))
        let redBtn = colorButton(.systemRed, action: #selector(redTapped))
        let blueBtn = colorButton(.systemBlue, action: #selector(blueTapped))

        let thinBtn = UIBarButtonItem(
            image: UIImage(systemName: "minus.circle"),
            style: .plain, target: self, action: #selector(thinTapped))
        let thickBtn = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle"),
            style: .plain, target: self, action: #selector(thickTapped))

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
            penButton, fix(), highlighterButton, fix(), eraserButton,
            flex(),
            blackBtn, fix(), redBtn, fix(), blueBtn,
            flex(),
            thinBtn, fix(), thickBtn,
            flex(),
            undoButton, fix(), redoButton,
            flex(),
            clearBtn,
        ]
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
        applyBrush()
        updateToolbarState()
    }

    @objc private func highlighterTapped() {
        currentBrushType = .highlighter
        applyBrush()
        updateToolbarState()
    }

    @objc private func eraserTapped() {
        currentBrushType = .eraser
        applyBrush()
        updateToolbarState()
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

    // MARK: - Width Actions

    @objc private func thinTapped() {
        currentWidth = max(1.0, currentWidth - 1.0)
        applyBrush()
    }

    @objc private func thickTapped() {
        currentWidth = min(20.0, currentWidth + 1.0)
        applyBrush()
    }

    // MARK: - Edit Actions

    @objc private func undoTapped() {
        canvasView.applyCommands(canvasView.engine.undo())
        updateToolbarState()
    }

    @objc private func redoTapped() {
        canvasView.applyCommands(canvasView.engine.redo())
        updateToolbarState()
    }

    @objc private func clearTapped() {
        canvasView.applyCommands(canvasView.engine.clearAll())
        updateToolbarState()
    }

    // MARK: - Gesture Handlers

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let center = gesture.location(in: canvasView)
        let commands = canvasView.engine.zoom(
            factor: Double(gesture.scale),
            focalX: Double(center.x),
            focalY: Double(center.y)
        )
        canvasView.applyCommands(commands)
        gesture.scale = 1.0
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let translation = gesture.translation(in: canvasView)
        let commands = canvasView.engine.pan(
            dx: Double(translation.x),
            dy: Double(translation.y)
        )
        canvasView.applyCommands(commands)
        gesture.setTranslation(.zero, in: canvasView)
    }

    // MARK: - Helpers

    private func applyBrush() {
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
        let config = BrushConfig(brushType: currentBrushType,
                                 color: color, baseWidth: width)
        canvasView.engine.setBrush(config: config)
    }

    private func updateToolbarState() {
        let state = canvasView.engine.getState()
        undoButton.isEnabled = state.canUndo
        redoButton.isEnabled = state.canRedo

        let active = UIColor.systemBlue
        let inactive = UIColor.gray
        penButton.tintColor = currentBrushType == .pen ? active : inactive
        highlighterButton.tintColor = currentBrushType == .highlighter ? active : inactive
        eraserButton.tintColor = currentBrushType == .eraser ? active : inactive
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
