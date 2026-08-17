import Foundation

/// Drives the reader's scroll position at a predictable pace. The view owns the actual proxy.
final class AutoScrollManager {
    private(set) var isRunning = false
    var secondsPerLine: Double = 0.8
    private var timer: Timer?

    func toggle(onTick: @escaping () -> Void) {
        isRunning ? stop() : start(onTick: onTick)
    }

    func start(onTick: @escaping () -> Void) {
        guard !isRunning else { return }; isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: secondsPerLine, repeats: true) { _ in onTick() }
    }

    func stop() { isRunning = false; timer?.invalidate(); timer = nil }
    deinit { stop() }
}
