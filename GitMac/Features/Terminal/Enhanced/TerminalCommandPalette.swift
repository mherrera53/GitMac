//
//  CommandPalette.swift
//  GitMac
//
//  Command Palette - Warp-style workflow launcher
//

import SwiftUI

// MARK: - Command Palette View

struct TerminalCommandPaletteView: View {
    @Binding var isPresented: Bool
    let onExecute: (TerminalWorkflow) -> Void

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @StateObject private var viewModel = TerminalCommandPaletteViewModel()

    var filteredWorkflows: [TerminalWorkflow] {
        viewModel.searchWorkflows(searchText)
    }

    var body: some View {
        ZStack {
            // Dimmed background
            AppTheme.background.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "command.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.accent)

                    DSTextField(placeholder: "Search workflows or type command...", text: $searchText)
                        .font(DesignTokens.Typography.body)
                        .onSubmit {
                            executeSelected()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(AppTheme.backgroundSecondary)

                Divider()

                // Results
                ScrollView {
                    LazyVStack(spacing: DesignTokens.Spacing.xxs) {
                        if filteredWorkflows.isEmpty {
                            EmptyPaletteState(searchText: searchText)
                        } else {
                            ForEach(Array(filteredWorkflows.enumerated()), id: \.element.id) { index, workflow in
                                WorkflowRow(
                                    workflow: workflow,
                                    isSelected: index == selectedIndex,
                                    onSelect: {
                                        onExecute(workflow)
                                        isPresented = false
                                    }
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(AppTheme.backgroundSecondary)

                Divider()

                // Footer hints
                HStack(spacing: DesignTokens.Spacing.lg) {
                    PaletteHint(icon: "↩", text: "Execute")
                    PaletteHint(icon: "↑↓", text: "Navigate")
                    PaletteHint(icon: "esc", text: "Close")
                    Spacer()
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(AppTheme.backgroundTertiary)
            }
            .frame(width: 480)
            .background(AppTheme.backgroundSecondary)
            .cornerRadius(DesignTokens.CornerRadius.lg)
            .shadow(color: AppTheme.background.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .onAppear {
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredWorkflows.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
    }

    private func executeSelected() {
        guard selectedIndex < filteredWorkflows.count else { return }
        let workflow = filteredWorkflows[selectedIndex]
        onExecute(workflow)
        isPresented = false
    }
}

// MARK: - Workflow Row

struct WorkflowRow: View {
    let workflow: TerminalWorkflow
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Category icon
                Image(systemName: categoryIcon)
                    .font(.system(size: DesignTokens.Size.iconSM))
                    .foregroundColor(categoryColor)
                    .frame(width: DesignTokens.Size.iconLG)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    // Name
                    Text(workflow.name)
                        .font(DesignTokens.Typography.callout.weight(.semibold))
                        .foregroundColor(AppTheme.textPrimary)

                    // Command preview
                    Text(workflow.command)
                        .font(DesignTokens.Typography.caption2.monospaced())
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                // Category tag
                Text(workflow.category)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xxs)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(DesignTokens.CornerRadius.sm)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isSelected ? AppTheme.selection : AppTheme.hover.opacity(0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var categoryIcon: String {
        switch workflow.category {
        case "Git": return "arrow.triangle.branch"
        case "Docker": return "shippingbox"
        case "Node": return "cube"
        case "Files": return "doc.text.magnifyingglass"
        default: return "terminal"
        }
    }

    var categoryColor: Color {
        switch workflow.category {
        case "Git": return .orange
        case "Docker": return .blue
        case "Node": return .green
        case "Files": return .purple
        default: return .gray
        }
    }
}

// MARK: - Empty State

struct EmptyPaletteState: View {
    let searchText: String

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(DesignTokens.Typography.iconXXXL)
                .foregroundColor(AppTheme.textPrimary)

            Text(searchText.isEmpty ? "No workflows yet" : "No workflows found")
                .font(DesignTokens.Typography.headline)

            Text(searchText.isEmpty ?
                "Workflows will appear here" :
                "Try a different search term")
                .font(DesignTokens.Typography.callout)
                .foregroundColor(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }
}

// MARK: - Palette Hint

struct PaletteHint: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(icon)
                .font(DesignTokens.Typography.caption2.monospaced())
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, DesignTokens.Spacing.xxs)
                .background(AppTheme.textSecondary.opacity(0.15))
                .cornerRadius(DesignTokens.CornerRadius.sm)

            Text(text)
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}

// MARK: - Command Palette ViewModel

@MainActor
class TerminalCommandPaletteViewModel: ObservableObject {
    @Published var workflows: [TerminalWorkflow] = []

    init() {
        loadWorkflows()
    }

    func loadWorkflows() {
        // Load default workflows
        workflows = [
            TerminalWorkflow(
                name: "Git Status",
                description: "Show git status",
                command: "git status",
                parameters: [],
                category: "Git",
                tags: ["git", "status"]
            ),
            TerminalWorkflow(
                name: "Git Add All",
                description: "Stage all changes",
                command: "git add .",
                parameters: [],
                category: "Git",
                tags: ["git", "add"]
            ),
            TerminalWorkflow(
                name: "Git Commit",
                description: "Commit with message",
                command: "git commit -m",
                parameters: [],
                category: "Git",
                tags: ["git", "commit"]
            ),
            TerminalWorkflow(
                name: "Git Push",
                description: "Push to remote",
                command: "git push",
                parameters: [],
                category: "Git",
                tags: ["git", "push"]
            ),
            TerminalWorkflow(
                name: "Git Pull",
                description: "Pull from remote",
                command: "git pull",
                parameters: [],
                category: "Git",
                tags: ["git", "pull"]
            ),
            TerminalWorkflow(
                name: "Docker Compose Up",
                description: "Start docker compose",
                command: "docker-compose up -d",
                parameters: [],
                category: "Docker",
                tags: ["docker", "compose"]
            ),
            TerminalWorkflow(
                name: "Docker PS",
                description: "List running containers",
                command: "docker ps",
                parameters: [],
                category: "Docker",
                tags: ["docker", "ps"]
            ),
            TerminalWorkflow(
                name: "NPM Install",
                description: "Install node modules",
                command: "npm install",
                parameters: [],
                category: "Node",
                tags: ["npm", "install"]
            ),
            TerminalWorkflow(
                name: "NPM Run Dev",
                description: "Run development server",
                command: "npm run dev",
                parameters: [],
                category: "Node",
                tags: ["npm", "dev"]
            )
        ]
    }

    func searchWorkflows(_ query: String) -> [TerminalWorkflow] {
        guard !query.isEmpty else { return workflows }

        let lowercased = query.lowercased()
        return workflows.filter { workflow in
            workflow.name.lowercased().contains(lowercased) ||
            workflow.description.lowercased().contains(lowercased) ||
            workflow.command.lowercased().contains(lowercased) ||
            workflow.tags.contains(where: { $0.lowercased().contains(lowercased) })
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TerminalCommandPaletteView_Previews: PreviewProvider {
    static var previews: some View {
        TerminalCommandPaletteView(
            isPresented: .constant(true),
            onExecute: { _ in }
        )
        .frame(width: 800, height: 600)
    }
}
#endif
