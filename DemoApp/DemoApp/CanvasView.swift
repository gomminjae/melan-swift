import UIKit
import MelanSwift

final class CanvasView: UIView {

    let canvas = MelanCanvas.a4()

    /// canvas 메서드 호출 시 동기적으로 캡처되는 렌더 커맨드
    private var _lastCommands: [RenderCommand] = []

    // committed: 완성된 획들의 래스터 스냅샷 (fullRender)
    // live: 진행 중인 획의 세그먼트 (addPoint에서 누적)
    private var committedImage: UIImage?
    private var liveSegments: [PathSegment] = []
    private var liveColor: (r: Float, g: Float, b: Float, a: Float) = (0, 0, 0, 1)

    private var displayImage: UIImage?
    private(set) var isStrokeActive = false

    // 올가미 모드
    var isLassoMode = false
    private var isLassoDragging = false

    // 지우개 커서 피드백
    var isEraserMode = false
    var eraserRadius: CGFloat = 15
    private var eraserPosition: CGPoint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isMultipleTouchEnabled = false

        canvas.onRenderCommands = { [weak self] commands in
            self?._lastCommands = commands
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshBuffer()
    }

    override func draw(_ rect: CGRect) {
        displayImage?.draw(in: bounds)
    }

    // MARK: - Public (ViewController에서 호출)

    /// 완성된 획 전체를 다시 렌더하고 화면에 반영한다.
    /// undo / redo / clear / zoom / pan 후 호출.
    func refreshBuffer() {
        renderCommitted()
        displayImage = committedImage
        setNeedsDisplay()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if isLassoMode {
            handleLassoBegan(at: loc)
            return
        }

        isStrokeActive = true
        renderCommitted()
        liveSegments = []

        if isEraserMode {
            eraserPosition = loc
        }

        canvas.beginStroke(
            x: Double(loc.x), y: Double(loc.y),
            pressure: pressureValue(for: touch),
            timestamp: touch.timestamp
        )
        compositeAndDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)

        if isLassoMode {
            guard isStrokeActive else { return }
            handleLassoMoved(at: loc)
            return
        }

        guard isStrokeActive else { return }
        let allTouches = event?.coalescedTouches(for: touch) ?? [touch]
        for t in allTouches {
            let tLoc = t.location(in: self)
            canvas.addPoint(
                x: Double(tLoc.x), y: Double(tLoc.y),
                pressure: pressureValue(for: t),
                timestamp: t.timestamp
            )
            if isEraserMode && !_lastCommands.isEmpty {
                // Partial eraser: engine returns full_render → re-render committed
                renderCommitted()
            } else {
                accumulateLive(from: _lastCommands)
            }
        }

        if isEraserMode {
            eraserPosition = loc
        }

        compositeAndDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isLassoMode {
            guard isStrokeActive else { return }
            handleLassoEnded()
            return
        }

        guard isStrokeActive else { return }
        isStrokeActive = false
        eraserPosition = nil
        canvas.endStroke()
        liveSegments = []
        refreshBuffer()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isLassoMode {
            guard isStrokeActive else { return }
            handleLassoEnded()
            return
        }

