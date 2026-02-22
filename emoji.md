Plan: Replace Emojis with SF Symbols + Unified Cyan Intensity Color System                            

 Context

 Overwatch uses a dark tactical HUD aesthetic (Jarvis-style), but two design elements break immersion:
 1. Emojis — cartoon-style icons clash with the futuristic monoline look
 2. Red/Green binary for sentiment/performance — introduces jarring warm colors into an otherwise
 cyan-dominant palette

 Goal: Replace emojis with SF Symbols rendered in accentCyan, and replace the red/green color logic with
  a cyan-to-amber intensity gradient where cyan = positive and amber = negative, with opacity/brightness
  communicating magnitude.

 ---
 Phase 1: Color System Overhaul

 1.1: New Sentiment/Performance Color Function in OverwatchTheme

 File: Overwatch/Theme/OverwatchTheme.swift

 Replace performanceColor(for:) and add a new sentimentColor(for:) that maps scores to the cyan↔amber
 spectrum:

 +1.0  → accentCyan (full brightness, strong glow)
 +0.5  → accentCyan (60% opacity)
  0.0  → textSecondary (dim, neutral)
 -0.5  → accentPrimary/amber (60% opacity)
 -1.0  → accentPrimary/amber (full brightness, strong glow)

 For performance scores (0-100):
 67-100 → accentCyan (bright)
 34-66  → accentCyan (40% opacity) blended toward amber
  0-33  → accentPrimary/amber

 - Add static func sentimentColor(for score: Double) -> Color — maps -1...+1 to cyan↔amber
 - Update static func performanceColor(for score: Double) -> Color — maps 0...100 to cyan↔amber
 - Add static func intensityOpacity(for magnitude: Double) -> Double — helper for glow strength
 (abs(score) maps to 0.3...1.0)

 1.2: Update SentimentIndicator

 File: Overwatch/Views/Components/SentimentIndicator.swift

 - Replace SentimentDot color logic (lines 19-20, 77-78): use OverwatchTheme.sentimentColor(for:)
 instead of green/red switch
 - Replace SentimentBadge color logic (lines 54-56): same

 1.3: Update SentimentTrendChart

 File: Overwatch/Views/Components/SentimentTrendChart.swift

 - Replace dotColor(for:) function (lines 403-407): use sentimentColor(for:) — dots become cyan/amber
 gradient
 - Update AreaMark fills (lines 341-345): use sentimentColor for zone coloring instead of green/red
 - Update legend (lines 437, 447): change "POSITIVE" green dot → "POSITIVE" cyan dot, "NEGATIVE" red dot
  → "NEGATIVE" amber dot

 1.4: Update SentimentGauge

 File: Overwatch/Views/Components/SentimentGauge.swift

 - Replace gaugeColor computed property (lines 22-24): use sentimentColor(for: averageScore) instead of
 green/amber/red thresholds

 1.5: Update HabitHeatMapView

 File: Overwatch/Views/Components/HabitHeatMapView.swift

 - Replace completion color thresholds (lines 270-272): use cyan intensity gradient instead of green/red

 1.6: Update HabitTrendChartView

 File: Overwatch/Views/Components/HabitTrendChartView.swift

 - Review WHOOP overlay colors — keep cyan-based (already mostly correct)
 - Update any remaining green/red usage

 1.7: Update ReportsView

 File: Overwatch/Views/ReportsView.swift

 - Replace sentimentColor() helper (lines 435-439): delegate to OverwatchTheme.sentimentColor(for:)
 - Replace coefficientColor() helper (lines 441-445): positive → cyan, negative → amber, neutral →
 textSecondary

 1.8: Update WarRoomView Charts

 File: Overwatch/Views/WarRoomView.swift

 - Recovery chart PointMark (line 392): use updated performanceColor
 - Recovery legend (lines 407-409): update labels "HIGH/MED/LOW" with cyan/amber colors
 - Habit-sentiment scatter (line 567): use sentimentColor instead of green/red

 1.9: Update MonthlyAnalysisView

 File: Overwatch/Views/Journal/MonthlyAnalysisView.swift

 - Replace coefficient bar colors (lines 270-271, 280, 288): positive → cyan, negative → amber
 - Replace sentiment indicator colors (lines 306, 318, 320)

 1.10: Update HabitsView

 File: Overwatch/Views/HabitsView.swift

 - Replace completion rate color thresholds (lines 529-531, 849-851, 943-945): use cyan intensity
 gradient

 1.11: Update Dashboard Components

 Files:
 - Overwatch/Views/Dashboard/HabitToggleButton.swift (line 230-232)
 - Overwatch/Views/Dashboard/HabitPanelView.swift (line 234-236)
 - Overwatch/Views/Dashboard/CompactWhoopStrip.swift (lines 36, 45, 127, 134 — uses performanceColor)
 - Overwatch/Views/Dashboard/TacticalDashboardView.swift (lines 363-364)
 - Overwatch/Views/Dashboard/QuickInputView.swift (lines 146, 150, 152 — alert color)
 - Update all to use new performanceColor / sentimentColor

 1.12: Update MetricTile + ArcGauge

 Files:
 - Overwatch/Views/Components/MetricTile.swift (lines 27-28): up → cyan, down → amber
 - Overwatch/Views/Components/ArcGauge.swift (lines 137, 144): high → cyan, low → amber

 1.13: Update SettingsView

 File: Overwatch/Views/SettingsView.swift

 - Status indicators (lines 615, 697-698, 710-712): success → cyan, failed → amber

 Note: accentSecondary (green) should NOT be removed from the theme — it may still be useful for
 specific "online/active" states (like the boot sequence "ONLINE" glow). But it should no longer be the
 default positive-sentiment color.

 ---
 Phase 2: SF Symbol Icon System

 2.1: Define Icon Catalog

 New file: Overwatch/Theme/HabitIcons.swift

 Create a centralized icon catalog mapping category names to SF Symbol names:

 enum HabitIcons {
     static let catalog: [String: String] = [
         "meditation": "brain.head.profile",
         "exercise": "figure.run",
         "water": "drop",
         "sleep": "moon.zzz",
         "reading": "book",
         "nutrition": "fork.knife",
         "supplements": "pill",
         "journaling": "pencil.line",
         "stretching": "figure.flexibility",
         "walking": "figure.walk",
         "alcohol": "wineglass",
         "breathing": "wind",
         "cold exposure": "snowflake",
         "strength": "dumbbell",
         "yoga": "figure.yoga",
         "default": "circle.fill",
     ]

     /// Resolves an icon name from a habit name or category, falling back to default.
     static func icon(for name: String, category: String = "") -> String { ... }
 }

 - Create HabitIcons.swift with catalog + fuzzy matching helper
 - Add to Xcode project (.pbxproj)

 2.2: Update Habit Model

 File: Overwatch/Models/Habit.swift

 - Add var iconName: String field (SF Symbol name)
 - Keep emoji field for backward compatibility (existing data)
 - Update init to accept iconName with a default that resolves from HabitIcons.icon(for: name)

 2.3: Create HabitIcon View Component

 New file: Overwatch/Views/Components/HabitIcon.swift

 A reusable component that replaces Text(emoji) everywhere:

 struct HabitIcon: View {
     let iconName: String
     let emoji: String  // fallback
     var size: CGFloat = 16
     var color: Color = OverwatchTheme.accentCyan

     var body: some View {
         if !iconName.isEmpty {
             Image(systemName: iconName)
                 .font(.system(size: size, weight: .medium))
                 .foregroundStyle(color)
                 .shadow(color: color.opacity(0.4), radius: 4)
         } else if !emoji.isEmpty {
             Text(emoji).font(.system(size: size))
         } else {
             Image(systemName: "circle.fill")
                 .font(.system(size: size * 0.5))
                 .foregroundStyle(color.opacity(0.5))
         }
     }
 }

 - Create HabitIcon.swift
 - Add to Xcode project (.pbxproj)

 2.4: Update ViewModels to Pass iconName

 Files to update:
 - Overwatch/ViewModels/DashboardViewModel.swift — TrackedHabit struct: add iconName: String
 - Overwatch/ViewModels/HabitsViewModel.swift — HabitRow struct: add iconName: String
 - Overwatch/ViewModels/WarRoomViewModel.swift — CorrelationPoint, HabitSentimentPoint, HabitDayPoint:
 add iconName: String
 - Overwatch/ViewModels/JournalTimelineViewModel.swift — HabitFilterOption: add iconName: String
 - Add iconName to all ViewModel display structs
 - Map from habit.iconName in all data loading methods

 2.5: Replace Emoji Rendering in Views

 Every Text(emoji) or Text(habit.emoji) becomes HabitIcon(iconName:emoji:):

 - Overwatch/Views/HabitsView.swift (lines 420, 625, 1218)
 - Overwatch/Views/Dashboard/HabitToggleButton.swift (line 35)
 - Overwatch/Views/Dashboard/HabitPanelView.swift (line 160)
 - Overwatch/Views/Components/JournalTimelineView.swift (line 169)
 - Overwatch/Views/Journal/MonthlyAnalysisView.swift (lines 174-175)
 - Overwatch/Views/WarRoomView.swift (lines 465, 570)
 - Overwatch/Views/OnboardingView.swift (line 346)

 2.6: Update Habit Creation UI

 Replace emoji text input with SF Symbol picker:

 - Overwatch/Views/HabitsView.swift — Replace emoji TextField with icon picker (scrollable grid of SF
 Symbols from HabitIcons.catalog)
 - Overwatch/Views/Dashboard/HabitPanelView.swift — Same (AddHabitSheet)
 - Overwatch/Views/Dashboard/TacticalDashboardView.swift — Same (AddHabitSheet)
 - Overwatch/Views/OnboardingView.swift — Update suggestion data to use iconName instead of emoji

 2.7: Update Synthetic Data Seeder

 File: Overwatch/Services/SyntheticDataSeeder.swift

 - Replace hardcoded emojis (lines 95-103) with SF Symbol icon names
 - Keep emoji as empty string or fallback

 2.8: Update IntelligenceManager + GeminiService

 Files:
 - Overwatch/Services/IntelligenceManager.swift
 - Overwatch/Services/GeminiService.swift
 - In RISEN prompts, replace emoji references in JSON payloads with habit names only (Gemini doesn't
 need icons)
 - Update HabitCompletionData, HabitMetadataItem structs to use iconName alongside or instead of emoji
 - Keep emoji in prompt text if non-empty (Gemini may reference it in narrative), otherwise omit

 2.9: Migration for Existing Data

 - Add a one-time migration in OverwatchApp.swift or AppState that runs on launch:
   - For each Habit where iconName is empty: resolve from HabitIcons.icon(for: habit.name, category:
 habit.category) and set it

 ---
 Phase 3: Verification

 - Build succeeds with zero errors
 - Run app — verify all habit icons render as SF Symbols in cyan
 - Check dashboard: habit toggle buttons show icons not emojis
 - Check habits view: habit list shows icons
 - Check War Room: chart annotations show icons
 - Check Reports: correlation rows show icons
 - Check SentimentTrendChart: dots are cyan/amber gradient instead of green/red
 - Check SentimentGauge: arc color is cyan/amber instead of green/red
 - Check heat map: cells are cyan intensity instead of green/red
 - Check recovery chart: dots are cyan/amber instead of green/red
 - Existing tests still pass
 - New habits created via UI use icon picker (no emoji field)
 - Existing habits with emojis fall back gracefully (show emoji if no iconName)

 ---
 Files Summary

 New Files

 - Overwatch/Theme/HabitIcons.swift
 - Overwatch/Views/Components/HabitIcon.swift

 Modified Files (Color System)

 - Overwatch/Theme/OverwatchTheme.swift
 - Overwatch/Views/Components/SentimentIndicator.swift
 - Overwatch/Views/Components/SentimentTrendChart.swift
 - Overwatch/Views/Components/SentimentGauge.swift
 - Overwatch/Views/Components/HabitHeatMapView.swift
 - Overwatch/Views/Components/HabitTrendChartView.swift
 - Overwatch/Views/Components/MetricTile.swift
 - Overwatch/Views/Components/ArcGauge.swift
 - Overwatch/Views/ReportsView.swift
 - Overwatch/Views/WarRoomView.swift
 - Overwatch/Views/HabitsView.swift
 - Overwatch/Views/SettingsView.swift
 - Overwatch/Views/Journal/MonthlyAnalysisView.swift
 - Overwatch/Views/Dashboard/HabitToggleButton.swift
 - Overwatch/Views/Dashboard/HabitPanelView.swift
 - Overwatch/Views/Dashboard/CompactWhoopStrip.swift
 - Overwatch/Views/Dashboard/TacticalDashboardView.swift
 - Overwatch/Views/Dashboard/QuickInputView.swift

 Modified Files (Icon System)

 - Overwatch/Models/Habit.swift
 - Overwatch/ViewModels/DashboardViewModel.swift
 - Overwatch/ViewModels/HabitsViewModel.swift
 - Overwatch/ViewModels/WarRoomViewModel.swift
 - Overwatch/ViewModels/JournalTimelineViewModel.swift
 - Overwatch/Services/IntelligenceManager.swift
 - Overwatch/Services/GeminiService.swift
 - Overwatch/Services/SyntheticDataSeeder.swift
 - Overwatch/Views/OnboardingView.swift
 - Overwatch/App/OverwatchApp.swift
 - Overwatch/Overwatch.xcodeproj/project.pbxproj