import SwiftUI
import SwiftData

// MARK: - Journal Timeline View

/// Scrollable timeline of all habit entry logs with filters, inline editing, and delete.
/// HUD-styled vertical timeline with connecting line and node dots.
struct JournalTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = JournalTimelineViewModel()
    @State private var sectionsVisible = false
    @State private var deleteGlowTrigger = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
                .materializeEffect(isVisible: sectionsVisible, delay: 0)

            filterBar
                .materializeEffect(isVisible: sectionsVisible, delay: 0.08)
                .padding(.bottom, OverwatchTheme.Spacing.md)

            if viewModel.filteredEntries.isEmpty {
                emptyState
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.16)
                    .frame(maxWidth: .infinity)
            } else {
                timelineList
            }
        }
        .onAppear {
            viewModel.loadEntries(from: modelContext)
            sectionsVisible = true
        }
        .alert(
            "PURGE ENTRY?",
            isPresented: $viewModel.showingDeleteAlert,
            presenting: viewModel.entryToDelete
        ) { _ in
            Button("CONFIRM", role: .destructive) {
                withAnimation(Animations.dataStream) {
                    viewModel.deleteEntry(in: modelContext)
                    deleteGlowTrigger = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        deleteGlowTrigger = false
                    }
                }
            }
            Button("CANCEL", role: .cancel) {}
        } message: { entry in
            Text("This will permanently remove the \(entry.habitName) entry logged at \(DateFormatters.time24h.string(from: entry.loggedAt)).")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            HStack(alignment: .center) {
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    Rectangle()
                        .fill(OverwatchTheme.accentCyan.opacity(0.6))
                        .frame(width: 3, height: 14)
                        .shadow(color: OverwatchTheme.accentCyan.opacity(0.6), radius: 4)

                    Text("FIELD LOG")
                        .font(Typography.subtitle)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(4)
                        .textGlow(OverwatchTheme.accentCyan, radius: 8)
                }

                Spacer()

                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    Text("\(viewModel.entryCount)")
                        .font(Typography.metricSmall)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .contentTransition(.numericText())
                    Text("ENTRIES")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(2)
                }

                if viewModel.hasActiveFilters {
                    Button {
                        withAnimation(Animations.quick) {
                            viewModel.clearFilters()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .medium))
                            Text("CLEAR")
                                .font(Typography.hudLabel)
                                .tracking(1)
                        }
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OverwatchTheme.surfaceElevated.opacity(0.5))
                        .clipShape(HUDFrameShape(chamferSize: 4))
                        .overlay(
                            HUDFrameShape(chamferSize: 4)
                                .stroke(OverwatchTheme.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HUDDivider(color: OverwatchTheme.accentCyan)
        }
        .padding(.bottom, OverwatchTheme.Spacing.sm)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            // Date range filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    ForEach(JournalTimelineViewModel.DateRangeFilter.allCases, id: \.self) { range in
                        FilterChip(
                            label: range.rawValue,
                            isSelected: viewModel.dateRangeFilter == range
                        ) {
                            withAnimation(Animations.quick) {
                                viewModel.dateRangeFilter = range
                            }
                        }
                    }

                    ChipDivider()

                    // Habit filter
                    FilterChip(
                        label: habitFilterLabel,
                        isSelected: viewModel.selectedHabitID != nil,
                        icon: "target"
                    ) {
                        withAnimation(Animations.quick) {
                            cycleHabitFilter()
                        }
                    }

                    // Category filter
                    if !viewModel.availableCategories.isEmpty {
                        FilterChip(
                            label: categoryFilterLabel,
                            isSelected: viewModel.selectedCategory != nil,
                            icon: "tag"
                        ) {
                            withAnimation(Animations.quick) {
                                cycleCategoryFilter()
                            }
                        }
                    }
                }
            }
        }
    }

    private var habitFilterLabel: String {
        if let id = viewModel.selectedHabitID,
           let habit = viewModel.availableHabits.first(where: { $0.id == id }) {
            return "\(habit.emoji) \(habit.name.uppercased())"
        }
        return "ALL HABITS"
    }

    private var categoryFilterLabel: String {
        if let cat = viewModel.selectedCategory {
            return cat.uppercased()
        }
        return "ALL CATEGORIES"
    }

    private func cycleHabitFilter() {
        let habits = viewModel.availableHabits
        guard !habits.isEmpty else { return }

        if let currentID = viewModel.selectedHabitID,
           let currentIndex = habits.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = habits.index(after: currentIndex)
            if nextIndex < habits.endIndex {
                viewModel.selectedHabitID = habits[nextIndex].id
            } else {
                viewModel.selectedHabitID = nil
            }
        } else {
            viewModel.selectedHabitID = habits.first?.id
        }
    }

    private func cycleCategoryFilter() {
        let cats = viewModel.availableCategories
        guard !cats.isEmpty else { return }

        if let current = viewModel.selectedCategory,
           let currentIndex = cats.firstIndex(of: current) {
            let nextIndex = cats.index(after: currentIndex)
            if nextIndex < cats.endIndex {
                viewModel.selectedCategory = cats[nextIndex]
            } else {
                viewModel.selectedCategory = nil
            }
        } else {
            viewModel.selectedCategory = cats.first
        }
    }

    // MARK: - Timeline List

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filteredEntries.enumerated()), id: \.element.id) { index, entry in
                    let isLast = index == viewModel.filteredEntries.count - 1
                    let isExpanded = viewModel.expandedEntryID == entry.id

                    TimelineEntryRow(
                        entry: entry,
                        isExpanded: isExpanded,
                        isLast: isLast,
                        editValue: $viewModel.editValue,
                        editNotes: $viewModel.editNotes,
                        onTap: {
                            withAnimation(Animations.standard) {
                                viewModel.toggleExpand(entry.id)
                            }
                        },
                        onSave: {
                            withAnimation(Animations.quick) {
                                viewModel.saveEdit(in: modelContext)
                            }
                        },
                        onDelete: {
                            viewModel.confirmDelete(entry)
                        }
                    )
                    .staggerEffect(index: index, delayPerItem: 0.04)
                }
            }
            .padding(.bottom, OverwatchTheme.Spacing.xl)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: OverwatchTheme.Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.1), radius: 8)

            Text("NO ENTRIES FOUND")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            if viewModel.hasActiveFilters {
                Text("Try adjusting your filters to see more entries")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            } else {
                Text("Log habits from the Dashboard to populate this timeline")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
        }
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }
}

