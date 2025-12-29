import Foundation
import Combine

// MARK: - Conflict Prevention Service

/// Service that detects potential merge conflicts BEFORE they happen
/// by analyzing overlapping changes between branches
actor ConflictPreventionService {
    static let shared = ConflictPreventionService()

    private let engine = GitEngine()

    // MARK: - Models

    /// Represents a potential conflict detected before merge
    struct PotentialConflict: Identifiable, Sendable {
        let id = UUID()
        let file: String
        let sourceBranch: String
        let targetBranch: String
        let sourceLines: ClosedRange<Int>
        let targetLines: ClosedRange<Int>
        let sourceAuthor: String?
        let targetAuthor: String?
        let sourceCommit: String?
        let targetCommit: String?
        let severity: Severity
        let overlappingContent: OverlappingContent?

        enum Severity: String, Sendable {
            case high = "high"       // Same lines modified
            case medium = "medium"   // Adjacent lines modified
            case low = "low"         // Same file, different sections

            var color: String {
                switch self {
                case .high: return "red"
                case .medium: return "orange"
                case .low: return "yellow"
                }
            }

            var icon: String {
                switch self {
                case .high: return "exclamationmark.triangle.fill"
                case .medium: return "exclamationmark.triangle"
                case .low: return "info.circle"
                }
            }
        }

        struct OverlappingContent: Sendable {
            let sourceContent: String
            let targetContent: String
        }
    }

    /// Result of conflict prevention analysis
    struct ConflictAnalysis: Sendable {
        let sourceBranch: String
        let targetBranch: String
        let potentialConflicts: [PotentialConflict]
        let safeFiles: [String]  // Files modified only in one branch
        let analyzedAt: Date

        var hasConflicts: Bool { !potentialConflicts.isEmpty }
        var highSeverityCount: Int { potentialConflicts.filter { $0.severity == .high }.count }
        var mediumSeverityCount: Int { potentialConflicts.filter { $0.severity == .medium }.count }
        var lowSeverityCount: Int { potentialConflicts.filter { $0.severity == .low }.count }

        var summary: String {
            if potentialConflicts.isEmpty {
                return "No conflicts detected. Safe to merge!"
            }
            var parts: [String] = []
            if highSeverityCount > 0 { parts.append("\(highSeverityCount) high") }
            if mediumSeverityCount > 0 { parts.append("\(mediumSeverityCount) medium") }
            if lowSeverityCount > 0 { parts.append("\(lowSeverityCount) low") }
            return "\(potentialConflicts.count) potential conflicts: \(parts.joined(separator: ", "))"
        }
    }

    /// File change info from a branch
    private struct FileChange {
        let file: String
        let lines: Set<Int>
        let author: String?
        let commit: String?
        let content: [Int: String]  // line number -> content
    }

    // MARK: - Public API

    /// Analyze potential conflicts between two branches
    /// - Parameters:
    ///   - source: The branch to merge FROM
    ///   - target: The branch to merge INTO
    ///   - repoPath: Repository path
    /// - Returns: Analysis of potential conflicts
    func analyzeConflicts(
        source: String,
        target: String,
        at repoPath: String
    ) async throws -> ConflictAnalysis {
        // Find the merge base (common ancestor)
        let mergeBase = try await getMergeBase(source: source, target: target, at: repoPath)

        // Get changes in source branch since merge base
        let sourceChanges = try await getChangedFiles(
            from: mergeBase,
            to: source,
            at: repoPath
        )

        // Get changes in target branch since merge base
        let targetChanges = try await getChangedFiles(
            from: mergeBase,
            to: target,
            at: repoPath
        )

        // Find overlapping files
        let sourceFiles = Set(sourceChanges.keys)
        let targetFiles = Set(targetChanges.keys)
        let overlappingFiles = sourceFiles.intersection(targetFiles)
        let safeFiles = Array(sourceFiles.symmetricDifference(targetFiles))

        // Analyze each overlapping file for conflicts
        var potentialConflicts: [PotentialConflict] = []

        for file in overlappingFiles {
            guard let sourceChange = sourceChanges[file],
                  let targetChange = targetChanges[file] else { continue }

            let conflicts = analyzeFileConflicts(
                file: file,
                sourceChange: sourceChange,
                targetChange: targetChange,
                sourceBranch: source,
                targetBranch: target
            )

            potentialConflicts.append(contentsOf: conflicts)
        }

        // Sort by severity
        potentialConflicts.sort { $0.severity.rawValue < $1.severity.rawValue }

        return ConflictAnalysis(
            sourceBranch: source,
            targetBranch: target,
            potentialConflicts: potentialConflicts,
            safeFiles: safeFiles,
            analyzedAt: Date()
        )
    }

    /// Quick check if branches have potential conflicts
    func hasConflicts(
        source: String,
        target: String,
        at repoPath: String
    ) async throws -> Bool {
        let analysis = try await analyzeConflicts(source: source, target: target, at: repoPath)
        return analysis.hasConflicts
    }

    /// Check conflicts for current branch against target (usually main/master)
    func checkCurrentBranchConflicts(
        against target: String = "main",
        at repoPath: String
    ) async throws -> ConflictAnalysis {
        let head = try await engine.getHead(at: repoPath)
        let currentBranch = head.name
        return try await analyzeConflicts(source: currentBranch, target: target, at: repoPath)
    }

    // MARK: - Private Methods

    /// Get the merge base (common ancestor) of two branches
    private func getMergeBase(source: String, target: String, at repoPath: String) async throws -> String {
        let result = try await ShellExecutor.shared.execute(
            "cd \(repoPath.shellEscaped) && git merge-base \(source.shellEscaped) \(target.shellEscaped)"
        )
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Get files changed between two refs with line-level detail
    private func getChangedFiles(
        from base: String,
        to head: String,
        at repoPath: String
    ) async throws -> [String: FileChange] {
        // Get list of changed files
        let diffResult = try await ShellExecutor.shared.execute(
            "cd \(repoPath.shellEscaped) && git diff --name-only \(base.shellEscaped)..\(head.shellEscaped)"
        )

        let files = diffResult.output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var changes: [String: FileChange] = [:]

        for file in files {
            // Get detailed diff for this file
            let fileDiff = try await ShellExecutor.shared.execute(
                "cd \(repoPath.shellEscaped) && git diff -U0 \(base.shellEscaped)..\(head.shellEscaped) -- \(file.shellEscaped)"
            )

            // Parse the diff to get changed line numbers
            let (lines, content) = parseDiffForLines(fileDiff.output)

            // Get the last author who modified this file
            let blameResult = try? await ShellExecutor.shared.execute(
                "cd \(repoPath.shellEscaped) && git log -1 --format='%an' \(head.shellEscaped) -- \(file.shellEscaped)"
            )
            let author = blameResult?.output.trimmingCharacters(in: .whitespacesAndNewlines)

            // Get the last commit for this file
            let commitResult = try? await ShellExecutor.shared.execute(
                "cd \(repoPath.shellEscaped) && git log -1 --format='%h' \(head.shellEscaped) -- \(file.shellEscaped)"
            )
            let commit = commitResult?.output.trimmingCharacters(in: .whitespacesAndNewlines)

            changes[file] = FileChange(
                file: file,
                lines: lines,
                author: author,
                commit: commit,
                content: content
            )
        }

        return changes
    }

    /// Parse diff output to extract changed line numbers
    private func parseDiffForLines(_ diff: String) -> (Set<Int>, [Int: String]) {
        var lines = Set<Int>()
        var content: [Int: String] = [:]
        var currentLine = 0

        for line in diff.components(separatedBy: "\n") {
            // Parse hunk header: @@ -old,count +new,count @@
            if line.hasPrefix("@@") {
                // Extract new file line number
                if let plusRange = line.range(of: "+"),
                   let spaceRange = line.range(of: " ", range: plusRange.upperBound..<line.endIndex) {
                    let numStr = String(line[plusRange.upperBound..<spaceRange.lowerBound])
                    if let commaIdx = numStr.firstIndex(of: ",") {
                        currentLine = Int(numStr[..<commaIdx]) ?? 0
                    } else {
                        currentLine = Int(numStr) ?? 0
                    }
                }
            } else if line.hasPrefix("+") && !line.hasPrefix("+++") {
                lines.insert(currentLine)
                content[currentLine] = String(line.dropFirst())
                currentLine += 1
            } else if line.hasPrefix("-") && !line.hasPrefix("---") {
                // Deletion - mark the line but don't increment
                lines.insert(currentLine)
            } else if !line.hasPrefix("-") {
                currentLine += 1
            }
        }

        return (lines, content)
    }

    /// Analyze a single file for conflicts between source and target changes
    private func analyzeFileConflicts(
        file: String,
        sourceChange: FileChange,
        targetChange: FileChange,
        sourceBranch: String,
        targetBranch: String
    ) -> [PotentialConflict] {
        var conflicts: [PotentialConflict] = []

        // Find overlapping lines
        let overlappingLines = sourceChange.lines.intersection(targetChange.lines)

        if !overlappingLines.isEmpty {
            // HIGH severity: exact same lines modified
            let sortedLines = overlappingLines.sorted()
            let ranges = groupConsecutiveLines(sortedLines)

            for range in ranges {
                let sourceContent = range.compactMap { sourceChange.content[$0] }.joined(separator: "\n")
                let targetContent = range.compactMap { targetChange.content[$0] }.joined(separator: "\n")

                conflicts.append(PotentialConflict(
                    file: file,
                    sourceBranch: sourceBranch,
                    targetBranch: targetBranch,
                    sourceLines: range.first!...range.last!,
                    targetLines: range.first!...range.last!,
                    sourceAuthor: sourceChange.author,
                    targetAuthor: targetChange.author,
                    sourceCommit: sourceChange.commit,
                    targetCommit: targetChange.commit,
                    severity: .high,
                    overlappingContent: PotentialConflict.OverlappingContent(
                        sourceContent: sourceContent,
                        targetContent: targetContent
                    )
                ))
            }
        } else {
            // Check for adjacent line modifications (within 3 lines)
            let adjacentConflicts = findAdjacentConflicts(
                sourceLines: sourceChange.lines,
                targetLines: targetChange.lines,
                threshold: 3
            )

            if !adjacentConflicts.isEmpty {
                // MEDIUM severity: adjacent lines modified
                for (sourceRange, targetRange) in adjacentConflicts {
                    conflicts.append(PotentialConflict(
                        file: file,
                        sourceBranch: sourceBranch,
                        targetBranch: targetBranch,
                        sourceLines: sourceRange,
                        targetLines: targetRange,
                        sourceAuthor: sourceChange.author,
                        targetAuthor: targetChange.author,
                        sourceCommit: sourceChange.commit,
                        targetCommit: targetChange.commit,
                        severity: .medium,
                        overlappingContent: nil
                    ))
                }
            } else {
                // LOW severity: same file, different sections
                let sourceRange = (sourceChange.lines.min() ?? 0)...(sourceChange.lines.max() ?? 0)
                let targetRange = (targetChange.lines.min() ?? 0)...(targetChange.lines.max() ?? 0)

                conflicts.append(PotentialConflict(
                    file: file,
                    sourceBranch: sourceBranch,
                    targetBranch: targetBranch,
                    sourceLines: sourceRange,
                    targetLines: targetRange,
                    sourceAuthor: sourceChange.author,
                    targetAuthor: targetChange.author,
                    sourceCommit: sourceChange.commit,
                    targetCommit: targetChange.commit,
                    severity: .low,
                    overlappingContent: nil
                ))
            }
        }

        return conflicts
    }

    /// Group consecutive line numbers into ranges
    private func groupConsecutiveLines(_ lines: [Int]) -> [[Int]] {
        guard !lines.isEmpty else { return [] }

        var groups: [[Int]] = []
        var currentGroup: [Int] = [lines[0]]

        for i in 1..<lines.count {
            if lines[i] == lines[i-1] + 1 {
                currentGroup.append(lines[i])
            } else {
                groups.append(currentGroup)
                currentGroup = [lines[i]]
            }
        }
        groups.append(currentGroup)

        return groups
    }

    /// Find adjacent line modifications within threshold
    private func findAdjacentConflicts(
        sourceLines: Set<Int>,
        targetLines: Set<Int>,
        threshold: Int
    ) -> [(ClosedRange<Int>, ClosedRange<Int>)] {
        var conflicts: [(ClosedRange<Int>, ClosedRange<Int>)] = []

        let sortedSource = sourceLines.sorted()
        let sortedTarget = targetLines.sorted()

        for sourceLine in sortedSource {
            for targetLine in sortedTarget {
                let distance = abs(sourceLine - targetLine)
                if distance > 0 && distance <= threshold {
                    // Found adjacent modification
                    let sourceRange = sourceLine...sourceLine
                    let targetRange = targetLine...targetLine
                    conflicts.append((sourceRange, targetRange))
                }
            }
        }

        return conflicts
    }
}

// MARK: - String Extension for Shell Escaping

private extension String {
    var shellEscaped: String {
        "'\(self.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
