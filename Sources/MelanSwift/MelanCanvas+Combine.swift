import Combine

extension MelanCanvas {

    /// Publishes render commands whenever the canvas mutates.
    public var renderPublisher: AnyPublisher<[RenderCommand], Never> {
        let subject: PassthroughSubject<[RenderCommand], Never>
        if let existing = _renderSubjectStorage as? PassthroughSubject<[RenderCommand], Never> {
            subject = existing
        } else {
            subject = PassthroughSubject<[RenderCommand], Never>()
            _renderSubjectStorage = subject
            _sendToSubject = { subject.send($0) }
        }
        return subject.eraseToAnyPublisher()
    }

    /// Publishes the engine state whenever it changes.
    public var statePublisher: AnyPublisher<EngineState, Never> {
        let subject: PassthroughSubject<EngineState, Never>
        if let existing = _stateSubjectStorage as? PassthroughSubject<EngineState, Never> {
            subject = existing
        } else {
            subject = PassthroughSubject<EngineState, Never>()
            _stateSubjectStorage = subject
            _sendStateToSubject = { subject.send($0) }
        }
        return subject.eraseToAnyPublisher()
    }
}
