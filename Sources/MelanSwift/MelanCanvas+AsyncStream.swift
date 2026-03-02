extension MelanCanvas {

    /// An async stream of render commands. Single consumer — creating a new stream replaces the previous one.
    public var renderStream: AsyncStream<[RenderCommand]> {
        AsyncStream { continuation in
            self._sendToContinuation = { continuation.yield($0) }
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in self._sendToContinuation = nil }
            }
        }
    }

    /// An async stream of engine state changes. Single consumer — creating a new stream replaces the previous one.
    public var stateStream: AsyncStream<EngineState> {
        AsyncStream { continuation in
            self._sendStateToContinuation = { continuation.yield($0) }
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in self._sendStateToContinuation = nil }
            }
        }
    }
}
