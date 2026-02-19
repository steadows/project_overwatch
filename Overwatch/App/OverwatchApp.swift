import SwiftUI
import SwiftData

@main
struct OverwatchApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: [
            Habit.self,
            HabitEntry.self,
            JournalEntry.self,
            MonthlyAnalysis.self,
            WhoopCycle.self,
            WeeklyInsight.self,
        ])
    }
}
