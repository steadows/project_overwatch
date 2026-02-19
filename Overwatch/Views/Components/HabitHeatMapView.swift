import SwiftUI
import SwiftData

// MARK: - Heat Map Data

/// Pre-computed daily completion data for the heat map.
/// Computed by a ViewModel, passed into the view — keeps the component pure.
struct HeatMapDay: Identifiable, Equatable {
    let id: Date // startOfDay
    let date: Date
    let completionRate: Double // 0.0–1.0
    let completedCount: Int
    let totalCount: Int

    /// Habit names completed on this day (for tooltip).
    let completedHabits: [String]
}

// MARK: - Heat Map Mode

enum HeatMapMode: Equatable {
    /// 52×7 grid — trailing 12 months. Used on Habits page.
    case full
    /// ~4×7 grid — trailing 30 days. Used on Dashboard preview.
    case compact
}

// MARK: - HabitHeatMapView

/// Canvas-rendered heat map grid showing daily habit completion intensity.
///
/// Supports two modes:
/// - **Full:** 52 weeks × 7 days (trailing 12 months) for the Habits page.
/// - **Compact:** ~4 weeks × 7 days (trailing 30 days) for the Dashboard preview.
///
/// Uses `Canvas` for rendering performance — 365+ cells at 60fps.
struct HabitHeatMapView: View {
    let days: [HeatMapDay]
    let mode: HeatMapMode

    /// Currently hovered day (for tooltip). Nil if no hover.
    @State private var hoveredDay: HeatMapDay?
    /// Screen position of the hovered cell (for tooltip placement).
    @State private var hoverPosition: CGPoint = .zero
    /// Whether the tooltip is visible (animated).
    @State private var tooltipVisible = false

    private var cellSpacing: CGFloat { mode == .compact ? 3 : 2 }
    private var cellCornerRadius: CGFloat { 2 }
    private var rows: Int { 7 } // Days of week (Mon–Sun)

    private var columns: Int {
        switch mode {
        case .full: return 52
        case .compact: return 5 // ~30 days ÷ 7 ≈ 4.3, round to 5 to cover
        }
    }

    /// Map days into a grid layout: column = week index, row = weekday index.
    private var grid: [[HeatMapDay?]] {
        let calendar = Calendar.current

        guard let firstDay = days.min(by: { $0.date < $1.date })?.date else {
            return Array(repeating: Array(repeating: nil, count: rows), count: columns)
        }

        let startOfFirstWeek = calendar.startOfDay(for: firstDay)

        // Build a lookup by date
        var lookup: [Date: HeatMapDay] = [:]
        for day in days {
            lookup[calendar.startOfDay(for: day.date)] = day
        }

        var result: [[HeatMapDay?]] = []

        for col in 0..<columns {
            var column: [HeatMapDay?] = []
            for row in 0..<rows {
                let dayOffset = col * 7 + row
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: startOfFirstWeek) {
                    let key = calendar.startOfDay(for: date)
                    column.append(lookup[key])
                } else {
                    column.append(nil)
                }
            }
            result.append(column)
        }

