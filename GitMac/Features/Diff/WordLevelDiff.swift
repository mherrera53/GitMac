import SwiftUI
import Foundation

// MARK: - Word-Level Diff Algorithm (Kaleidoscope-style)

/// Represents a segment of text with its diff status
struct DiffSegment: Identifiable {
    let id = UUID()
    let text: String
    let type: SegmentType

    enum SegmentType {
        case unchanged  // Same in both versions
        case added      // Only in new version
        case removed    // Only in old version
        case changed    // Modified (for character-level)
    }
}

/// Word-level diff result for a pair of lines
struct WordLevelDiffResult {
    let oldSegments: [DiffSegment]
    let newSegments: [DiffSegment]
    let hasInlineChanges: Bool
}

/// Computes word-level and character-level diffs between two strings
enum WordLevelDiff {

    /// Compare two lines and return highlighted segments
    static func compare(oldLine: String, newLine: String) -> WordLevelDiffResult {
        // If lines are identical, no inline changes
        if oldLine == newLine {
            return WordLevelDiffResult(
                oldSegments: [DiffSegment(text: oldLine, type: .unchanged)],
                newSegments: [DiffSegment(text: newLine, type: .unchanged)],
                hasInlineChanges: false
            )
        }

        // If one is empty, the whole line is changed
        if oldLine.isEmpty {
            return WordLevelDiffResult(
                oldSegments: [],
                newSegments: [DiffSegment(text: newLine, type: .added)],
                hasInlineChanges: true
            )
        }

        if newLine.isEmpty {
            return WordLevelDiffResult(
                oldSegments: [DiffSegment(text: oldLine, type: .removed)],
                newSegments: [],
                hasInlineChanges: true
            )
        }

        // Find common prefix and suffix
        let (prefix, oldMiddle, newMiddle, suffix) = findCommonPrefixSuffix(oldLine, newLine)

        // Build segments
        var oldSegments: [DiffSegment] = []
        var newSegments: [DiffSegment] = []

        // Add common prefix
        if !prefix.isEmpty {
            oldSegments.append(DiffSegment(text: prefix, type: .unchanged))
            newSegments.append(DiffSegment(text: prefix, type: .unchanged))
        }

        // Add changed middle parts
        if !oldMiddle.isEmpty {
            oldSegments.append(DiffSegment(text: oldMiddle, type: .removed))
        }
        if !newMiddle.isEmpty {
            newSegments.append(DiffSegment(text: newMiddle, type: .added))
        }

        // Add common suffix
        if !suffix.isEmpty {
            oldSegments.append(DiffSegment(text: suffix, type: .unchanged))
            newSegments.append(DiffSegment(text: suffix, type: .unchanged))
        }

        let hasChanges = !oldMiddle.isEmpty || !newMiddle.isEmpty

        return WordLevelDiffResult(
            oldSegments: oldSegments,
            newSegments: newSegments,
            hasInlineChanges: hasChanges
        )
    }

    /// Find common prefix, different middle, and common suffix
    private static func findCommonPrefixSuffix(_ old: String, _ new: String) -> (prefix: String, oldMiddle: String, newMiddle: String, suffix: String) {
        let oldChars = Array(old)
        let newChars = Array(new)

        // Find common prefix length
        var prefixLen = 0
        while prefixLen < oldChars.count && prefixLen < newChars.count && oldChars[prefixLen] == newChars[prefixLen] {
            prefixLen += 1
        }

        // Find common suffix length (don't overlap with prefix)
        var suffixLen = 0
        while suffixLen < (oldChars.count - prefixLen) &&
              suffixLen < (newChars.count - prefixLen) &&
              oldChars[oldChars.count - 1 - suffixLen] == newChars[newChars.count - 1 - suffixLen] {
            suffixLen += 1
        }

        let prefix = String(oldChars[0..<prefixLen])
        let suffix = suffixLen > 0 ? String(oldChars[(oldChars.count - suffixLen)...]) : ""
        let oldMiddle = String(oldChars[prefixLen..<(oldChars.count - suffixLen)])
        let newMiddle = String(newChars[prefixLen..<(newChars.count - suffixLen)])

        return (prefix, oldMiddle, newMiddle, suffix)
    }

    /// Word-based comparison (tokenizes by whitespace and punctuation)
    static func compareWords(oldLine: String, newLine: String) -> WordLevelDiffResult {
        let oldTokens = tokenize(oldLine)
        let newTokens = tokenize(newLine)

        // Use LCS (Longest Common Subsequence) for word-level diff
        let lcs = longestCommonSubsequence(oldTokens, newTokens)

        var oldSegments: [DiffSegment] = []
        var newSegments: [DiffSegment] = []

        var oldIndex = 0
        var newIndex = 0
        var lcsIndex = 0

        while oldIndex < oldTokens.count || newIndex < newTokens.count {
            if lcsIndex < lcs.count {
                // Add removed tokens from old
                while oldIndex < oldTokens.count && oldTokens[oldIndex] != lcs[lcsIndex] {
                    oldSegments.append(DiffSegment(text: oldTokens[oldIndex], type: .removed))
                    oldIndex += 1
                }

                // Add added tokens to new
                while newIndex < newTokens.count && newTokens[newIndex] != lcs[lcsIndex] {
                    newSegments.append(DiffSegment(text: newTokens[newIndex], type: .added))
                    newIndex += 1
                }

                // Add common token
                if oldIndex < oldTokens.count && newIndex < newTokens.count {
                    oldSegments.append(DiffSegment(text: oldTokens[oldIndex], type: .unchanged))
                    newSegments.append(DiffSegment(text: newTokens[newIndex], type: .unchanged))
                    oldIndex += 1
                    newIndex += 1
                    lcsIndex += 1
                }
            } else {
                // Add remaining tokens
                while oldIndex < oldTokens.count {
                    oldSegments.append(DiffSegment(text: oldTokens[oldIndex], type: .removed))
                    oldIndex += 1
                }
                while newIndex < newTokens.count {
                    newSegments.append(DiffSegment(text: newTokens[newIndex], type: .added))
                    newIndex += 1
                }
            }
        }

        let hasChanges = oldSegments.contains { $0.type == .removed } || newSegments.contains { $0.type == .added }

        return WordLevelDiffResult(
            oldSegments: oldSegments,
            newSegments: newSegments,
            hasInlineChanges: hasChanges
        )
    }

