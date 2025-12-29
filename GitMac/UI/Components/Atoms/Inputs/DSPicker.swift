//
//  DSPicker.swift
//  GitMac
//
//  Created on 2025-12-28.
//  Design System Picker Component with Auto-styling
//

import SwiftUI

struct DSPicker<Item: Hashable & Identifiable, Label: View>: View {
    let items: [Item]
    @Binding var selection: Item?
    let label: (Item) -> Label
    let disabled: Bool

    init(
        items: [Item],
        selection: Binding<Item?>,
        disabled: Bool = false,
        @ViewBuilder label: @escaping (Item) -> Label
    ) {
        self.items = items
        self._selection = selection
        self.disabled = disabled
        self.label = label
    }

    var body: some View {
        Group {
            if items.count <= 5 {
                // Segmented control for 5 or fewer items
                segmentedPicker
            } else {
                // Menu picker for more than 5 items
                menuPicker
            }
        }
        .disabled(disabled)
    }

    @ViewBuilder
    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Button(action: {
                    selection = item
                }) {
                    label(item)
                        .font(DesignTokens.Typography.callout)
                        .foregroundColor(isSelected(item) ? AppTheme.buttonTextOnColor : AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(isSelected(item) ? AppTheme.accent : Color.clear)
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }
        }
        .background(AppTheme.backgroundSecondary)
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(AppTheme.backgroundTertiary, lineWidth: 1)
        )
        .opacity(disabled ? DesignTokens.Opacity.disabled : 1.0)
    }

    @ViewBuilder
    private var menuPicker: some View {
        Menu {
            ForEach(items) { item in
                Button(action: {
                    selection = item
                }) {
                    HStack {
                        label(item)
                        Spacer()
                        if isSelected(item) {
                            Image(systemName: "checkmark")
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
            }
        } label: {
            HStack {
                if let selected = selection {
                    label(selected)
                        .foregroundColor(AppTheme.textPrimary)
                } else {
                    Text("Select...")
                        .foregroundColor(AppTheme.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: DesignTokens.Sizing.Icon.sm))
                    .foregroundColor(AppTheme.textMuted)
            }
            .font(DesignTokens.Typography.body)
            .padding(DesignTokens.Spacing.sm)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(AppTheme.backgroundTertiary, lineWidth: 1)
            )
        }
        .opacity(disabled ? DesignTokens.Opacity.disabled : 1.0)
    }

    private func isSelected(_ item: Item) -> Bool {
        selection?.id == item.id
    }
}

// MARK: - String Extension for Simple Pickers
extension DSPicker where Item == PickerItem, Label == Text {
    init(
        items: [String],
        selection: Binding<String?>,
        disabled: Bool = false
    ) {
        let pickerItems = items.map { PickerItem(title: $0) }
        let pickerSelection = Binding<PickerItem?>(
            get: {
                guard let selected = selection.wrappedValue else { return nil }
                return pickerItems.first { $0.title == selected }
            },
            set: { newValue in
                selection.wrappedValue = newValue?.title
            }
        )

        self.init(
            items: pickerItems,
            selection: pickerSelection,
            disabled: disabled
        ) { item in
            Text(item.title)
        }
    }
}

// MARK: - Helper Types
struct PickerItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.xl) {
        Text("Segmented (≤5 items)")
            .font(DesignTokens.Typography.headline)

        DSPicker(
            items: ["Option 1", "Option 2", "Option 3"],
            selection: .constant("Option 2")
        )

        Text("Menu (>5 items)")
            .font(DesignTokens.Typography.headline)

        DSPicker(
            items: ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5", "Item 6", "Item 7"],
            selection: .constant("Item 3")
        )

        Text("Disabled")
            .font(DesignTokens.Typography.headline)

        DSPicker(
            items: ["One", "Two", "Three"],
            selection: .constant("One"),
            disabled: true
        )
    }
    .padding()
    .frame(width: 300)
}
