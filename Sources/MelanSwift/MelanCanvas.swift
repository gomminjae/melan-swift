import Foundation

/// High-level SDK wrapper around `MelanEngine`.
///
/// All mutation methods deliver `[RenderCommand]` via callbacks / Publisher / AsyncStream
/// instead of returning them directly, so callers never need to handle return values.
@MainActor
public final class MelanCanvas {

    // MARK: - Private engine

    private let engine: MelanEngine

    // MARK: - Callbacks

    /// Called whenever new render commands are produced.
    public var onRenderCommands: (([RenderCommand]) -> Void)?

    /// Called whenever engine state changes (undo/redo availability, selection, etc.).
    public var onStateChanged: (() -> Void)?

    // MARK: - Observable state

    public private(set) var canUndo: Bool = false
    public private(set) var canRedo: Bool = false
    public private(set) var hasSelection: Bool = false
    public private(set) var state: EngineState

    // MARK: - Internal hooks (set by Combine / AsyncStream extensions)

    internal var _sendToSubject: (([RenderCommand]) -> Void)?
    internal var _sendToContinuation: (([RenderCommand]) -> Void)?
    internal var _sendStateToSubject: ((EngineState) -> Void)?
    internal var _sendStateToContinuation: ((EngineState) -> Void)?

    // MARK: - Lazy storage for Combine subjects (AnyObject to avoid importing Combine here)

    internal var _renderSubjectStorage: AnyObject?
    internal var _stateSubjectStorage: AnyObject?

    // MARK: - Init

    public convenience init(canvasSize: CanvasSize) {
        self.init(engine: MelanEngine(canvasSize: canvasSize))
    }

    public static func a4() -> MelanCanvas {
        MelanCanvas(engine: MelanEngine.newA4())
    }

    private init(engine: MelanEngine) {
        self.engine = engine
        self.state = engine.getState()
        self.canUndo = state.canUndo
        self.canRedo = state.canRedo
        self.hasSelection = state.hasSelection
    }

    // MARK: - Delivery helpers

    /// Deliver commands without state refresh (used by fullRender).
    private func deliverCommands(_ commands: [RenderCommand]) {
        guard !commands.isEmpty else { return }
        onRenderCommands?(commands)
        _sendToSubject?(commands)
        _sendToContinuation?(commands)
    }

    /// Deliver commands and refresh state (used by all mutations).
    private func emit(_ commands: [RenderCommand]) {
        deliverCommands(commands)
        refreshState()
    }

    private func refreshState() {
        let newState = engine.getState()
        state = newState
        canUndo = newState.canUndo
        canRedo = newState.canRedo
        hasSelection = newState.hasSelection
        onStateChanged?()
        _sendStateToSubject?(newState)
        _sendStateToContinuation?(newState)
    }

    // MARK: - Stroke operations (mutation)

    public func beginStroke(x: Double, y: Double, pressure: Double, timestamp: Double) {
        emit(engine.beginStroke(x: x, y: y, pressure: pressure, timestamp: timestamp))
    }

    public func addPoint(x: Double, y: Double, pressure: Double, timestamp: Double) {
        emit(engine.addPoint(x: x, y: y, pressure: pressure, timestamp: timestamp))
    }

    public func endStroke() {
        emit(engine.endStroke())
    }

    // MARK: - Canvas operations (mutation)

    public func clearAll() {
        emit(engine.clearAll())
    }

    // MARK: - History (mutation)

    public func undo() {
        emit(engine.undo())
    }

    public func redo() {
        emit(engine.redo())
    }

    // MARK: - Viewport (mutation)

    public func zoom(factor: Double, focalX: Double, focalY: Double) {
        emit(engine.zoom(factor: factor, focalX: focalX, focalY: focalY))
    }

    public func pan(dx: Double, dy: Double) {
        emit(engine.pan(dx: dx, dy: dy))
    }

    public func resetViewport() {
        emit(engine.resetViewport())
    }

    // MARK: - Lasso selection (mutation)

    public func beginLasso(x: Double, y: Double) {
        emit(engine.beginLasso(x: x, y: y))
    }

    public func addLassoPoint(x: Double, y: Double) {
        emit(engine.addLassoPoint(x: x, y: y))
    }

    public func endLasso() {
        emit(engine.endLasso())
    }

    public func cancelLasso() {
        emit(engine.cancelLasso())
    }

    // MARK: - Lasso drag (mutation)

    public func beginLassoDrag(x: Double, y: Double) {
        emit(engine.beginLassoDrag(x: x, y: y))
    }

    public func updateLassoDrag(x: Double, y: Double) {
        emit(engine.updateLassoDrag(x: x, y: y))
    }

    public func endLassoDrag() {
        emit(engine.endLassoDrag())
    }

    // MARK: - Lasso actions (mutation)

    public func lassoDelete() {
        emit(engine.lassoDelete())
    }

    public func lassoDuplicate() {
        emit(engine.lassoDuplicate())
    }

    // MARK: - Read-only command emission

    /// Re-emits the full scene without changing state.
    public func fullRender() {
        deliverCommands(engine.fullRender())
    }

    // MARK: - Non-emitting

    /// Updates the active brush. No commands are produced.
    public func setBrush(_ config: BrushConfig) {
        engine.setBrush(config: config)
    }

    // MARK: - Persistence

    public func save(format: SaveFormat) throws -> Data {
        try engine.save(format: format)
    }

    public func load(data: Data) throws {
        try engine.load(data: data)
        emit(engine.fullRender())
    }
}
