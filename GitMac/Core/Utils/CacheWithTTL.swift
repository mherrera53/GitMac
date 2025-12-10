import Foundation

/// A simple cache with Time-To-Live (TTL) expiration
/// Follows Apple WWDC 2018 recommendations for memory-efficient caching
struct CacheWithTTL<T> {
    private var value: T?
    private var timestamp: Date?
    private let ttl: TimeInterval

    /// Initialize cache with specified TTL in seconds
    /// - Parameter ttl: Time-to-live in seconds (default 30 seconds)
    init(ttl: TimeInterval = 30) {
        self.ttl = ttl
    }

    /// Get cached value if still valid (within TTL)
    /// Returns nil if cache is empty or expired
    mutating func get() -> T? {
        guard let ts = timestamp, Date().timeIntervalSince(ts) < ttl else {
            // Cache expired - clear it
            value = nil
            timestamp = nil
            return nil
        }
        return value
    }

    /// Set a new cached value with current timestamp
    mutating func set(_ newValue: T) {
        value = newValue
        timestamp = Date()
    }

    /// Check if cache has a valid (non-expired) value
    var hasValidValue: Bool {
        guard let ts = timestamp else { return false }
        return Date().timeIntervalSince(ts) < ttl
    }

    /// Invalidate the cache (clear value and timestamp)
    mutating func invalidate() {
        value = nil
        timestamp = nil
    }
}
