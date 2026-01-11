//
//  ActionButton.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 10))
                Spacer()
            }
            .foregroundColor(isHovered ? AppTheme.textPrimary : AppTheme.textMuted)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isHovered ? AppTheme.hover : Color.clear)
            .cornerRadius(DesignTokens.CornerRadius.sm)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
