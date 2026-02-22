import SwiftUI
import SwiftData

/// Intel Briefings archive — list of past AI-generated weekly reports
/// with on-demand generation via date picker. Phase 7.3.
struct ReportsView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = ReportsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: OverwatchTheme.Spacing.xl) {
                headerSection
                generationBanner
                reportsList
            }
            .padding(OverwatchTheme.Spacing.xl)
        }
        .onAppear { viewModel.loadReports(from: context) }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: OverwatchTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.xs) {
                    Text("INTEL BRIEFINGS")
                        .font(Typography.largeTitle)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .tracking(6)
                        .textGlow(OverwatchTheme.accentCyan, radius: 20)

                    Text("AI-GENERATED PERFORMANCE REPORTS")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.45))
                        .tracking(5)
                        .textGlow(OverwatchTheme.accentCyan, radius: 4)
                }

                Spacer()

                generateButton
            }

            HUDDivider(color: OverwatchTheme.accentCyan)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            withAnimation(Animations.standard) {
                viewModel.showDatePicker.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.diamond")
                    .font(.system(size: 11, weight: .medium))
                Text("GENERATE REPORT")
                    .font(Typography.hudLabel)
                    .tracking(2)
            }
            .foregroundStyle(OverwatchTheme.accentPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(OverwatchTheme.accentPrimary.opacity(0.1))
            .clipShape(HUDFrameShape(chamferSize: 6))
            .overlay(
                HUDFrameShape(chamferSize: 6)
                    .stroke(OverwatchTheme.accentPrimary.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGenerating)
    }

    // MARK: - Generation Banner (Date Picker + Progress)

    @ViewBuilder
    private var generationBanner: some View {
        if viewModel.showDatePicker {
            TacticalCard(glowColor: OverwatchTheme.accentPrimary) {
                VStack(spacing: OverwatchTheme.Spacing.md) {
                    HStack(spacing: OverwatchTheme.Spacing.sm) {
                        Rectangle()
                            .fill(OverwatchTheme.accentPrimary.opacity(0.6))
                            .frame(width: 3, height: 12)
                            .shadow(color: OverwatchTheme.accentPrimary.opacity(0.6), radius: 4)

                        Text("// SELECT DATE RANGE")
                            .font(Typography.hudLabel)
                            .foregroundStyle(OverwatchTheme.accentPrimary.opacity(0.5))
                            .tracking(3)
                            .textGlow(OverwatchTheme.accentPrimary, radius: 3)

                        Spacer()
                    }

                    HStack(spacing: OverwatchTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("START")
                                .font(Typography.hudLabel)
                                .foregroundStyle(OverwatchTheme.textSecondary)
                                .tracking(2)
                            DatePicker(
                                "",
                                selection: $viewModel.customStartDate,
                                in: ...viewModel.customEndDate,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .colorScheme(.dark)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("END")
                                .font(Typography.hudLabel)
                                .foregroundStyle(OverwatchTheme.textSecondary)
                                .tracking(2)
                            DatePicker(
                                "",
                                selection: $viewModel.customEndDate,
                                in: viewModel.customStartDate...Date.now,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .colorScheme(.dark)
                        }

                        Spacer()

                        HStack(spacing: OverwatchTheme.Spacing.sm) {
                            Button {
                                withAnimation(Animations.standard) {
                                    viewModel.showDatePicker = false
                                }
                            } label: {
                                Text("CANCEL")
                                    .font(Typography.hudLabel)
                                    .tracking(1.5)
                                    .foregroundStyle(OverwatchTheme.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.generateReport(from: context)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 9))
                                    Text("COMPILE")
                                        .font(Typography.hudLabel)
                                        .tracking(1.5)
                                }
                                .foregroundStyle(OverwatchTheme.accentPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(OverwatchTheme.accentPrimary.opacity(0.12))
                                .clipShape(HUDFrameShape(chamferSize: 4))
                                .overlay(
                                    HUDFrameShape(chamferSize: 4)
                                        .stroke(OverwatchTheme.accentPrimary.opacity(0.4), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isGenerating)
                        }
                    }
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                removal: .opacity
            ))
        }

        if viewModel.isGenerating {
            TacticalCard(glowColor: OverwatchTheme.accentPrimary) {
                HStack(spacing: OverwatchTheme.Spacing.md) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(OverwatchTheme.accentPrimary)

                    Text(viewModel.generationProgress ?? "COMPILING INTELLIGENCE BRIEFING...")
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.accentPrimary)
                        .tracking(2)
                        .textGlow(OverwatchTheme.accentPrimary, radius: 4)

                    Spacer()

                    Button {
                        withAnimation(Animations.quick) {
                            viewModel.cancelGeneration()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                            Text("ABORT")
                                .font(Typography.hudLabel)
                                .tracking(1.5)
                        }
                        .foregroundStyle(OverwatchTheme.alert)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(OverwatchTheme.alert.opacity(0.1))
                        .clipShape(HUDFrameShape(chamferSize: 4))
                        .overlay(
                            HUDFrameShape(chamferSize: 4)
                                .stroke(OverwatchTheme.alert.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Reports List

    // MARK: - Status Badges

    @ViewBuilder
    private var statusBadges: some View {
        if !viewModel.geminiAvailable {
            HUDStatusBadge.intelligenceOffline()
        }

        if viewModel.isThrottled {
            HUDStatusBadge.intelligenceThrottled(
                retryDetail: viewModel.throttleMessage ?? "Rate limit exceeded — try again later"
            )
        }

        if let progress = viewModel.generationProgress, !viewModel.isGenerating {
            HUDStatusBadge(
                icon: "exclamationmark.triangle",
                label: "GENERATION ERROR",
                detail: progress,
                color: OverwatchTheme.alert
            )
        }
    }

    // MARK: - Reports List

    @ViewBuilder
    private var reportsList: some View {
        statusBadges

        if viewModel.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: OverwatchTheme.Spacing.lg) {
                ForEach(Array(viewModel.reports.enumerated()), id: \.element.id) { index, report in
                    ReportCardView(
                        report: report,
                        isExpanded: viewModel.selectedReportID == report.id,
                        onTap: { viewModel.selectReport(report.id) },
                        onDelete: { viewModel.deleteReport(report.id, from: context) }
                    )
                    .hudBoot(delay: Double(index) * 0.06)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        TacticalCard {
            VStack(spacing: OverwatchTheme.Spacing.lg) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.15))

                Text("NO BRIEFINGS YET")
                    .font(Typography.hudLabel)
                    .foregroundStyle(OverwatchTheme.accentCyan.opacity(0.35))
                    .tracking(2)
                    .textGlow(OverwatchTheme.accentCyan, radius: 3)

                Text("Your first intel report generates after one week of tracking data.")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OverwatchTheme.Spacing.xxl)
        }
    }
}

// MARK: - Report Card View

private struct ReportCardView: View {
    let report: ReportsViewModel.ReportCard
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        TacticalCard(glowColor: isExpanded ? OverwatchTheme.accentPrimary : OverwatchTheme.accentCyan) {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(Animations.standard) { onTap() } }

                if isExpanded {
                    expandedDetail
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                }
            }
        }
    }

    // MARK: - Card Header (always visible)

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.dateRangeLabel)
                        .font(Typography.subtitle)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .tracking(1)

                    Text(report.summaryPreview)
                        .font(Typography.metricTiny)
                        .foregroundStyle(OverwatchTheme.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    // Force multiplier badge
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text(report.forceMultiplierHabit.uppercased())
                            .font(Typography.hudLabel)
                            .tracking(1)
                    }
                    .foregroundStyle(OverwatchTheme.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(OverwatchTheme.accentPrimary.opacity(0.1))
                    .clipShape(HUDFrameShape(chamferSize: 4))
                    .overlay(
                        HUDFrameShape(chamferSize: 4)
                            .stroke(OverwatchTheme.accentPrimary.opacity(0.3), lineWidth: 1)
                    )

                    // Sentiment badge
                    if let avgSentiment = report.averageSentiment {
                        HStack(spacing: 4) {
                            if let arrow = report.sentimentTrendArrow {
                                Image(systemName: arrow)
                                    .font(.system(size: 8, weight: .bold))
                            }
                            Text(sentimentLabel(avgSentiment))
                                .font(Typography.metricTiny)
                        }
                        .foregroundStyle(sentimentColor(avgSentiment))
                    }
                }
            }

            // Generated timestamp
            HStack {
                Spacer()
                Text("GENERATED \(formattedTimestamp(report.generatedAt))")
                    .font(Typography.metricTiny)
                    .foregroundStyle(OverwatchTheme.textSecondary.opacity(0.6))
                    .tracking(1)
            }
        }
    }

    // MARK: - Expanded Detail

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.lg) {
            HUDDivider(color: OverwatchTheme.accentCyan)
                .padding(.vertical, OverwatchTheme.Spacing.sm)

            // Full summary
            fullSummarySection

            // Force multiplier
            forceMultiplierSection

            // Recommendations
            recommendationsSection

            // Correlations
            if !report.correlations.isEmpty {
                correlationsSection
            }

            // Sentiment summary
            if report.averageSentiment != nil {
                sentimentSection
            }

            HUDDivider(color: OverwatchTheme.alert.opacity(0.3))

            // Delete
            HStack {
                Spacer()
                Button {
                    withAnimation(Animations.standard) { onDelete() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9, weight: .medium))
                        Text("DELETE BRIEFING")
                            .font(Typography.hudLabel)
                            .tracking(1.5)
                    }
                    .foregroundStyle(OverwatchTheme.alert.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(OverwatchTheme.alert.opacity(0.06))
                    .clipShape(HUDFrameShape(chamferSize: 4))
                    .overlay(
                        HUDFrameShape(chamferSize: 4)
                            .stroke(OverwatchTheme.alert.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var fullSummarySection: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("// ANALYSIS SUMMARY")

            Text(report.summary)
                .font(Typography.metricSmall)
                .foregroundStyle(OverwatchTheme.textPrimary.opacity(0.9))
                .lineSpacing(4)
        }
    }

    private var forceMultiplierSection: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("// FORCE MULTIPLIER")

            HStack(spacing: OverwatchTheme.Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(OverwatchTheme.accentPrimary)
                    .shadow(color: OverwatchTheme.accentPrimary.opacity(0.6), radius: 6)

                Text(report.forceMultiplierHabit)
                    .font(Typography.subtitle)
                    .foregroundStyle(OverwatchTheme.accentPrimary)
                    .textGlow(OverwatchTheme.accentPrimary, radius: 6)
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("// RECOMMENDATIONS")

            ForEach(Array(report.recommendations.enumerated()), id: \.offset) { index, rec in
                HStack(alignment: .top, spacing: OverwatchTheme.Spacing.sm) {
                    Text("\(index + 1).")
                        .font(Typography.metricSmall)
                        .foregroundStyle(OverwatchTheme.accentCyan)
                        .frame(width: 20, alignment: .trailing)

                    Text(rec)
                        .font(Typography.metricSmall)
                        .foregroundStyle(OverwatchTheme.textPrimary.opacity(0.85))
                        .lineSpacing(2)
                }
            }
        }
    }

    private var correlationsSection: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("// HABIT CORRELATIONS")

            ForEach(report.correlations) { coeff in
                HStack(spacing: OverwatchTheme.Spacing.sm) {
                    HabitIcon(iconName: coeff.habitEmoji, emoji: coeff.habitEmoji, size: 12, color: directionColor(coeff.direction))

                    Text(coeff.habitName.uppercased())
                        .font(Typography.hudLabel)
                        .foregroundStyle(OverwatchTheme.textPrimary)
                        .tracking(1)

                    Spacer()

                    // Direction arrow
                    Image(systemName: coeff.direction == .positive ? "arrow.up" : coeff.direction == .negative ? "arrow.down" : "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(directionColor(coeff.direction))

                    // Strength bar
                    strengthBar(value: abs(coeff.coefficient), color: directionColor(coeff.direction))

                    Text(String(format: "%.2f", coeff.coefficient))
                        .font(Typography.metricTiny)
                        .foregroundStyle(directionColor(coeff.direction))
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private var sentimentSection: some View {
        VStack(alignment: .leading, spacing: OverwatchTheme.Spacing.sm) {
            sectionLabel("// SENTIMENT OVERVIEW")

            HStack(spacing: OverwatchTheme.Spacing.lg) {
                if let avg = report.averageSentiment {
                    VStack(spacing: 2) {
                        Text(sentimentLabel(avg))
                            .font(Typography.metricMedium)
                            .foregroundStyle(sentimentColor(avg))
                            .textGlow(sentimentColor(avg), radius: 6)
                        Text("AVG SCORE")
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                    }
                }

                if let trend = report.sentimentTrend {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            if let arrow = report.sentimentTrendArrow {
                                Image(systemName: arrow)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Text(trend.uppercased())
                                .font(Typography.metricSmall)
                        }
                        .foregroundStyle(trendColor(trend))
                        Text("TREND")
                            .font(Typography.metricTiny)
                            .foregroundStyle(OverwatchTheme.textSecondary)
                    }
                }

                Spacer()
            }
        }
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

            Spacer()
        }
    }

    private func strengthBar(value: Double, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HUDFrameShape(chamferSize: 2)
                    .fill(color.opacity(0.1))

                HUDFrameShape(chamferSize: 2)
                    .fill(color.opacity(0.6))
                    .frame(width: max(4, geo.size.width * min(value, 1.0)))
                    .shadow(color: color.opacity(0.4), radius: 3)
            }
        }
        .frame(width: 60, height: 6)
    }

    private func directionColor(_ direction: HabitCoefficient.Direction) -> Color {
        switch direction {
        case .positive: OverwatchTheme.accentSecondary
        case .negative: OverwatchTheme.alert
        case .neutral: OverwatchTheme.textSecondary
        }
    }

    private func sentimentLabel(_ score: Double) -> String {
        let sign = score >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", score))"
    }

    private func sentimentColor(_ score: Double) -> Color {
        if score >= 0.33 { return OverwatchTheme.accentSecondary }
        if score >= -0.33 { return OverwatchTheme.accentPrimary }
        return OverwatchTheme.alert
    }

    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "improving": OverwatchTheme.accentSecondary
        case "declining": OverwatchTheme.alert
        default: OverwatchTheme.accentPrimary
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy 'at' HH:mm"
        return fmt.string(from: date).uppercased()
    }
}

// MARK: - Preview

#Preview("Reports — With Data") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        ReportsView()
    }
    .frame(width: 800, height: 700)
}

#Preview("Reports — Empty") {
    ZStack {
        OverwatchTheme.background.ignoresSafeArea()
        GridBackdrop().ignoresSafeArea()
        ReportsView()
    }
    .frame(width: 800, height: 500)
}
