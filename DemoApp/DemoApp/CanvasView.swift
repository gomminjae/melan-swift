import UIKit
import MelanCore

final class CanvasView: UIView {

    let engine = MelanEngine.newA4()

    /// ViewController가 툴바 상태를 갱신할 수 있도록 콜백 제공
    var onStateChanged: (() -> Void)?

    private var bufferImage: UIImage?
    private(set) var isStrokeActive = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshBuffer()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        bufferImage?.draw(in: bounds)
    }

    // MARK: - Public

    /// 렌더 커맨드 실행. Clear 포함 여부에 따라 전체/증분 렌더링 결정.
    func applyCommands(_ commands: [RenderCommand]) {
        guard !commands.isEmpty else { return }

        let isFull = commands.contains {
            if case .clear = $0 { return true }
            return false
        }

        if isFull {
            renderFull(commands)
        } else {
            renderIncremental(commands)
        }

        setNeedsDisplay()
    }

    /// 엔진의 fullRender()로 버퍼를 갱신한다.
    func refreshBuffer() {
        renderFull(engine.fullRender())
        setNeedsDisplay()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        isStrokeActive = true
        let loc = touch.location(in: self)
        let commands = engine.beginStroke(
            x: Double(loc.x), y: Double(loc.y),
            pressure: pressureValue(for: touch),
            timestamp: touch.timestamp
        )
        applyCommands(commands)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, isStrokeActive else { return }

        // coalescedTouches로 보다 부드러운 입력
        let allTouches = event?.coalescedTouches(for: touch) ?? [touch]
        for t in allTouches {
            let loc = t.location(in: self)
            let commands = engine.addPoint(
                x: Double(loc.x), y: Double(loc.y),
                pressure: pressureValue(for: t),
                timestamp: t.timestamp
            )
            applyCommands(commands)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isStrokeActive else { return }
        isStrokeActive = false
        applyCommands(engine.endStroke())
        onStateChanged?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isStrokeActive else { return }
        isStrokeActive = false
        applyCommands(engine.endStroke())
        onStateChanged?()
    }

    // MARK: - Rendering (Offscreen Buffer)

    private func renderFull(_ commands: [RenderCommand]) {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        for cmd in commands {
            execute(cmd, in: ctx)
        }

        bufferImage = UIGraphicsGetImageFromCurrentImageContext()
    }

    private func renderIncremental(_ commands: [RenderCommand]) {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 기존 버퍼를 먼저 그린 뒤 증분 커맨드를 덧그림
        bufferImage?.draw(in: CGRect(origin: .zero, size: size))

        for cmd in commands {
            execute(cmd, in: ctx)
        }

        bufferImage = UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - RenderCommand → CGContext

    private func execute(_ command: RenderCommand, in ctx: CGContext) {
        switch command {
        case .clear(let r, let g, let b, let a):
            ctx.setFillColor(red: CGFloat(r), green: CGFloat(g),
                             blue: CGFloat(b), alpha: CGFloat(a))
            ctx.fill(CGRect(origin: .zero, size: bounds.size))

        case .saveState:
            ctx.saveGState()

        case .restoreState:
            ctx.restoreGState()

        case .setTransform(let scale, let translateX, let translateY):
            let t = CGAffineTransform(
                a: CGFloat(scale), b: 0,
                c: 0, d: CGFloat(scale),
                tx: CGFloat(translateX), ty: CGFloat(translateY)
            )
            ctx.concatenate(t)

        case .drawVariableWidthPath(let segments, let r, let g, let b, let a, let isEraser):
            if isEraser {
                ctx.setBlendMode(.clear)
            }

            ctx.setStrokeColor(red: CGFloat(r), green: CGFloat(g),
                               blue: CGFloat(b), alpha: CGFloat(a))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            for seg in segments {
                let width = (seg.startWidth + seg.endWidth) / 2.0
                ctx.setLineWidth(CGFloat(max(width, 0.5)))

                ctx.move(to: CGPoint(x: seg.p0X, y: seg.p0Y))
                ctx.addCurve(
                    to: CGPoint(x: seg.p3X, y: seg.p3Y),
                    control1: CGPoint(x: seg.cp1X, y: seg.cp1Y),
                    control2: CGPoint(x: seg.cp2X, y: seg.cp2Y)
                )
                ctx.strokePath()
            }

            if isEraser {
                ctx.setBlendMode(.normal)
            }
        }
    }

    // MARK: - Pressure

    private func pressureValue(for touch: UITouch) -> Double {
        guard touch.maximumPossibleForce > 0 else { return 0.5 }
        return Double(touch.force / touch.maximumPossibleForce)
    }
}
