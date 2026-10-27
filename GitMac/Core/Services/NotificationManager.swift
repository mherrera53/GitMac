import SwiftUI
import AppKit

/// Notification Manager - Toast notifications system
/// Displays success, error, warning, and info messages
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var notifications: [ToastNotification] = []
    @Published var lastAction: LastAction?

    @AppStorage("notificationSounds") var soundsEnabled: Bool = false

    private let maxNotifications = 5
    private let defaultDuration: TimeInterval = 6.0
    private var dismissalTasks: [UUID: Task<Void, Never>] = [:]

    /// Tracks the last action performed for retry functionality
    struct LastAction {
        let name: String
        let timestamp: Date
        let retryAction: (() async -> Void)?

        var displayTime: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: timestamp, relativeTo: Date())
        }
    }

    init(defaults: UserDefaults = .standard, observeNotifications: Bool = true) {
        _soundsEnabled = AppStorage(wrappedValue: false, "notificationSounds", store: defaults)
        if observeNotifications { setupNotificationObservers() }
    }

    /// Record an action for potential retry
    func recordAction(_ name: String, retry: (() async -> Void)? = nil) {
        lastAction = LastAction(name: name, timestamp: Date(), retryAction: retry)
    }

    /// Retry the last action if available
    func retryLastAction() {
        guard let action = lastAction?.retryAction else { return }
        Task {
            await action()
        }
    }
    
    // MARK: - Public API
    
    func show(_ message: String, type: NotificationType = .info, duration: TimeInterval? = nil) {
        let notification = ToastNotification(
            message: message,
            type: type,
            duration: duration ?? defaultDuration
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.addNotification(notification)
        }
    }
    
    func success(_ message: String, detail: String? = nil) {
        show(detail.map { "\(message)\n\($0)" } ?? message, type: .success)
    }
    
    func error(_ message: String, detail: String? = nil) {
        // A previous operation is not evidence that it caused this error.
        // Recovery must be supplied explicitly by the operation that failed.
        show(detail.map { "\(message)\n\($0)" } ?? message, type: .error, duration: 8.0)
    }

    /// Show error without retry option
    func errorSimple(_ message: String, detail: String? = nil) {
        show(detail.map { "\(message)\n\($0)" } ?? message, type: .error, duration: 6.0)
    }
    
    func warning(_ message: String, detail: String? = nil) {
        show(detail.map { "\(message)\n\($0)" } ?? message, type: .warning, duration: 5.0)
    }
    
    func info(_ message: String, detail: String? = nil) {
        show(detail.map { "\(message)\n\($0)" } ?? message, type: .info)
    }
    
    /// Show error with suggested fix action button
    func errorWithFix(
        _ message: String,
        detail: String? = nil,
        fixTitle: String,
        fixHint: String,
        fixAction: @escaping () -> Void
    ) {
        let fullMessage = detail.map { "\(message)\n\($0)" } ?? message
        let notification = ToastNotification(
            message: fullMessage,
            type: .error,
            duration: 10.0, // Longer for actionable notifications
            actionTitle: fixTitle,
            actionHint: fixHint,
            action: fixAction
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.addNotification(notification)
        }
    }
    
    func dismiss(_ notification: ToastNotification) {
        dismissalTasks.removeValue(forKey: notification.id)?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    func dismissAll() {
        dismissalTasks.values.forEach { $0.cancel() }
        dismissalTasks.removeAll()
        withAnimation(.easeOut(duration: 0.2)) {
            notifications.removeAll()
        }
    }
    
    // MARK: - Private
    
    private func addNotification(_ notification: ToastNotification) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Remove oldest if at max
            if notifications.count >= maxNotifications {
                let removed = notifications.removeFirst()
                dismissalTasks.removeValue(forKey: removed.id)?.cancel()
            }

            notifications.append(notification)
        }

        // Play sound if enabled
        if soundsEnabled {
            playSound(for: notification.type)
        }

        // Recovery actions stay available until acted on or dismissed explicitly.
        guard !notification.hasAction else { return }
        let duration = notification.duration.isFinite ? max(1, min(notification.duration, 60)) : defaultDuration
        dismissalTasks[notification.id] = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
            catch { return }
            self?.dismiss(notification)
        }
    }

    private func playSound(for type: NotificationType) {
        let soundName: NSSound.Name
        switch type {
        case .success:
            soundName = "Glass"
        case .error:
            soundName = "Basso"
        case .warning:
            soundName = "Purr"
        case .info:
            soundName = "Pop"
        }
        NSSound(named: soundName)?.play()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .showNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let message = notification.object as? NotificationMessage {
                Task { @MainActor in
                    switch message.type {
                    case .success:
                        self?.success(message.message, detail: message.detail)
                    case .error:
                        self?.error(message.message, detail: message.detail)
                    case .warning:
                        self?.warning(message.message, detail: message.detail)
                    case .info:
                        self?.info(message.message, detail: message.detail)
                    }
                }
            }
        }
    }
}

// MARK: - Toast Notification Model

struct ToastNotification: Identifiable, Equatable {
    let id: UUID
    let message: String
    let type: NotificationType
    let duration: TimeInterval
    let timestamp: Date
    
