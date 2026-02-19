import SwiftUI
import Charts

/// Collapsible "MONTHLY INTELLIGENCE" section showing regression analysis results,
/// force multiplier habit, coefficient bar chart, and Gemini narrative.
///
/// Month selection is handled externally by the global period picker in JournalView.
/// This view displays analysis for whatever month is currently selected.
struct MonthlyAnalysisView: View {
    let analysis: JournalViewModel.MonthlyAnalysisItem?
    let isGenerating: Bool
    let currentMonthEntryCount: Int
    let selectedMonthLabel: String
    let isRangeMode: Bool
    var analysisError: String? = nil
    let onGenerate: () -> Void

    @State private var isExpanded = true

    private var sortedCoefficients: [HabitCoefficient] {
        guard let analysis else { return [] }
        return analysis.coefficients
            .sorted { abs($0.coefficient) > abs($1.coefficient) }
    }

    /// Whether the generate button should be enabled.
    private var canGenerate: Bool {
        !isGenerating && !isRangeMode && currentMonthEntryCount >= 14
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            if isExpanded {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
                    if isGenerating {
                        loadingState
                    } else if let analysis {
                        analysisContent(analysis)
                    } else if let error = analysisError {
                        errorState(error)
                    } else if isRangeMode {
                        selectMonthPrompt
                    } else if currentMonthEntryCount >= 14 {
                        readyToGenerateState
                    } else {
                        insufficientDataState
                    }
                }
                .padding(.top, OverwatchTheme.Spacing.md)
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: OverwatchTheme.Spacing.sm) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    Rectangle()
                        .fill(OverwatchTheme.accentPrimary.opacity(0.6))
                        .frame(width: 3, height: 12)
                        .shadow(color: OverwatchTheme.accentPrimary.opacity(0.6), radius: 4)

