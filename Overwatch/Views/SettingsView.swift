import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()

    @State private var exportJSONData: Data?
    @State private var exportCSVData: Data?
    @State private var showJSONExport = false
    @State private var showCSVExport = false

    #if DEBUG
    @State private var seedStatus: String?
    @State private var isSeeding = false
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                stubHeader("SETTINGS", subtitle: "SYSTEM CONFIGURATION")

                connectionsSection
                reportsSection
                habitsSection
                notificationsSection
                dataSection
                appearanceSection

                #if DEBUG
                debugSection
                #endif
            }
            .padding(OverwatchTheme.Spacing.xl)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .fileExporter(
            isPresented: $showJSONExport,
            document: ExportFileDocument(data: exportJSONData ?? Data()),
            contentType: .json,
            defaultFilename: "overwatch_export.json"
        ) { result in
            handleExportResult(result, label: "JSON")
        }
        .fileExporter(
            isPresented: $showCSVExport,
            document: ExportFileDocument(data: exportCSVData ?? Data()),
            contentType: .commaSeparatedText,
            defaultFilename: "overwatch_habits.csv"
        ) { result in
            handleExportResult(result, label: "CSV")
        }
        .onChange(of: appState.whoopSyncStatus) { _, newStatus in
            if case .synced(let date) = newStatus {
                viewModel.lastSyncDisplay = DateFormatters.relative.localizedString(
                    for: date, relativeTo: .now
                ).uppercased()
            }
        }
    }

    // MARK: - Connections

    private var connectionsSection: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                sectionLabel("CONNECTIONS")

                whoopConnectionRow
                HUDDivider().opacity(0.5)
                geminiConnectionRow
            }
        }
    }

    private var whoopConnectionRow: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
            HStack(spacing: OverwatchTheme.Spacing.md) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(whoopStatusColor)
                    .textGlow(whoopStatusColor, radius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WHOOP BIOMETRIC LINK")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .tracking(2)

                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        Circle()
                            .fill(whoopStatusColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: whoopStatusColor.opacity(0.6), radius: 3)

                        Text(whoopStatusLabel)
                            .font(Typography.hudLabel)
                            .foregroundStyle(whoopStatusColor)
                            .tracking(1.5)
                    }
                }

                Spacer()

                if viewModel.isConnectingWhoop {
                    ProgressView()
                        .controlSize(.small)
                        .tint(OverwatchTheme.accentCyan)
                } else if viewModel.whoopStatus == .linked {
                    if case .error(let msg) = appState.whoopSyncStatus, msg.contains("SESSION EXPIRED") {
                        hudButton("RECONNECT", color: OverwatchTheme.accentPrimary) {
                            appState.stopWhoopSync()
                            viewModel.disconnectWhoop()
                            connectWhoop()
                        }
                    } else {
                        hudButton("DISCONNECT", color: OverwatchTheme.alert) {
                            appState.stopWhoopSync()
                            viewModel.disconnectWhoop()
                        }
                    }
                } else {
                    hudButton("CONNECT WHOOP", color: OverwatchTheme.accentCyan) {
                        connectWhoop()
                    }
                }
            }

            if viewModel.whoopStatus == .linked {
                Text("LAST SYNC: \(viewModel.lastSyncDisplay)")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
                    .tracking(1)
                    .padding(.leading, 34)
            }

            if let error = viewModel.whoopError {
                Text("ERROR: \(error)")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.alert)
                    .padding(.leading, 34)
            }
        }
    }

    private var geminiConnectionRow: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
            HStack(spacing: OverwatchTheme.Spacing.md) {
                Image(systemName: "brain")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(geminiStatusColor)
                    .textGlow(geminiStatusColor, radius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("GEMINI AI ENGINE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .tracking(2)

                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        Circle()
                            .fill(geminiSourceColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: geminiSourceColor.opacity(0.6), radius: 3)

                        Text(viewModel.geminiKeySource.displayLabel)
                            .font(Typography.hudLabel)
                            .foregroundStyle(geminiSourceColor)
                            .tracking(1.5)
                    }

                    if !viewModel.geminiKeyDisplay.isEmpty {
                        Text(viewModel.geminiKeyDisplay)
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                    }
                }

                Spacer()

                geminiTestBadge
            }

            if viewModel.geminiKeySource == .none {
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(OverwatchTheme.textSecondary)
                    Text("Add GEMINI_API_KEY to .env file in project root, then rebuild.")
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                }
            }

            hudButton("TEST CONNECTION", color: OverwatchTheme.accentPrimary) {
                Task { await viewModel.testGeminiConnection() }
            }
        }
    }

    @ViewBuilder
    private var geminiTestBadge: some View {
        switch viewModel.geminiTestStatus {
        case .idle:
            EmptyView()
        case .testing:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                    .tint(OverwatchTheme.accentPrimary)
                Text("TESTING")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentPrimary)
                    .tracking(1)
            }
        case .success:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(OverwatchTheme.accentSecondary)
                Text("VERIFIED")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentSecondary)
                    .tracking(1)
                    .textGlow(OverwatchTheme.accentSecondary, radius: 4)
            }
        case .failed(let msg):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(OverwatchTheme.alert)
                Text(msg.uppercased())
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.alert)
                    .tracking(1)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Reports

    private var reportsSection: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                sectionLabel("INTEL REPORTS")

                settingRow("AUTO-GENERATE") {
                    hudToggle(isOn: $viewModel.autoGenerateReports)
                }

                if viewModel.autoGenerateReports {
                    settingRow("SCHEDULE DAY") {
                        Picker("", selection: $viewModel.reportDayOfWeek) {
                            ForEach(1...7, id: \.self) { day in
                                Text(viewModel.dayName(for: day).uppercased())
                                    .tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                        .tint(OverwatchTheme.accentCyan)
                    }

                    settingRow("SCHEDULE TIME") {
                        HStack(spacing: OverwatchTheme.Spacing.xs) {
                            timePicker(value: $viewModel.reportHour, range: 0...23, width: 55)
                            Text(":")
                                .font(Typography.metricSmall)
                                .foregroundStyle(OverwatchTheme.accentCyan)
                            timePicker(value: $viewModel.reportMinute, range: stride(from: 0, through: 55, by: 5), width: 55)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Habits

    private var habitsSection: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                sectionLabel("OPERATIONS")

                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                    Text("CATEGORIES")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(2)

                    categoryChips

                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        TextField("", text: $viewModel.newCategoryName, prompt: categoryPlaceholder)
                            .font(Typography.metricSmall)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, OverwatchTheme.Spacing.md)
                            .padding(.vertical, OverwatchTheme.Spacing.sm)
                            .background(OverwatchTheme.background.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm)
                                    .stroke(OverwatchTheme.accentCyan.opacity(0.25), lineWidth: 1)
                            )
                            .onSubmit { viewModel.addCategory() }

                        hudButton("ADD", color: OverwatchTheme.accentCyan) {
                            viewModel.addCategory()
                        }

                        Spacer()

                        hudButton("RESET DEFAULTS", color: OverwatchTheme.textSecondary) {
                            viewModel.resetCategoriesToDefault()
                        }
                    }
                }

                HUDDivider().opacity(0.5)

                settingRow("DEFAULT HABIT SUGGESTIONS") {
                    hudToggle(isOn: $viewModel.showDefaultSuggestions)
                }
            }
        }
    }

    private var categoryChips: some View {
        FlowLayout(spacing: OverwatchTheme.Spacing.sm) {
            ForEach(viewModel.categories, id: \.self) { category in
                HStack(spacing: OverwatchTheme.Spacing.xs) {
                    Text(category.uppercased())
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(1)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            viewModel.deleteCategory(category)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(OverwatchTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, OverwatchTheme.Spacing.md)
                .padding(.vertical, OverwatchTheme.Spacing.xs + 2)
                .background(OverwatchTheme.accentCyan.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm)
                        .stroke(OverwatchTheme.accentCyan.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    private var categoryPlaceholder: Text {
        Text("New category name...")
            .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.5))
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                sectionLabel("ALERTS")

                settingRow("DAILY HABIT REMINDER") {
                    hudToggle(isOn: $viewModel.dailyReminderEnabled)
                }

                if viewModel.dailyReminderEnabled {
                    settingRow("REMINDER TIME") {
                        HStack(spacing: OverwatchTheme.Spacing.xs) {
                            timePicker(value: $viewModel.reminderHour, range: 0...23, width: 55)
                            Text(":")
                                .font(Typography.metricSmall)
                                .foregroundStyle(OverwatchTheme.accentCyan)
                            timePicker(value: $viewModel.reminderMinute, range: stride(from: 0, through: 55, by: 5), width: 55)
                        }
                    }
                }

                HUDDivider().opacity(0.5)

                settingRow("WEEKLY REPORT READY") {
                    hudToggle(isOn: $viewModel.weeklyReportNotification)
                }
            }
        }
    }

    // MARK: - Data Management

    private var dataSection: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                sectionLabel("DATA MANAGEMENT")

                HStack(spacing: OverwatchTheme.Spacing.md) {
                    hudButton("EXPORT ALL DATA", icon: "square.and.arrow.up", color: OverwatchTheme.accentCyan) {
                        exportJSONData = viewModel.buildAllDataJSON(from: modelContext)
                        if exportJSONData != nil { showJSONExport = true }
                    }

                    Text("JSON")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(1)
                }

                HStack(spacing: OverwatchTheme.Spacing.md) {
                    hudButton("EXPORT HABITS", icon: "tablecells", color: OverwatchTheme.accentCyan) {
                        exportCSVData = viewModel.buildHabitsCSV(from: modelContext)
                        if exportCSVData != nil { showCSVExport = true }
                    }

                    Text("CSV")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(1)
                }

                if let feedback = viewModel.exportFeedback {
                    Text(feedback)
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentSecondary)
                        .tracking(1)
                }

                HUDDivider().opacity(0.5)

                purgeSection
            }
        }
    }

    private var purgeSection: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
            if !viewModel.showPurgeConfirmation {
                hudButton("PURGE ALL DATA", icon: "trash", color: OverwatchTheme.alert) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        viewModel.showPurgeConfirmation = true
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.md) {
                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(OverwatchTheme.alert)
                        Text("DANGER ZONE")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.alert)
                            .tracking(2)
                            .textGlow(OverwatchTheme.alert, radius: 4)
                    }

                    Text("This will permanently destroy ALL habits, entries, WHOOP data, and journal entries. This cannot be undone.")
                        .font(Typography.caption)
                        .foregroundStyle(OverwatchTheme.textSecondary)

                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        TextField("", text: $viewModel.purgeConfirmText, prompt: purgePlaceholder)
                            .font(Typography.metricSmall)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, OverwatchTheme.Spacing.md)
                            .padding(.vertical, OverwatchTheme.Spacing.sm)
                            .background(OverwatchTheme.background.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm)
                                    .stroke(OverwatchTheme.alert.opacity(0.4), lineWidth: 1)
                            )
                            .frame(maxWidth: 250)

                        hudButton("CONFIRM PURGE", color: OverwatchTheme.alert) {
                            viewModel.purgeAllData(from: modelContext)
                        }
                        .opacity(viewModel.purgeConfirmText == "PURGE" ? 1.0 : 0.3)
                        .disabled(viewModel.purgeConfirmText != "PURGE")

                        hudButton("CANCEL", color: OverwatchTheme.textSecondary) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                viewModel.showPurgeConfirmation = false
                                viewModel.purgeConfirmText = ""
                            }
                        }
                    }
                }
                .padding(OverwatchTheme.Spacing.md)
                .background(OverwatchTheme.alert.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.md)
                        .stroke(OverwatchTheme.alert.opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var purgePlaceholder: Text {
        Text("Type PURGE to confirm")
            .foregroundStyle(OverwatchTheme.alert.opacity(0.4))
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                sectionLabel("APPEARANCE")

                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
                    Text("ACCENT COLOR")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .tracking(2)

                    HStack(spacing: OverwatchTheme.Spacing.md) {
                        ForEach(SettingsViewModel.AccentColorChoice.allCases) { choice in
                            accentColorSwatch(choice)
                        }
                    }
                }
            }
        }
    }

    private func accentColorSwatch(_ choice: SettingsViewModel.AccentColorChoice) -> some View {
        let color = swatchColor(for: choice)
        let isSelected = viewModel.accentColor == choice

        return Button {
            withAnimation(.easeOut(duration: 0.2)) {
                viewModel.accentColor = choice
            }
        } label: {
            VStack(spacing: OverwatchTheme.Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.white : color.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: isSelected ? color.opacity(0.6) : .clear, radius: 8)
                    .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 16)
                    .scaleEffect(isSelected ? 1.15 : 1.0)

                Text(choice.rawValue.uppercased())
                    .font(Typography.hudLabel)
                    .foregroundStyle(isSelected ? color : OverwatchTheme.textSecondary)
                    .tracking(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Debug (DEBUG only)

    #if DEBUG
    private var debugSection: some View {
        TacticalCard {
            VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                sectionLabel("DEBUG")

                Text("Seed or clear 60 days of synthetic journal + habit data with designed sentiment correlations. Your real entries are never touched.")
                    .font(Typography.caption)
                    .foregroundStyle(OverwatchTheme.textSecondary)

                HStack(spacing: OverwatchTheme.Spacing.md) {
                    hudButton(
                        "SEED DEMO DATA",
                        icon: "flask",
                        color: OverwatchTheme.accentPrimary
                    ) {
                        guard !isSeeding else { return }
                        isSeeding = true
                        seedStatus = nil

                        SyntheticDataSeeder.seedJournalAndHabits(in: modelContext)

                        let service = SentimentAnalysisService()
                        Task {
                            let descriptor = FetchDescriptor<JournalEntry>(
                                predicate: #Predicate<JournalEntry> { $0.sentimentScore == 0.0 },
                                sortBy: [SortDescriptor(\.date)]
                            )
                            if let entries = try? modelContext.fetch(descriptor) {
                                await service.analyzeBatch(entries)
                            }
                            seedStatus = "Seeded 60 days + scored sentiment"
                            isSeeding = false
                        }
                    }
                    .disabled(isSeeding)
                    .opacity(isSeeding ? 0.5 : 1.0)

                    hudButton(
                        "CLEAR DEMO DATA",
                        icon: "trash",
                        color: OverwatchTheme.alert
                    ) {
                        guard !isSeeding else { return }
                        SyntheticDataSeeder.clearSyntheticData(from: modelContext)
                        seedStatus = "Demo data removed"
                    }
                    .disabled(isSeeding)

                    if isSeeding {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(OverwatchTheme.accentPrimary)
                    }
                }

                if let status = seedStatus {
                    Text(status)
                        .font(Typography.hudLabel)
                        .foregroundStyle(
                            status.contains("removed")
                                ? OverwatchTheme.alert
                                : OverwatchTheme.accentSecondary
                        )
                        .tracking(1)
                }
            }
        }
    }
    #endif

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.subtitle)
            .foregroundStyle(OverwatchTheme.accentCyan)
            .tracking(4)
            .textGlow(OverwatchTheme.accentCyan, radius: 6)
    }

    private func settingRow<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            Text(label)
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.textSecondary)
                .tracking(2)

            Spacer()

            control()
        }
    }

    private func hudToggle(isOn: Binding<Bool>) -> some View {
        HUDToggle(isOn: isOn)
    }

    private func hudButton(
        _ title: String,
        icon: String? = nil,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: OverwatchTheme.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                }
                Text(title)
                    .font(Typography.hudLabel)
                    .tracking(1.5)
            }
            .foregroundStyle(color)
            .padding(.horizontal, OverwatchTheme.Spacing.md)
            .padding(.vertical, OverwatchTheme.Spacing.sm)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: OverwatchTheme.CornerRadius.sm)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func timePicker<S: Sequence>(value: Binding<Int>, range: S, width: CGFloat) -> some View where S.Element == Int {
        Picker("", selection: value) {
            ForEach(Array(range), id: \.self) { v in
                Text(String(format: "%02d", v)).tag(v)
            }
        }
        .pickerStyle(.menu)
        .frame(width: width)
        .tint(OverwatchTheme.accentCyan)
    }

    private var whoopStatusColor: Color {
        if viewModel.whoopStatus == .linked {
            if case .error = appState.whoopSyncStatus {
                return OverwatchTheme.accentPrimary // Amber — linked but sync error
            }
            return OverwatchTheme.accentSecondary
        }
        return OverwatchTheme.alert
    }

    private var whoopStatusLabel: String {
        if viewModel.whoopStatus == .linked {
            if case .error(let msg) = appState.whoopSyncStatus {
                return msg.contains("SESSION EXPIRED") ? "SESSION EXPIRED" : "LINKED"
            }
            if case .syncing = appState.whoopSyncStatus {
                return "SYNCING..."
            }
            return "LINKED"
        }
        return "DISCONNECTED"
    }

    private var geminiStatusColor: Color {
        switch viewModel.geminiTestStatus {
        case .success: OverwatchTheme.accentSecondary
        case .failed: OverwatchTheme.alert
        default: viewModel.geminiKeySource == .none ? OverwatchTheme.textSecondary : OverwatchTheme.accentPrimary
        }
    }

    private var geminiSourceColor: Color {
        viewModel.geminiKeySource == .none ? OverwatchTheme.alert : OverwatchTheme.accentSecondary
    }

    private func swatchColor(for choice: SettingsViewModel.AccentColorChoice) -> Color {
        switch choice {
        case .cyan: OverwatchTheme.accentCyan
        case .green: OverwatchTheme.accentSecondary
        case .amber: OverwatchTheme.accentPrimary
        case .red: OverwatchTheme.alert
        case .purple: Color(red: 0.69, green: 0.32, blue: 1.0)
        case .white: Color.white
        }
    }

    private func connectWhoop() {
        Task {
            viewModel.isConnectingWhoop = true
            viewModel.whoopError = nil
            let auth = WhoopAuthManager()
            do {
                print("[WHOOP] Starting OAuth flow...")
                try await auth.authorize()
                print("[WHOOP] OAuth succeeded — tokens stored")
                viewModel.markWhoopConnected()
                // Pass the same auth manager to sync — its in-memory tokens are guaranteed valid.
                // Creating a new WhoopAuthManager would read from Keychain, which may fail silently.
                appState.restartWhoopSync(modelContainer: modelContext.container, authProvider: auth)
                print("[WHOOP] Sync restart triggered (reusing auth)")
            } catch {
                print("[WHOOP] OAuth FAILED: \(error)")
                viewModel.whoopError = error.localizedDescription
            }
            viewModel.isConnectingWhoop = false
        }
    }

    private func handleExportResult(_ result: Result<URL, any Error>, label: String) {
        switch result {
        case .success:
            viewModel.exportFeedback = "✓ \(label) EXPORT COMPLETE"
            Task {
                try? await Task.sleep(for: .seconds(2))
                viewModel.exportFeedback = nil
            }
        case .failure:
            viewModel.exportFeedback = nil
        }
    }
}

// MARK: - HUD Toggle

private struct HUDToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn ? OverwatchTheme.accentCyan.opacity(0.2) : OverwatchTheme.surface)
                    .frame(width: 40, height: 22)
                    .overlay(
                        Capsule()
                            .stroke(
                                isOn ? OverwatchTheme.accentCyan.opacity(0.6) : OverwatchTheme.textSecondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )

                Circle()
                    .fill(isOn ? OverwatchTheme.accentCyan : OverwatchTheme.textSecondary.opacity(0.5))
                    .frame(width: 16, height: 16)
                    .shadow(color: isOn ? OverwatchTheme.accentCyan.opacity(0.5) : .clear, radius: 4)
                    .offset(x: isOn ? 9 : -9)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Export Document

private struct ExportFileDocument: FileDocument {
    nonisolated(unsafe) static var readableContentTypes: [UTType] = [.json, .commaSeparatedText]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        SettingsView()
    }
    .environment(AppState())
    .modelContainer(for: [Habit.self, HabitEntry.self, JournalEntry.self, WhoopCycle.self],
                    inMemory: true)
    .frame(width: 800, height: 900)
}
