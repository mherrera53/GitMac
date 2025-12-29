//
//  DSAvatar.swift
//  GitMac
//
//  Created on 2025-12-28.
//

import SwiftUI

/// Avatar size variants
enum DSAvatarSize {
    case sm
    case md
    case lg
    case xl

    var dimension: CGFloat {
        switch self {
        case .sm: return 24
        case .md: return 32
        case .lg: return 48
        case .xl: return 64
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .sm: return 10
        case .md: return 13
        case .lg: return 18
        case .xl: return 24
        }
    }
}

/// Design System Avatar component
struct DSAvatar: View {
    let image: Image?
    let initials: String?
    let size: DSAvatarSize
    let backgroundColor: Color?

    init(image: Image, size: DSAvatarSize = .md) {
        self.image = image
        self.initials = nil
        self.size = size
        self.backgroundColor = nil
    }

    init(initials: String, size: DSAvatarSize = .md, backgroundColor: Color? = nil) {
        self.image = nil
        self.initials = initials
        self.size = size
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        ZStack {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.dimension, height: size.dimension)
                    .clipShape(Circle())
            } else if let initials = initials {
                Circle()
                    .fill(backgroundColor ?? AppTheme.accent.opacity(0.2))
                    .frame(width: size.dimension, height: size.dimension)

                Text(initials)
                    .font(.system(size: size.fontSize, weight: .medium))
                    .foregroundColor(backgroundColor != nil ? AppTheme.textPrimary : AppTheme.accent)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
    }
}

#Preview("DSAvatar Variants") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        // Initials variants - all sizes
        HStack(spacing: DesignTokens.Spacing.md) {
            DSAvatar(initials: "JD", size: .sm)
            DSAvatar(initials: "JD", size: .md)
            DSAvatar(initials: "JD", size: .lg)
            DSAvatar(initials: "JD", size: .xl)
        }

        // Custom background colors
        HStack(spacing: DesignTokens.Spacing.md) {
            DSAvatar(initials: "AB", size: .md, backgroundColor: AppTheme.success.opacity(0.2))
            DSAvatar(initials: "CD", size: .md, backgroundColor: AppTheme.warning.opacity(0.2))
            DSAvatar(initials: "EF", size: .md, backgroundColor: AppTheme.error.opacity(0.2))
            DSAvatar(initials: "GH", size: .md, backgroundColor: AppTheme.info.opacity(0.2))
        }

        // Image avatar (placeholder)
        HStack(spacing: DesignTokens.Spacing.md) {
            DSAvatar(image: Image(systemName: "person.circle.fill"), size: .sm)
            DSAvatar(image: Image(systemName: "person.circle.fill"), size: .md)
            DSAvatar(image: Image(systemName: "person.circle.fill"), size: .lg)
            DSAvatar(image: Image(systemName: "person.circle.fill"), size: .xl)
        }
    }
    .padding()
    .background(AppTheme.background)
}