                    Text("// MONTHLY INTELLIGENCE")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.5))
                        .tracking(3)
                        .textGlow(OverwatchTheme.accentPrimary, radius: 3)

                    if !selectedMonthLabel.isEmpty {
                        Text("— \(selectedMonthLabel.uppercased())")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.3))
                            .tracking(2)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.4))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if isExpanded {
                generateButton
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button(action: onGenerate) {
            HStack(spacing: 4) {
                Image(systemName: analysis != nil ? "arrow.clockwise" : "cpu")
                    .font(.system(size: 10, weight: .medium))
                Text(analysis != nil ? "REGENERATE" : "GENERATE")
                    .font(Typography.hudLabel)
                    .tracking(1)
            }
            .foregroundStyle(OverwatchTheme.accentPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(OverwatchTheme.accentPrimary.opacity(0.08))
            .clipShape(HUDFrameShape(chamferSize: 6))
            .overlay(
                HUDFrameShape(chamferSize: 6)
                    .stroke(OverwatchTheme.accentPrimary.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canGenerate)
        .opacity(canGenerate ? 1.0 : 0.4)
    }

    // MARK: - Analysis Content

    @ViewBuilder
    private func analysisContent(_ item: JournalViewModel.MonthlyAnalysisItem) -> some View {
        narrativeSummary(item.summary)
        forceMultiplierSection(item)
        coefficientChart
        qualityIndicators(item)
    }

    // MARK: - Narrative Summary

    private func narrativeSummary(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                Text("ANALYSIS")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .tracking(2)
            }

            Text(summary)
                .font(Typography.commandLine)
                .foregroundStyle(OverwatchTheme.textPrimary.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Force Multiplier

    private func forceMultiplierSection(_ item: JournalViewModel.MonthlyAnalysisItem) -> some View {
        Group {
            if !item.forceMultiplierHabit.isEmpty {
                let multiplierCoeff = item.coefficients.first {
                    $0.habitName == item.forceMultiplierHabit
                }

                HStack(spacing: OverwatchTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                        Text("FORCE MULTIPLIER")
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.6))
                            .tracking(2)

                        HStack(spacing: OverwatchTheme.Spacing.sm) {
                            if let emoji = multiplierCoeff?.habitEmoji, !emoji.isEmpty {
                                Text(emoji)
                                    .font(.system(size: 22))
                            }

                            Text(item.forceMultiplierHabit.uppercased())
                                .font(Typography.title)
                                .foregroundStyle(OverwatchTheme.accentPrimary)
                                .tracking(2)
                                .textGlow(OverwatchTheme.accentPrimary, radius: 10)
                        }
                    }

                    Spacer()

                    if let coeff = multiplierCoeff {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%+.3f", coeff.coefficient))
                                .font(Typography.metricMedium)
                                .foregroundStyle(OverwatchTheme.accentPrimary)
                                .monospacedDigit()
                            Text("COEFFICIENT")
                                .font(Typography.metricTiny)
                                .foregroundStyle(OverwatchTheme.textSecondary)
                                .tracking(1)
                        }
                    }
                }
                .padding(OverwatchTheme.Spacing.md)
                .background(OverwatchTheme.accentPrimary.opacity(0.04))
                .clipShape(HUDFrameShape(chamferSize: 10))
                .overlay(
                    HUDFrameShape(chamferSize: 10)
                        .stroke(OverwatchTheme.accentPrimary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: OverwatchTheme.accentPrimary.opacity(0.08), radius: 12)
            }
        }
    }

    // MARK: - Coefficient Bar Chart

    private var coefficientChart: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                Text("HABIT IMPACT")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.5))
                    .tracking(2)
            }

            if !sortedCoefficients.isEmpty {
                Chart(sortedCoefficients) { coeff in
                    BarMark(
                        x: .value("Impact", coeff.coefficient),
                        y: .value("Habit", "\(coeff.habitEmoji) \(coeff.habitName)")
                    )
                    .foregroundStyle(barColor(for: coeff))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.15))
                        AxisValueLabel()
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.textPrimary.opacity(0.7))
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(OverwatchTheme.surface.opacity(0.3))
                }
                .frame(height: max(CGFloat(sortedCoefficients.count) * 32, 80))
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8),
                    value: sortedCoefficients.count
                )

                chartLegend
            }
        }
    }

    private func barColor(for coeff: HabitCoefficient) -> Color {
        switch coeff.direction {
        case .positive: OverwatchTheme.accentSecondary
        case .negative: OverwatchTheme.alert
        case .neutral: OverwatchTheme.textSecondary
        }
    }

    private var chartLegend: some View {
        HStack(spacing: OverwatchTheme.Spacing.lg) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(OverwatchTheme.accentSecondary)
                    .frame(width: 12, height: 8)
                Text("POSITIVE")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(OverwatchTheme.alert)
                    .frame(width: 12, height: 8)
                Text("NEGATIVE")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Quality Indicators

    private func qualityIndicators(_ item: JournalViewModel.MonthlyAnalysisItem) -> some View {
        HStack(spacing: OverwatchTheme.Spacing.xl) {
            qualityMetric(
                label: "R\u{00B2} FIT",
                value: String(format: "%.3f", item.modelR2),
                color: item.modelR2 > 0.3
                    ? OverwatchTheme.accentSecondary
                    : OverwatchTheme.textSecondary
            )
            qualityMetric(
                label: "ENTRIES",
                value: "\(item.entryCount)",
                color: OverwatchTheme.accentCyan
            )
            qualityMetric(
                label: "AVG SENTIMENT",
                value: String(format: "%+.2f", item.averageSentiment),
                color: item.averageSentiment > 0.1
                    ? OverwatchTheme.accentSecondary
                    : (item.averageSentiment < -0.1
                        ? OverwatchTheme.alert
                        : OverwatchTheme.textSecondary)
            )
            qualityMetric(
                label: "GENERATED",
                value: item.generatedAt.formatted(.dateTime.month(.abbreviated).day()),
                color: OverwatchTheme.textSecondary
            )

            Spacer()
        }
    }

    private func qualityMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.metricSmall)
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.6))
                .tracking(1)
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            ProgressView()
                .tint(OverwatchTheme.accentPrimary)
                .scaleEffect(0.8)

            Text("COMPUTING REGRESSION...")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.5))
                .tracking(3)
                .textGlow(OverwatchTheme.accentPrimary, radius: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(OverwatchTheme.alert.opacity(0.4))

            Text("ANALYSIS FAILED")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.alert.opacity(0.5))
                .tracking(2)
                .textGlow(OverwatchTheme.alert, radius: 3)

            Text(message)
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }

    // MARK: - Select Month Prompt (range mode, no specific month selected)

    private var selectMonthPrompt: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.15))

            Text("SELECT A MONTH")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.35))
                .tracking(2)
                .textGlow(OverwatchTheme.accentPrimary, radius: 3)

            Text("Choose a specific month from the period selector above to generate or view analysis")
                .font(Typography.metricTiny)
                .foregroundStyle(OverwatchTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }

    // MARK: - Ready to Generate (specific month, enough data, no analysis yet)

    private var readyToGenerateState: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            Image(systemName: "cpu")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.25))

            Text("READY TO ANALYZE")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.5))
                .tracking(2)
                .textGlow(OverwatchTheme.accentPrimary, radius: 3)

            Text(
                "\(currentMonthEntryCount) entries available for \(selectedMonthLabel)"
            )
            .font(Typography.metricTiny)
            .foregroundStyle(OverwatchTheme.textSecondary)
            .multilineTextAlignment(.center)

            Button(action: onGenerate) {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.system(size: 11, weight: .medium))
                    Text("GENERATE ANALYSIS")
                        .font(Typography.hudLabel)
                        .tracking(1.5)
                }
                .foregroundStyle(OverwatchTheme.accentPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(OverwatchTheme.accentPrimary.opacity(0.08))
                .clipShape(HUDFrameShape(chamferSize: 8))
                .overlay(
                    HUDFrameShape(chamferSize: 8)
                        .stroke(OverwatchTheme.accentPrimary.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }

    // MARK: - Insufficient Data State

    private var insufficientDataState: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 28, weight: .thin))
                .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.15))

            Text("NEED MORE DATA")
                .font(Typography.hudLabel)
                .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.35))
                .tracking(2)
                .textGlow(OverwatchTheme.accentPrimary, radius: 3)

            Text(
                "Log at least 14 journal entries for \(selectedMonthLabel) to generate analysis (\(currentMonthEntryCount)/14)"
            )
            .font(Typography.metricTiny)
            .foregroundStyle(OverwatchTheme.textSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, OverwatchTheme.Spacing.xxl)
    }
}

