import Foundation

/// Represents a Git tag
struct Tag: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let targetSHA: String
    let isAnnotated: Bool
    let message: String?
    let tagger: String?
    let taggerEmail: String?
    let date: Date?

    init(
        name: String,
        targetSHA: String,
        isAnnotated: Bool = false,
        message: String? = nil,
        tagger: String? = nil,
        taggerEmail: String? = nil,
        date: Date? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.targetSHA = targetSHA
        self.isAnnotated = isAnnotated
        self.message = message
        self.tagger = tagger
        self.taggerEmail = taggerEmail
        self.date = date
    }

    var shortSHA: String {
        String(targetSHA.prefix(7))
    }

    var isVersionTag: Bool {
        // Check if tag looks like a version (v1.0.0, 1.0.0, etc.)
        let versionPattern = #"^v?\d+\.\d+(\.\d+)?(-[\w.]+)?$"#
        return name.range(of: versionPattern, options: .regularExpression) != nil
    }

    var version: SemanticVersion? {
        SemanticVersion(from: name)
    }

    var relativeDate: String? {
        guard let date = date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// Semantic version parsing
struct SemanticVersion: Comparable {
    let major: Int
    let minor: Int
    let patch: Int
    let prerelease: String?
    let build: String?

    init?(from string: String) {
        var versionString = string

        // Remove 'v' prefix if present
        if versionString.hasPrefix("v") || versionString.hasPrefix("V") {
            versionString = String(versionString.dropFirst())
        }

        // Split by - for prerelease
        let mainParts = versionString.split(separator: "-", maxSplits: 1)
        let versionPart = String(mainParts[0])
        let prereleasePart = mainParts.count > 1 ? String(mainParts[1]) : nil

        // Split prerelease by + for build metadata
        var prereleaseString: String? = nil
        var buildString: String? = nil

        if let prerelease = prereleasePart {
            let buildParts = prerelease.split(separator: "+", maxSplits: 1)
            prereleaseString = String(buildParts[0])
            buildString = buildParts.count > 1 ? String(buildParts[1]) : nil
        }

        // Parse major.minor.patch
        let numbers = versionPart.split(separator: ".").compactMap { Int($0) }

        guard numbers.count >= 2 else { return nil }

        self.major = numbers[0]
        self.minor = numbers[1]
        self.patch = numbers.count > 2 ? numbers[2] : 0
        self.prerelease = prereleaseString
        self.build = buildString
    }

    var string: String {
        var result = "\(major).\(minor).\(patch)"
        if let prerelease = prerelease {
            result += "-\(prerelease)"
        }
        if let build = build {
            result += "+\(build)"
        }
        return result
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }

        // Prerelease versions have lower precedence
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, _): return false
        case (_, nil): return true
        case let (l?, r?): return l < r
        }
    }
}

/// Tag creation options
struct TagOptions {
    var name: String
    var targetRef: String = "HEAD"
    var message: String?
    var isAnnotated: Bool = true
    var force: Bool = false

    var arguments: [String] {
        var args: [String] = []

        if isAnnotated {
            args.append("-a")
        }

        args.append(name)

        if let message = message {
            args.append("-m")
            args.append(message)
        }

        if force {
            args.append("-f")
        }

        args.append(targetRef)

        return args
    }
}