        guard isStrokeActive else { return }
        isStrokeActive = false
        eraserPosition = nil
        canvas.endStroke()
        liveSegments = []
        refreshBuffer()
    }

    // MARK: - Lasso Touch

    private func handleLassoBegan(at loc: CGPoint) {
        isStrokeActive = true

        if canvas.hasSelection {
            let selRect = selectionScreenRect()
            if selRect.insetBy(dx: -20, dy: -20).contains(loc) {
                isLassoDragging = true
                canvas.beginLassoDrag(x: Double(loc.x), y: Double(loc.y))
                refreshBuffer()
            } else {
                canvas.cancelLasso()
                canvas.beginLasso(x: Double(loc.x), y: Double(loc.y))
                refreshBuffer()
            }
        } else {
            canvas.beginLasso(x: Double(loc.x), y: Double(loc.y))
            refreshBuffer()
        }
    }

    private func handleLassoMoved(at loc: CGPoint) {
        if isLassoDragging {
            canvas.updateLassoDrag(x: Double(loc.x), y: Double(loc.y))
        } else {
            canvas.addLassoPoint(x: Double(loc.x), y: Double(loc.y))
        }
        refreshBuffer()
    }

    private func handleLassoEnded() {
        isStrokeActive = false
        if isLassoDragging {
            isLassoDragging = false
            canvas.endLassoDrag()
        } else {
            canvas.endLasso()
        }
        refreshBuffer()
    }

    private func selectionScreenRect() -> CGRect {
        let s = canvas.state
        let minX = s.selectionMinX * s.scale + s.offsetX
        let minY = s.selectionMinY * s.scale + s.offsetY
        let maxX = s.selectionMaxX * s.scale + s.offsetX
        let maxY = s.selectionMaxY * s.scale + s.offsetY
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // MARK: - Committed Render (완성된 획 전체)

    private func renderCommitted() {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        canvas.fullRender()
        for cmd in _lastCommands {
            execute(cmd, in: ctx)
        }

        committedImage = UIGraphicsGetImageFromCurrentImageContext()
    }

    // MARK: - Composite (committed + live → display)

    private func compositeAndDisplay() {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // 1) 완성된 획 배경
        committedImage?.draw(in: CGRect(origin: .zero, size: size))

        // 2) 진행 중 획을 뷰포트 변환 적용해서 덧그림
        if !liveSegments.isEmpty {
            let state = canvas.state

            ctx.saveGState()
            ctx.concatenate(CGAffineTransform(
                a: CGFloat(state.scale), b: 0,
                c: 0, d: CGFloat(state.scale),
                tx: CGFloat(state.offsetX), ty: CGFloat(state.offsetY)
            ))

            let useLiveTransparency = liveColor.a < 1.0

            if useLiveTransparency {
                ctx.setAlpha(CGFloat(liveColor.a))
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                ctx.setStrokeColor(red: CGFloat(liveColor.r), green: CGFloat(liveColor.g),
                                   blue: CGFloat(liveColor.b), alpha: 1.0)
            } else {
                ctx.setStrokeColor(red: CGFloat(liveColor.r), green: CGFloat(liveColor.g),
                                   blue: CGFloat(liveColor.b), alpha: CGFloat(liveColor.a))
            }

            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            for seg in liveSegments {
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

            if useLiveTransparency {
                ctx.endTransparencyLayer()
            }

            ctx.restoreGState()
        }

        // 3) 지우개 커서 오버레이
        if let pos = eraserPosition {
            let cursorRect = CGRect(
                x: pos.x - eraserRadius,
                y: pos.y - eraserRadius,
                width: eraserRadius * 2,
                height: eraserRadius * 2
            )
            ctx.setFillColor(UIColor.gray.withAlphaComponent(0.15).cgColor)
            ctx.fillEllipse(in: cursorRect)
            ctx.setStrokeColor(UIColor.gray.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(1.0)
            ctx.strokeEllipse(in: cursorRect)
        }

        displayImage = UIGraphicsGetImageFromCurrentImageContext()
        setNeedsDisplay()
    }

    // MARK: - Live Segment 누적
    //
    // 엔진 패턴:
    //   n=2 → 1 segment 반환 (직선)        → append
    //   n≥3 → 2 segments 반환 (교체 + 새것) → replace last + append
    // 이렇게 하면 교체된 Catmull-Rom 곡선이 항상 최신 상태로 유지된다.

    private func accumulateLive(from commands: [RenderCommand]) {
        for cmd in commands {
            guard case .drawVariableWidthPath(let segments, let r, let g, let b, let a, _) = cmd else {
                continue
            }
            liveColor = (r, g, b, a)

            if segments.count == 1 {
                liveSegments.append(segments[0])
            } else if segments.count >= 2 {
                // segments[0] = 이전 마지막 세그먼트의 교체본 (Catmull-Rom)
                // segments[1] = 새로운 trailing 세그먼트
                if !liveSegments.isEmpty {
                    liveSegments[liveSegments.count - 1] = segments[0]
                } else {
                    liveSegments.append(segments[0])
                }
                liveSegments.append(segments[1])
            }
        }
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
            ctx.concatenate(CGAffineTransform(
                a: CGFloat(scale), b: 0,
                c: 0, d: CGFloat(scale),
                tx: CGFloat(translateX), ty: CGFloat(translateY)
            ))

        case .drawVariableWidthPath(let segments, let r, let g, let b, let a, let isEraser):
            if isEraser {
                ctx.setBlendMode(.clear)
            }

            let useTransparencyLayer = a < 1.0 && !isEraser

            if useTransparencyLayer {
                ctx.saveGState()
                ctx.setAlpha(CGFloat(a))
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                ctx.setStrokeColor(red: CGFloat(r), green: CGFloat(g),
                                   blue: CGFloat(b), alpha: 1.0)
            } else {
                ctx.setStrokeColor(red: CGFloat(r), green: CGFloat(g),
                                   blue: CGFloat(b), alpha: CGFloat(a))
            }

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

            if useTransparencyLayer {
                ctx.endTransparencyLayer()
                ctx.restoreGState()
            }

            if isEraser {
                ctx.setBlendMode(.normal)
            }

        case .drawClosedPath(let points, let r, let g, let b, let a, let lineWidth):
            guard points.count >= 2 else { break }
            ctx.setStrokeColor(red: CGFloat(r), green: CGFloat(g),
                               blue: CGFloat(b), alpha: CGFloat(a))
            ctx.setLineWidth(CGFloat(lineWidth))
            ctx.setLineDash(phase: 0, lengths: [5, 3])
            ctx.move(to: CGPoint(x: points[0].x, y: points[0].y))
            for i in 1..<points.count {
                ctx.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
            }
            ctx.closePath()
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])

        case .drawRect(let minX, let minY, let maxX, let maxY, let r, let g, let b, let a, let lineWidth):
            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            ctx.setStrokeColor(red: CGFloat(r), green: CGFloat(g),
                               blue: CGFloat(b), alpha: CGFloat(a))
            ctx.setLineWidth(CGFloat(lineWidth))
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            ctx.stroke(rect)
            ctx.setLineDash(phase: 0, lengths: [])
        }
    }

    // MARK: - Pressure

    private func pressureValue(for touch: UITouch) -> Double {
        guard touch.maximumPossibleForce > 0 else { return 0.5 }
        return Double(touch.force / touch.maximumPossibleForce)
    }
}