// MARK: - Preview

#Preview("Monthly Analysis — With Data") {
    let mockCoefficients: [HabitCoefficient] = [
        HabitCoefficient(habitName: "Meditation", habitEmoji: "\u{1F9D8}", coefficient: 0.34, pValue: 0.01, completionRate: 0.8, direction: .positive),
        HabitCoefficient(habitName: "Exercise", habitEmoji: "\u{1F3CB}\u{FE0F}", coefficient: 0.21, pValue: 0.05, completionRate: 0.7, direction: .positive),
        HabitCoefficient(habitName: "Reading", habitEmoji: "\u{1F4DA}", coefficient: 0.02, pValue: 0.85, completionRate: 0.5, direction: .neutral),
        HabitCoefficient(habitName: "Alcohol", habitEmoji: "\u{1F37A}", coefficient: -0.28, pValue: 0.02, completionRate: 0.3, direction: .negative),
    ]

    let mockAnalysis = JournalViewModel.MonthlyAnalysisItem(
        id: UUID(),
        month: 2,
        year: 2026,
        monthLabel: "February 2026",
        averageSentiment: 0.42,
        entryCount: 28,
        forceMultiplierHabit: "Meditation",
        modelR2: 0.61,
        summary: "Strong month overall. Your meditation practice stands out as a clear wellbeing driver \u{2014} days when you meditated correlated with significantly higher sentiment scores. Exercise also contributed positively, while alcohol consumption showed a notable negative association. Consider doubling down on your morning meditation routine.",
        coefficients: mockCoefficients,
        generatedAt: .now
    )

    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            MonthlyAnalysisView(
                analysis: mockAnalysis,
                isGenerating: false,
                currentMonthEntryCount: 28,
                selectedMonthLabel: "February 2026",
                isRangeMode: false,
                onGenerate: {}
            )
        }
        .padding(24)
    }
    .frame(width: 700, height: 600)
}

#Preview("Monthly Analysis — Ready to Generate") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            MonthlyAnalysisView(
                analysis: nil,
                isGenerating: false,
                currentMonthEntryCount: 29,
                selectedMonthLabel: "December 2025",
                isRangeMode: false,
                onGenerate: {}
            )
        }
        .padding(24)
    }
    .frame(width: 700, height: 400)
}

#Preview("Monthly Analysis — Select Month") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()

        TacticalCard {
            MonthlyAnalysisView(
                analysis: nil,
                isGenerating: false,
                currentMonthEntryCount: 0,
                selectedMonthLabel: "",
                isRangeMode: true,
                onGenerate: {}
            )
        }
        .padding(24)
    }
    .frame(width: 700, height: 400)
}
