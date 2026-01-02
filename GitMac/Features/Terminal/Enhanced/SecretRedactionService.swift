//
//  SecretRedactionService.swift
//  GitMac
//
//  Auto-redact sensitive information in terminal output
//

import Foundation
import SwiftUI

// MARK: - Secret Pattern Types

enum SecretType: String, CaseIterable {
    case apiKey = "API Key"
    case password = "Password"
    case token = "Token"
    case privateKey = "Private Key"
    case awsKey = "AWS Key"
    case githubToken = "GitHub Token"
    case jwt = "JWT"
    case connectionString = "Connection String"
    case creditCard = "Credit Card"
    case ssn = "SSN"

    var icon: String {
        switch self {
        case .apiKey, .token, .githubToken, .jwt:
            return "key.fill"
        case .password:
            return "lock.fill"
        case .privateKey:
            return "key.radiowaves.forward.fill"
        case .awsKey:
            return "cloud.fill"
        case .connectionString:
            return "link.circle.fill"
        case .creditCard, .ssn:
            return "creditcard.fill"
        }
    }
}

struct RedactedSecret: Identifiable {
    let id = UUID()
    let type: SecretType
    let range: NSRange
    let originalText: String
    var isRevealed: Bool = false
}

// MARK: - Secret Redaction Service

@MainActor
class SecretRedactionService {
    static let shared = SecretRedactionService()

    private init() {}

    // Regex patterns for different secret types
    private let patterns: [SecretType: [String]] = [
        .apiKey: [
            "(?i)(api[_-]?key|apikey|api[_-]?token)[\\s:=\"']+([A-Za-z0-9_\\-]{20,})",
            "(?i)(sk|pk)[_-][a-z0-9]{48,}",
            "AIza[0-9A-Za-z\\-_]{35}" // Google API
        ],
        .password: [
            "(?i)(password|passwd|pwd)[\\s:=\"']+([^\\s\"']{8,})",
            "(?i)PASS[\\s:=\"']+([^\\s\"']{8,})"
        ],
        .token: [
            "(?i)(bearer|token)[\\s:=\"']+([A-Za-z0-9_\\-\\.]{20,})",
            "(?i)(access[_-]?token|auth[_-]?token)[\\s:=\"']+([A-Za-z0-9_\\-]{20,})"
        ],
        .privateKey: [
            "-----BEGIN (RSA |DSA |EC )?PRIVATE KEY-----",
            "-----BEGIN OPENSSH PRIVATE KEY-----"
        ],
        .awsKey: [
            "AKIA[0-9A-Z]{16}", // AWS Access Key
            "(?i)aws[_-]?secret[_-]?access[_-]?key[\\s:=\"']+([A-Za-z0-9/+=]{40})"
        ],
        .githubToken: [
            "ghp_[A-Za-z0-9]{36}", // GitHub Personal Access Token
            "gho_[A-Za-z0-9]{36}", // GitHub OAuth Token
            "ghs_[A-Za-z0-9]{36}"  // GitHub Server Token
        ],
        .jwt: [
            "eyJ[A-Za-z0-9_-]*\\.eyJ[A-Za-z0-9_-]*\\.[A-Za-z0-9_-]*"
        ],
        .connectionString: [
            "(?i)(mongodb|mysql|postgres|postgresql):\\/\\/[^\\s\"']+:[^\\s\"']+@",
            "(?i)(server|host|hostname)[\\s=]+[^;\\s]+;.*password[\\s=]+[^;\\s]+"
        ],
        .creditCard: [
            "\\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13})\\b"
        ],
        .ssn: [
            "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        ]
    ]

    // MARK: - Redaction

    func redactSecrets(in text: String) -> (redactedText: String, secrets: [RedactedSecret]) {
        var redactedText = text
        var secrets: [RedactedSecret] = []
        var offset = 0

        for (type, patternList) in patterns {
            for pattern in patternList {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

                for match in matches {
                    guard match.range.location != NSNotFound else { continue }

                    // Adjust range for previous redactions
                    let adjustedRange = NSRange(
                        location: match.range.location - offset,
                        length: match.range.length
                    )

                    // Get original text
                    guard let swiftRange = Range(match.range, in: text),
                          let originalText = String(text[swiftRange]).isEmpty ? nil : String(text[swiftRange]) else {
                        continue
                    }

                    // Create redacted replacement
                    let redactedReplacement = createRedactedText(for: type, length: match.range.length)

                    // Replace in redacted text
                    if let redactedRange = Range(adjustedRange, in: redactedText) {
                        redactedText.replaceSubrange(redactedRange, with: redactedReplacement)

                        // Track secret
                        let secret = RedactedSecret(
                            type: type,
                            range: adjustedRange,
                            originalText: originalText
                        )
                        secrets.append(secret)

                        // Update offset
                        offset += match.range.length - redactedReplacement.count
                    }
                }
            }
        }

        return (redactedText, secrets)
    }

    private func createRedactedText(for type: SecretType, length: Int) -> String {
        let icon = type.icon
        let dots = String(repeating: "•", count: min(length, 20))
        return "[\(type.rawValue): \(dots)]"
    }

    // MARK: - Pattern Detection

    func detectSecretType(in text: String) -> SecretType? {
        for (type, patternList) in patterns {
            for pattern in patternList {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, range: range) != nil {
                    return type
                }
            }
        }
        return nil
    }

    func shouldRedact(command: String) -> Bool {
        let sensitiveCommands = ["export", "set", "echo", "cat", "print", "printf"]
        let lowerCommand = command.lowercased()

        return sensitiveCommands.contains { lowerCommand.hasPrefix($0) }
    }
}

// MARK: - Attributed String with Redaction

extension String {
    func redactingSecrets() -> NSAttributedString {
        let (redactedText, secrets) = SecretRedactionService.shared.redactSecrets(in: self)

        let attributed = NSMutableAttributedString(string: redactedText)

        for secret in secrets {
            let range = secret.range

            // Apply blur/redaction styling
            attributed.addAttribute(.backgroundColor,
                                   value: NSColor.systemRed.withAlphaComponent(0.2),
                                   range: range)
            attributed.addAttribute(.foregroundColor,
                                   value: NSColor.systemRed,
                                   range: range)
        }

        return attributed
    }
}
