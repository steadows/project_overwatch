import SwiftUI
import SwiftData

// MARK: - Journal View

/// Full journal page — master-detail layout with entry list, inline editor,
/// sentiment filtering, live sentiment scoring, and tag management.
struct JournalView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = JournalViewModel()
    @State private var sectionsVisible = false
    @State private var showingDeleteAlert = false
    @State private var entryToDelete: JournalViewModel.JournalItem?
    @State private var newTagText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerArea
                .materializeEffect(isVisible: sectionsVisible, delay: 0)

            if viewModel.entries.isEmpty && !viewModel.isEditing {
                Spacer()
                emptyState
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.12)
                Spacer()
            } else {
                filterBar
                    .materializeEffect(isVisible: sectionsVisible, delay: 0.08)
                    .padding(.horizontal, OverwatchTheme.Spacing.xl)
                    .padding(.bottom, OverwatchTheme.Spacing.md)

                masterDetailLayout
            }
        }
        .onAppear {
            viewModel.loadEntries(from: modelContext)
            viewModel.loadSentimentTrend(from: modelContext)
            viewModel.loadLatestAnalysis(from: modelContext)
            sectionsVisible = true
        }
        .alert(
            "PURGE ENTRY?",
            isPresented: $showingDeleteAlert,
            presenting: entryToDelete
        ) { entry in
            Button("CONFIRM", role: .destructive) {
                withAnimation(Animations.dataStream) {
                    viewModel.deleteEntry(entry.id, from: modelContext)
                }
            }
            Button("CANCEL", role: .cancel) {}
        } message: { entry in
            Text("Entry \"\(entry.title)\" will be permanently purged. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerArea: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text("JOURNAL")
                        .font(Typography.largeTitle)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(6)
                        .textGlow(OverwatchTheme.accentCyan, radius: 20)

                    Text("FIELD LOG")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.45))
                        .tracking(5)
                        .textGlow(OverwatchTheme.accentCyan, radius: 4)
                }

                Spacer()

                // Entry count
                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    Text("\(viewModel.entries.count)")
                        .font(Typography.metricMedium)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .contentTransition(.numericText())
                    Text("ENTRIES")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(2)
                }

                // New entry button
                Button {
                    withAnimation(Animations.quick) {
                        viewModel.startNewEntry()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("NEW ENTRY")
                            .font(Typography.hudLabel)
                            .tracking(1)
                    }
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(OverwatchTheme.accentCyan.opacity(0.08))
                    .clipShape(HUDFrameShape(chamferSize: 6))
                    .overlay(
                        HUDFrameShape(chamferSize: 6)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HUDDivider(color: OverwatchTheme.accentCyan)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.xl)
        .padding(.top, OverwatchTheme.Spacing.xl)
        .padding(.bottom, OverwatchTheme.Spacing.sm)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: OverwatchTheme.Spacing.lg) {
            // Date + sentiment filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    ForEach(JournalViewModel.DateFilter.allCases) { filter in
                        FilterChip(
                            label: filter.rawValue,
                            isSelected: viewModel.dateFilter == filter
                        ) {
                            withAnimation(Animations.quick) {
                                viewModel.dateFilter = filter
                            }
                        }
                    }

                    // Divider between filter groups
                    Rectangle()
                        .fill(OverwatchTheme.accentCyan.opacity(0.15))
                        .frame(width: 1, height: 16)

                    ForEach(JournalViewModel.SentimentFilter.allCases) { filter in
                        FilterChip(
                            label: filter.rawValue,
                            isSelected: viewModel.sentimentFilter == filter
                        ) {
                            withAnimation(Animations.quick) {
                                viewModel.sentimentFilter = filter
                            }
                        }
                    }
                }
            }

            // Search field
            HStack(spacing: OverwatchTheme.Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))

                TextField("SEARCH ENTRIES", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(Typography.commandLine)
                    .foregroundStyle(OverwatchTheme.textPrimary)
            }
            .padding(.horizontal, OverwatchTheme.Spacing.sm)
            .padding(.vertical, OverwatchTheme.Spacing.xs + 2)
            .background(OverwatchTheme.surface)
            .clipShape(HUDFrameShape(chamferSize: 6))
            .overlay(
                HUDFrameShape(chamferSize: 6)
                    .stroke(OverwatchTheme.accentCyan.opacity(0.2), lineWidth: 1)
            )
            .frame(maxWidth: 220)
        }
    }

    // MARK: - Master-Detail Layout

    private var masterDetailLayout: some View {
        HStack(alignment: .top, spacing: OverwatchTheme.Spacing.lg) {
            // Left: entry list
            ScrollView {
                VStack(spacing: OverwatchTheme.Spacing.sm) {
                    ForEach(
                        Array(viewModel.filteredEntries.enumerated()),
                        id: \.element.id
                    ) { index, entry in
                        JournalEntryRow(
                            entry: entry,
                            isSelected: viewModel.selectedEntryID == entry.id,
                            onSelect: {
                                withAnimation(Animations.quick) {
                                    viewModel.selectEntry(entry.id, from: modelContext)
                                }
                            },
                            onDelete: {
                                entryToDelete = entry
                                showingDeleteAlert = true
                            }
                        )
                        .staggerEffect(index: index, delayPerItem: 0.06)
                    }

                    if viewModel.filteredEntries.isEmpty && !viewModel.entries.isEmpty {
                        filterEmptyState
                    }
                }
                .padding(.bottom, OverwatchTheme.Spacing.xl)
            }
            .frame(minWidth: 280, idealWidth: 360, maxWidth: 400)

            // Right: editor / detail panel + sentiment trend
            ScrollView {
                VStack(spacing: OverwatchTheme.Spacing.lg) {
                    editorPanel

                    if !viewModel.sentimentTrend.isEmpty {
                        TacticalCard {
                            SentimentTrendChart(
                                data: viewModel.sentimentTrend
                            )
                        }
                        .materializeEffect(
                            isVisible: sectionsVisible, delay: 0.16
                        )
                    }
                }
                .padding(.bottom, OverwatchTheme.Spacing.xl)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.xl)
    }

    // MARK: - Editor Panel

    private var editorPanel: some View {
        TacticalCard {
            if viewModel.isEditing {
                activeEditor
            } else if let entry = viewModel.selectedEntry {
                entryDetail(entry)
            } else {
                emptySelection
            }
        }
    }

    // MARK: - Active Editor

    private var activeEditor: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
            // Header row: label + sentiment badge + actions
            HStack {
                sectionLabel(
                    viewModel.editingEntryID != nil
                        ? "// EDITING ENTRY"
                        : "// NEW ENTRY"
                )

                Spacer()

                liveSentimentBadge

                Button {
                    Task {
                        await viewModel.saveEntry(in: modelContext)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .medium))
                        Text("SAVE")
                            .font(Typography.hudLabel)
                            .tracking(1)
                    }
                }
                .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.accentSecondary))
                .disabled(
                    viewModel.editorContent
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button {
                    withAnimation(Animations.quick) {
                        viewModel.cancelEditing()
                    }
                } label: {
                    Text("CANCEL")
                        .font(Typography.hudLabel)
                        .tracking(1)
                }
                .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.textSecondary))
            }

            // Title field
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                Text("TITLE")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentCyan, radius: 2)

                TextField("Entry title...", text: $viewModel.editorTitle)
                    .textFieldStyle(.plain)
                    .font(Typography.commandLine)
                    .foregroundStyle(OverwatchTheme.textPrimary)
                    .padding(OverwatchTheme.Spacing.sm)
                    .background(OverwatchTheme.surface)
                    .clipShape(HUDFrameShape(chamferSize: 8))
                    .overlay(
                        HUDFrameShape(chamferSize: 8)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.3), lineWidth: 1)
                    )
            }

            // Content editor
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                Text("CONTENT")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .tracking(3)
                    .textGlow(OverwatchTheme.accentCyan, radius: 2)

                TextEditor(text: $viewModel.editorContent)
                    .scrollContentBackground(.hidden)
                    .font(Typography.commandLine)
                    .foregroundStyle(OverwatchTheme.textPrimary)
                    .padding(OverwatchTheme.Spacing.sm)
                    .frame(minHeight: 200, idealHeight: 350)
                    .background(OverwatchTheme.surface)
                    .clipShape(HUDFrameShape(chamferSize: 8))
                    .overlay(
                        HUDFrameShape(chamferSize: 8)
                            .stroke(OverwatchTheme.accentCyan.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: viewModel.editorContent) { _, _ in
                        Task { await viewModel.analyzeSentimentLive() }
                    }
            }

            HUDDivider()

            // Tags
            tagEditor
        }
    }

    // MARK: - Tag Editor

    private var tagEditor: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
            Text("TAGS")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    ForEach(viewModel.editorTags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag.uppercased())
                                .font(Typography.metricTiny)
                                .tracking(1)

                            Button {
                                withAnimation(Animations.quick) {
                                    viewModel.editorTags.removeAll { $0 == tag }
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .semibold))
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OverwatchTheme.accentCyan.opacity(0.08))
                        .clipShape(.capsule)
                        .overlay(
                            Capsule()
                                .stroke(OverwatchTheme.accentCyan.opacity(0.25), lineWidth: 1)
                        )
                    }

                    TextField("ADD TAG", text: $newTagText)
                        .textFieldStyle(.plain)
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .frame(minWidth: 60, maxWidth: 120)
                        .onSubmit {
                            let tag = newTagText
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            if !tag.isEmpty && !viewModel.editorTags.contains(tag) {
                                withAnimation(Animations.quick) {
                                    viewModel.editorTags.append(tag)
                                }
                            }
                            newTagText = ""
                        }
                }
            }
        }
    }

    // MARK: - Live Sentiment Badge

    private var liveSentimentBadge: some View {
        SentimentBadge(
            score: viewModel.currentSentiment.score,
            label: viewModel.currentSentiment.label.rawValue
        )
    }

    // MARK: - Entry Detail (Read-Only)

    private func entryDetail(_ entry: JournalViewModel.JournalItem) -> some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text(
                        (entry.title.isEmpty ? "UNTITLED" : entry.title)
                            .uppercased()
                    )
                    .font(Typography.title)
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .tracking(2)
                    .textGlow(OverwatchTheme.accentCyan, radius: 8)

                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        Text(
                            entry.date.formatted(
                                .dateTime.month(.abbreviated).day().year()
                            )
                        )
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)

                        Text("\(entry.wordCount) WORDS")
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                            .tracking(1)

                        sentimentBadge(
                            label: entry.sentimentLabel,
                            score: entry.sentimentScore
                        )
                    }
                }

                Spacer()

                Button {
                    withAnimation(Animations.quick) {
                        viewModel.selectEntry(entry.id, from: modelContext)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10, weight: .medium))
                        Text("EDIT")
                            .font(Typography.hudLabel)
                            .tracking(1)
                    }
                }
                .buttonStyle(HUDCompactButtonStyle(color: OverwatchTheme.accentCyan))
            }

            HUDDivider()

            // Content preview
            Text(entry.contentPreview)
                .font(Typography.commandLine)
                .foregroundStyle(OverwatchTheme.textPrimary.opacity(0.8))
                .lineSpacing(4)

            // Tags
            if !entry.tags.isEmpty {
                HUDDivider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OverwatchTheme.Spacing.xs) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text(tag.uppercased())
                                .font(Typography.metricTiny)
                                .tracking(1)
                                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(OverwatchTheme.accentCyan.opacity(0.06))
                                .clipShape(.capsule)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            OverwatchTheme.accentCyan.opacity(0.15),
                                            lineWidth: 1
                                        )
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty States

    private var emptySelection: some View {
        VStack(spacing: OverwatchTheme.Spacing.lg) {
            Image(systemName: "doc.text")
                .font(.system(size: 42, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.1), radius: 8)

            Text("SELECT AN ENTRY")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            Text("Choose a journal entry from the list to view or edit")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl * 2)
    }

    private var emptyState: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.lg) {
                Image(systemName: "book.pages")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.2))
                    .shadow(
                        color: OverwatchTheme.accentCyan.opacity(0.15),
                        radius: 12
                    )

                Text("BEGIN YOUR FIELD LOG")
                    .font(Typography.title)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.4))
                    .tracking(4)
                    .textGlow(OverwatchTheme.accentCyan, radius: 8)

                Text(
                    "Record thoughts, reflections, and daily observations"
                )
                .font(Typography.caption)
                .foregroundStyle(OverwatchTheme.textSecondary)

                Button {
                    withAnimation(Animations.quick) {
                        viewModel.startNewEntry()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("CREATE FIRST ENTRY")
                            .font(Typography.hudLabel)
                            .tracking(1.5)
                    }
                    .foregroundStyle(OverwatchTheme.accentCyan)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(OverwatchTheme.accentCyan.opacity(0.08))
                    .clipShape(HUDFrameShape(chamferSize: 8))
                    .overlay(
                        HUDFrameShape(chamferSize: 8)
                            .stroke(
                                OverwatchTheme.accentCyan.opacity(0.4),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OverwatchTheme.Spacing.xxl)
        }
        .padding(.horizontal, OverwatchTheme.Spacing.xl)
    }

    private var filterEmptyState: some View {
        VStack(spacing: OverwatchTheme.Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))

            Text("NO ENTRIES FOUND")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                .tracking(3)

            Text("Try adjusting your filters or search query")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            Rectangle()
                .fill(OverwatchTheme.accentCyan.opacity(0.6))
                .frame(width: 3, height: 12)
                .shadow(color: OverwatchTheme.accentCyan.opacity(0.6), radius: 4)

            Text(text)
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)
        }
    }

    private func sentimentBadge(label: String, score: Double) -> some View {
        SentimentBadge(score: score, label: label)
    }
}