    /// Tokenize string into words and whitespace
    private static func tokenize(_ string: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inWord = false

        for char in string {
            let isWordChar = char.isLetter || char.isNumber || char == "_"

            if isWordChar {
                if !inWord && !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                inWord = true
                currentToken.append(char)
            } else {
                if inWord && !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                inWord = false
                currentToken.append(char)
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    /// Longest Common Subsequence algorithm
    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count
        let n = b.count

        if m == 0 || n == 0 {
            return []
        }

        // Build LCS table
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i-1] == b[j-1] {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }

        // Backtrack to find LCS
        var lcs: [String] = []
        var i = m
        var j = n

        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] {
                lcs.insert(a[i-1], at: 0)
                i -= 1
                j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return lcs
    }
}

// MARK: - Highlighted Text View

/// Renders text with inline diff highlighting
struct InlineDiffText: View {
    let segments: [DiffSegment]
    let side: DiffSide
    let font: Font

    enum DiffSide {
        case old
        case new
    }

    init(segments: [DiffSegment], side: DiffSide, font: Font = DesignTokens.Typography.diffLine) {
        self.segments = segments
        self.side = side
        self.font = font
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments) { segment in
                Text(segment.text)
                    .font(font)
                    .foregroundColor(textColor(for: segment.type))
                    .background(backgroundColor(for: segment.type))
            }
        }
    }

    private func textColor(for type: DiffSegment.SegmentType) -> Color {
        switch type {
        case .unchanged:
            return AppTheme.textPrimary
        case .added:
            return AppTheme.success
        case .removed:
            return AppTheme.error
        case .changed:
            return side == .old ? AppTheme.error : AppTheme.success
        }
    }

    private func backgroundColor(for type: DiffSegment.SegmentType) -> Color {
        switch type {
        case .unchanged:
            return Color.clear
        case .added:
            return AppTheme.success.opacity(0.25)
        case .removed:
            return AppTheme.error.opacity(0.25)
        case .changed:
            return (side == .old ? AppTheme.error : AppTheme.success).opacity(0.25)
        }
    }
}

// MARK: - Enhanced Diff Line Row with Word-Level Highlighting

struct EnhancedDiffLineRow: View {
    let line: DiffLine
    let pairedLine: DiffLine?
    let showLineNumber: Bool
    let side: DiffSide

    enum DiffSide {
        case left   // Old/deletion side
        case right  // New/addition side
    }

    private var diffResult: WordLevelDiffResult? {
        guard let paired = pairedLine else { return nil }

        // Only compute word-level diff for deletion-addition pairs
        if (line.type == .deletion && paired.type == .addition) ||
           (line.type == .addition && paired.type == .deletion) {
            let oldContent = line.type == .deletion ? line.content : paired.content
            let newContent = line.type == .addition ? line.content : paired.content
            return WordLevelDiff.compare(oldLine: oldContent, newLine: newContent)
        }

        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            // Line number
            if showLineNumber {
                Text(lineNumberText)
                    .font(DesignTokens.Typography.commitHash)
                    .foregroundColor(AppTheme.textSecondary.opacity(0.6))
                    .frame(width: 45, alignment: .trailing)
                    .padding(.trailing, DesignTokens.Spacing.sm)
            }

            // Content with word-level highlighting
            if let result = diffResult {
                let segments = side == .left ? result.oldSegments : result.newSegments
                InlineDiffText(segments: segments, side: side == .left ? .old : .new)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(line.content)
                    .font(DesignTokens.Typography.diffLine)
                    .foregroundColor(contentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(backgroundColor)
    }

    private var lineNumberText: String {
        switch side {
        case .left:
            return line.oldLineNumber.map { "\($0)" } ?? ""
        case .right:
            return line.newLineNumber.map { "\($0)" } ?? ""
        }
    }

    private var contentColor: Color {
        switch line.type {
        case .addition:
            return AppTheme.success
        case .deletion:
            return AppTheme.error
        case .context:
            return AppTheme.textPrimary
        case .hunkHeader:
            return AppTheme.info
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .addition:
            return AppTheme.success.opacity(0.1)
        case .deletion:
            return AppTheme.error.opacity(0.1)
        case .context:
            return Color.clear
        case .hunkHeader:
            return AppTheme.info.opacity(0.1)
        }
    }
}
