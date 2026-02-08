import SwiftUI

// MARK: - Graph Display Settings
@MainActor
class GraphSettings: ObservableObject {
    // Column visibility
    @Published var showBranchColumn = true {
        didSet { saveSettings() }
    }
    @Published var showAuthorColumn = false {
        didSet { saveSettings() }
    }
    @Published var showDateColumn = false {
        didSet { saveSettings() }
    }
    @Published var showSHAColumn = false {
        didSet { saveSettings() }
    }

    // Column widths
    @Published var branchColumnWidth: CGFloat = 140 {
        didSet { saveSettings() }
    }

    // Base graph column width (minimum) - actual width is calculated dynamically
    @Published var baseGraphColumnWidth: CGFloat = 120 {
        didSet { saveSettings() }
    }

    // Maximum lane number in current graph (set by ViewModel)
    @Published var maxLane: Int = 4

    // Available width for responsive layout (set by view)
    @Published var availableWidth: CGFloat = 1200

    // Lane spacing (pixels per lane)
    static let baseLaneWidth: CGFloat = 28
    static let minLaneWidth: CGFloat = 14  // Minimum lane width when compressed
    static let minGraphWidth: CGFloat = 100
    static let maxGraphWidth: CGFloat = 320  // Cap graph width for many branches
    static let lineWidth: CGFloat = 2.5

    // Breakpoints for responsive layout
    static let compactBreakpoint: CGFloat = 900
    static let mediumBreakpoint: CGFloat = 1100

    // Dynamic lane width - scales down when many branches to fit in max width
    var effectiveLaneWidth: CGFloat {
        let laneCount = CGFloat(maxLane + 1)
        let idealWidth = laneCount * Self.baseLaneWidth + 24

        if idealWidth > Self.maxGraphWidth {
            // Scale down lanes to fit
            let availableForLanes = Self.maxGraphWidth - 24
            return max(availableForLanes / laneCount, Self.minLaneWidth)
        }
        return Self.baseLaneWidth
    }

    // Dynamic graph column width based on max lanes (uses effective lane width)
    var graphColumnWidth: CGFloat {
        let laneCount = CGFloat(maxLane + 1)
        let calculatedWidth = laneCount * effectiveLaneWidth + 24
        let baseWidth = max(calculatedWidth, Self.minGraphWidth)

        // Further reduce on small screens
        if availableWidth < Self.compactBreakpoint {
            return min(baseWidth * 0.8, 200) * zoomLevel
        }
        return baseWidth * zoomLevel
    }

    // Responsive column visibility
    var shouldShowAuthorColumn: Bool {
        showAuthorColumn && availableWidth > Self.compactBreakpoint
    }

    var shouldShowDateColumn: Bool {
        showDateColumn && availableWidth > Self.mediumBreakpoint
    }

    var shouldShowSHAColumn: Bool {
        showSHAColumn && availableWidth > Self.mediumBreakpoint
    }

    var shouldShowBranchColumn: Bool {
        showBranchColumn
    }

    // Responsive branch column width
    var responsiveBranchColumnWidth: CGFloat {
        if availableWidth < Self.compactBreakpoint {
            return min(branchColumnWidth, 100)
        }
        return branchColumnWidth
    }

    // Responsive changes indicator width
    @Published var changesColumnWidth: CGFloat = 140 {
        didSet { saveSettings() }
    }

    var responsiveChangesColumnWidth: CGFloat {
        if availableWidth < Self.compactBreakpoint {
            return min(changesColumnWidth, 80)
        }
        return changesColumnWidth
    }
    @Published var authorColumnWidth: CGFloat = 120 {
        didSet { saveSettings() }
    }
    @Published var dateColumnWidth: CGFloat = 100 {
        didSet { saveSettings() }
    }
    @Published var shaColumnWidth: CGFloat = 80 {
        didSet { saveSettings() }
    }

    // Display preferences
    @Published var showAvatars = true {
        didSet { saveSettings() }
    }
    @Published var showInitials = false {
        didSet { saveSettings() }
    }
    @Published var compactMode = false {
        didSet { saveSettings() }
    }
    @Published var dimMergeCommits = false {
        didSet { saveSettings() }
    }

    // Zoom level (0.5 to 2.0, default 1.0)
    static let zoomMin: CGFloat = 0.5
    static let zoomMax: CGFloat = 2.0
    static let zoomStep: CGFloat = 0.1

