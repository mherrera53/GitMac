import Foundation

/// Manipulates git patches for line-level staging/discarding operations
/// Advanced feature, allows staging or discarding individual lines from a diff
actor PatchManipulator {

    private let shellExecutor = ShellExecutor()

    // MARK: - Public API

    /// Stage a single line from an unstaged diff
    func stageLine(filePath: String, hunk: DiffHunk, lineIndex: Int, repoPath: String) async throws {
        let line = hunk.lines[lineIndex]

        guard line.type != .context && line.type != .hunkHeader else {
            throw PatchError.cannotStageContextLine
        }

        // Generate a minimal patch for just this line
        let patch = try createSingleLinePatch(
            hunk: hunk,
            lineIndex: lineIndex,
            filePath: filePath,
            inverse: false
        )

        // Apply the patch to the staging area
        try await applyPatch(patch, cached: true, reverse: false, repoPath: repoPath)
    }

    /// Discard (revert) a single line from an unstaged diff
    func discardLine(filePath: String, hunk: DiffHunk, lineIndex: Int, repoPath: String) async throws {
        let line = hunk.lines[lineIndex]

        guard line.type != .context && line.type != .hunkHeader else {
            throw PatchError.cannotDiscardContextLine
        }

        // For discard, we apply the inverse patch to the working tree
        let patch = try createSingleLinePatch(
            hunk: hunk,
            lineIndex: lineIndex,
            filePath: filePath,
            inverse: true
        )

        // Apply inverse patch to working tree (not cached)
        try await applyPatch(patch, cached: false, reverse: false, repoPath: repoPath)
    }

    /// Unstage a single line from a staged diff
    func unstageLine(filePath: String, hunk: DiffHunk, lineIndex: Int, repoPath: String) async throws {
        let line = hunk.lines[lineIndex]

        guard line.type != .context && line.type != .hunkHeader else {
            throw PatchError.cannotUnstageContextLine
        }

        // Generate patch and apply with --reverse --cached
        let patch = try createSingleLinePatch(
            hunk: hunk,
            lineIndex: lineIndex,
            filePath: filePath,
            inverse: false
        )

        try await applyPatch(patch, cached: true, reverse: true, repoPath: repoPath)
    }

    // MARK: - Hunk-Level Operations

    /// Stage an entire hunk from an unstaged diff
    func stageHunk(filePath: String, hunk: DiffHunk, repoPath: String) async throws {
        let patch = try createHunkPatch(hunk: hunk, filePath: filePath, inverse: false)
        try await applyPatch(patch, cached: true, reverse: false, repoPath: repoPath)
    }

    /// Discard (revert) an entire hunk from an unstaged diff
    func discardHunk(filePath: String, hunk: DiffHunk, repoPath: String) async throws {
        let patch = try createHunkPatch(hunk: hunk, filePath: filePath, inverse: true)
        try await applyPatch(patch, cached: false, reverse: false, repoPath: repoPath)
    }

    /// Unstage an entire hunk from a staged diff
    func unstageHunk(filePath: String, hunk: DiffHunk, repoPath: String) async throws {
        let patch = try createHunkPatch(hunk: hunk, filePath: filePath, inverse: false)
        try await applyPatch(patch, cached: true, reverse: true, repoPath: repoPath)
    }

    // MARK: - Patch Generation

    /// Creates a patch for an entire hunk
    private func createHunkPatch(
        hunk: DiffHunk,
        filePath: String,
        inverse: Bool
    ) throws -> String {
        var patch = ""

        // File headers
        patch += "--- a/\(filePath)\n"
        patch += "+++ b/\(filePath)\n"

        // Calculate hunk header bounds for inverse if needed
        let oldStart: Int
        let oldLines: Int
        let newStart: Int
        let newLines: Int

        if inverse {
            // When inverting, swap old and new
            oldStart = hunk.newStart
            oldLines = hunk.newLines
            newStart = hunk.oldStart
            newLines = hunk.oldLines
        } else {
            oldStart = hunk.oldStart
            oldLines = hunk.oldLines
            newStart = hunk.newStart
            newLines = hunk.newLines
        }

        // Hunk header
        patch += "@@ -\(oldStart),\(oldLines) +\(newStart),\(newLines) @@\n"

        // Add all lines from the hunk
        for line in hunk.lines {
            switch line.type {
            case .hunkHeader:
                continue // Skip the original hunk header
            case .context:
                patch += " \(line.content)\n"
            case .addition:
                if inverse {
                    patch += "-\(line.content)\n"
                } else {
                    patch += "+\(line.content)\n"
                }
            case .deletion:
                if inverse {
                    patch += "+\(line.content)\n"
                } else {
                    patch += "-\(line.content)\n"
                }
            }
        }

        return patch
    }

    /// Creates a minimal valid unified diff patch for a single line
    private func createSingleLinePatch(
        hunk: DiffHunk,
        lineIndex: Int,
        filePath: String,
        inverse: Bool
    ) throws -> String {
        let targetLine = hunk.lines[lineIndex]

        guard targetLine.type == .addition || targetLine.type == .deletion else {
            throw PatchError.invalidLineType
        }

        // Gather context lines around the target line (git needs context)
        let contextLines = gatherContextForLine(hunk: hunk, targetIndex: lineIndex, maxContext: 3)

        // Calculate line numbers for the new hunk header
        let (oldStart, oldCount, newStart, newCount) = calculateHunkBounds(
            targetLine: targetLine,
            contextBefore: contextLines.before,
            contextAfter: contextLines.after,
            inverse: inverse
        )

        // Build the patch
        var patch = ""

        // File headers
        patch += "--- a/\(filePath)\n"
        patch += "+++ b/\(filePath)\n"

        // Hunk header
        patch += "@@ -\(oldStart),\(oldCount) +\(newStart),\(newCount) @@\n"

        // Context before
        for line in contextLines.before {
            patch += " \(line.content)\n"
        }

        // The target line (potentially inverted)
        if inverse {
            // Invert: addition becomes deletion and vice versa
            if targetLine.type == .addition {
                patch += "-\(targetLine.content)\n"
            } else {
                patch += "+\(targetLine.content)\n"
            }
        } else {
            // Normal patch
            if targetLine.type == .addition {
                patch += "+\(targetLine.content)\n"
            } else {
                patch += "-\(targetLine.content)\n"
            }
        }

        // Context after
        for line in contextLines.after {
            patch += " \(line.content)\n"
        }

        return patch
    }

    /// Gather context lines around a target line
    private func gatherContextForLine(
        hunk: DiffHunk,
        targetIndex: Int,
        maxContext: Int
    ) -> (before: [DiffLine], after: [DiffLine]) {
        var before: [DiffLine] = []
        var after: [DiffLine] = []

        // Gather context BEFORE the target line
        var i = targetIndex - 1
        while i >= 0 && before.count < maxContext {
            let line = hunk.lines[i]
            if line.type == .context {
                before.insert(line, at: 0)
            } else if line.type != .hunkHeader {
                // If we hit another change, we need to include it or stop
                // For simplicity, just stop here
                break
            }
            i -= 1
        }

        // Gather context AFTER the target line
        var j = targetIndex + 1
        while j < hunk.lines.count && after.count < maxContext {
            let line = hunk.lines[j]
            if line.type == .context {
                after.append(line)
            } else if line.type != .hunkHeader {
                // If we hit another change, stop
                break
            }
            j += 1
        }

        return (before, after)
    }

    /// Calculate the hunk header bounds for a single line patch
    private func calculateHunkBounds(
        targetLine: DiffLine,
        contextBefore: [DiffLine],
        contextAfter: [DiffLine],
        inverse: Bool
    ) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int) {
        let contextCount = contextBefore.count + contextAfter.count

        // Determine starting line numbers
        let baseOldLine: Int
        let baseNewLine: Int

        if let firstContext = contextBefore.first {
            baseOldLine = firstContext.oldLineNumber ?? 1
            baseNewLine = firstContext.newLineNumber ?? 1
        } else if targetLine.type == .deletion {
            baseOldLine = targetLine.oldLineNumber ?? 1
            baseNewLine = targetLine.oldLineNumber ?? 1
        } else { // addition
            baseOldLine = targetLine.newLineNumber ?? 1
            baseNewLine = targetLine.newLineNumber ?? 1
        }

        let oldStart = baseOldLine
        let newStart = baseNewLine

        // Calculate counts based on line type and whether inverted
        var oldCount = contextCount
        var newCount = contextCount

        let effectiveType = inverse ?
            (targetLine.type == .addition ? DiffLineType.deletion : DiffLineType.addition) :
            targetLine.type

        if effectiveType == .deletion {
            oldCount += 1
        } else if effectiveType == .addition {
            newCount += 1
        }

        return (oldStart, oldCount, newStart, newCount)
    }

    // MARK: - Patch Application

    /// Apply a patch using git apply
    private func applyPatch(
        _ patch: String,
        cached: Bool,
        reverse: Bool,
        repoPath: String
    ) async throws {
        // Write patch to a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let patchFile = tempDir.appendingPathComponent("gitmac_patch_\(UUID().uuidString).patch")

        do {
            try patch.write(to: patchFile, atomically: true, encoding: .utf8)
        } catch {
            throw PatchError.failedToWritePatch(error.localizedDescription)
        }

        defer {
            try? FileManager.default.removeItem(at: patchFile)
        }

        // Build git apply arguments
        var args = ["apply", "--unidiff-zero", "--verbose"]

        if cached {
            args.append("--cached")
        }

        if reverse {
            args.append("--reverse")
        }

        args.append(patchFile.path)

        // Execute git apply
        let result = await shellExecutor.execute(
            "git",
            arguments: args,
            workingDirectory: repoPath
        )

        guard result.isSuccess else {
            // Try to provide helpful error message
            let errorMsg = result.stderr.isEmpty ? result.stdout : result.stderr
            throw PatchError.applyFailed(errorMsg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

// MARK: - Errors

enum PatchError: LocalizedError {
    case cannotStageContextLine
    case cannotDiscardContextLine
    case cannotUnstageContextLine
    case invalidLineType
    case failedToWritePatch(String)
    case applyFailed(String)
    case invalidHunk

    var errorDescription: String? {
        switch self {
        case .cannotStageContextLine:
            return "Cannot stage context lines (only additions and deletions)"
        case .cannotDiscardContextLine:
            return "Cannot discard context lines (only additions and deletions)"
        case .cannotUnstageContextLine:
            return "Cannot unstage context lines (only additions and deletions)"
        case .invalidLineType:
            return "Invalid line type for patch operation"
        case .failedToWritePatch(let error):
            return "Failed to write patch file: \(error)"
        case .applyFailed(let error):
            return "Git apply failed: \(error)"
        case .invalidHunk:
            return "Invalid hunk structure"
        }
    }
}
