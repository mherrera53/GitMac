import Foundation
import os.log

/// Production-safe logger that only logs in DEBUG builds
enum Logger {
    private static let subsystem = "com.gitmac"

    private static let generalLog = OSLog(subsystem: subsystem, category: "general")
    private static let gitLog = OSLog(subsystem: subsystem, category: "git")
    private static let performanceLog = OSLog(subsystem: subsystem, category: "performance")

    /// Debug log - only in DEBUG builds
    @inlinable
    static func debug(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        os_log(.debug, log: generalLog, "%{public}s:%d: %{public}s", filename, line, message())
        #endif
    }

    /// Error log - always logged
    @inlinable
    static func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        os_log(.error, log: generalLog, "%{public}s:%d: %{public}s", filename, line, message())
    }

    /// Git operation log - only in DEBUG builds
    @inlinable
    static func git(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log(.debug, log: gitLog, "%{public}s", message())
        #endif
    }

    /// Performance measurement - only in DEBUG builds
    @inlinable
    static func perf(_ message: @autoclosure () -> String) {
        #if DEBUG
        os_log(.debug, log: performanceLog, "%{public}s", message())
        #endif
    }
}
