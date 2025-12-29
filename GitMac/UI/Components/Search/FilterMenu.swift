import SwiftUI

// MARK: - Filter Menu

/// A menu for filtering items by file extension or other criteria
struct FilterMenu: View {
    let extensions: [String]
    let extensionCounts: [String: Int]
    @Binding var selectedExtension: String?

    var body: some View {
        Menu {
            Button {
                selectedExtension = nil
            } label: {
                HStack {
                    Text("All Files")
                    Spacer()
                    if selectedExtension == nil {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }

            if !extensions.isEmpty {
                Divider()

                ForEach(extensions, id: \.self) { ext in
                    Button {
                        selectedExtension = ext
                    } label: {
                        HStack {
                            Text(".\(ext)")
                            Spacer()
                            if let count = extensionCounts[ext] {
                                Text("(\(count))")
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            if selectedExtension == ext {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14))
                Text(selectedExtension.map { ".\($0)" } ?? "All")
                    .font(.system(size: 11))
            }
            .foregroundColor(AppTheme.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .help("Filter by file extension")
    }
}

// MARK: - Extension Filter Badge

/// A compact badge showing the current filter
struct FilterBadge: View {
    let selectedExtension: String?
    let onClear: () -> Void

    var body: some View {
        if let ext = selectedExtension {
            HStack(spacing: 4) {
                Text(".\(ext)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Clear filter")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.backgroundTertiary)
            .cornerRadius(LayoutConstants.CornerRadius.sm)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FilterMenu_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            FilterMenu(
                extensions: ["swift", "js", "ts", "py", "md"],
                extensionCounts: [
                    "swift": 42,
                    "js": 18,
                    "ts": 25,
                    "py": 7,
                    "md": 3
                ],
                selectedExtension: .constant(nil)
            )

            FilterMenu(
                extensions: ["swift", "js", "ts"],
                extensionCounts: ["swift": 10, "js": 5, "ts": 8],
                selectedExtension: .constant("swift")
            )

            HStack {
                Text("Filtered:")
                FilterBadge(selectedExtension: "swift", onClear: {})
            }
        }
        .padding()
        .frame(width: 300)
    }
}
#endif
