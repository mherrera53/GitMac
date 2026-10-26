import Foundation
import Darwin
@testable import GitMac

private final class CapturedText: @unchecked Sendable {
    private let lock = NSLock()
    private var value = ""
    func append(_ text: String) { lock.withLock { value += text } }
    var text: String { lock.withLock { value } }
}

@main struct ProcessIntegration {
    static func main() async throws {
        let shell = ShellExecutor.shared
        var failures = 0
        func check(_ condition: Bool, _ label: String) {
            print("\(condition ? "PASS" : "FAIL") \(label)")
            if !condition { failures += 1 }
        }
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("gitmac-process-\(UUID())'s fixture")
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: fixture) }

        let flood = await shell.execute("/bin/sh", arguments: ["-c",
            "/usr/bin/head -c 262144 /dev/zero & /usr/bin/head -c 262144 /dev/zero >&2 & wait"], timeout: 10)
        check(flood.isSuccess && flood.stdout.utf8.count == 262144 && flood.stderr.utf8.count == 262144,
              "F13 both full pipes drain concurrently without data loss")
        let literal = "literal '; echo not-a-command; # ñ"
        let rawBytes = Data([0, 1, 13, 10, 255, 254, 195, 177, 0])
        let rawFile = fixture.appendingPathComponent("raw blob.bin")
        try rawBytes.write(to: rawFile)
        let raw = await shell.executeData("/bin/cat", arguments: [rawFile.path])
        check(raw.isSuccess && raw.stdout.isEmpty && raw.stdoutData == rawBytes,
              "F13 binary capture preserves NUL, CRLF and invalid UTF8 exactly")
        let rawCapped = await shell.executeData("/usr/bin/head", arguments: ["-c", "1048576", "/dev/zero"], maxOutputBytes: 4096)
        check(rawCapped.termination == .outputLimitExceeded && !rawCapped.isSuccess && rawCapped.stdoutData?.count == 4096,
              "F13 binary capture rejects truncation with the same typed output limit")
        let arguments = await shell.execute("/usr/bin/printf", arguments: ["%s", literal])
        check(arguments.stdout == literal && arguments.isSuccess, "F13 argv remains literal")
        check(arguments.stdoutData == nil, "F13 text callers retain no duplicate binary capture")
        let cwd = await shell.execute("/bin/pwd", workingDirectory: fixture.path)
        let reportedDirectory = cwd.stdout.trimmingCharacters(in: .newlines)
        let expectedIdentity = try FileManager.default.attributesOfItem(atPath: fixture.path)
        let actualIdentity = try FileManager.default.attributesOfItem(atPath: reportedDirectory)
        check(cwd.isSuccess && expectedIdentity[.systemFileNumber] as? NSNumber == actualIdentity[.systemFileNumber] as? NSNumber
              && expectedIdentity[.systemNumber] as? NSNumber == actualIdentity[.systemNumber] as? NSNumber,
              "F13 quoted working directory identifies the same directory across macOS path aliases")
        let environment = await shell.execute("/bin/sh", arguments: ["-c", "printf %s \"$GITMAC_FIXTURE\""], environment: ["GITMAC_FIXTURE": "environment ñ"])
        check(environment.stdout == "environment ñ", "F13 per-operation environment override")
        let missing = await shell.execute("gitmac-nonexistent-fixture-command")
        check(!missing.isSuccess && !missing.stderr.isEmpty, "F13 missing executable fails explicitly")
        let badDirectory = await shell.execute("/bin/true", workingDirectory: fixture.appendingPathComponent("missing").path)
        check(badDirectory.termination == .launchFailed, "F13 invalid cwd is a launch failure")
        let error = await shell.execute("/bin/sh", arguments: ["-c", "printf 'diagnostic' >&2; exit 7"])
        check(error.exitCode == 7 && error.stderr == "diagnostic", "F13 preserves stderr and nonzero exit status")
        let capped = await shell.execute("/usr/bin/head", arguments: ["-c", "1048576", "/dev/zero"], maxOutputBytes: 4096)
        check(!capped.isSuccess && capped.termination == .outputLimitExceeded && capped.stdout.utf8.count == 4096,
              "F13 bounded capture never silently succeeds with truncated output")
        let timed = await shell.execute("/bin/sleep", arguments: ["3"], timeout: 0.1)
        check(timed.termination == .timedOut && !timed.isSuccess, "F13 timeout is typed and non-success")
        let start = Date()
        let operation = Task { await shell.execute("/bin/sleep", arguments: ["3"]) }
        try await Task.sleep(nanoseconds: 100_000_000)
        operation.cancel()
        let cancelled = await operation.value
        check(cancelled.termination == .cancelled && Date().timeIntervalSince(start) < 2,
              "F13 task cancellation stops the operation promptly")

        // The leader exits immediately; a TERM-ignoring child holds both pipes.
        // This used to hang after the executor cancelled its timeout at leader exit.
        let orphanStart = Date()
        let descendant = await shell.execute("/bin/sh", arguments: ["-c",
            "(trap '' TERM; echo child=$$; /bin/sleep 10) & exit 0"], timeout: 0.1)
        check(descendant.termination == .timedOut && Date().timeIntervalSince(orphanStart) < 2,
              "F13 deadline remains active after leader exit until inherited pipes close")

        let stdout = CapturedText(), stderr = CapturedText()
        let callbackCode = await shell.executeWithStreaming("/bin/sh", arguments: ["-c",
            #"printf '\303'; /bin/sleep .05; printf '\261'; printf '\342' >&2; /bin/sleep .05; printf '\202\254' >&2; printf final"#],
            onOutput: { stdout.append($0) }, onError: { stderr.append($0) })
        check(callbackCode == 0 && stdout.text == "ñfinal" && stderr.text == "€",
              "F13 callbacks preserve split UTF-8 and final pipe output")
        var lines: [String] = []
        for try await line in shell.executeStreaming("/usr/bin/printf", arguments: ["uno\r\nñ\nfinal"], bufferSize: 1) { lines.append(line) }
        check(lines == ["uno", "ñ", "final"], "F13 streaming preserves UTF-8, CRLF and last line without newline")
        do {
            for try await _ in shell.executeStreaming("/bin/sh", arguments: ["-c", "printf 'stream diagnostic' >&2; exit 9"]) {}
            check(false, "F13 stream propagates process failure")
        } catch { check(error.localizedDescription.contains("stream diagnostic"), "F13 stream propagates process failure and diagnostic") }
        do {
            for try await _ in shell.executeStreaming("/usr/bin/head", arguments: ["-c", "2097152", "/dev/zero"]) {}
            check(false, "F13 oversized line has a visible bounded-output failure")
        } catch { check(error.localizedDescription.contains("limit"), "F13 oversized line has a visible bounded-output failure") }

        let marker = fixture.appendingPathComponent("producer-finished")
        let stream = shell.executeStreaming("/bin/sh", arguments: ["-c",
            #"/usr/bin/seq 1 30000; printf done > "$1""#, "fixture", marker.path], bufferSize: 8)
        var iterator = stream.makeAsyncIterator()
        check(try await iterator.next() == "1", "F13 bounded stream starts yielding immediately")
        try await Task.sleep(nanoseconds: 500_000_000)
        check(!FileManager.default.fileExists(atPath: marker.path), "F13 slow consumer backpressures producer rather than buffering all output")
        var count = 1
        while let line = try await iterator.next() {
            count += 1
            if line != String(count) { failures += 1 }
        }
        check(count == 30000 && FileManager.default.fileExists(atPath: marker.path), "F13 backpressure preserves every line in order")
        let streaming = Task {
            do {
                for try await _ in shell.executeStreaming("/bin/sh", arguments: ["-c", "echo started; /bin/sleep 10"], bufferSize: 1) {}
            } catch {}
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        let streamCancelStart = Date()
        streaming.cancel()
        await streaming.value
        check(Date().timeIntervalSince(streamCancelStart) < 2, "F13 cancelled stream terminates promptly")
        let sequence = await shell.executeSequence([("/bin/false", []), ("/bin/true", [])])
        check(sequence.count == 1 && !sequence[0].isSuccess, "F13 command sequence stops at the first failure")

        print("\(failures) process integration failures")
        if failures != 0 { exit(1) }
        print("PROCESS INTEGRATION PASSED")
    }
}
