import SwiftUI

// MARK: - Navigation Environment Key

private struct NavigateToSectionKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: (NavigationSection) -> Void = { _ in }
}

extension EnvironmentValues {
    var navigateToSection: (NavigationSection) -> Void {
        get { self[NavigateToSectionKey.self] }
        set { self[NavigateToSectionKey.self] = newValue }
    }
}

// MARK: - Section Enum

/// The six sidebar navigation sections.
enum NavigationSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case habits = "Habits"
    case journal = "Journal"
    case warRoom = "War Room"
    case reports = "Reports"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .habits: "target"
        case .journal: "book.pages"
        case .warRoom: "chart.bar.xaxis"
        case .reports: "doc.text.magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

// MARK: - Navigation Shell

/// Custom sidebar + detail layout. Full HUD styling — not NavigationSplitView.
struct NavigationShell: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: NavigationSection = .dashboard
    @State private var isSidebarExpanded = true
    @State private var appeared = false

    private let expandedWidth: CGFloat = 200
    private let collapsedWidth: CGFloat = 52

    private var sidebarWidth: CGFloat {
        isSidebarExpanded ? expandedWidth : collapsedWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detailView
        }
        .background(OverwatchTheme.background)
        .onAppear {
            appeared = true
            startWhoopSyncIfAuthenticated()
        }
        .onChange(of: selectedSection) { _, _ in
            // If sync died overnight (session expired, error), restart it when the user navigates
            appState.ensureSyncRunning(modelContainer: modelContext.container)
        }
    }

    /// Check if WHOOP tokens exist in Keychain and kick off the recurring sync loop.
    private func startWhoopSyncIfAuthenticated() {
        guard KeychainHelper.readString(key: KeychainHelper.Keys.whoopAccessToken) != nil else { return }
        appState.startWhoopSync(modelContainer: modelContext.container)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            sidebarItems
            Spacer()
            collapseToggle
        }
        .frame(width: sidebarWidth)
        .background(
            ZStack {
                OverwatchTheme.surface
                ScanLineOverlay(color: OverwatchTheme.scanLine.opacity(0.5))
            }
        )
        .overlay(alignment: .trailing) {
            // Right edge border
            Rectangle()
                .fill(OverwatchTheme.accentCyan.opacity(0.2))
                .frame(width: 1)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSidebarExpanded)
    }

    private var sidebarHeader: some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 18, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(OverwatchTheme.accentCyan)
                .textGlow(OverwatchTheme.accentCyan, radius: 8)

            if isSidebarExpanded {
                Text("OVERWATCH")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(4)
                    .textGlow(OverwatchTheme.accentCyan, radius: 4)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .frame(maxWidth: .infinity, alignment: isSidebarExpanded ? .leading : .center)
        .padding(.horizontal, OverwatchTheme.Spacing.lg)
        .padding(.vertical, OverwatchTheme.Spacing.lg)
    }

    private var sidebarItems: some View {
        VStack(spacing: 0) {
            HUDDivider()
                .padding(.horizontal, OverwatchTheme.Spacing.sm)
                .padding(.bottom, OverwatchTheme.Spacing.sm)

            ForEach(NavigationSection.allCases) { section in
                SidebarItem(
                    section: section,
                    isSelected: selectedSection == section,
                    isExpanded: isSidebarExpanded
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSection = section
                    }
                }

                if section != NavigationSection.allCases.last {
                    HUDDivider()
                        .padding(.horizontal, OverwatchTheme.Spacing.sm)
                        .opacity(0.4)
                }
            }

            HUDDivider()
                .padding(.horizontal, OverwatchTheme.Spacing.sm)
                .padding(.top, OverwatchTheme.Spacing.sm)
        }
    }

    private var collapseToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isSidebarExpanded.toggle()
            }
        } label: {
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OverwatchTheme.textSecondary)

                if isSidebarExpanded {
                    Text("COLLAPSE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(1)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .frame(maxWidth: .infinity, alignment: isSidebarExpanded ? .leading : .center)
            .padding(.horizontal, OverwatchTheme.Spacing.lg)
            .padding(.vertical, OverwatchTheme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Detail View

    private var detailView: some View {
        ZStack {
            // Background layers owned by shell
            OverwatchTheme.background.ignoresSafeArea()
            GridBackdrop().ignoresSafeArea()
            DataStreamTexture(opacity: 0.03, scrollSpeed: 8).ignoresSafeArea()
            ScanLineOverlay().ignoresSafeArea()

            // Content — section transition per spec
            detailContent(for: selectedSection)
                .id(selectedSection)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    )
                )
                .animation(.easeInOut(duration: 0.2), value: selectedSection)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.navigateToSection) { section in
            withAnimation(.easeInOut(duration: 0.2)) {
                self.selectedSection = section
            }
        }
    }

    @ViewBuilder
    private func detailContent(for section: NavigationSection) -> some View {
        switch section {
        case .dashboard:
            TacticalDashboardView()
        case .habits:
            HabitsView()
        case .journal:
            JournalView()
        case .warRoom:
            WarRoomView()
        case .reports:
            ReportsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Sidebar Item

private struct SidebarItem: View {
    let section: NavigationSection
    let isSelected: Bool
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var glowBreathing = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: OverwatchTheme.Spacing.md) {
                // Left accent bar (selected only) — pulses gently
                RoundedRectangle(cornerRadius: 1)
                    .fill(isSelected ? OverwatchTheme.accentCyan : .clear)
                    .frame(width: 2, height: 24)
                    .shadow(
                        color: isSelected ? OverwatchTheme.accentCyan.opacity(glowBreathing ? 0.8 : 0.4) : .clear,
                        radius: isSelected ? (glowBreathing ? 8 : 4) : 0
                    )

                // Icon — glow breathes when selected
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 20)
                    .shadow(
                        color: isSelected ? OverwatchTheme.accentCyan.opacity(glowBreathing ? 0.7 : 0.3) : .clear,
                        radius: isSelected ? (glowBreathing ? 10 : 5) : 0
                    )

                // Label (expanded only)
                if isExpanded {
                    Text(section.rawValue.uppercased())
                        .font(Typography.hudLabel)
                        .foregroundStyle(labelColor)
                        .tracking(3)
                        .lineLimit(1)
                        .textGlow(isSelected ? OverwatchTheme.accentCyan : .clear, radius: 3)
                        .transition(.opacity.combined(with: .move(edge: .leading)))

                    Spacer()
                }
            }
            .padding(.horizontal, isExpanded ? OverwatchTheme.Spacing.sm : 0)
            .padding(.vertical, OverwatchTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: isExpanded ? .leading : .center)
            .background(backgroundFill)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onChange(of: isSelected) { _, selected in
            if selected {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowBreathing = true
                }
            } else {
                glowBreathing = false
            }
        }
        .onAppear {
            if isSelected {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowBreathing = true
                }
            }
        }
    }

    private var iconColor: Color {
        if isSelected { return OverwatchTheme.accentCyan }
        if isHovered { return OverwatchTheme.accentCyan.opacity(0.8) }
        return OverwatchTheme.textSecondary
    }

    private var labelColor: Color {
        if isSelected { return OverwatchTheme.accentCyan }
        if isHovered { return OverwatchTheme.textPrimary }
        return OverwatchTheme.textSecondary
    }

    @ViewBuilder
    private var backgroundFill: some View {
        if isSelected {
            OverwatchTheme.surfaceElevated.opacity(0.6)
        } else if isHovered {
            OverwatchTheme.surfaceElevated.opacity(0.4)
        } else {
            Color.clear
        }
    }
}

// MARK: - Preview

#Preview("Navigation Shell") {
    NavigationShell()
        .environment(AppState())
        .modelContainer(for: [Habit.self, HabitEntry.self, JournalEntry.self, MonthlyAnalysis.self, WhoopCycle.self],
                        inMemory: true)
        .frame(width: 1100, height: 700)
}

#Preview("Sidebar Collapsed") {
    NavigationShell()
        .environment(AppState())
        .modelContainer(for: [Habit.self, HabitEntry.self, JournalEntry.self, MonthlyAnalysis.self, WhoopCycle.self],
                        inMemory: true)
        .frame(width: 900, height: 600)
}
