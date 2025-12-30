import Foundation

/// Parses advanced search syntax for commit graph
/// Supported syntax:
/// - @me - my changes
/// - message:"text" or message:text or =:text
/// - author:name or author:@:name
/// - commit:sha or #:sha
/// - file:path or ?:path
/// - type:stash or is:merge
/// - change:text or ~:text (searches in diff)
/// - after:date or since:date
/// - before:date or until:date
class SearchSyntaxParser {

    /// Parse search string into structured query
    static func parse(_ input: String) -> SearchQuery {
        var query = SearchQuery()

        // Tokenize input
        let tokens = tokenize(input)
        var freeTextParts: [String] = []

        for token in tokens {
            if token.hasPrefix("@me") {
                query.isMyChanges = true
            }
            else if let value = extractValue(from: token, prefixes: ["message:", "=:"]) {
                query.message = value
            }
            else if let value = extractValue(from: token, prefixes: ["author:", "@:"]) {
                query.author = value
            }
            else if let value = extractValue(from: token, prefixes: ["commit:", "#:"]) {
                query.commitSHA = value
            }
            else if let value = extractValue(from: token, prefixes: ["file:", "?:"]) {
                query.file = value
            }
            else if let value = extractValue(from: token, prefixes: ["type:", "is:"]) {
                query.type = SearchQuery.CommitType(rawValue: value.lowercased())
            }
            else if let value = extractValue(from: token, prefixes: ["change:", "~:"]) {
                query.change = value
            }
            else if let value = extractValue(from: token, prefixes: ["after:", "since:"]) {
                query.afterDate = parseDate(value)
            }
            else if let value = extractValue(from: token, prefixes: ["before:", "until:"]) {
                query.beforeDate = parseDate(value)
            }
            else {
                // Free text
                freeTextParts.append(token)
            }
        }

        if !freeTextParts.isEmpty {
            query.freeText = freeTextParts.joined(separator: " ")
        }

        return query
    }

    /// Tokenize input respecting quoted strings
    private static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuotes = false

        for char in input {
            if char == "\"" {
                inQuotes.toggle()
            } else if char.isWhitespace && !inQuotes {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    /// Extract value from token with given prefixes
    private static func extractValue(from token: String, prefixes: [String]) -> String? {
        for prefix in prefixes {
            if token.lowercased().hasPrefix(prefix) {
                let value = String(token.dropFirst(prefix.count))
                return value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }

    /// Parse date from string (supports various formats)
    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        // Try ISO format first (YYYY-MM-DD)
        if let date = formatter.date(from: value) {
            return date
        }

        // Try relative dates
        let lower = value.lowercased()
        let calendar = Calendar.current
        let now = Date()

        if lower == "today" {
            return calendar.startOfDay(for: now)
        } else if lower == "yesterday" {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        } else if lower == "week" || lower == "last week" {
            return calendar.date(byAdding: .day, value: -7, to: now)
        } else if lower == "month" || lower == "last month" {
            return calendar.date(byAdding: .month, value: -1, to: now)
        } else if lower == "year" || lower == "last year" {
            return calendar.date(byAdding: .year, value: -1, to: now)
        }

        return nil
    }

    /// Get autocomplete suggestions for given input
    static func autocompleteSuggestions(for input: String) -> [String] {
        let suggestions = [
            "@me",
            "message:",
            "author:",
            "commit:",
            "file:",
            "type:stash",
            "type:merge",
            "is:stash",
            "is:merge",
            "change:",
            "after:today",
            "after:yesterday",
            "after:week",
            "before:today",
            "since:week",
            "until:today"
        ]

        if input.isEmpty {
            return suggestions
        }

        return suggestions.filter { $0.lowercased().hasPrefix(input.lowercased()) }
    }
}