        return result
    }

    var body: some View {
        VStack(spacing: OverwatchTheme.Spacing.sm) {
            heatMapCanvas
            if mode == .full {
                legendBar
            }
        }
    }

    // MARK: - Canvas Grid

    private var heatMapCanvas: some View {
        GeometryReader { geo in
            let totalSpacingX = CGFloat(columns - 1) * cellSpacing
            let totalSpacingY = CGFloat(rows - 1) * cellSpacing
            let cellW = (geo.size.width - totalSpacingX) / CGFloat(columns)
            let cellH = (geo.size.height - totalSpacingY) / CGFloat(rows)
            let cellSize = min(cellW, cellH)

            let gridData = grid

            Canvas { context, size in
                for col in 0..<gridData.count {
                    for row in 0..<rows {
                        guard row < gridData[col].count else { continue }

                        let x = CGFloat(col) * (cellSize + cellSpacing)
                        let y = CGFloat(row) * (cellSize + cellSpacing)
                        let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
                        let roundedRect = Path(roundedRect: rect, cornerRadius: cellCornerRadius)

                        let rate = gridData[col][row]?.completionRate ?? -1
                        let isHovered = hoveredDay != nil
                            && gridData[col][row]?.id == hoveredDay?.id

                        let color = cellColor(rate: rate, isHovered: isHovered)
                        context.fill(roundedRect, with: .color(color))

                        // Glow on high-completion cells or hovered cells
                        if rate >= 1.0 || isHovered {
                            context.drawLayer { ctx in
                                ctx.addFilter(.shadow(
                                    color: OverwatchTheme.accentCyan.opacity(isHovered ? 0.5 : 0.3),
                                    radius: isHovered ? 5 : 3
                                ))
                                ctx.fill(roundedRect, with: .color(color))
                            }
                        } else if rate > 0.67 {
                            context.drawLayer { ctx in
                                ctx.addFilter(.shadow(
                                    color: OverwatchTheme.accentCyan.opacity(0.15),
                                    radius: 2
                                ))
                                ctx.fill(roundedRect, with: .color(color))
                            }
                        }
                    }
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let gridData = grid
                    let col = Int(location.x / (cellSize + cellSpacing))
                    let row = Int(location.y / (cellSize + cellSpacing))
                    if col >= 0, col < gridData.count, row >= 0, row < rows,
                       row < gridData[col].count,
                       let day = gridData[col][row] {
                        if hoveredDay?.id != day.id {
                            hoveredDay = day
                            hoverPosition = CGPoint(
                                x: CGFloat(col) * (cellSize + cellSpacing) + cellSize / 2,
                                y: CGFloat(row) * (cellSize + cellSpacing) + cellSize + 6
                            )
                            withAnimation(.easeOut(duration: 0.15)) {
                                tooltipVisible = true
                            }
                        }
                    } else {
                        dismissTooltip()
                    }
                case .ended:
                    dismissTooltip()
                }
            }
            .overlay {
                if let day = hoveredDay, tooltipVisible {
                    heatMapTooltip(for: day)
                        .position(x: hoverPosition.x, y: hoverPosition.y + 30)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .frame(height: heatMapHeight)
    }

    private var heatMapHeight: CGFloat {
        switch mode {
        case .full: return 120
        case .compact: return 64
        }
    }

    private func dismissTooltip() {
        withAnimation(.easeIn(duration: 0.1)) {
            tooltipVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !tooltipVisible { hoveredDay = nil }
        }
    }

    // MARK: - Cell Color

    private func cellColor(rate: Double, isHovered: Bool) -> Color {
        let scale: CGFloat = isHovered ? 1.15 : 1.0
        _ = scale // hover scale handled by glow, not cell size in Canvas

        switch rate {
        case ..<0:
            // No data for this cell (outside date range)
            return Color.clear
        case 0:
            return Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
        case 0.01..<0.34:
            return OverwatchTheme.accentCyan.opacity(0.2)
        case 0.34..<0.67:
            return OverwatchTheme.accentCyan.opacity(0.5)
        case 0.67..<1.0:
            return OverwatchTheme.accentCyan.opacity(0.8)
        default:
            return OverwatchTheme.accentCyan
        }
    }

    // MARK: - Tooltip

    private func heatMapTooltip(for day: HeatMapDay) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan)
                .tracking(1.5)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            HStack(spacing: 6) {
                Text("\(day.completedCount)/\(day.totalCount)")
                    .font(Typography.metricSmall)
                    .foregroundStyle(OverwatchTheme.textPrimary)

                Text("\(Int(day.completionRate * 100))%")
                    .font(Typography.metricTiny)
                    .foregroundStyle(tooltipRateColor(day.completionRate))
            }

            if !day.completedHabits.isEmpty {
                Text(day.completedHabits.joined(separator: ", "))
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(OverwatchTheme.surfaceElevated)
        .clipShape(HUDFrameShape(chamferSize: 6))
        .overlay(
            HUDFrameShape(chamferSize: 6)
                .stroke(OverwatchTheme.accentCyan.opacity(0.5), lineWidth: 1)
        )
        .hudGlow(color: OverwatchTheme.accentCyan)
        .fixedSize()
    }

    private func tooltipRateColor(_ rate: Double) -> Color {
        switch rate {
        case 0.67...: return OverwatchTheme.accentSecondary
        case 0.34..<0.67: return OverwatchTheme.accentPrimary
        default: return OverwatchTheme.alert
        }
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: OverwatchTheme.Spacing.md) {
            Text("LESS")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)

            HStack(spacing: 3) {
                legendCell(color: Color(red: 0.11, green: 0.11, blue: 0.12))
                legendCell(color: OverwatchTheme.accentCyan.opacity(0.2))
                legendCell(color: OverwatchTheme.accentCyan.opacity(0.5))
                legendCell(color: OverwatchTheme.accentCyan.opacity(0.8))
                legendCell(color: OverwatchTheme.accentCyan)
            }

            Text("MORE")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)

            Spacer()
        }
    }

    private func legendCell(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 12, height: 12)
    }
}

