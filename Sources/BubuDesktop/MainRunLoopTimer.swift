import Foundation

extension Timer {
    /// Menu tracking is a common run-loop mode. Animation deadlines must keep
    /// running there, just like the read-only input source.
    @MainActor
    static func commonModesTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        block: @escaping @Sendable (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: block)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
