import SwiftUI

/// Notification Manager - Toast notifications system
/// Displays success, error, warning, and info messages
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [ToastNotification] = []
    
    private let maxNotifications = 5
    private let defaultDuration: TimeInterval = 4.0
    
    init() {
        // Listen to global notifications
        setupNotificationObservers()
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
        withAnimation(.easeOut(duration: 0.2)) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    func dismissAll() {
        withAnimation(.easeOut(duration: 0.2)) {
            notifications.removeAll()
        }
    }
    
    // MARK: - Private
    
    private func addNotification(_ notification: ToastNotification) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Remove oldest if at max
            if notifications.count >= maxNotifications {
                notifications.removeFirst()
            }
            
            notifications.append(notification)
        }
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) { [weak self] in
            self?.dismiss(notification)
        }
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
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

// MARK: - Toast View

struct ToastNotificationView: View {
    let notification: ToastNotification
    let onDismiss: () -> Void
    
    @State private var isHovered = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: notification.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(notification.type.color)
                
                // Message
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(notification.message.components(separatedBy: "\n"), id: \.self) { line in
                        Text(line)
                            .font(line == notification.message.components(separatedBy: "\n").first ? .body : .caption)
                            .foregroundColor(line == notification.message.components(separatedBy: "\n").first ? .primary : .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Close button (on hover)
                if isHovered {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Action button for error recovery with explanation
            if notification.hasAction, let title = notification.actionTitle {
                Divider()
                
                VStack(alignment: .leading, spacing: 6) {
                    if let hint = notification.actionHint {
                        Text("💡 \(hint)")
                            .font(.caption)
                            .foregroundColor(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Button {
                        notification.performAction()
                        onDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(AppTheme.info)
                            Text(title)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(notification.type.color)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.type.color.opacity(0.5), lineWidth: 2)
        )
        .frame(width: 380)
        .offset(x: dragOffset)
        .onHover { isHovered = $0 }
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    if abs(value.translation.width) > 100 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

// MARK: - Toast Container View

struct ToastContainer: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.notifications) { notification in
                ToastNotificationView(notification: notification) {
                    notificationManager.dismiss(notification)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding()
    }
}

// MARK: - View Extension

extension View {
    func withToastNotifications() -> some View {
        ZStack(alignment: .topTrailing) {
            self
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
                    message: "Operation completed successfully",
                    type: .success,
                    duration: 4.0
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
