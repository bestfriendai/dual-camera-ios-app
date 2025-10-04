import Foundation
import Combine

@available(iOS 26.0, *)
extension Timer {
    static func asyncSequence(interval: TimeInterval, tolerance: TimeInterval = 0.1) -> AsyncStream<Date> {
        AsyncStream { continuation in
            let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
                continuation.yield(Date())
            }
            timer.tolerance = tolerance
            
            continuation.onTermination = { @Sendable _ in
                timer.invalidate()
            }
        }
    }
}

extension Timer.PublisherScheduler where Self == RunLoop {
    static var mainRunLoop: RunLoop {
        .main
    }
}

@available(iOS 13.0, *)
extension Timer {
    static func asyncTimer(interval: TimeInterval, on runLoop: RunLoop = .main, in mode: RunLoop.Mode = .default) -> AsyncStream<Date> {
        AsyncStream { continuation in
            let timer = Timer.publish(every: interval, on: runLoop, in: mode)
                .autoconnect()
                .sink { date in
                    continuation.yield(date)
                }
            
            continuation.onTermination = { @Sendable _ in
                timer.cancel()
            }
        }
    }
}
