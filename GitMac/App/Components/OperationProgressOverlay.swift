//
//  OperationProgressOverlay.swift
//  GitMac
//
//  Extracted from ContentView.swift
//

import SwiftUI

// MARK: - Operation Progress Overlay
struct OperationProgressOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            AppTheme.background.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.backgroundSecondary)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            )
        }
    }
}
