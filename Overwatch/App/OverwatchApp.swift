import SwiftUI
import SwiftData

@main
struct OverwatchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationShell()
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: [
            Habit.self,
            HabitEntry.self,
            JournalEntry.self,
            WhoopCycle.self,
        ])
    }
}
