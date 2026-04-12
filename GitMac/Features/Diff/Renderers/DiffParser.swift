import Foundation

// MARK: - Diff Parser

struct DiffParser {
    /// Maximum lines to parse (prevents freezing on huge files)
    private static let maxLinesToParse = 100000

    /// Pre-compiled hunk header regex (avoid recompiling on every @@ line)
    private static let hunkHeaderRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@.*"#)
    }()

    /// Strip surrounding quotes and unescape octal sequences from git-quoted paths
    private static func unquotePath(_ raw: String) -> String {
        var path = raw
        // Git quotes paths containing special characters: "path/with spaces.txt"
        if path.hasPrefix("\"") && path.hasSuffix("\"") {
            path = String(path.dropFirst().dropLast())
            // Unescape octal sequences like \303\261 -> bytes
            var result = ""
            var i = path.startIndex
            while i < path.endIndex {
                if path[i] == "\\" && path.index(after: i) < path.endIndex {
                    let next = path.index(after: i)
                    if path[next].isNumber {
                        // Octal sequence: up to 3 digits
                        var octal = ""
                        var j = next
                        while j < path.endIndex && octal.count < 3 && path[j] >= "0" && path[j] <= "7" {
                            octal.append(path[j])
                            j = path.index(after: j)
                        }
                        if let byte = UInt8(octal, radix: 8) {
                            result.append(Character(UnicodeScalar(byte)))
                        } else {
                            result.append("\\")
                            result.append(contentsOf: octal)
                        }
                        i = j
                        continue
                    } else {
                        // Common escapes
                        switch path[next] {
                        case "n": result.append("\n")
                        case "t": result.append("\t")
                        case "\\": result.append("\\")
                        case "\"": result.append("\"")
                        default:
                            result.append("\\")
                            result.append(path[next])
                        }
                        i = path.index(next, offsetBy: 1)
                        continue
                    }
                }
                result.append(path[i])
                i = path.index(after: i)
            }
            path = result
        }
        return path
    }

    /// Parse a unified diff string into FileDiff objects (ASYNC - runs on background thread)
    static func parseAsync(_ diffString: String) async -> [FileDiff] {
        // Run parsing on background thread to avoid UI freeze
        return await Task.detached(priority: .userInitiated) {
            parse(diffString)
        }.value
    }

    /// Parse a unified diff string into FileDiff objects
    /// Limits parsing to maxLinesToParse for performance
    static func parse(_ diffString: String) -> [FileDiff] {
        var files: [FileDiff] = []
        var currentFile: (oldPath: String?, newPath: String, hunks: [DiffHunk], additions: Int, deletions: Int)?
        var currentHunk: (header: String, oldStart: Int, oldLines: Int, newStart: Int, newLines: Int, lines: [DiffLine])?

        // For very large diffs, truncate the string first to avoid memory issues
        // Use utf8.count which is O(1) for native strings
        let maxBytes = 50_000_000 // ~50MB max
        let truncatedString: String
        var wasTruncated = false

        if diffString.utf8.count > maxBytes {
            // Truncate by taking prefix of utf8 bytes
            truncatedString = String(diffString.utf8.prefix(maxBytes)) ?? String(diffString.prefix(maxBytes / 4))
            wasTruncated = true
        } else {
            truncatedString = diffString
        }

        let lines = truncatedString.components(separatedBy: "\n")
        var oldLineNum = 0
        var newLineNum = 0
        var linesParsed = 0
        var lastDiffGitPath: String? = nil
        var isBinary = false
        var renameFrom: String? = nil
        var renameTo: String? = nil

        for line in lines {
            // Limit lines parsed
            linesParsed += 1
            if linesParsed > maxLinesToParse {
                wasTruncated = true
                break
            }
            if line.hasPrefix("diff --git") {
                // Save previous file
                if var file = currentFile {
                    if let hunk = currentHunk {
                        file.hunks.append(DiffHunk(
                            header: hunk.header,
                            oldStart: hunk.oldStart,
                            oldLines: hunk.oldLines,
                            newStart: hunk.newStart,
                            newLines: hunk.newLines,
                            lines: hunk.lines
                        ))
                    }
                    files.append(FileDiff(
                        oldPath: file.oldPath,
                        newPath: file.newPath,
                        status: determineStatus(file.oldPath, file.newPath),
                        hunks: file.hunks,
                        isBinary: isBinary,
                        additions: file.additions,
                        deletions: file.deletions
                    ))
                }
                currentFile = nil
                currentHunk = nil
                isBinary = false
                renameFrom = nil
                renameTo = nil

                // C4: Extract file path from "diff --git a/OLD b/NEW"
                // Parse the b/NEW path as fallback when --- / +++ are missing
                let stripped = String(line.dropFirst("diff --git ".count))
                if let bRange = stripped.range(of: " b/") {
                    lastDiffGitPath = unquotePath(String(stripped[stripped.index(bRange.lowerBound, offsetBy: 3)...]))
                } else {
                    lastDiffGitPath = nil
                }
            } else if line.hasPrefix("Binary files") || line.hasPrefix("GIT binary patch") {
                // C1: Mark current file as binary and skip content parsing
                isBinary = true
                if currentFile == nil, let fallback = lastDiffGitPath {
                    currentFile = (oldPath: nil, newPath: fallback, hunks: [], additions: 0, deletions: 0)
                }
                continue
            } else if line.hasPrefix("old mode") || line.hasPrefix("new mode") {
                // I6: Permission-only change - ensure we have a file from diff --git header
                if currentFile == nil, let fallback = lastDiffGitPath {
                    currentFile = (oldPath: fallback, newPath: fallback, hunks: [], additions: 0, deletions: 0)
                }
                continue
            } else if line.hasPrefix("rename from ") {
                // I7: Save rename source path
                renameFrom = String(line.dropFirst("rename from ".count))
                continue
            } else if line.hasPrefix("rename to ") {
                // I7: Save rename destination path
                renameTo = String(line.dropFirst("rename to ".count))
                if currentFile == nil {
                    currentFile = (oldPath: renameFrom, newPath: renameTo ?? "", hunks: [], additions: 0, deletions: 0)
                }
                continue
            } else if line.hasPrefix("--- ") {
                let raw = unquotePath(String(line.dropFirst(4)))
                let path = raw.hasPrefix("a/") ? String(raw.dropFirst(2)) : raw
                if currentFile == nil {
                    currentFile = (oldPath: path == "/dev/null" ? nil : path, newPath: "", hunks: [], additions: 0, deletions: 0)
                } else {
                    currentFile?.oldPath = path == "/dev/null" ? nil : path
                }
            } else if line.hasPrefix("+++ ") {
                let raw = unquotePath(String(line.dropFirst(4)))
                let path = raw.hasPrefix("b/") ? String(raw.dropFirst(2)) : raw
                if currentFile == nil {
                    currentFile = (oldPath: nil, newPath: path, hunks: [], additions: 0, deletions: 0)
                } else {
                    currentFile?.newPath = path
                }
            } else if line.hasPrefix("@@") {
                // Save previous hunk
                if let hunk = currentHunk {
                    currentFile?.hunks.append(DiffHunk(
                        header: hunk.header,
                        oldStart: hunk.oldStart,
                        oldLines: hunk.oldLines,
                        newStart: hunk.newStart,
                        newLines: hunk.newLines,
                        lines: hunk.lines
                    ))
                }

                // Parse hunk header: @@ -oldStart,oldLines +newStart,newLines @@
                if let regex = hunkHeaderRegex,
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                    let oldStart = Int(line[Range(match.range(at: 1), in: line)!]) ?? 0
                    let oldLines = match.range(at: 2).location != NSNotFound ?
                        Int(line[Range(match.range(at: 2), in: line)!]) ?? 1 : 1
                    let newStart = Int(line[Range(match.range(at: 3), in: line)!]) ?? 0
                    let newLines = match.range(at: 4).location != NSNotFound ?
                        Int(line[Range(match.range(at: 4), in: line)!]) ?? 1 : 1

                    oldLineNum = oldStart
                    newLineNum = newStart

                    currentHunk = (header: line, oldStart: oldStart, oldLines: oldLines, newStart: newStart, newLines: newLines, lines: [])
                }
            } else if line.hasPrefix("\\") {
                // C2: Git marker like "\ No newline at end of file" - skip
                continue
            } else if currentHunk != nil {
                let type: DiffLineType
                var content = line
                var oldNum: Int? = nil
                var newNum: Int? = nil

                if line.hasPrefix("+") {
                    type = .addition
                    content = String(line.dropFirst())
                    newNum = newLineNum
                    newLineNum += 1
                    currentFile?.additions += 1
                } else if line.hasPrefix("-") {
                    type = .deletion
                    content = String(line.dropFirst())
                    oldNum = oldLineNum
                    oldLineNum += 1
                    currentFile?.deletions += 1
                } else if line.hasPrefix(" ") {
                    type = .context
                    content = String(line.dropFirst())
                    oldNum = oldLineNum
                    newNum = newLineNum
                    oldLineNum += 1
                    newLineNum += 1
                } else {
                    type = .context
                    oldNum = oldLineNum
                    newNum = newLineNum
                    oldLineNum += 1
                    newLineNum += 1
                }

                currentHunk?.lines.append(DiffLine(
                    type: type,
                    content: content,
                    oldLineNumber: oldNum,
                    newLineNumber: newNum
                ))
            }
        }

        // Save last file
        if var file = currentFile {
            if var hunk = currentHunk {
                // Add truncation indicator if needed
                if wasTruncated {
                    hunk.lines.append(DiffLine(
                        type: .context,
                        content: "... [Diff truncated - file too large to display fully] ...",
                        oldLineNumber: nil,
                        newLineNumber: nil
                    ))
                }
                file.hunks.append(DiffHunk(
                    header: hunk.header,
                    oldStart: hunk.oldStart,
                    oldLines: hunk.oldLines,
                    newStart: hunk.newStart,
                    newLines: hunk.newLines,
                    lines: hunk.lines
                ))
            }
            files.append(FileDiff(
                oldPath: file.oldPath,
                newPath: file.newPath,
                status: determineStatus(file.oldPath, file.newPath),
                hunks: file.hunks,
                isBinary: isBinary,
                additions: file.additions,
                deletions: file.deletions
            ))
        }

        return files
    }

    private static func determineStatus(_ oldPath: String?, _ newPath: String) -> FileStatusType {
        if oldPath == nil || oldPath == "/dev/null" {
            return .added
        } else if newPath.isEmpty || newPath == "/dev/null" {
            return .deleted
        } else if oldPath != newPath {
            return .renamed
        }
        return .modified
    }
}