// MARK: - Timeline Entry Row

private struct TimelineEntryRow: View {
    let entry: JournalTimelineViewModel.EntryItem
    let isExpanded: Bool
    let isLast: Bool
    @Binding var editValue: String
    @Binding var editNotes: String
    let onTap: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline spine
            timelineSpine
                .frame(width: 32)

            // Entry content
            VStack(alignment: .leading, spacing: 0) {
                entryContent
                    .padding(.vertical, OverwatchTheme.Spacing.sm)
                    .padding(.horizontal, OverwatchTheme.Spacing.md)
                    .background(
                        isHovered || isExpanded
                            ? OverwatchTheme.surfaceElevated.opacity(0.3)
                            : .clear
                    )
                    .clipShape(HUDFrameShape(chamferSize: 6))
                    .overlay(
                        HUDFrameShape(chamferSize: 6)
                            .stroke(
                                isExpanded
                                    ? OverwatchTheme.accentCyan.opacity(0.4)
                                    : (isHovered ? OverwatchTheme.accentCyan.opacity(0.15) : .clear),
                                lineWidth: 1
                            )
                    )
                    .contentShape(HUDFrameShape(chamferSize: 6))
                    .onTapGesture(perform: onTap)
                    .onHover { isHovered = $0 }

                // Expanded edit panel
                if isExpanded {
                    editPanel
                        .slideRevealEffect(isExpanded: isExpanded)
                        .padding(.top, OverwatchTheme.Spacing.xs)
                }
            }
            .padding(.trailing, OverwatchTheme.Spacing.sm)
        }
    }

    // MARK: - Timeline Spine

    private var timelineSpine: some View {
        VStack(spacing: 0) {
            // Node dot
            Circle()
                .fill(entry.completed ? OverwatchTheme.accentCyan : OverwatchTheme.textSecondary.opacity(0.3))
                .frame(width: 8, height: 8)
                .shadow(
                    color: entry.completed
                        ? OverwatchTheme.accentCyan.opacity(isHovered ? 0.6 : 0.3)
                        : .clear,
                    radius: isHovered ? 6 : 3
                )
                .padding(.top, 14)

            // Connecting line
            if !isLast {
                Rectangle()
                    .fill(OverwatchTheme.accentCyan.opacity(0.15))
                    .frame(width: 1)
            }
        }
    }

    // MARK: - Entry Content

    private var entryContent: some View {
        HStack(spacing: OverwatchTheme.Spacing.md) {
            // Emoji
            Text(entry.habitEmoji.isEmpty ? "●" : entry.habitEmoji)
                .font(.system(size: 16))
                .frame(width: 22)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    Text(entry.habitName.uppercased())
                        .font(Typography.hudLabel)
                        .foregroundStyle(
                            entry.completed ? OverwatchTheme.textPrimary : OverwatchTheme.textSecondary
                        )
                        .tracking(2)
                        .lineLimit(1)

                    if let value = entry.value {
                        HStack(spacing: 2) {
                            Text(String(format: "%g", value))
                                .font(Typography.metricTiny)
                                .foregroundStyle(OverwatchTheme.accentCyan)
                                .monospacedDigit()
                            if !entry.unitLabel.isEmpty {
                                Text(entry.unitLabel.uppercased())
                                    .font(Typography.metricTiny)
                                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(OverwatchTheme.accentCyan.opacity(0.06))
                        .clipShape(.capsule)
                    }
                }

                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    // Timestamp
                    Text(formattedTimestamp)
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .monospacedDigit()

                    // Notes preview (if any, not expanded)
                    if !entry.notes.isEmpty && !isExpanded {
                        Text("— \(entry.notes)")
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Status indicator
            if entry.completed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(OverwatchTheme.accentSecondary.opacity(0.6))
            }

            // Expand chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .light))
                .foregroundStyle(OverwatchTheme.textSecondary.opacity(isHovered ? 0.5 : 0.2))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(Animations.quick, value: isExpanded)
        }
    }

    // MARK: - Edit Panel

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            // Value field (if quantitative)
            if entry.isQuantitative {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text("VALUE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                        .tracking(2)
                        .textGlow(OverwatchTheme.accentCyan, radius: 2)

                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        TextField("0", text: $editValue)
                            .textFieldStyle(.plain)
                            .font(Typography.commandLine)
                            .foregroundStyle(OverwatchTheme.textPrimary)
                            .frame(width: 80)
                            .padding(.horizontal, OverwatchTheme.Spacing.sm)
                            .padding(.vertical, OverwatchTheme.Spacing.xs + 2)
                            .background(OverwatchTheme.surface)
                            .clipShape(HUDFrameShape(chamferSize: 5))
                            .overlay(
                                HUDFrameShape(chamferSize: 5)
                                    .stroke(OverwatchTheme.accentCyan.opacity(0.25), lineWidth: 1)
                            )

                        if !entry.unitLabel.isEmpty {
                            Text(entry.unitLabel.uppercased())
                                .font(Typography.hudLabel)
                                .foregroundStyle(OverwatchTheme.textSecondary)
                                .tracking(1)
                        }
                    }
                }
            }

            // Notes field
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                Text("NOTES")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                    .tracking(2)
                    .textGlow(OverwatchTheme.accentCyan, radius: 2)

                TextField("Add notes...", text: $editNotes)
                    .textFieldStyle(.plain)
                    .font(Typography.commandLine)
                    .foregroundStyle(OverwatchTheme.textPrimary)
                    .padding(.horizontal, OverwatchTheme.Spacing.sm)
                    .padding(.vertical, OverwatchTheme.Spacing.xs + 2)
                    .background(OverwatchTheme.surface)
                    .clipShape(HUDFrameShape(chamferSize: 5))
                    .overlay(
                        HUDFrameShape(chamferSize: 5)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.25), lineWidth: 1)
                    )
            }

            // Action buttons
            HStack(spacing: OverwatchTheme.Spacing.sm) {
                Button("SAVE") { onSave() }
                    .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.accentCyan))

                Button("DELETE") { onDelete() }
                    .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.alert))

                Spacer()

                // Entry date
                Text(DateFormatters.displayDate.string(from: entry.date))
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
        }
        .padding(OverwatchTheme.Spacing.md)
        .background(OverwatchTheme.surface.opacity(0.4))
        .clipShape(HUDFrameShape(chamferSize: 6))
        .overlay(
            HUDFrameShape(chamferSize: 6)
                .stroke(OverwatchTheme.accentCyan.opacity(0.2), lineWidth: 1)
        )
        .padding(.leading, OverwatchTheme.Spacing.xs)
    }

    // MARK: - Helpers

    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let now = Date.now
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!

        let time = DateFormatters.time24h.string(from: entry.loggedAt)

        if entry.loggedAt >= todayStart {
            return "TODAY \(time)"
        } else if entry.loggedAt >= yesterdayStart {
            return "YESTERDAY \(time)"
        } else {
            let date = DateFormatters.shortDate.string(from: entry.loggedAt).uppercased()
            return "\(date) \(time)"
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8))
                }
                Text(label)
                    .font(Typography.hudLabel)
                    .tracking(1.5)
                    .lineLimit(1)
            }
            .foregroundStyle(
                isSelected
                    ? OverwatchTheme.accentCyan
                    : OverwatchTheme.textSecondary
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? OverwatchTheme.accentCyan.opacity(0.1)
                    : (isHovered ? OverwatchTheme.surfaceElevated : .clear)
            )
            .clipShape(HUDFrameShape(chamferSize: 5))
            .overlay(
                HUDFrameShape(chamferSize: 5)
                    .stroke(
                        isSelected
                            ? OverwatchTheme.accentCyan.opacity(0.5)
                            : OverwatchTheme.accentCyan.opacity(isHovered ? 0.2 : 0.1),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? OverwatchTheme.accentCyan.opacity(0.2) : .clear,
                radius: 6
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Chip Divider

private struct ChipDivider: View {
    var body: some View {
        Rectangle()
            .fill(OverwatchTheme.accentCyan.opacity(0.15))
            .frame(width: 1, height: 14)
    }
}

// MARK: - Preview

#Preview("Journal Timeline") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        JournalTimelineView()
            .padding(OverwatchTheme.Spacing.xl)
    }
    .modelContainer(
        for: [Habit.self, HabitEntry.self, JournalEntry.self, WhoopCycle.self],
        inMemory: true
    )
    .frame(width: 600, height: 700)
}