// MARK: - Heat Map Data Builder

/// Computes heat map data from SwiftData models.
/// Called by ViewModels to prepare data for HabitHeatMapView.
enum HeatMapDataBuilder {

    /// Build aggregate heat map data for all habits over the given day count.
    /// - Parameters:
    ///   - habits: All tracked habits
    ///   - dayCount: Number of trailing days (30 for compact, 365 for full)
    /// - Returns: Array of HeatMapDay sorted oldest → newest
    static func buildAggregate(habits: [Habit], dayCount: Int) -> [HeatMapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let totalHabits = max(habits.count, 1)

        // Collect all entries into a date-keyed lookup
        var entriesByDate: [Date: [(habitName: String, completed: Bool)]] = [:]
        for habit in habits {
            for entry in habit.entries where entry.completed {
                let dayKey = calendar.startOfDay(for: entry.date)
                entriesByDate[dayKey, default: []].append((habit.name, true))
            }
        }

        var days: [HeatMapDay] = []
        for offset in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: -(dayCount - 1 - offset), to: today)!
            let dayKey = calendar.startOfDay(for: date)
            let dayEntries = entriesByDate[dayKey] ?? []

            // Deduplicate by habit name (one completion per habit per day)
            let uniqueHabits = Array(Set(dayEntries.map(\.habitName)))
            let completedCount = uniqueHabits.count
            let rate = Double(completedCount) / Double(totalHabits)

            days.append(HeatMapDay(
                id: dayKey,
                date: dayKey,
                completionRate: min(rate, 1.0),
                completedCount: completedCount,
                totalCount: totalHabits,
                completedHabits: uniqueHabits.sorted()
            ))
        }

        return days
    }

    /// Build heat map data for a single habit over the given day count.
    static func buildForHabit(_ habit: Habit, dayCount: Int) -> [HeatMapDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var completedDates: Set<Date> = []
        for entry in habit.entries where entry.completed {
            completedDates.insert(calendar.startOfDay(for: entry.date))
        }

        var days: [HeatMapDay] = []
        for offset in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: -(dayCount - 1 - offset), to: today)!
            let dayKey = calendar.startOfDay(for: date)
            let completed = completedDates.contains(dayKey)

            days.append(HeatMapDay(
                id: dayKey,
                date: dayKey,
                completionRate: completed ? 1.0 : 0.0,
                completedCount: completed ? 1 : 0,
                totalCount: 1,
                completedHabits: completed ? [habit.name] : []
            ))
        }

        return days
    }
}

// MARK: - Preview

#Preview("Heat Map — Full") {
    let sampleDays = (0..<364).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
        let rate = Double.random(in: 0...1)
        return HeatMapDay(
            id: Calendar.current.startOfDay(for: date),
            date: date,
            completionRate: rate,
            completedCount: Int(rate * 5),
            totalCount: 5,
            completedHabits: rate > 0.3 ? ["Water", "Exercise"] : []
        )
    }.reversed()

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        VStack(spacing: 24) {
            Text("PERFORMANCE MATRIX")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentCyan)
                .tracking(3)
                .textGlow(OverwatchTheme.accentCyan, radius: 3)

            TacticalCard {
                HabitHeatMapView(days: Array(sampleDays), mode: .full)
            }
            .padding(.horizontal, 24)
        }
    }
    .frame(width: 900, height: 300)
}

#Preview("Heat Map — Compact") {
    let sampleDays = (0..<35).map { offset in
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
        let rate = Double.random(in: 0...1)
        return HeatMapDay(
            id: Calendar.current.startOfDay(for: date),
            date: date,
            completionRate: rate,
            completedCount: Int(rate * 5),
            totalCount: 5,
            completedHabits: rate > 0.3 ? ["Water", "Exercise"] : []
        )
    }.reversed()

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()

        TacticalCard {
            HabitHeatMapView(days: Array(sampleDays), mode: .compact)
        }
        .padding(24)
    }
    .frame(width: 500, height: 160)
}