    @Published var zoomLevel: CGFloat = 1.0 {
        didSet {
            // Clamp value without recursion
            let clamped = min(max(zoomLevel, Self.zoomMin), Self.zoomMax)
            if zoomLevel != clamped {
                zoomLevel = clamped
                return // saveSettings will be called on the recursive didSet
            }
            if oldValue != zoomLevel {
                saveSettings()
            }
        }
    }

    func zoomIn() {
        zoomLevel = min(zoomLevel + Self.zoomStep, Self.zoomMax)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - Self.zoomStep, Self.zoomMin)
    }

    func resetZoom() {
        zoomLevel = 1.0
    }

    // Filtering
    @Published var showTags = true
    @Published var showBranches = true
    @Published var showStashes = true
    @Published var filterAuthor: String = ""
    @Published var searchText: String = ""

    // Repository path for persistence
    private var repositoryPath: String = ""
    private let defaults = UserDefaults.standard

    // Computed properties (scaled by zoom)
    var rowHeight: CGFloat {
        let base: CGFloat = compactMode ? 32 : 44
        return base * zoomLevel
    }

    var nodeRadius: CGFloat {
        let base: CGFloat = compactMode ? 10 : 14
        return base * zoomLevel
    }

    var avatarSize: CGFloat {
        let base: CGFloat = compactMode ? 18 : 26
        return base * zoomLevel
    }

    var fontSize: CGFloat {
        let base: CGFloat = compactMode ? 11 : 13
        return base * zoomLevel
    }

    var zoomPercentage: Int {
        Int(round(zoomLevel * 100))
    }

    // MARK: - Persistence
    func setRepository(_ path: String) {
        self.repositoryPath = path
        loadSettings()
    }

    private func saveSettings() {
        guard !repositoryPath.isEmpty else { return }

        let key = "graphSettings_\(repositoryPath)"
        let settings: [String: Any] = [
            "showBranchColumn": showBranchColumn,
            "showAuthorColumn": showAuthorColumn,
            "showDateColumn": showDateColumn,
            "showSHAColumn": showSHAColumn,
            "branchColumnWidth": branchColumnWidth,
            "baseGraphColumnWidth": baseGraphColumnWidth,
            "changesColumnWidth": changesColumnWidth,
            "authorColumnWidth": authorColumnWidth,
            "dateColumnWidth": dateColumnWidth,
            "shaColumnWidth": shaColumnWidth,
            "showAvatars": showAvatars,
            "showInitials": showInitials,
            "compactMode": compactMode,
            "dimMergeCommits": dimMergeCommits,
            "zoomLevel": zoomLevel
        ]
        defaults.set(settings, forKey: key)
    }

    private func loadSettings() {
        guard !repositoryPath.isEmpty else { return }

        let key = "graphSettings_\(repositoryPath)"
        guard let settings = defaults.dictionary(forKey: key) else { return }

        if let value = settings["showBranchColumn"] as? Bool {
            showBranchColumn = value
        }
        if let value = settings["showAuthorColumn"] as? Bool {
            showAuthorColumn = value
        }
        if let value = settings["showDateColumn"] as? Bool {
            showDateColumn = value
        }
        if let value = settings["showSHAColumn"] as? Bool {
            showSHAColumn = value
        }
        if let value = settings["branchColumnWidth"] as? CGFloat {
            branchColumnWidth = value
        }
        if let value = settings["baseGraphColumnWidth"] as? CGFloat {
            baseGraphColumnWidth = value
        }
        if let value = settings["changesColumnWidth"] as? CGFloat {
            changesColumnWidth = value
        }
        if let value = settings["authorColumnWidth"] as? CGFloat {
            authorColumnWidth = value
        }
        if let value = settings["dateColumnWidth"] as? CGFloat {
            dateColumnWidth = value
        }
        if let value = settings["shaColumnWidth"] as? CGFloat {
            shaColumnWidth = value
        }
        if let value = settings["showAvatars"] as? Bool {
            showAvatars = value
        }
        if let value = settings["showInitials"] as? Bool {
            showInitials = value
        }
        if let value = settings["compactMode"] as? Bool {
            compactMode = value
        }
        if let value = settings["dimMergeCommits"] as? Bool {
            dimMergeCommits = value
        }
        if let value = settings["zoomLevel"] as? CGFloat {
            zoomLevel = value
        }
    }
}
