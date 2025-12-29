import SwiftUI

// MARK: - Search Bar

/// Reusable search bar component with clear button
/// Used for searching files, commits, branches, etc.
struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSubmit: (() -> Void)? = nil
    var onClear: (() -> Void)? = nil
    var style: SearchStyle = .default

    enum SearchStyle {
        case `default`      // Standard search bar
        case compact        // Smaller, minimal padding
        case prominent      // Larger, more visible
    }

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: style.spacing) {
            Image(systemName: "magnifyingglass")
                .font(style.iconFont)
                .foregroundColor(AppTheme.textMuted)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(style.textFont)
                        .foregroundColor(AppTheme.textMuted)
                }
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .font(style.textFont)
                    .foregroundColor(AppTheme.textPrimary)
                    .focused($isFocused)
                    .onSubmit {
                        onSubmit?()
                    }
            }

            if !text.isEmpty {
                Button {
                    text = ""
                    onClear?()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(style.iconFont)
                        .foregroundColor(AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.vertical, style.verticalPadding)
        .background(backgroundColor)
        .cornerRadius(style.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        isFocused ? AppTheme.accent : AppTheme.border
    }
}

// MARK: - Search Style Extension

extension SearchBar.SearchStyle {
    var spacing: CGFloat {
        switch self {
        case .default: return DesignTokens.Spacing.sm
        case .compact: return DesignTokens.Spacing.md / 2
        case .prominent: return DesignTokens.Spacing.sm + DesignTokens.Spacing.xxs
        }
    }

    var iconFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var textFont: Font {
        switch self {
        case .default: return .body
        case .compact: return .caption
        case .prominent: return .title3
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .default: return DesignTokens.Spacing.md
        case .compact: return DesignTokens.Spacing.sm
        case .prominent: return DesignTokens.Spacing.lg
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .default: return DesignTokens.Spacing.md / 2
        case .compact: return DesignTokens.Spacing.xs
        case .prominent: return DesignTokens.Spacing.sm
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .default: return DesignTokens.CornerRadius.md
        case .compact: return DesignTokens.CornerRadius.sm
        case .prominent: return DesignTokens.CornerRadius.lg
        }
    }
}

// MARK: - Search Bar with Button

/// Search bar with integrated search button
struct SearchBarWithButton: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var buttonTitle: String = "Search"
    var onSearch: () -> Void
    var style: SearchBar.SearchStyle = .default

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            SearchBar(
                text: $text,
                placeholder: placeholder,
                onSubmit: onSearch,
                style: style
            )

            Button(buttonTitle) {
                onSearch()
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.isEmpty)
            .keyboardShortcut(.return)
        }
    }
}

// MARK: - Convenience Initializers

extension SearchBar {
    /// Creates a default search bar
    static func `default`(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: (() -> Void)? = nil
    ) -> SearchBar {
        SearchBar(text: text, placeholder: placeholder, onSubmit: onSubmit, style: .default)
    }

    /// Creates a compact search bar
    static func compact(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: (() -> Void)? = nil
    ) -> SearchBar {
        SearchBar(text: text, placeholder: placeholder, onSubmit: onSubmit, style: .compact)
    }

    /// Creates a prominent search bar
    static func prominent(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: (() -> Void)? = nil
    ) -> SearchBar {
        SearchBar(text: text, placeholder: placeholder, onSubmit: onSubmit, style: .prominent)
    }
}

// MARK: - Preview

#if DEBUG
struct SearchBar_Previews: PreviewProvider {
    @State static var text1 = ""
    @State static var text2 = "sample search"
    @State static var text3 = ""

    static var previews: some View {
        VStack(spacing: 24) {
            // Default style
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Style").font(.headline)
                SearchBar(text: $text1, placeholder: "Search files...")
                SearchBar(text: $text2, placeholder: "Search commits...")
            }

            Divider()

            // Compact style
            VStack(alignment: .leading, spacing: 8) {
                Text("Compact Style").font(.headline)
                SearchBar.compact(text: $text1, placeholder: "Quick search...")
            }

            Divider()

            // Prominent style
            VStack(alignment: .leading, spacing: 8) {
                Text("Prominent Style").font(.headline)
                SearchBar.prominent(text: $text1, placeholder: "Search everywhere...")
            }

            Divider()

            // With button
            VStack(alignment: .leading, spacing: 8) {
                Text("With Button").font(.headline)
                SearchBarWithButton(
                    text: $text3,
                    placeholder: "Enter search query...",
                    onSearch: { print("Searching for: \(text3)") }
                )
            }
        }
        .padding()
        .frame(width: 500)
    }
}
#endif
