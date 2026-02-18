# Plan — Overwatch: Tactical Habit & Performance Intelligence System

> **Stack:** Swift 6 | SwiftUI | SwiftData | Gemini 3 API | WHOOP API | macOS native
> **Aesthetic:** CIA Agent meets Pro Athlete — dark mode, data-dense, bento-box grid
> **Env:** Xcode 16+ (required) | Swift Package Manager for dependencies

---

## Dependency Graph

```
0.1 ──→ 0.2 ──→ 0.3 ──→ 1.1.1 ──→ 1.1.2 ──→ 1.1.3
                                                  │
                          ┌───────────────────────┤
                          ↓                       ↓
                        1.2.1 ──→ 1.2.2        1.3.1 ──→ 1.3.2
                          │                       │
                          ↓                       ↓
                   ┌──────┴──────┐          ┌─────┴──────┐
                   ↓             ↓          ↓            ↓
                 2.1.1 → 2.1.2  2.2.1    2.2.1        2.2.2 → 2.2.3
                   │             │                       │
                   ↓             ↓                       ↓
                 2.1.3         2.2.2 ──────────→ 2.2.3
                   │                               │
                   ↓                               ↓
          ┌────── 4.1.1 ←─────────────────── 3.1.1 → 3.1.2 → 3.1.3
          │        │                                           │
          ↓        ↓                                           ↓
        4.2.1    4.1.2                                  3.2.1 → 3.2.2 → 3.2.3
          │        │                                                      │
          ↓        ↓                                                      ↓
        4.2.2    4.1.3                                             3.3.1 → 3.3.2
          │        │
          ↓        ↓
        4.3.1    4.3.1 (converge)
          │
          ↓
        4.3.2 ──→ 5.1.1 → 5.1.2 → 5.2.1 → 5.2.2
                                               │
                              ┌────────────────┤
                              ↓                ↓
                            6.1.1 → 6.1.2    6.2.1 → 6.2.2 → 6.2.3
                              │
                              ↓
                            6.1.3 → 6.3.1 → 6.3.2 → 6.3.3
                                                        │
                                    ┌───────────────────┤
                                    ↓                   ↓
                                  7.1.1 → 7.1.2      7.2.1 → 7.2.2 → 7.2.3
                                                                        │
                                                                        ↓
                                                         8.1.1 → 8.1.2 → 8.1.3
                                                                          │
                                                                          ↓
                                                                  9.1.1 → 9.1.2
```

### Parallelization Guide

| After completing... | You can run in parallel... |
|---------------------|---------------------------|
| 1.1.3 (project shell) | **1.2.x** (theme) ‖ **1.3.x** (models setup) |
| 1.2.2 + 1.3.2 | **2.1.x** (habit models) ‖ **2.2.x** (WHOOP models) |
| 2.1.3 (habit models done) | **4.2.x** (heat map UI) — only needs habit models |
| 2.2.3 (WHOOP models done) | **3.1.x** (OAuth) — only needs WHOOP structs |
| 3.3.2 + 2.1.3 | **4.1.x** (dashboard + status bar) — needs WHOOP cache + habit models |
| 4.3.2 (input wired) | **5.1.x** (local parser) ‖ can preview **6.1.x** (intel manager structs) |
| 5.2.2 (parser done) | **6.1.x** (weekly reports) ‖ **6.2.x** (report view) |
| 6.3.3 (war room done) | **7.1.x** (windows) ‖ **7.2.x** (polish) |

---

## Phase 0 — Environment & Tooling

### 0.1: Xcode Installation
- [ ] Install Xcode 16.2+ from Mac App Store
- [ ] Run `xcode-select -s /Applications/Xcode.app/Contents/Developer`
- [ ] Verify `xcodebuild -version` returns Xcode 16+

### 0.2: API Credentials
> **Depends on:** nothing (can run parallel with 0.1)
- [ ] Register for WHOOP Developer API access at https://developer.whoop.com
- [ ] Create WHOOP OAuth app — note client ID, client secret, redirect URI
- [ ] Confirm Google AI Studio API key is ready for Gemini 3

### 0.3: Git & Repo Init
> **Depends on:** nothing (can run parallel with 0.1, 0.2)
- [ ] Initialize git repo in `project_overwatch/`
- [ ] Create `.gitignore` (Xcode, macOS, Swift, secrets)
- [ ] Create initial commit with `CLAUDE.md`, `plan.md`, `.gitignore`

---

## Phase 1 — Project Foundation