// MARK: - Journal Entry Row

private struct JournalEntryRow: View {
    let entry: JournalViewModel.JournalItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: OverwatchTheme.Spacing.md) {
                // Sentiment dot
                SentimentDot(label: entry.sentimentLabel)

                // Title + meta
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        (entry.title.isEmpty ? "Untitled" : entry.title)
                            .uppercased()
                    )
                    .font(Typography.hudLabel)
                    .foregroundStyle(
                        isSelected
                            ? OverwatchTheme.textPrimary
                            : OverwatchTheme.textSecondary
                    )
                    .tracking(2)
                    .textGlow(
                        isSelected ? OverwatchTheme.accentCyan : .clear,
                        radius: 3
                    )
                    .lineLimit(1)

                    HStack(spacing: OverwatchTheme.Spacing.xs) {
                        Text(
                            entry.date.formatted(
                                .dateTime.month(.abbreviated).day()
                            )
                        )
                        .font(Typography.metricTiny)
                        .foregroundStyle(
                            OverwatchTheme.accentCyan.opacity(0.35)
                        )

                        Text("·")
                            .foregroundStyle(
                                OverwatchTheme.textSecondary.opacity(0.3)
                            )

                        Text(entry.contentPreview)
                            .font(Typography.metricTiny)
                            .foregroundStyle(
                                OverwatchTheme.textSecondary.opacity(0.5)
                            )
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Word count
                Text("\(entry.wordCount)w")
                    .font(Typography.metricTiny)
                    .foregroundStyle(
                        OverwatchTheme.textSecondary.opacity(0.5)
                    )
                    .monospacedDigit()
            }
            .padding(.horizontal, OverwatchTheme.Spacing.md)
            .padding(.vertical, OverwatchTheme.Spacing.sm + 2)
            .background(
                isSelected
                    ? OverwatchTheme.surfaceElevated.opacity(0.6)
                    : (isHovered
                        ? OverwatchTheme.surfaceElevated.opacity(0.3)
                        : .clear)
            )
            .clipShape(HUDFrameShape(chamferSize: 8))
            .overlay(
                HUDFrameShape(chamferSize: 8)
                    .stroke(
                        isSelected
                            ? OverwatchTheme.accentCyan.opacity(0.5)
                            : OverwatchTheme.accentCyan.opacity(
                                isHovered ? 0.2 : 0.08
                            ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected
                    ? OverwatchTheme.accentCyan.opacity(0.12) : .clear,
                radius: 8
            )
            .contentShape(HUDFrameShape(chamferSize: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Purge Entry", systemImage: "trash")
            }
        }
    }

}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.hudLabel)
                .tracking(1.5)
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
                        : (isHovered
                            ? OverwatchTheme.surfaceElevated
                            : .clear)
                )
                .clipShape(HUDFrameShape(chamferSize: 5))
                .overlay(
                    HUDFrameShape(chamferSize: 5)
                        .stroke(
                            isSelected
                                ? OverwatchTheme.accentCyan.opacity(0.5)
                                : OverwatchTheme.accentCyan.opacity(
                                    isHovered ? 0.2 : 0.1
                                ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? OverwatchTheme.accentCyan.opacity(0.2) : .clear,
                    radius: 6
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#Preview("Journal Page") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        JournalView()
    }
    .modelContainer(
        for: [Habit.self, HabitEntry.self, JournalEntry.self,
              MonthlyAnalysis.self, WhoopCycle.self],
        inMemory: true
    )
    .frame(width: 900, height: 700)
}
