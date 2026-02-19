import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {

    // MARK: - Types

    enum ConnectionStatus: Equatable {
        case linked, disconnected
    }

    enum TestStatus: Equatable {
        case idle, testing, success, failed(String)
    }

    enum AccentColorChoice: String, CaseIterable, Identifiable {
        case cyan = "Cyan"
        case green = "Green"
        case amber = "Amber"
        case red = "Red"
        case purple = "Purple"
        case white = "White"

        var id: String { rawValue }
    }

    // MARK: - UserDefaults Keys

    private enum Key {
        static let autoGenerate = "settings_autoGenerateReports"
        static let reportDay = "settings_reportDayOfWeek"
        static let reportHour = "settings_reportHour"
        static let reportMinute = "settings_reportMinute"
        static let reminderEnabled = "settings_dailyReminderEnabled"
        static let reminderHour = "settings_dailyReminderHour"
        static let reminderMinute = "settings_dailyReminderMinute"
        static let weeklyNotify = "settings_weeklyReportNotification"
        static let suggestions = "settings_showDefaultSuggestions"
        static let categories = "settings_customCategories"
        static let accent = "settings_accentColor"
    }

    // MARK: - WHOOP Connection

    var whoopStatus: ConnectionStatus = .disconnected
    var isConnectingWhoop = false
    var whoopError: String?
    var lastSyncDisplay = "NEVER"

    // MARK: - Gemini Connection

    var geminiKeyDisplay = ""
    var geminiKeySource: EnvironmentConfig.KeySource = .none
    var geminiTestStatus: TestStatus = .idle

    // MARK: - Report Settings

    var autoGenerateReports: Bool {
        didSet { UserDefaults.standard.set(autoGenerateReports, forKey: Key.autoGenerate) }
    }
    var reportDayOfWeek: Int {
        didSet { UserDefaults.standard.set(reportDayOfWeek, forKey: Key.reportDay) }
    }
    var reportHour: Int {
        didSet { UserDefaults.standard.set(reportHour, forKey: Key.reportHour) }
    }
    var reportMinute: Int {
        didSet { UserDefaults.standard.set(reportMinute, forKey: Key.reportMinute) }
    }

    // MARK: - Habit Settings

    var categories: [String] = []
    var newCategoryName = ""
    var showDefaultSuggestions: Bool {
        didSet { UserDefaults.standard.set(showDefaultSuggestions, forKey: Key.suggestions) }
    }

    // MARK: - Notification Settings

    var dailyReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(dailyReminderEnabled, forKey: Key.reminderEnabled) }
    }
    var reminderHour: Int {
        didSet { UserDefaults.standard.set(reminderHour, forKey: Key.reminderHour) }
    }
    var reminderMinute: Int {
        didSet { UserDefaults.standard.set(reminderMinute, forKey: Key.reminderMinute) }
    }
    var weeklyReportNotification: Bool {
        didSet { UserDefaults.standard.set(weeklyReportNotification, forKey: Key.weeklyNotify) }
    }

    // MARK: - Appearance

    var accentColor: AccentColorChoice {
        didSet { UserDefaults.standard.set(accentColor.rawValue, forKey: Key.accent) }
    }

    // MARK: - Data Management

    var showPurgeConfirmation = false
    var purgeConfirmText = ""
    var exportFeedback: String?

    // MARK: - Init

    init() {
        let d = UserDefaults.standard

        self.autoGenerateReports = d.bool(forKey: Key.autoGenerate)

        let day = d.integer(forKey: Key.reportDay)
        self.reportDayOfWeek = day > 0 ? day : 1

        let rh = d.integer(forKey: Key.reportHour)
        self.reportHour = rh > 0 || d.object(forKey: Key.reportHour) != nil ? rh : 8
        self.reportMinute = d.integer(forKey: Key.reportMinute)

        self.dailyReminderEnabled = d.bool(forKey: Key.reminderEnabled)
        let dh = d.integer(forKey: Key.reminderHour)
        self.reminderHour = dh > 0 || d.object(forKey: Key.reminderHour) != nil ? dh : 9
        self.reminderMinute = d.integer(forKey: Key.reminderMinute)
        self.weeklyReportNotification = d.bool(forKey: Key.weeklyNotify)

        self.showDefaultSuggestions = d.object(forKey: Key.suggestions) as? Bool ?? true

        if let stored = d.stringArray(forKey: Key.categories) {
            self.categories = stored
        } else {
            self.categories = HabitsViewModel.defaultCategories
        }

        if let raw = d.string(forKey: Key.accent), let c = AccentColorChoice(rawValue: raw) {
            self.accentColor = c
        } else {
            self.accentColor = .cyan
        }

        refreshConnectionStates()
    }

    // MARK: - Connection Methods

    func refreshConnectionStates() {
        whoopStatus = KeychainHelper.readString(key: KeychainHelper.Keys.whoopAccessToken) != nil
            ? .linked : .disconnected

        geminiKeySource = EnvironmentConfig.geminiKeySource
        if let key = EnvironmentConfig.geminiAPIKey {
            geminiKeyDisplay = maskKey(key)
        } else {
            geminiKeyDisplay = ""
        }
    }

    func markWhoopConnected() {
        whoopStatus = .linked
        whoopError = nil
    }

    func disconnectWhoop() {
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopAccessToken)
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopRefreshToken)
        KeychainHelper.delete(key: KeychainHelper.Keys.whoopTokenExpiry)
        whoopStatus = .disconnected
        lastSyncDisplay = "NEVER"
    }

    func testGeminiConnection() async {
        geminiTestStatus = .testing
        guard let service = GeminiService.create() else {
            geminiTestStatus = .failed("No API key — add to .env file")
            return
        }
        do {
            let ok = try await service.testConnection()
            geminiTestStatus = ok ? .success : .failed("Invalid response")
        } catch {
            geminiTestStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Category Management

    func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !categories.contains(name) else { return }
        categories.append(name)
        persistCategories()
        newCategoryName = ""
    }

    func deleteCategory(_ name: String) {
        categories.removeAll { $0 == name }
        persistCategories()
    }

    func resetCategoriesToDefault() {
        categories = HabitsViewModel.defaultCategories
        persistCategories()
    }

    private func persistCategories() {
        UserDefaults.standard.set(categories, forKey: Key.categories)
    }

    // MARK: - Data Export

    func buildAllDataJSON(from context: ModelContext) -> Data? {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
        let journals = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        let cycles = (try? context.fetch(FetchDescriptor<WhoopCycle>())) ?? []
        let iso = ISO8601DateFormatter()

        let export: [String: Any] = [
            "exportedAt": iso.string(from: .now),
            "version": "1.0",
            "habits": habits.map { h -> [String: Any] in
                [
                    "id": h.id.uuidString, "name": h.name, "emoji": h.emoji,
                    "category": h.category, "targetFrequency": h.targetFrequency,
                    "isQuantitative": h.isQuantitative, "unitLabel": h.unitLabel,
                    "sortOrder": h.sortOrder, "createdAt": iso.string(from: h.createdAt),
                ]
            },
            "habitEntries": entries.map { e -> [String: Any] in
                var d: [String: Any] = [
                    "id": e.id.uuidString, "date": iso.string(from: e.date),
                    "completed": e.completed, "loggedAt": iso.string(from: e.loggedAt),
                    "habitName": e.habit?.name ?? "Unknown",
                ]
                if let v = e.value { d["value"] = v }
                if !e.notes.isEmpty { d["notes"] = e.notes }
                return d
            },
            "journalEntries": journals.map { j -> [String: Any] in
                [
                    "id": j.id.uuidString, "date": iso.string(from: j.date),
                    "content": j.content, "parsedHabits": j.parsedHabits,
                    "createdAt": iso.string(from: j.createdAt),
                ]
            },
            "whoopCycles": cycles.map { c -> [String: Any] in
                [
                    "cycleId": c.cycleId, "date": iso.string(from: c.date),
                    "strain": c.strain, "kilojoules": c.kilojoules,
                    "recoveryScore": c.recoveryScore, "hrvRmssdMilli": c.hrvRmssdMilli,
                    "restingHeartRate": c.restingHeartRate,
                    "sleepPerformance": c.sleepPerformance,
                    "fetchedAt": iso.string(from: c.fetchedAt),
                ]
            },
        ]

        return try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }

    func buildHabitsCSV(from context: ModelContext) -> Data? {
        let entries = (try? context.fetch(FetchDescriptor<HabitEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []

        var csv = "Date,Habit,Emoji,Category,Completed,Value,Unit,Notes\n"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        for e in entries {
            let parts: [String] = [
                df.string(from: e.date),
                csvEscape(e.habit?.name ?? "Unknown"),
                e.habit?.emoji ?? "",
                csvEscape(e.habit?.category ?? ""),
                e.completed ? "Yes" : "No",
                e.value.map { String($0) } ?? "",
                e.habit?.unitLabel ?? "",
                csvEscape(e.notes),
            ]
            csv += parts.joined(separator: ",") + "\n"
        }

        return csv.data(using: .utf8)
    }

    func purgeAllData(from context: ModelContext) {
        if let h = try? context.fetch(FetchDescriptor<Habit>()) {
            for item in h { context.delete(item) }
        }
        if let c = try? context.fetch(FetchDescriptor<WhoopCycle>()) {
            for item in c { context.delete(item) }
        }
        if let j = try? context.fetch(FetchDescriptor<JournalEntry>()) {
            for item in j { context.delete(item) }
        }
        try? context.save()

        showPurgeConfirmation = false
        purgeConfirmText = ""
    }

    // MARK: - Helpers

    static let dayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday",
    ]

    func dayName(for index: Int) -> String {
        guard (1...7).contains(index) else { return "Sunday" }
        return Self.dayNames[index - 1]
    }

    func formatTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        return String(key.prefix(4)) + String(repeating: "•", count: key.count - 8) + String(key.suffix(4))
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