### 1.1.1: Create Xcode Project
> **Depends on:** 0.1 (Xcode installed), 0.3 (git initialized)
- [ ] Create new Xcode project: `Overwatch.xcodeproj` (macOS App, SwiftUI lifecycle)
- [ ] Set Bundle ID `com.overwatch.app`, deployment target macOS 15.0+
- [ ] Enable Swift 6 strict concurrency in build settings

### 1.1.2: SPM Dependencies & Folder Structure
> **Depends on:** 1.1.1
- [ ] Add SPM dependency: `google-generative-ai-swift` (Gemini SDK)
- [ ] Create folder groups: `App/`, `Models/`, `Services/`, `Views/`, `ViewModels/`, `Theme/`, `Utilities/`
- [ ] Create sub-folders under `Views/`: `Dashboard/`, `WarRoom/`, `Reports/`, `Components/`

### 1.1.3: App Shell & Verify Build
> **Depends on:** 1.1.2
- [ ] Create `OverwatchApp.swift` with `@main`, empty `WindowGroup`
- [ ] Create `AppState.swift` — `@Observable` class (empty for now)
- [ ] Verify project builds clean and launches an empty window

### 1.2.1: Color Palette & Typography
> **Depends on:** 1.1.3 | **Parallel with:** 1.3.x
- [ ] Create `OverwatchTheme.swift` — all colors (#000, #1C1C1E, #2C2C2E, #FFB800, #39FF14, #FF453A, #FFF, #8E8E93)
- [ ] Create `Typography.swift` — SF Pro Display (headers), SF Mono (data/metrics)
- [ ] Create `Animations.swift` — standard spring `spring(response: 0.3, dampingFraction: 0.7)`

### 1.2.2: Reusable UI Components
> **Depends on:** 1.2.1
- [ ] Create `TacticalCard.swift` — glassmorphic container (`.ultraThinMaterial`, corner radius, border)
- [ ] Create `MetricTile.swift` — SF Symbol icon + label + value + trend arrow
- [ ] Verify both components render correctly in SwiftUI previews

### 1.3.1: SwiftData Container Setup
> **Depends on:** 1.1.3 | **Parallel with:** 1.2.x
- [ ] Add `ModelContainer` configuration to `OverwatchApp.swift` (empty schema for now)
- [ ] Create `DateFormatters.swift` utility (ISO8601, display, relative)
- [ ] Create `KeychainHelper.swift` — save/read/delete wrapper for Keychain Services

### 1.3.2: Placeholder Dashboard
> **Depends on:** 1.3.1
- [ ] Create placeholder `TacticalDashboardView.swift` with theme background
- [ ] Wire as `WindowGroup` content view
- [ ] Verify app launches to themed black window

---

## Phase 2 — Data Models

### 2.1.1: Habit Model
> **Depends on:** 1.3.2 | **Parallel with:** 2.2.x
- [ ] Create `Habit.swift` — SwiftData `@Model`: `id`, `name`, `emoji`, `category`, `targetFrequency`, `createdAt`
- [ ] Define one-to-many relationship: `Habit` → `[HabitEntry]`
- [ ] Register `Habit` in `ModelContainer`

### 2.1.2: HabitEntry & JournalEntry Models
> **Depends on:** 2.1.1
- [ ] Create `HabitEntry.swift` — SwiftData `@Model`: `id`, `date`, `completed`, `value` (Double?), `notes`, `loggedAt`
- [ ] Create `JournalEntry.swift` — SwiftData `@Model`: `id`, `date`, `content`, `parsedHabits`, `createdAt`
- [ ] Register both in `ModelContainer`

### 2.1.3: Habit Model Tests
> **Depends on:** 2.1.2
- [ ] Write unit tests for `Habit` creation and default values
- [ ] Write unit tests for `Habit` ↔ `HabitEntry` relationship (add, delete cascade)
- [ ] Write unit test for `JournalEntry` creation

### 2.2.1: WHOOP Codable Structs
> **Depends on:** 1.3.2 | **Parallel with:** 2.1.x
- [ ] Create `WhoopRecoveryResponse.swift` — Codable struct matching `/v1/recovery` JSON
- [ ] Create `WhoopSleepResponse.swift` — Codable struct matching `/v1/sleep` JSON
- [ ] Create `WhoopStrainResponse.swift` — Codable struct matching `/v1/cycle` JSON

### 2.2.2: WHOOP Cache Model
> **Depends on:** 2.2.1
- [ ] Create `WhoopCycle.swift` — SwiftData `@Model`: `cycleId`, `date`, `strain`, `recoveryScore`, `hrvRMSSD`, `restingHeartRate`, `sleepPerformance`, `sleepSWS`, `sleepREM`, `fetchedAt`
- [ ] Add transform methods: `WhoopRecoveryResponse` → `WhoopCycle` fields
- [ ] Register `WhoopCycle` in `ModelContainer`

### 2.2.3: WHOOP Model Tests
> **Depends on:** 2.2.2
- [ ] Write unit tests: decode sample JSON → each Codable struct
- [ ] Write unit tests: transform API responses → `WhoopCycle` properties
- [ ] Write unit test for `WhoopCycle` deduplication by `cycleId`

---

## Phase 3 — WHOOP Integration

### 3.1.1: OAuth URL & PKCE
> **Depends on:** 2.2.3 (WHOOP models), 0.2 (API credentials)
- [ ] Create `WhoopAuthManager.swift` — build OAuth 2.0 authorization URL with PKCE
- [ ] Implement code verifier + challenge generation (SHA256)
- [ ] Register custom URL scheme `overwatch` in `Info.plist`

### 3.1.2: OAuth Session & Token Exchange
> **Depends on:** 3.1.1
- [ ] Implement `ASWebAuthenticationSession` flow for macOS
- [ ] Parse authorization code from `overwatch://whoop/callback` redirect
- [ ] Exchange code for access + refresh tokens, store in Keychain

### 3.1.3: OAuth Tests & Token Refresh
> **Depends on:** 3.1.2
- [ ] Implement token refresh logic (detect expiry, call refresh endpoint)
- [ ] Write unit tests for OAuth URL construction and PKCE challenge
- [ ] Write unit tests for token parsing and refresh flow

### 3.2.1: WHOOP Client — Core
> **Depends on:** 3.1.3
- [ ] Create `WhoopClient.swift` actor — base URL, inject `WhoopAuthManager`
- [ ] Implement `fetchRecovery()` → `GET /v1/recovery`
- [ ] Auto-attach Bearer token from Keychain to all requests

### 3.2.2: WHOOP Client — All Endpoints
> **Depends on:** 3.2.1
- [ ] Implement `fetchSleep()` → `GET /v1/sleep`
- [ ] Implement `fetchStrain()` → `GET /v1/cycle`
- [ ] Implement 401 → token refresh → retry original request

### 3.2.3: WHOOP Client — Resilience & Tests
> **Depends on:** 3.2.2
- [ ] Add exponential backoff retry logic for rate limiting / transient errors
- [ ] Write integration tests with mock `URLProtocol` for all three endpoints
- [ ] Write test for 401 → refresh → retry flow

### 3.3.1: Background Sync Manager
> **Depends on:** 3.2.3
- [ ] Create `WhoopSyncManager.swift` — fetch all data on launch, recurring every 30 min
- [ ] Transform API responses → `WhoopCycle` SwiftData models, deduplicate by `cycleId`
- [ ] Add sync status enum to `AppState` (`.idle`, `.syncing`, `.error`, `.synced`)

### 3.3.2: Sync Wiring & Tests
> **Depends on:** 3.3.1
- [ ] Wire `WhoopSyncManager` into `AppState`, start on app launch
- [ ] Write tests for deduplication logic
- [ ] Manual test: full OAuth → fetch → cache flow in Xcode

---

## Phase 4 — Tactical Dashboard UI

### 4.1.1: Dashboard Layout Shell
> **Depends on:** 3.3.2 (WHOOP cache), 2.1.3 (habit models)
- [ ] Create `DashboardViewModel.swift` — `@Observable`, owns WHOOP sync status + habit data transforms
- [ ] Create `TacticalDashboardView.swift` — VStack layout (status bar / heat map / input)
- [ ] Apply bento-box grid with `.ultraThinMaterial` card backgrounds, deep black (#000) background

### 4.1.2: WHOOP Status Bar
> **Depends on:** 4.1.1
- [ ] Create `WhoopStatusBar.swift` — HStack of three `MetricTile` (Recovery, Strain, Sleep)
- [ ] Color-code thresholds: green (≥67%), amber (34-66%), red (≤33%)
- [ ] Wire to `@Query` on latest `WhoopCycle`, animated transitions on refresh

### 4.1.3: Status Bar Polish & States
> **Depends on:** 4.1.2
- [ ] Create loading/placeholder state for when WHOOP data is unavailable
- [ ] Add "last synced" timestamp display
- [ ] Verify in SwiftUI previews with sample data

### 4.2.1: Heat Map Grid
> **Depends on:** 2.1.3 (habit models) | **Parallel with:** 4.1.x
- [ ] Create `HabitHeatMapView.swift` — 52×7 grid (weeks × days), trailing year
- [ ] Create `HeatMapCell.swift` — rounded rect, color intensity from completion %
- [ ] Use `Canvas` or `Grid` for rendering performance

### 4.2.2: Heat Map Interaction & Data
> **Depends on:** 4.2.1
- [ ] Wire heat map to `@Query` on `HabitEntry` data
- [ ] Add hover tooltip: date + habits completed that day
- [ ] Add legend showing color intensity scale

### 4.3.1: Command Line Input — UI
> **Depends on:** 4.1.3, 4.2.2 (dashboard sections ready)
- [ ] Create `CommandLineInputView.swift` — SF Mono, `>` prompt, blinking cursor feel
- [ ] Placeholder: `"Log a habit... (e.g., 'Drank 3L water')"`
- [ ] Add input history — up arrow cycles previous entries

### 4.3.2: Command Line Input — Wiring
> **Depends on:** 4.3.1
- [ ] On submit: route to `NaturalLanguageParser` (stub returning hardcoded `ParsedHabit`)
- [ ] Wire successful parse → create `HabitEntry` in SwiftData
- [ ] Verify full loop: type → parse → save → heat map updates

---

## Phase 5 — Natural Language Parsing

### 5.1.1: ParsedHabit Struct & Local Parser
> **Depends on:** 4.3.2
- [ ] Define `ParsedHabit` struct — `habitName`, `value`, `unit`, `confidence`, `rawInput`
- [ ] Create `NaturalLanguageParser.swift` with `parseLocally(_ input:) -> ParsedHabit?`
- [ ] Implement regex: quantity patterns ("Drank 3L water", "Slept 8 hours", "Meditated 20 min")

### 5.1.2: Parser — Patterns & Matching
> **Depends on:** 5.1.1
- [ ] Implement regex: boolean patterns ("Worked out", "No alcohol", "Skipped sugar")
- [ ] Implement fuzzy matching against existing `Habit` names in SwiftData
- [ ] Write unit tests for all regex patterns + edge cases

### 5.2.1: Gemini Parsing Fallback
> **Depends on:** 5.1.2
- [ ] Add `parseWithGemini(_ input:) async -> ParsedHabit` to `NaturalLanguageParser`
- [ ] Implement hybrid logic: local first → if confidence < 0.7 → call Gemini
- [ ] Cache Gemini mappings locally for repeat inputs

### 5.2.2: Parser Integration & Tests
> **Depends on:** 5.2.1
- [ ] Replace stub in `CommandLineInputView` with real `NaturalLanguageParser`
- [ ] Write integration test with mock Gemini response
- [ ] Test edge cases: gibberish, multi-habit, emoji-only input

---

## Phase 6 — Intelligence Layer

### 6.1.1: Intelligence Manager Setup
> **Depends on:** 5.2.2 | **Parallel with:** 6.2.x (report view can start)
- [ ] Create `IntelligenceManager.swift` — init Gemini client with API key
- [ ] Define system prompt: performance physiologist / tactical strategist persona
- [ ] Define `WeeklyInsight` struct — `summary`, `forceMultiplierHabit`, `recommendations`, `correlations`

### 6.1.2: Weekly Report Generation
> **Depends on:** 6.1.1
- [ ] Implement `generateWeeklyReport(habits:whoop:) async -> WeeklyInsight`
- [ ] Package 7 days of data as JSON, send to Gemini, parse response
- [ ] Cache `WeeklyInsight` in SwiftData for offline viewing

### 6.1.3: Weekly Report Scheduling & Tests
> **Depends on:** 6.1.2
- [ ] Create scheduled trigger: auto-generate Sunday 8am local
- [ ] Write tests with mock Gemini responses
- [ ] Test caching and offline retrieval of past reports

### 6.2.1: Weekly Report View — Layout
> **Depends on:** 5.2.2 | **Parallel with:** 6.1.x
- [ ] Create `WeeklyReportView.swift` — "Intel Briefing" header with date range
- [ ] Force Multiplier habit highlighted with accent color
- [ ] Summary + recommendations sections

### 6.2.2: Weekly Report View — Charts
> **Depends on:** 6.2.1
- [ ] Add correlation chart: habit completion vs recovery score (SwiftUI Charts)
- [ ] Add navigation to browse past weekly reports
- [ ] Wire to cached `WeeklyInsight` via `@Query`

### 6.2.3: Weekly Report View — Verify
> **Depends on:** 6.2.2, 6.1.3 (need real/mock data)
- [ ] Verify with sample/mock data in previews
- [ ] Test empty state (no reports yet)
- [ ] Test navigation between weeks

### 6.3.1: Yearly Review — Data & Structs
> **Depends on:** 6.1.3
- [ ] Define `YearlyInsight` struct — `summary`, `seasonalPatterns`, `bestPeriod`, `worstPeriod`, `longTermTrends`
- [ ] Implement `generateYearlyReview(habits:whoop:) async -> YearlyInsight`
- [ ] Package full year of data, leverage Gemini's large context window

### 6.3.2: War Room — Layout & Charts
> **Depends on:** 6.3.1
- [ ] Create `WarRoomView.swift` — full-screen, dark "command center" layout
- [ ] Create `TrendChartView.swift` — line (recovery), bar (habits), scatter (correlation), area (sleep)
- [ ] Add date range selector (monthly, quarterly, yearly)

### 6.3.3: War Room — Integration & Polish
> **Depends on:** 6.3.2
- [ ] Integrate Gemini yearly insights alongside chart panels
- [ ] Animate chart transitions with spring animation
- [ ] Verify with sample data, test empty/loading states

---

## Phase 7 — Platform Polish

### 7.1.1: Multi-Window Support
> **Depends on:** 6.3.3 | **Parallel with:** 7.2.x
- [ ] Add `WindowGroup` scenes: Dashboard, War Room, Weekly Report
- [ ] Add keyboard shortcuts: `⌘N` (input), `⌘R` (refresh), `⌘1/2/3` (views)
- [ ] Add macOS menu bar items for window switching

### 7.1.2: Menu Bar Widget
> **Depends on:** 7.1.1
- [ ] Create menu bar extra showing today's recovery score
- [ ] Click to open main dashboard window
- [ ] Add Dock badge for low recovery alert (optional)

### 7.2.1: Error States
> **Depends on:** 6.3.3 | **Parallel with:** 7.1.x
- [ ] No WHOOP connection → "Connect WHOOP" prompt
- [ ] API error → tactical-themed retry message
- [ ] Offline mode → cached data with "last synced" timestamp

### 7.2.2: Onboarding Flow
> **Depends on:** 7.2.1
- [ ] Welcome screen with app overview
- [ ] Step 1: Connect WHOOP → Step 2: Add habits → Step 3: Dashboard
- [ ] Skip option for users who want to start without WHOOP

### 7.2.3: Visual Audit & Polish
> **Depends on:** 7.2.2, 7.1.2
- [ ] Audit all views for consistent theme, `.ultraThinMaterial`, SF Symbol `.hierarchical`
- [ ] Add staggered fade-in entrance animations for dashboard cards
- [ ] App icon design — dark, minimal, tactical

---

## Phase 8 — Testing & Hardening

### 8.1.1: Unit Tests
> **Depends on:** 7.2.3
- [ ] Unit tests for all SwiftData models (create, update, relationships, cascades)
- [ ] Unit tests for `NaturalLanguageParser` — all patterns + edge cases
- [ ] Unit tests for `KeychainHelper` and `DateFormatters`

### 8.1.2: Integration & UI Tests
> **Depends on:** 8.1.1
- [ ] Integration tests for `WhoopClient` with mock `URLProtocol`
- [ ] Integration tests for `IntelligenceManager` with mock Gemini
- [ ] UI tests for dashboard navigation, habit logging, report viewing

### 8.1.3: Performance & Edge Cases
> **Depends on:** 8.1.2
- [ ] Test offline mode (cached WHOOP, no Gemini)
- [ ] Performance profiling — dashboard renders at 60fps (< 16ms frames)
- [ ] Memory leak check with Instruments (chart views, background sync)

---

## Phase 9 — Deployment

### 9.1.1: Build & Sign
> **Depends on:** 8.1.3
- [ ] Code signing with Developer ID
- [ ] Create DMG or integrate Sparkle for auto-updates
- [ ] Write README.md with setup instructions

### 9.1.2: Ship
> **Depends on:** 9.1.1
- [ ] Final QA pass on all views and flows
- [ ] Tag v1.0 release in git
- [ ] Ship

---

> **Current Phase:** 0.1 — Xcode Installation
> **Blocked on:** Xcode download
> **Parallel tracks available:** 0.2 (API credentials) ‖ 0.3 (Git init)