    // Action button for error recovery
    let actionTitle: String?
    let actionHint: String?
    private let actionHandler: (() -> Void)?
    
    var hasAction: Bool { actionTitle != nil && actionHandler != nil }
    
    init(message: String, type: NotificationType, duration: TimeInterval, actionTitle: String? = nil, actionHint: String? = nil, action: (() -> Void)? = nil) {
        self.id = UUID()
        self.message = message
        self.type = type
        self.duration = duration
        self.timestamp = Date()
        self.actionTitle = actionTitle
        self.actionHint = actionHint
        self.actionHandler = action
    }
    
    func performAction() {
        actionHandler?()
    }
    
    static func == (lhs: ToastNotification, rhs: ToastNotification) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Notification Type

enum NotificationType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    @MainActor var color: Color {
        switch self {
        case .success: return AppTheme.success
        case .error: return AppTheme.error
        case .warning: return AppTheme.warning
        case .info: return AppTheme.info
        }
    }
}

// MARK: - Toast View

@MainActor enum ToastAppearance {
    /// Flatten custom alpha onto the window surface: content behind a toast must never show through.
    static var surface: Color {
        let window = CodableColor(Color(nsColor: .windowBackgroundColor))
        let base = CodableColor(AppTheme.background).composited(over: window)
        return CodableColor(AppTheme.backgroundSecondary).composited(over: base).color
    }
    static var text: Color { AppTheme.readableTextColor(preferred: AppTheme.textPrimary, on: surface) }
    static var secondaryText: Color { AppTheme.readableTextColor(preferred: AppTheme.textSecondary, on: surface) }
    static func status(_ type: NotificationType) -> Color {
        AppTheme.readableTextColor(preferred: type.color, on: surface)
    }
}

struct ToastNotificationView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let notification: ToastNotification
    let onDismiss: () -> Void
    var icon: String? = nil
    @State private var timeRemaining: CGFloat = 1.0

    private var title: String { notification.message.components(separatedBy: "\n").first ?? notification.message }
    private var subtitle: String? {
        let lines = notification.message.components(separatedBy: "\n")
        return lines.count > 1 ? lines.dropFirst().joined(separator: "\n") : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon ?? notification.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ToastAppearance.status(notification.type))
                    .frame(width: 20, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ToastAppearance.text).lineLimit(3)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12))
                            .foregroundStyle(ToastAppearance.secondaryText).lineLimit(5)
                    }
                    if notification.hasAction, let actionTitle = notification.actionTitle {
                        Button {
                            notification.performAction()
                            onDismiss()
                        } label: {
                            Text(actionTitle).font(.system(size: 12, weight: .medium))
                                .foregroundStyle(ToastAppearance.text)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .help(notification.actionHint ?? actionTitle)
                        .accessibilityIdentifier("toast-recovery-action")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                Button(action: onDismiss) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ToastAppearance.secondaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).help("Dismiss notification")
                .accessibilityLabel("Dismiss notification")
                .accessibilityIdentifier("dismiss-toast")
            }
            .padding(12)
            if !notification.hasAction {
                GeometryReader { geometry in
                    Rectangle().fill(ToastAppearance.status(notification.type))
                        .frame(width: geometry.size.width * timeRemaining)
                }
                .frame(height: 2).accessibilityHidden(true)
            }
        }
        .background(ToastAppearance.surface)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .help(notification.message)
        .onAppear {
            guard !notification.hasAction else { return }
            if reduceMotion { timeRemaining = 0 }
            else { withAnimation(.linear(duration: notification.duration)) { timeRemaining = 0 } }
        }
    }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).capitalized + dropFirst()
    }
}

// MARK: - Toast Container View

struct ToastContainer: View {
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.notifications) { notification in
                ToastNotificationView(
                    notification: notification,
                    onDismiss: {
                        notificationManager.dismiss(notification)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .frame(maxWidth: 520)
        .padding(12)
        .allowsHitTesting(!notificationManager.notifications.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: notificationManager.notifications.count)
    }
}

extension View {
    func withToastNotifications() -> some View {
        overlay(alignment: .topTrailing) {
            ToastContainer()
        }
    }
}

// MARK: - SwiftUI Preview

struct ToastNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ToastNotificationView(
                notification: ToastNotification(
                    message: "Successfully committed changes",
                    type: .success,
                    duration: 5.0
                ),
                onDismiss: {}
            )
            
            ToastNotificationView(
                notification: ToastNotification(
                    message: "Failed to push to remote\nCheck your network connection",
                    type: .error,
                    duration: 6.0
                ),
                onDismiss: {}
            )
            
            ToastNotificationView(
                notification: ToastNotification(
                    message: "Uncommitted changes detected",
                    type: .warning,
                    duration: 5.0
                ),
                onDismiss: {}
            )
            
            ToastNotificationView(
                notification: ToastNotification(
                    message: "Fetching updates from remote",
                    type: .info,
                    duration: 4.0
                ),
                onDismiss: {}
            )
        }
        .padding()
        .frame(width: 400, height: 600)
    }
}
