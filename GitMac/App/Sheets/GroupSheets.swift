//
//  GroupSheets.swift
//  GitMac
//
//  Sheets for managing repository groups
//

import SwiftUI

// MARK: - Group Management Sheet

struct GroupManagementSheet: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupsService = RepoGroupsService.shared
    @State private var editingGroup: RepoGroupsService.RepoGroup?
    @State private var showCreateGroup = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(DesignTokens.Typography.iconXL)
                    .foregroundStyle(AppTheme.accent)
                Text("Manage Groups")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(DesignTokens.Typography.callout)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if groupsService.groups.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(DesignTokens.Typography.iconXXXL)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("No groups yet")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.xxl)
                    } else {
                        ForEach(groupsService.groups.sorted(by: { $0.sortOrder < $1.sortOrder })) { group in
                            GroupManagementRow(group: group, onEdit: {
                                editingGroup = group
                            }, onDelete: {
                                groupsService.deleteGroup(group.id)
                            })
                        }
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }

            Divider()

            HStack {
                DSButton("Done", variant: .secondary, size: .sm) {
                    dismiss()
                }
                Spacer()
                Button { showCreateGroup = true } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Group")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 500, height: 400)
        .background(AppTheme.background)
        .sheet(isPresented: $showCreateGroup) { CreateGroupSheet() }
        .sheet(item: $editingGroup) { group in EditGroupSheet(group: group) }
    }
}

// MARK: - Group Management Row

struct GroupManagementRow: View {
    let group: RepoGroupsService.RepoGroup
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Circle()
                .fill(SwiftUI.Color(hex: group.color))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(group.name)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(group.repos.count) repositories")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            if isHovered {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button { onEdit() } label: {
                        Image(systemName: "pencil")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppTheme.error)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(isHovered ? AppTheme.hover : Color.clear)
        .clipShape(.rect(cornerRadius: DesignTokens.CornerRadius.md))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Create Group Sheet

struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupsService = RepoGroupsService.shared
    @State private var groupName = ""
    @State private var selectedColor = "007AFF"
    private let availableColors = [
        ("Blue", "007AFF"), ("Purple", "5E5CE6"), ("Pink", "FF2D55"),
        ("Red", "FF3B30"), ("Orange", "FF9500"), ("Yellow", "FFCC00"),
        ("Green", "34C759"), ("Teal", "5AC8FA"), ("Indigo", "5856D6")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Create Group")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Group Name")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    DSTextField(placeholder: "Work Projects", text: $groupName)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Color")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: DesignTokens.Spacing.md) {
                        ForEach(availableColors, id: \.1) { _, hex in
                            ColorPickerButton(
                                color: SwiftUI.Color(hex: hex),
                                isSelected: selectedColor == hex
                            ) {
                                selectedColor = hex
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
            Divider()

            HStack {
                DSButton("Cancel", variant: .secondary, size: .sm) {
                    dismiss()
                }
                Spacer()
                Button("Create") {
                    _ = groupsService.createGroup(name: groupName, color: selectedColor)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(groupName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }
}

// MARK: - Edit Group Sheet

struct EditGroupSheet: View {
    let group: RepoGroupsService.RepoGroup
    @Environment(\.dismiss) private var dismiss
    @StateObject private var groupsService = RepoGroupsService.shared
    @State private var groupName: String
    @State private var selectedColor: String
    private let availableColors = [
        ("Blue", "007AFF"), ("Purple", "5E5CE6"), ("Pink", "FF2D55"),
        ("Red", "FF3B30"), ("Orange", "FF9500"), ("Yellow", "FFCC00"),
        ("Green", "34C759"), ("Teal", "5AC8FA"), ("Indigo", "5856D6")
    ]

    init(group: RepoGroupsService.RepoGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _selectedColor = State(initialValue: group.color)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Group")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DesignTokens.Spacing.lg)

            Divider()

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Group Name")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    DSTextField(placeholder: "Work Projects", text: $groupName)
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Color")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(AppTheme.textPrimary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: DesignTokens.Spacing.md) {
                        ForEach(availableColors, id: \.1) { _, hex in
                            ColorPickerButton(
                                color: SwiftUI.Color(hex: hex),
                                isSelected: selectedColor == hex
                            ) {
                                selectedColor = hex
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)

            Spacer()
            Divider()

            HStack {
                DSButton("Cancel", variant: .secondary, size: .sm) {
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    var updatedGroup = group
                    updatedGroup.name = groupName
                    updatedGroup.color = selectedColor
                    groupsService.updateGroup(updatedGroup)
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(groupName.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .frame(width: 400, height: 300)
        .background(AppTheme.background)
    }
}

// MARK: - Color Picker Button

struct ColorPickerButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .strokeBorder(AppTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
