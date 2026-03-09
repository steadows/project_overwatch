# Plan — Overwatch: Tactical Habit & Performance Intelligence System

> **Stack:** Swift 6 | SwiftUI | SwiftData | Gemini 3 API | WHOOP API | macOS native
> **Aesthetic:** Holographic HUD — Jarvis from Iron Man. Translucent panels, wireframe traces, glow bloom, scan lines, data-stream textures. Cinematic and alive.
> **Env:** Xcode 16+ (required) | Swift Package Manager for dependencies

---

## Visual Design Specification

> This section is the **single source of truth** for how Overwatch looks and moves. Every view, component, and interaction should reference this spec. When in doubt about a visual choice, come back here.

### The Holographic HUD Aesthetic

The UI should feel like a **holographic projection floating in a dark room** — not a flat app painted on a screen. Every element should have a sense of depth, luminosity, and engineered precision. Think: Tony Stark's workshop interfaces, fighter jet cockpit displays, cyberpunk command terminals.

**Core visual principles:**
1. **Luminous on void** — Bright, glowing elements on a near-black background. Elements emit light, they don't just have color.
2. **Constructed, not drawn** — Panels feel like they were assembled from wireframes and structural elements, not painted as rectangles.
3. **Active and alive** — Subtle ambient motion everywhere. Nothing is perfectly static. Glows pulse, scan lines drift, data streams tick.
4. **Layered depth** — Multiple translucency layers create a sense of Z-depth. Foreground elements are brighter and more opaque; background elements are dimmer and more transparent.

### Color System

| Token | Hex | Usage |
|---|---|---|
| `void` | `#0A0A0F` | App background — near-black with blue undertone |
| `surface` | `#111219` | Panel/card fill — very dark blue-grey |
| `surfaceElevated` | `#191A23` | Raised elements, hover states |
| `accentCyan` | `#00D4FF` | Primary UI chrome — borders, labels, active indicators |
| `accentAmber` | `#FFB800` | Warnings, secondary highlights |
| `statusGreen` | `#39FF14` | Good/high performance values |
| `statusRed` | `#FF453A` | Bad/low performance values, errors |
| `textPrimary` | `#FFFFFF` | Primary text and values |
| `textSecondary` | `#8E8E93` | Dimmed labels, inactive items |
| `glowCyan` | `#00D4FF` @ 30-50% | Glow/bloom effects on active elements |
| `scanLine` | `#00D4FF` @ 6-8% | Subtle CRT scan line overlay |

**Glow rules:**
- Interactive elements (buttons, toggles, selected items) get a **dual-layer glow**: tight inner (4-6pt radius, 30-40% opacity) + wide bloom (16-24pt radius, 10-15% opacity)
- Data values that change get a **brief glow flash** on update (0.3s decay)
- The sidebar selected item and active section headers get a **constant subtle pulse** (2s cycle, ±5% opacity)

### Holographic Effects Library

These effects should be used consistently throughout the app:

#### Scan Lines
- **What:** Horizontal lines drawn every 3pt at 6-8% cyan opacity across panel surfaces
- **Implementation:** `Canvas` overlay, clipped to panel shape
- **Where:** Every `TacticalCard`, sidebar background, full-screen backdrop
- **Motion:** Optional slow drift (0.5pt/sec upward) for "active display" feel

#### Grid Backdrop
- **What:** Dot grid (every 20pt) at 4-6% cyan opacity on the void background
- **Implementation:** `Canvas` on the root background layer
- **Where:** Behind all content, visible through translucent panels
- **Motion:** Static (provides spatial reference, shouldn't distract)

#### Glow Bloom
- **What:** Soft light radiation around luminous elements — borders, icons, active text
- **Implementation:** `.shadow(color: .cyan.opacity(0.3), radius: 8)` layered (inner tight + outer wide)
- **Where:** Active borders, selected items, important values, buttons on hover/press
- **Motion:** Pulses gently on idle (2s cycle), flares bright on interaction (0.3s spike + 0.5s decay)

#### Wireframe Trace
- **What:** A border/outline that **draws itself** along its path, like a laser tracing the shape
- **Implementation:** `trim(from:to:)` animated from 0→1 on a `Shape` stroke, or `strokeEnd` in a `CAShapeLayer`
- **Where:** Panel borders on appear, new elements entering the view, loading states
- **Timing:** 0.3-0.5s, ease-out. Start from top-left corner, trace clockwise

#### Data Stream Texture
- **What:** Cascading small characters/numbers (like subtle Matrix rain) inside panel backgrounds
- **Implementation:** `Canvas` or `TimelineView` drawing random monospace chars at very low opacity (3-5%), scrolling slowly downward
- **Where:** War Room background, loading states, behind charts. Subtle — should be barely visible
- **Motion:** Continuous slow downward scroll (10pt/sec)

#### Particle Scatter
- **What:** Tiny luminous dots that burst outward from an interaction point and fade
- **Implementation:** `TimelineView` + array of particle structs with position/velocity/opacity, or `Canvas` with animation
- **Where:** Habit toggle completion, streak milestone celebrations, button confirmations
- **Timing:** 8-12 particles, burst outward over 0.4s, fade to 0 opacity by 0.6s

#### HUD Frame Shape
- **What:** Hexagonal panel frame with 45° chamfered (angled cut) corners on top-right and bottom-left
- **Implementation:** Custom SwiftUI `Shape` with 6-point path
- **Where:** Every card/panel — this IS the panel shape, not rounded rectangles
- **Details:** Chamfer size 10-14pt. Stroke at 1-1.5pt, 60-70% opacity cyan

#### Frame Accents
- **What:** Small decorative details on panel edges — short lines near chamfer points, dots at midpoints, L-shaped corner marks
- **Implementation:** `Canvas` overlay on each panel
- **Where:** Every `TacticalCard`
- **Details:** Lines 20-24pt long, 1pt wide. Dots 2-3pt diameter. Corner marks 6-8pt arms

### Animation Vocabulary

Every animation in the app should use one of these named patterns. This keeps the motion language consistent — the app should feel like one coherent system, not a collection of random transitions.

#### Materialize (element appearing)
> An element "powers on" — wireframe traces in, then fill sweeps across, then content fades up.

1. **Frame trace** (0.0-0.3s): Border draws itself via `trim(from:to:)` — starts from a corner, traces the full perimeter
2. **Fill sweep** (0.2-0.4s): Background color sweeps in from left to right (gradient mask or `clipShape` with animated width)
3. **Content fade** (0.3-0.5s): Inner content (text, icons, data) fades in with slight upward drift (6pt translateY)
4. **Glow flash** (0.4-0.6s): Brief bright glow on border that decays to normal idle glow

Use for: new panels appearing, dashboard sections on load, onboarding steps entering.

#### Dissolve (element disappearing)
> Reverse of materialize — content fades, fill dissolves, wireframe fades.

1. **Content fade** (0.0-0.15s): Inner content fades out
2. **Fill dissolve** (0.1-0.25s): Background becomes transparent
3. **Frame fade** (0.2-0.35s): Border fades to 0

Use for: panels being removed, navigating away, dismissing sheets.

#### Slide-Reveal (panel expansion)
> A panel slides open to reveal new content — like a Jarvis interface panel splitting to show detail.

1. **Border extend** (0.0-0.2s): The bottom border of the parent panel extends downward, tracing the new panel's sides
2. **Space open** (0.1-0.4s): Content below pushes down with spring physics (damping 0.85, response 0.35)
3. **Content slide** (0.2-0.5s): New content slides in from the left edge or fades up from bottom
4. **Glow pulse** (0.4-0.6s): Brief glow on the newly revealed panel border

Use for: habit toggle tap-to-expand, WHOOP strip expanding to full gauges, report card expanding to detail.

#### Slide-Retract (panel collapse)
> Reverse of slide-reveal — content slides out, space closes, border retracts.

1. **Content exit** (0.0-0.15s): Content slides out or fades
2. **Space close** (0.1-0.35s): Spring physics pull content back together
3. **Border retract** (0.2-0.4s): Extended borders animate back to original panel shape

Use for: collapsing expanded habit panel, closing expanded WHOOP strip.

#### Glow Pulse (confirmation/interaction feedback)
> A brief bright flash that confirms an action happened.

1. **Spike** (0.0-0.1s): Glow opacity and radius jump to 2× normal
2. **Decay** (0.1-0.5s): Ease-out back to normal idle glow level

Use for: habit toggle completion, button presses, data sync complete.

#### Data Count (numeric value change)
> Numbers don't snap — they count up/down through intermediate values with a glow trail.

1. **Value roll** (0.0-0.4s): Number animates through intermediate values (use `.contentTransition(.numericText())`)
2. **Glow trail** (0.0-0.6s): Brief cyan glow shadow on the changing number, decays after value settles

Use for: WHOOP metrics updating, completion percentages changing, streak counters incrementing.

#### Stagger (multiple elements appearing)
> Sibling elements appear one after another with a consistent delay.

- **Delay per item:** 0.08-0.12s
- **Each item uses:** Materialize or simple fade+drift (opacity 0→1, translateY 8→0)
- **Spring:** response 0.3, damping 0.8

Use for: dashboard sections on load, habit list rows, chart data points, onboarding step content.

#### Section Transition (sidebar navigation)
> Switching between sidebar sections (Dashboard → Habits → War Room etc.)

1. **Current view exit** (0.0-0.15s): Content fades to 0 opacity with slight scale to 0.98 (or slight horizontal slide toward sidebar)
2. **New view enter** (0.1-0.3s): New content fades in from 0 opacity with slight scale from 0.98→1.0 (or slight horizontal slide from right)
3. **Sidebar indicator** (0.0-0.3s): Selection highlight glow slides from old item to new item with spring

Use for: every sidebar section change. Must feel fast — total duration ≤0.3s.

### Component Visual Specs

#### Sidebar
- **Width expanded:** ~200pt, showing icon + label
- **Width collapsed:** ~52pt, showing icon only
- **Background:** `surface` (#111219) with scan line overlay at reduced opacity (4%)
- **Dividers:** `HUDDivider` between items (thin cyan line with diamond center)
- **Item idle:** Icon + label in `textSecondary`, no glow
- **Item hover:** Background lightens to `surfaceElevated`, icon tints to `accentCyan`, subtle glow appears
- **Item selected:** Full `accentCyan` tint on icon + label, left edge accent bar (2pt wide, full height of item), glow bloom on icon
- **Collapse animation:** Spring slide (0.3s, damping 0.85). Labels fade out at 50% of the width transition. Icons stay centered throughout

#### TacticalCard (panel)
- **Shape:** `HUDFrameShape` with chamfered corners (NOT rounded rect)
- **Fill:** `surface` with scan line overlay
- **Border:** 1.5pt stroke, `accentCyan` at 60-70% opacity
- **Glow:** Dual-layer — 6pt inner at 35%, 24pt outer at 15%
- **Accents:** `FrameAccents` overlay (edge lines, dots, corner marks)
- **Appear animation:** Materialize (trace → fill → content → glow)

#### Habit Toggle Button
- **Idle (incomplete):** `HUDFrameShape` card, `surface` fill, dim border (30% cyan), emoji + name in `textSecondary`
- **Idle (complete):** Brighter border (70% cyan), checkmark icon glowing, emoji + name in `textPrimary`, subtle constant glow
- **Hover:** Border brightens, background shifts to `surfaceElevated`
- **Press:** Brief scale to 0.97, glow spike
- **Toggle complete:** Checkmark draws in with spring (0.3s), particle scatter burst from center, glow pulse
- **Expand:** Slide-Reveal animation — panel opens below with value/notes fields

#### Quick Input Field
- **Idle:** Dark background, very dim border (15% cyan), ">" prompt in `textSecondary`, blinking cursor (0.8s cycle)
- **Focused:** Border brightens to 60% cyan, glow bloom appears, ">" prompt brightens to `accentCyan`, placeholder text dims
- **Typing:** Each character appears with micro glow flash (very subtle, 0.1s)
- **Submit success:** Brief green glow sweep across the field, confirmation text flashes ("✓ LOGGED: {habit name}"), field clears
- **Submit error:** Brief red glow pulse, field shakes (3pt horizontal shake, 0.3s), error text appears below

#### Heat Map
- **Cells:** Rounded rect (2pt radius), sized to fill available width
- **Empty (0%):** `#1C1C1E` — barely visible on void background
- **Low (1-33%):** Dim cyan (20% opacity solid fill)
- **Medium (34-66%):** Medium cyan (50% opacity)
- **High (67-99%):** Bright cyan (80% opacity) with subtle glow shadow
- **Full (100%):** Full cyan with 2s pulsing glow (like a fully charged cell)
- **Hover:** Cell scales to 1.15×, glow intensifies, tooltip materializes below (Materialize animation, 0.2s)
- **Tooltip:** Small `TacticalCard` showing date + completion details

#### Charts (War Room)
- **Background:** `void` with faint grid lines (8% cyan) and optional data stream texture
- **Line charts:** Cyan line, 2pt, with glow shadow. Data points as 4pt circles with glow
- **Bar charts:** Filled bars with gradient (darker at base, brighter at top), subtle glow on top edge
- **Scatter points:** 6pt circles with glow bloom, pulsing gently
- **Axes:** `textSecondary` color, 1pt, monospace labels
- **Data appear:** Stagger animation — points/bars animate in left to right (0.05s delay each)
- **Date range change:** Old data fades + shrinks, new data materializes + grows (spring, 0.4s)
- **Hover on data point:** Point enlarges to 8pt, glow flares, tooltip materializes nearby

### Ambient Motion (Always Active)

These subtle animations run continuously to keep the UI feeling alive:

1. **Scan line drift:** Scan lines move upward at 0.5pt/sec (barely perceptible, adds "active display" feeling)
2. **Glow breathing:** Selected/active elements pulse glow opacity ±5% on a 2-3s cycle
3. **Status indicator pulse:** Sync status dot pulses with `PulsingGlow` (1.5s cycle)
4. **Cursor blink:** Quick input field cursor blinks at 0.8s interval
5. **Data stream scroll** (War Room only): Background character rain scrolls slowly downward

**Performance rule:** All ambient animations must use `Canvas` or `TimelineView` — never spawn dozens of simultaneous `withAnimation` blocks. GPU-friendly, compositor-driven.

---

```
Phases 0–6: COMPLETE (foundation, models, WHOOP, dashboard, habits, NLP parsing)
Phase 8.1, 9.1: COMPLETE (boot sequence, settings)

Current flow (Phase 6.5 onward):

6.5.1 (Models) --+--- 6.5.2 (Sentiment Svc) --+--- 6.5.6 (JournalVM) --- 6.5.7 (Journal UI)
                 |                              |         |                       |
                 +--- 6.5.3 (Regression Svc) ---+         |               6.5.8 (Sentiment Viz)
                 |         |                              |                       |
                 |   6.5.4 (Gemini Narr.) ----------------+              6.5.10 (Dashboard Pulse)
                 |                                        |                       |
                 +--- 6.5.5 (Nav Sidebar) ----------------+              6.5.9 (Monthly Analysis)
                                                                                  |
                                                                  6.5.11 (Synthetic Data + Tests)
                                                                          |
                                                                  6.5.12 (War Room Charts)
                                                                  6.5.13 (Reports Stubs)
                                                                          |
                     7.1 (Intel Manager) --- 7.2 (Reports Gen) --- 7.3 (Reports Page)
                                                                          |
                                                               7.4 (War Room Split Pane)
                                                                          |
                     8.2 (Onboarding)                                     |
                                                                          |
                     9.2 (Error States) <---------------------------------+
                          |
                    9.3 (Visual Audit) --- 10.1 (Unit Tests) --- 10.2 (Integration)
                                                                        |
                                                                 10.3 (Performance)
                                                                        |
                                                        11.1 (Build) --- 11.2 (Ship)
```

### Parallelization Guide

| After completing... | You can run in parallel... |
|---------------------|---------------------------|
| 6.5.1 (models) | **6.5.2** (sentiment svc) ‖ **6.5.3** (regression svc) ‖ **6.5.5** (nav sidebar) |
| 6.5.2 + 6.5.3 | **6.5.4** (Gemini narrative) ‖ **6.5.6** (JournalVM) |
| 6.5.5 + 6.5.6 | **6.5.7** (Journal UI) |
| 6.5.7 | **6.5.8** (sentiment viz) ‖ **6.5.10** (dashboard pulse) |
| 6.5.8 + 6.5.4 | **6.5.9** (monthly analysis UI) |
| 6.5.6 + 6.5.2 + 6.5.3 | **6.5.11** (synthetic data + tests) |
| 6.5.8 + 6.5.11 | **6.5.12** (War Room charts) |
| 6.5.9 | **6.5.13** (reports integration stubs) |
| 6.5.13 (journal done) | **7.1** (intel manager) ‖ **8.2** (onboarding) |
| 7.2 (report gen) | **7.3** (reports page) ‖ **7.4** (war room) |
| 7.4 + all views built | **9.2** (error states) |
| 9.3 (polish done) | **10.1** (unit tests) ‖ **10.2** (integration tests) |

---

## Phase 0 — Environment & Tooling

### 0.1: Xcode Installation
- [x] Install Xcode 16.2+ from Mac App Store
- [x] Run `xcode-select -s /Applications/Xcode.app/Contents/Developer`
- [x] Verify `xcodebuild -version` returns Xcode 16+ → **Xcode 26.2 (Build 17C52)**

### 0.2: API Credentials
> **Depends on:** nothing (can run parallel with 0.1)
- [ ] Register for WHOOP Developer API access at https://developer.whoop.com
- [ ] Create WHOOP OAuth app — note client ID, client secret, redirect URI
- [ ] Confirm Google AI Studio API key is ready for Gemini 3

### 0.3: Git & Repo Init
> **Depends on:** nothing (can run parallel with 0.1, 0.2)
- [x] Initialize git repo in `project_overwatch/`
- [x] Create `.gitignore` (Xcode, macOS, Swift, secrets)
- [x] Create initial commit with `CLAUDE.md`, `plan.md`, `.gitignore`

---

## Phase 1 — Project Foundation

### 1.1.1: Create Xcode Project
> **Depends on:** 0.1 (Xcode installed), 0.3 (git initialized)
- [x] Create new Xcode project: `Overwatch.xcodeproj` (macOS App, SwiftUI lifecycle) — via xcodegen + project.yml
- [x] Set Bundle ID `com.overwatch.app`, deployment target macOS 15.0+
- [x] Enable Swift 6 strict concurrency in build settings

### 1.1.2: SPM Dependencies & Folder Structure
> **Depends on:** 1.1.1
- [x] Add SPM dependency: `google-generative-ai-swift` (Gemini SDK)
- [x] Create folder groups: `App/`, `Models/`, `Services/`, `Views/`, `ViewModels/`, `Theme/`, `Utilities/`
- [x] Create sub-folders under `Views/`: `Dashboard/`, `WarRoom/`, `Reports/`, `Components/`

### 1.1.3: App Shell & Verify Build
> **Depends on:** 1.1.2
- [x] Create `OverwatchApp.swift` with `@main`, empty `WindowGroup`
- [x] Create `AppState.swift` — `@Observable @MainActor` class with SyncStatus enum
- [x] Verify project builds clean → **BUILD SUCCEEDED** (Xcode 26.2)

### 1.2.1: Color Palette & Typography
> **Depends on:** 1.1.3 | **Parallel with:** 1.3.x
- [x] Create `OverwatchTheme.swift` — all colors (#000, #1C1C1E, #2C2C2E, #FFB800, #39FF14, #FF453A, #FFF, #8E8E93)
- [x] Create `Typography.swift` — SF Pro Display (headers), SF Mono (data/metrics)
- [x] Create `Animations.swift` — standard spring `spring(response: 0.3, dampingFraction: 0.7)`

### 1.2.2: Reusable UI Components
> **Depends on:** 1.2.1
- [x] Create `TacticalCard.swift` — glassmorphic container (`.ultraThinMaterial`, corner radius, border)
- [x] Create `MetricTile.swift` — SF Symbol icon + label + value + trend arrow
- [x] Verify both components render correctly in SwiftUI previews — **BUILD SUCCEEDED**, previews included

### 1.3.1: SwiftData Container Setup
> **Depends on:** 1.1.3 | **Parallel with:** 1.2.x
- [x] Add `ModelContainer` configuration to `OverwatchApp.swift` (empty schema for now)
- [x] Create `DateFormatters.swift` utility (ISO8601, display, relative)
- [x] Create `KeychainHelper.swift` — save/read/delete wrapper for Keychain Services

### 1.3.2: Placeholder Dashboard
> **Depends on:** 1.3.1
- [x] Create placeholder `TacticalDashboardView.swift` with theme background
- [x] Wire as `WindowGroup` content view
- [x] Verify app launches to themed black window — **BUILD SUCCEEDED**

---

## Phase 2 — Data Models

### 2.1.1: Habit Model
> **Depends on:** 1.3.2 | **Parallel with:** 2.2.x
- [x] Create `Habit.swift` — SwiftData `@Model`: `id`, `name`, `emoji`, `category`, `targetFrequency`, `createdAt`
- [x] Define one-to-many relationship: `Habit` → `[HabitEntry]`
- [x] Register `Habit` in `ModelContainer`

### 2.1.2: HabitEntry & JournalEntry Models
> **Depends on:** 2.1.1
- [x] Create `HabitEntry.swift` — SwiftData `@Model`: `id`, `date`, `completed`, `value` (Double?), `notes`, `loggedAt`
- [x] Create `JournalEntry.swift` — SwiftData `@Model`: `id`, `date`, `content`, `parsedHabits`, `createdAt`
- [x] Register both in `ModelContainer`

### 2.1.3: Habit Model Tests
> **Depends on:** 2.1.2
- [x] Write unit tests for `Habit` creation and default values
- [x] Write unit tests for `Habit` ↔ `HabitEntry` relationship (add, delete cascade)
- [x] Write unit test for `JournalEntry` creation

### 2.2.1: WHOOP Codable Structs
> **Depends on:** 1.3.2 | **Parallel with:** 2.1.x
- [x] Create `WhoopRecoveryResponse.swift` — Codable struct matching `/v1/recovery` JSON
- [x] Create `WhoopSleepResponse.swift` — Codable struct matching `/v1/sleep` JSON
- [x] Create `WhoopStrainResponse.swift` — Codable struct matching `/v1/cycle` JSON

### 2.2.2: WHOOP Cache Model
> **Depends on:** 2.2.1
- [x] Create `WhoopCycle.swift` — SwiftData `@Model`: `cycleId`, `date`, `strain`, `recoveryScore`, `hrvRMSSD`, `restingHeartRate`, `sleepPerformance`, `sleepSWS`, `sleepREM`, `fetchedAt`
- [x] Add transform methods: `WhoopRecoveryResponse` → `WhoopCycle` fields
- [x] Register `WhoopCycle` in `ModelContainer` — **BUILD SUCCEEDED**

### 2.2.3: WHOOP Model Tests
> **Depends on:** 2.2.2
- [x] Write unit tests: decode sample JSON → each Codable struct
- [x] Write unit tests: transform API responses → `WhoopCycle` properties
- [x] Write unit test for `WhoopCycle` deduplication by `cycleId`

---

## Phase 3 — WHOOP Integration

### 3.1.1: OAuth URL & PKCE
> **Depends on:** 2.2.3 (WHOOP models), 0.2 (API credentials)
- [x] Create `WhoopAuthManager.swift` — build OAuth 2.0 authorization URL with PKCE
- [x] Implement code verifier + challenge generation (SHA256)
- [x] Register custom URL scheme `overwatch` in `Info.plist` — already present from 1.1.1

### 3.1.2: OAuth Session & Token Exchange
> **Depends on:** 3.1.1
- [x] Implement `ASWebAuthenticationSession` flow for macOS
- [x] Parse authorization code from `overwatch://whoop/callback` redirect
- [x] Exchange code for access + refresh tokens, store in Keychain

### 3.1.3: OAuth Tests & Token Refresh
> **Depends on:** 3.1.2
- [x] Implement token refresh logic (detect expiry, call refresh endpoint)
- [x] Write unit tests for OAuth URL construction and PKCE challenge
- [x] Write unit tests for token parsing and refresh flow

### 3.2.1: WHOOP Client — Core
> **Depends on:** 3.1.3
- [x] Create `WhoopClient.swift` actor — base URL, inject `WhoopAuthManager`
- [x] Implement `fetchRecovery()` → `GET /v1/recovery`
- [x] Auto-attach Bearer token from Keychain to all requests

### 3.2.2: WHOOP Client — All Endpoints
> **Depends on:** 3.2.1
- [x] Implement `fetchSleep()` → `GET /v1/sleep`
- [x] Implement `fetchStrain()` → `GET /v1/cycle`
- [x] Implement 401 → token refresh → retry original request

### 3.2.3: WHOOP Client — Resilience & Tests
> **Depends on:** 3.2.2
- [x] Add exponential backoff retry logic for rate limiting / transient errors
- [x] Write integration tests with mock `URLProtocol` for all three endpoints
- [x] Write test for 401 → refresh → retry flow

### 3.3.1: Background Sync Manager
> **Depends on:** 3.2.3
- [x] Create `WhoopSyncManager.swift` — fetch all data on launch, recurring every 30 min
- [x] Transform API responses → `WhoopCycle` SwiftData models, deduplicate by `cycleId`
- [x] Add sync status enum to `AppState` (`.idle`, `.syncing`, `.error`, `.synced`) — already existed

### 3.3.2: Sync Wiring & Tests
> **Depends on:** 3.3.1
- [x] Wire `WhoopSyncManager` into `AppState`, start on app launch
- [x] Write tests for deduplication logic — covered in WhoopCycleDeduplicationTests (Phase 2)
- [ ] Manual test: full OAuth → fetch → cache flow in Xcode — requires WHOOP API credentials

---

## Phase 4 — App Navigation & Dashboard UI

> **Design context:** Single-window app with collapsible sidebar. Habits are the star of the show — WHOOP metrics are visible but secondary, used for correlation and analysis. Holographic HUD aesthetic with Jarvis-level animation polish (translucent overlays, wireframes, scan lines, particle effects, light bloom).

### 4.0: HUD Visual Redesign — Sci-Fi Cockpit Aesthetic ✅
> **Depends on:** 4.1.1 | **Parallel with:** nothing — theme changes first, then resume 4.1.2+
- [x] Update `OverwatchTheme.swift` — blue-black bg (#0A0A0F), `accentCyan` (#00D4FF), glow helpers, tighter corners
- [x] Update `Typography.swift` — all fonts → monospaced, light/medium weights for sleek feel, add `hudLabel`
- [x] Update `Animations.swift` — add `dataStream`, `glowPulse`, `bootSequence` animations
- [x] Create `Theme/HUDEffects.swift` — `HUDFrameShape` (chamfered corners), `FrameAccents`, `ScanLineOverlay`, `GridBackdrop`, `HUDDivider`, `HUDBootEffect`, `PulsingGlow`, `.hudGlow()`/`.hudBoot()` extensions
- [x] Create `Views/Components/HUDProgressBar.swift` — 3pt glowing instrument gauge bar
- [x] Create `Views/Components/ArcGauge.swift` — 270° circular ring gauge with tick marks for percentage metrics
- [x] Update `TacticalCard.swift` — `HUDFrameShape` (chamfered frame, not rounded rect), bright cyan border, scan lines, frame accent decorations, dual-layer glow
- [x] Update `MetricTile.swift` — cyan tracked labels, optional progress bar, glowing values
- [x] Update `TacticalDashboardView.swift` — cyan title with glow, section labels, `HUDDivider`, `GridBackdrop`, arc gauges for Recovery/Sleep, boot-up stagger, blinking cursor
- [x] Verify build + 30/30 tests pass + visual preview

### 4.1: Dashboard Core ✅
> These tasks built the initial dashboard before the sidebar redesign. All still valid — the dashboard view will be embedded inside the new navigation shell.

#### 4.1.1: Dashboard Layout Shell
> **Depends on:** 3.3.2 (WHOOP cache), 2.1.3 (habit models)
- [x] Create `DashboardViewModel.swift` — `@Observable`, owns WHOOP sync status + habit data transforms
- [x] Create `TacticalDashboardView.swift` — VStack layout (status bar / heat map / input)
- [x] Apply bento-box grid with `.ultraThinMaterial` card backgrounds, deep black (#000) background

#### 4.1.2: WHOOP Status Bar
> **Depends on:** 4.1.1
- [x] Create WHOOP status section — `ArcGauge` for Recovery + Sleep, `MetricTile` for Strain + HRV
- [x] Color-code thresholds: green (≥67%), amber (34-66%), red (≤33%) via `performanceColor(for:)`
- [x] Wire to `DashboardViewModel.whoopMetrics`, animated transitions via `.contentTransition(.numericText())`

#### 4.1.3: Status Bar Polish & States
> **Depends on:** 4.1.2
- [x] Create loading/placeholder state for when WHOOP data is unavailable
- [x] Add sync status badge with pulsing glow indicator (IDLE/SYNCING/SYNCED/ERROR)
- [x] Verify in SwiftUI previews with sample data

#### 4.1.4: Habit Tracking Panel
> **Depends on:** 4.1.1
- [x] Extend `DashboardViewModel` — `TrackedHabit` struct with weekly/monthly completion rates
- [x] Add `addHabit()` and `toggleHabitCompletion()` methods to ViewModel
- [x] Create `Views/Dashboard/HabitPanelView.swift` — full habit list with today toggle, 7-day / 30-day completion bars
- [x] Add habit sheet with HUD-styled form (DESIGNATION + ICON fields, ACTIVATE/CANCEL buttons)
- [x] Empty state for no tracked habits
- [x] Wire into `TacticalDashboardView` as "ACTIVE OPERATIONS" section
- [x] Verify build + 30/30 tests pass

### 4.1.5: Advanced HUD Effects Library
> **Depends on:** 4.0 (existing effects) | **Must complete before:** 4.3 (dashboard uses these), 8.1 (boot sequence uses Wireframe Trace)
>
> Phase 4.0 built: scan lines, grid backdrop, glow bloom, HUD frame shape, frame accents, progress bar, arc gauge. These three remaining effects from the Visual Design Spec need reusable components before views can use them.

- [x] Create `Theme/WireframeTrace.swift` — animatable ViewModifier that draws a Shape's border via `trim(from:to:)`
  - [x] Generic over any `Shape` — works with `HUDFrameShape`, `RoundedRectangle`, `Circle`, any custom shape
  - [x] Configurable: duration (default 0.4s), easing (default ease-out), stroke width, color
  - [x] Trigger via `.wireframeTrace(isVisible:)` modifier — animates trim from 0→1 when `isVisible` becomes true
  - [x] Start point: top-left corner, traces clockwise
  - [x] Used by: **Materialize** animation pattern (first phase), boot sequence grid lines, loading indicators
- [x] Create `Theme/DataStreamTexture.swift` — Canvas-based cascading character rain effect
  - [x] Renders random monospace characters (0-9, A-F, symbols) falling slowly downward
  - [x] Configurable: opacity (default 3-5%), scroll speed (default 10pt/sec), column spacing, character set
  - [x] Uses `TimelineView(.animation)` for continuous motion, `Canvas` for rendering (GPU-friendly, no per-character View)
  - [x] Characters fade in at top, fade out at bottom (gradient mask)
  - [x] Used by: War Room background, loading/processing states, boot sequence backdrop
- [x] Create `Theme/ParticleScatter.swift` — burst particle animation triggered on interaction
  - [x] `ParticleScatterView` takes a trigger binding — fires burst when trigger flips
  - [x] Configurable: particle count (default 10), burst radius (default 40pt), fade duration (default 0.5s), color
  - [x] Each particle: random angle, velocity with slight randomization, starts at 100% opacity → 0% over lifetime
  - [x] Uses `TimelineView` + particle struct array for animation (not `withAnimation` per particle)
  - [x] Particles are tiny dots (2-3pt) with glow shadow matching particle color
  - [x] Used by: habit toggle completion, streak milestones, button confirmations
- [x] Create `Theme/AnimationPatterns.swift` — reusable ViewModifiers for the named animation vocabulary
  - [x] `.materializeEffect(isVisible:delay:)` — orchestrates: wireframe trace → fill sweep → content fade → glow flash
  - [x] `.dissolveEffect(isVisible:)` — reverse: content fade → fill dissolve → frame fade
  - [x] `.slideRevealEffect(isExpanded:)` — border extend → spring space → content slide → glow pulse
  - [x] `.slideRetractEffect(isExpanded:)` — reverse of slide-reveal (handled by slideRevealEffect toggle)
  - [x] `.glowPulseEffect(trigger:color:)` — brief spike + decay on trigger
  - [x] `.staggerEffect(index:)` — delay based on index for sequential appearance
- [x] Verify all new effects render correctly in SwiftUI previews
- [x] Verify existing 30 tests still pass (no view-layer test changes needed)

### 4.1.6: Visual Overhaul — Holographic Polish ✅
> **Depends on:** 4.1.5, 4.2 | **Triggered by:** User feedback ("still not feeling futuristic or Jarvis-like")
>
> Pulled forward from 9.3 (Visual Audit). Comprehensive overhaul to achieve the holographic projection feel.

- [x] Rewrite `Typography.swift` — Futura Medium (hero titles), Avenir Next Ultra Light (section headers), Avenir Next Light (subtitles), SF Pro Ultra Light (captions/HUD labels), SF Mono Light (data values). All thinner than normal — projected, not painted.
- [x] Add `surfaceTranslucent` to `OverwatchTheme` — 55% opacity surface lets grid/data stream bleed through
- [x] Create `.textGlow()` View modifier — dual-layer shadow (inner 0.6 opacity + outer bloom 0.2 opacity at 2.5× radius) for emissive text
- [x] Update `TacticalCard` — translucent background, inner glow gradient at top edge (holographic light spill), drifting scan lines, cranked border bloom
- [x] Apply `.textGlow()` across entire codebase: TacticalDashboardView, MetricTile, ArcGauge, HabitPanelView, NavigationShell sidebar, StubHeader, BlinkingCursor
- [x] Widen tracking on all HUD labels (1.5→3), section labels (→4), hero subtitle (→5), hero title (→6)
- [x] Verify build + 30/30 tests pass

### 4.2: Navigation Shell — Sidebar & View Routing ✅
> **Depends on:** 4.1.4, 4.1.5 (effects library) | **Priority: HIGH — restructures the entire app from single-view to sidebar navigation**

- [x] Create `NavigationShell.swift` — custom sidebar + detail layout (not `NavigationSplitView` — we need full control for HUD styling)
- [x] Implement collapsible sidebar with 5 sections:
  - [x] **Dashboard** — daily ops, habit toggles, WHOOP summary, quick input
  - [x] **Habits** — full habit management, per-habit heat maps, journal timeline, trend charts
  - [x] **War Room** — split-pane analytics (AI briefing + interactive charts)
  - [x] **Reports** — weekly AI intel briefings archive
  - [x] **Settings** — connections, API keys, preferences
- [x] Each sidebar item: SF Symbol icon + label text, HUD-styled selection state with cyan glow highlight
- [x] Sidebar collapse/expand: spring slide (0.3s, damping 0.85), labels fade at 50% width, icons stay centered (see Sidebar spec in Visual Design Specification)
- [x] Create stub placeholder views: `HabitsView.swift`, `WarRoomView.swift`, `ReportsView.swift`, `SettingsView.swift`
- [x] Wire `NavigationShell` as the root `WindowGroup` content (replaces direct `TacticalDashboardView`)
- [x] Embed existing `TacticalDashboardView` as the Dashboard detail content
- [x] Sidebar selection transitions: use **Section Transition** pattern from spec — current view fades+scales to 0.98, new view enters from 0.98→1.0 (≤0.3s total), selection glow slides between items with spring
- [x] Sidebar styling per Visual Design Spec **Sidebar component spec**: `surface` background with scan line overlay (4% opacity), `HUDDivider` between items, hover → `surfaceElevated` + cyan icon tint, selected → full cyan tint + 2pt left accent bar + glow bloom on icon
- [x] Verify build + all existing 30 tests still pass + sidebar toggles between stub views

### 4.3: Dashboard Redesign — Habits-First Layout
> **Depends on:** 4.2 (navigation shell in place)
>
> **Key change:** Habits are the hero. WHOOP metrics are supplementary context, not the headline. The dashboard is for daily action — what do I need to do today?

- [x] Restructure `TacticalDashboardView` layout:
  - **Top section: "TODAY'S OPS"** — quick-toggle habit buttons, large and prominent
  - **Mid section: "BIOMETRIC STATUS"** — WHOOP metrics as a compact horizontal strip (not full arc gauges)
  - **Bottom section: "FIELD LOG"** — text input for freeform habit logging
- [x] Quick-toggle habit buttons: large HUD-styled buttons showing emoji + habit name + today's status
- [x] **Tap-to-expand interaction** (see **Habit Toggle Button** spec + **Slide-Reveal** animation pattern):
  - [x] Tapping a habit button slides open an inline panel below it
  - [x] Expanded panel shows: optional value field (e.g., "3L"), optional notes field, CONFIRM / CANCEL buttons
  - [x] Expand: use **Slide-Reveal** pattern — border extends downward (0.0-0.2s) → space opens with spring damping 0.85 (0.1-0.4s) → content slides in from left (0.2-0.5s) → **Glow Pulse** on new border (0.4-0.6s)
  - [x] Collapse: use **Slide-Retract** pattern — content exits (0.0-0.15s) → space closes with spring (0.1-0.35s) → border retracts (0.2-0.4s)
  - [x] Toggle completion: checkmark draws in with spring (0.3s) + **Particle Scatter** burst from center + **Glow Pulse** on button border
  - [x] Use `matchedGeometryEffect` or custom `AnchorPreference` for smooth transitions
- [x] WHOOP metrics compact strip: single horizontal row of small `MetricTile`s for Recovery / Sleep / Strain / HRV
  - [x] Tap the strip to expand into the full arc gauge view (existing 4.1.2 work)
  - [x] When WHOOP data unavailable: show "CONNECT WHOOP" prompt in the strip area
- [x] 30-day mini heat map preview: small aggregate heat map (last 30 days) at bottom of habits section
  - [x] Links to full heat map on Habits page when tapped
- [x] Loading/placeholder states for all sections when data is unavailable (completes old 4.1.3 task)
- [x] Verify the dashboard feels habits-first, WHOOP-supplementary, action-oriented

### 4.4: Heat Map Component
> **Depends on:** 4.3 | **Reusable component** — used by Dashboard (30-day preview) and Habits page (full 12-month)

- [x] Create `HabitHeatMapView.swift` — configurable grid component
  - [x] Full mode: 52×7 grid (weeks × days), trailing 12 months
  - [x] Compact mode: ~4×7 grid, trailing 30 days (for dashboard preview)
  - [x] Mode set via init parameter, same component for both
- [x] Create `HeatMapCell.swift` — rounded rect, color intensity from completion percentage (integrated into Canvas rendering, no separate file needed)
  - [x] 0%: dark/empty (#1C1C1E)
  - [x] 1-33%: dim cyan
  - [x] 34-66%: medium cyan
  - [x] 67-99%: bright cyan
  - [x] 100%: full glow with subtle pulse
- [x] Use `Canvas` for rendering performance (365+ cells must render at 60fps)
- [x] **Aggregate mode** (default): shows overall daily completion % across all habits
- [x] **Per-habit filter mode**: `HeatMapDataBuilder.buildForHabit()` — ready for Habits page (Phase 5.2) to add dropdown
- [x] Hover interaction:
  - [x] Tooltip slides in showing: date, habits completed that day, completion percentage
  - [x] Cell glow intensifies on hover
- [x] Legend bar showing color intensity scale (0% → 100%) with HUD styling
- [x] Wire to `@Query` on `HabitEntry` data, computed by `DashboardViewModel` or `HabitsViewModel`
- [x] Verify performance: smooth scrolling/hover with 365 days of sample data

### 4.5: Quick Input Field
> **Depends on:** 4.3 (dashboard layout has the input section)

- [x] Create `QuickInputView.swift` — SF Mono font, ">" prompt character, blinking cursor animation
- [x] Placeholder text: `"Log a habit... (e.g., 'Drank 3L water')"`
- [x] HUD-styled text field: dark background, cyan border on focus, glow pulse when active
- [x] On submit: route to `NaturalLanguageParser` (stub returning hardcoded `ParsedHabit` for now)
- [x] Wire successful parse → create `HabitEntry` in SwiftData
- [x] Success feedback: **Glow Pulse** (cyan) sweeps across field + **Particle Scatter** from submit point + confirmation text **Materialize**s ("✓ LOGGED: {habit name}"), auto-dismiss after 1.5s
- [x] Error feedback: **Glow Pulse** (red) on input field + horizontal shake (3pt, 0.3s) + "UNRECOGNIZED INPUT" label **Materialize**s below in red
- [x] Input history: up/down arrow cycles through previous entries (store last 20 in UserDefaults)
- [x] Verify full loop: type → parse → save → habit toggle updates + heat map reflects new entry

---

## Phase 5 — Habits Deep-Dive Page

> **Design context:** The Habits page is the single source of truth for all habit data. Full CRUD management, individual heat maps, scrollable journal timeline, and per-habit trend charts. This is where you go to understand your habits deeply — the Dashboard is for quick daily action, the Habits page is for review and configuration.

### 5.1: Habit Management ✅
> **Depends on:** 4.2 (navigation shell routes to Habits page)

- [x] Create `HabitsViewModel.swift` — `@Observable @MainActor`, owns all habit CRUD + computed stats
  - [x] `habits: [HabitItem]` — all tracked habits from SwiftData (as display structs)
  - [x] `selectedHabit: HabitItem?` — currently selected for detail view
  - [x] `addHabit(name:emoji:category:targetFrequency:isQuantitative:unitLabel:)` method
  - [x] `updateHabit(_:)` method
  - [x] `deleteHabit(_:)` method with entry cascade
  - [x] `reorderHabits(_:)` / `moveHabit(from:toPositionOf:)` / `commitReorder(in:)` methods
  - [x] `calculateCurrentStreak()` and `calculateLongestStreak()` methods
  - [x] Category filtering with `selectedCategory` + `filteredHabits` computed property
- [x] Extended `Habit` model with `sortOrder: Int`, `isQuantitative: Bool`, `unitLabel: String`
- [x] Create `HabitsView.swift` — main habits page routed from sidebar
  - [x] Master-detail layout: habit list (left ~40%) + selected habit detail (right ~60%)
  - [x] Header with page title, habit count, NEW OP button
- [x] Habit list items: emoji + name + category badge + current streak (🔥) + weekly completion rate bar
- [x] Add Habit sheet: HUD-styled form (`HabitFormSheet`)
  - [x] Name field (DESIGNATION)
  - [x] Emoji field (ICON)
  - [x] Category chips (General, Health, Fitness, Mindfulness, Productivity, Social, Financial, Educational, Religious)
  - [x] Target frequency picker (Daily / X per week with +/- controls)
  - [x] Unit type (Toggle ○/● / Quantity 123 with unit label field)
  - [x] ACTIVATE / CANCEL buttons (UPDATE for edit mode)
- [x] Edit Habit: same `HabitFormSheet` in edit mode, pre-populated, triggered by context menu
- [x] Delete Habit: confirmation alert ("DECOMMISSION OPERATION?"), cascade deletes all entries
- [x] Reorder habits via drag-and-drop (drag handle + `DropDelegate` reorder)
- [x] Category filtering: scrollable chip bar (ALL + per-category) at top
- [x] Empty state: "NO ACTIVE OPERATIONS — Establish first operation"
- [x] Detail panel: basic stats grid (streak, longest, total, rates, frequency) + Phase 5.2 placeholder
- [x] Updated `DashboardViewModel` to sort habits by `sortOrder` then `name`
- [x] Verify build + 30/30 tests pass

### 5.2: Per-Habit Heat Maps & Stats ✅
> **Depends on:** 5.1, 4.4 (heat map component built)

- [x] Habit detail panel (when a habit is selected or row is expanded):
  - [x] Individual heat map using `HabitHeatMapView` in per-habit mode (full 12-month view)
  - [x] Stats card showing:
    - [x] Current streak (consecutive days/occurrences)
    - [x] Longest streak (all time)
    - [x] Total completions
    - [x] Weekly completion rate (last 7 days)
    - [x] Monthly completion rate (last 30 days)
    - [x] All-time completion rate
- [x] Streak milestone celebrations: HUD-style glow burst animation at 7-day, 30-day, 100-day, 365-day milestones
- [x] Stats displayed as `MetricTile` components for visual consistency

### 5.3: Journal Timeline ✅
> **Depends on:** 5.1

- [x] Create `JournalTimelineView.swift` — scrollable timeline of all `HabitEntry` logs
  - [x] Newest entries first
  - [x] Each entry row: timestamp + habit emoji + habit name + value/notes if present
  - [x] HUD-styled vertical timeline line connecting entries (thin cyan line with node dots at each entry)
- [x] Filters:
  - [x] By habit (cycle-through chip filter on all tracked habits)
  - [x] By date range (preset: today, last 7 days, last 30 days, all)
  - [x] By category (cycle-through chip filter on all categories)
- [x] Tap entry to edit: inline expand with value/notes fields + save/delete buttons
- [x] Delete entry: delete button with "PURGE ENTRY?" confirmation alert
- [x] Lazy loading for performance with large datasets (LazyVStack)
- [x] Created `JournalTimelineViewModel.swift` — separate ViewModel for journal state (avoids 5.2 conflict)
- [x] Integrated into HabitsView as collapsible "FIELD LOG" section below master-detail
- [x] Verify build + 30/30 tests pass

### 5.3.1: Habit UX Improvements — Edit Access, Icon Picker, Goal-Relative Rates ✅
> **Depends on:** 5.1 | **Priority: HIGH — quality-of-life fixes before building more features on top**

- [x] **Edit button in detail panel:** Add a prominent "EDIT OPERATION" button to the `HabitDetailPanel` header (right side of Habits page) so users don't need to discover the context menu
  - [x] HUD-styled button (pencil icon + label), positioned in the detail header next to the habit name
  - [x] Opens the same `HabitFormSheet` in `.edit` mode
  - [x] Requires surfacing `activeSheet` state or an edit callback from the detail panel
- [x] **Pre-populated icon picker:** Replace the free-text "ICON" emoji field in `HabitFormSheet` with a scrollable grid of curated icons
  - [x] Curated set of ~40-50 common habit icons organized by category (fitness, health, productivity, mindfulness, etc.)
  - [x] Grid layout with tappable cells — selected icon gets cyan highlight + glow
  - [x] Still allow custom emoji entry via a "CUSTOM" option or text field at the end
  - [x] Icons display at ~28pt in the grid, selected icon previewed larger in the form header
  - [x] HUD-styled grid cells (HUDFrameShape, surface background, cyan selection border)
- [x] **Goal-relative rate calculations:** Update completion rate math to factor in `targetFrequency`
  - [x] Weekly rate: completed days in last 7 / `min(targetFrequency, 7)` instead of raw `/7`
  - [x] Monthly rate: completed days in last 30 / `(targetFrequency * 30/7)` — proportional to weekly target
  - [x] Update in both `HabitsViewModel` and `DashboardViewModel` (both compute rates)
  - [x] Detail panel: add "ON TRACK" / "BEHIND" indicator comparing current rate to target
  - [x] Color-code relative to goal: green (≥100% of target), amber (50-99%), red (<50%)
- [x] Verify build + all existing tests pass

### 5.4: Per-Habit Trend Charts
> **Depends on:** 5.2

- [x] Create `HabitTrendChartView.swift` using SwiftUI Charts
  - [x] For boolean habits: line chart of completion rate over time (7-day rolling average)
  - [x] For quantity habits: line chart of actual values over time (e.g., water intake in liters)
- [x] WHOOP correlation overlay: option to overlay recovery score on the same chart
  - [x] Dual Y-axis: habit metric (left) + recovery % (right)
  - [x] Visual correlation — do good habit weeks align with high recovery?
- [x] Date range selector: 1 week / 1 month / 3 months / 1 year
- [x] HUD chart styling: cyan line, dark background, subtle grid lines, glow on data points
- [x] Animated transitions when switching date ranges (spring animation on data points)
- [x] Empty state: "INSUFFICIENT DATA — Log more entries to see trends" (minimum 7 data points)

---

## Phase 6 — Natural Language Parsing

> **Design context:** The quick input field on the Dashboard routes text through a parser. Local regex-based parsing handles common patterns instantly. Gemini is a fallback for ambiguous or complex inputs. The goal: type naturally, habits get logged automatically.

### 6.1: ParsedHabit & Local Parser ✅
> **Depends on:** 4.5 (quick input wired with stub)

- [x] Define `ParsedHabit` struct:
  - [x] `habitName: String` — matched or inferred habit name
  - [x] `value: Double?` — numeric value if present (e.g., 3.0 for "3L water")
  - [x] `unit: String?` — unit label if present (e.g., "L", "hours", "min")
  - [x] `confidence: Double` — 0.0 to 1.0, how sure the parser is
  - [x] `rawInput: String` — original user text
  - [x] `matchedHabitID: UUID?` — reference to existing habit if fuzzy-matched (lightweight ID instead of SwiftData model ref)
- [x] Create `NaturalLanguageParser.swift` — `Sendable` class (decoupled from SwiftData; takes `[HabitReference]` for fuzzy matching)
  - [x] `func parse(_ input: String, habits:) async -> ParsedHabit` — main entry point (Gemini fallback placeholder for 6.2)
  - [x] `func parseLocally(_ input: String, habits:) -> ParsedHabit?` — regex-based, synchronous
- [x] Implement quantity patterns:
  - [x] "Drank 3L water" → water, 3.0, "L"
  - [x] "Slept 8 hours" → sleep, 8.0, "hours"
  - [x] "Meditated 20 min" → meditation, 20.0, "min"
  - [x] "Ran 5k" → running, 5.0, "km"
  - [x] Handle decimal values: "Drank 2.5L water"
- [x] Implement boolean patterns:
  - [x] "Worked out" → exercise, completed = true
  - [x] "No alcohol" → alcohol, completed = true (inverted habit)
  - [x] "Skipped sugar" → sugar, completed = true (inverted habit)
  - [x] "Did yoga" → yoga, completed = true
- [x] Implement fuzzy matching against existing `Habit.name` values in SwiftData
  - [x] Case-insensitive contains match
  - [x] Common abbreviation handling (e.g., "med" → "Meditation")
- [x] Write unit tests for all regex patterns + edge cases (empty string, numbers only, emoji only)
- [x] Wire `NaturalLanguageParser` into `QuickInputView` — replaces stub parser, routes values through `confirmHabitEntry`
- [x] Verify build + 70/70 tests pass (38 new parser tests + 32 existing)

### 6.2: Gemini Parsing Fallback
> **Depends on:** 6.1

- [x] Create `GeminiService.swift` actor — centralizes all Gemini API communication
  - [x] Init with API key from EnvironmentConfig (.env file → bundle → Keychain fallback)
  - [x] Manages `GenerativeModel` instance (gemini-2.0-flash)
  - [x] Rate limiting / request queuing (actor serialization)
- [x] Add `parseHabit(_ input: String, existingHabits: [String]) async throws -> GeminiParsedResponse`
  - [x] Prompt includes list of user's existing habit names for context
  - [x] Response format: structured JSON matching `GeminiParsedResponse` fields
- [x] Implement hybrid logic in `NaturalLanguageParser.parse()`:
  - [x] Step 1: Try local parser (return if confidence >= 0.7)
  - [x] Step 2: Check cache for previous Gemini result
  - [x] Step 3: If local confidence < 0.7, call Gemini
  - [x] Step 4: If Gemini also fails, return low-confidence result with "UNRECOGNIZED" flag
- [x] Cache Gemini mappings: store `rawInput → ParsedHabit` in UserDefaults for repeat inputs
  - [x] Cache TTL: 30 days
  - [x] Avoid redundant API calls for the same phrasing
- [x] Wire async `NaturalLanguageParser.parse()` into `QuickInputView` (replaces sync `parseLocally`)
  - [x] Added `isParsing` loading state with "ANALYZING INPUT..." prompt
- [x] Created `EnvironmentConfig.swift` — reads API key from .env file bundled at build time
  - [x] Post-build script copies project root `.env` into app bundle as `env.local`
  - [x] Priority: ProcessInfo env → bundled .env → Keychain fallback
  - [x] Updated Settings UI to show key source (ENV FILE / KEYCHAIN / NOT CONFIGURED)
- [x] Write integration tests with mock Gemini response (GeminiParsedResponse decoding)
- [x] Test edge cases: gibberish input, emoji-only, very long input, empty input
- [x] Verify build + all tests pass (existing + 21 new)

---

## Phase 6.5 — AI-Powered Journal

> **Design context:** The Journal is a dedicated section for freeform writing about the user's day, thoughts, and feelings. Each entry is automatically scored for sentiment using Apple's NaturalLanguage framework (NLTagger — offline, instant, free). Monthly linear regression analysis correlates habit completion with sentiment to identify which habits most impact wellbeing. Gemini generates a narrative interpretation of results. This is where data becomes self-knowledge.
>
> **Key decisions:** Linear regression (not logistic) on continuous sentiment (-1.0 to 1.0) via Accelerate/LAPACK. NLTagger for per-entry scoring, Gemini for monthly narrative only. New 6th sidebar item. All data in SwiftData.

### 6.5.1: Model Layer — JournalEntry Extension & MonthlyAnalysis
> **Depends on:** 2.1.2 (JournalEntry exists)

- [x] Extend `JournalEntry.swift` with new properties (all with defaults for lightweight migration):
  - [x] `sentimentScore: Double` (default 0.0) — range -1.0 to 1.0
  - [x] `sentimentLabel: String` (default "neutral") — "positive", "negative", "neutral"
  - [x] `sentimentMagnitude: Double` (default 0.0) — abs(sentimentScore)
  - [x] `title: String` (default "") — optional short title for the entry
  - [x] `wordCount: Int` (default 0) — cached for display
  - [x] `tags: [String]` (default []) — user-applied tags
  - [x] `updatedAt: Date` (default .now) — last edit timestamp
- [x] Create `MonthlyAnalysis.swift` — SwiftData `@Model`:
  - [x] `id: UUID`, `month: Int`, `year: Int`, `startDate: Date`, `endDate: Date`
  - [x] `habitCoefficients: [HabitCoefficient]` (Codable array via Transformable)
  - [x] `forceMultiplierHabit: String` — habit with highest positive coefficient
  - [x] `modelR2: Double` — R-squared goodness of fit
  - [x] `averageSentiment: Double`, `entryCount: Int`, `summary: String`, `generatedAt: Date`
- [x] Create `HabitCoefficient` Codable struct: `habitName`, `habitEmoji`, `coefficient`, `pValue`, `completionRate`, `direction`
- [x] Register `MonthlyAnalysis` in `OverwatchApp.swift` ModelContainer
- [x] Write unit tests: model creation, defaults, HabitCoefficient Codable round-trip

### 6.5.2: SentimentAnalysisService
> **Depends on:** 6.5.1 | **Parallel with:** 6.5.3, 6.5.5

- [x] Create `SentimentAnalysisService.swift` — `actor` using Apple `NaturalLanguage` framework
- [x] Implement `analyzeSentiment(_ text: String) -> SentimentResult` using `NLTagger` with `.sentimentScore` scheme
  - [x] Score: -1.0 to 1.0 | Label: > 0.1 = positive, < -0.1 = negative, else neutral | Magnitude: abs(score)
- [x] Create `SentimentResult` struct (Sendable): `score`, `label`, `magnitude`
- [x] Handle edge cases: empty text → neutral, short text (< 10 chars) → neutral with magnitude 0
- [x] Write unit tests: known positive phrases, known negative, neutral, empty string, emoji-only, multi-paragraph

### 6.5.3: RegressionService
> **Depends on:** 6.5.1 | **Parallel with:** 6.5.2, 6.5.5

- [x] Create `RegressionService.swift` — `final class RegressionService: Sendable` using `import Accelerate`
- [x] Define `RegressionInput` struct: `habitNames`, `habitEmojis`, `featureMatrix` ([days × habits]), `targetVector` ([days])
- [x] Define `RegressionOutput` struct: `coefficients: [HabitCoefficient]`, `r2: Double`, `intercept: Double`
- [x] Implement `computeRegression(_ input:) -> RegressionOutput?` via normal equation (X'X)^(-1)X'y with Gaussian elimination
  - [x] Compute R-squared from residuals / total sum of squares
  - [x] Compute t-statistics and approximate p-values per coefficient
  - [x] Guard: return nil if < 14 observations or < 2 habits with variance
- [x] Write unit tests: synthetic data with known correlations, insufficient data → nil, zero variance, single habit

### 6.5.4: GeminiService Extension — Regression Narrative
> **Depends on:** 6.5.3, 6.2 (GeminiService exists)

- [x] Add `interpretRegressionResults(coefficients:averageSentiment:monthName:entryCount:) async throws -> String` to `GeminiService`
- [x] Build prompt with performance coach persona: encouraging, data-driven, actionable
- [x] Output: 2-3 paragraph narrative summarizing wellbeing drivers + force multiplier callout + recommendation
- [x] Graceful fallback when Gemini unavailable: template-based summary from coefficients alone
- [ ] Write tests with mock Gemini response

### 6.5.5: Navigation Update — Journal Sidebar
> **Depends on:** 4.2 (NavigationShell) | **Parallel with:** 6.5.2, 6.5.3

- [x] Add `.journal` case to `NavigationSection` enum between `.habits` and `.warRoom`
- [x] Icon: `"book.pages"`, label: `"Journal"`
- [x] Add case to `detailContent(for:)` switch → render `JournalView`
- [x] Verify sidebar renders correctly with 6 items

### 6.5.6: JournalViewModel
> **Depends on:** 6.5.2, 6.5.3

- [x] Create `JournalViewModel.swift` — `@Observable @MainActor`, inject `SentimentAnalysisService` + `RegressionService` via init
- [x] Display types: `JournalItem` (id, date, title, contentPreview, wordCount, sentimentScore, sentimentLabel, tags, createdAt), `SentimentDataPoint` (date, score), `MonthlyAnalysisItem`
- [x] State: entries, selectedEntryID, editorContent/Title/Tags, isEditing, editingEntryID, currentSentiment, sentimentTrend, filters, latestAnalysis, isGeneratingAnalysis
- [x] Implement `loadEntries(from:)`, `saveEntry(in:)` async (with sentiment analysis), `deleteEntry`, `selectEntry`, `startNewEntry`
- [x] Implement `analyzeSentimentLive()` async — debounced 1s for live indicator
- [x] Implement `loadSentimentTrend(from:)` — build SentimentDataPoint array
- [x] Implement `generateMonthlyAnalysis(for:from:)` async — build regression input, call services, save MonthlyAnalysis
- [x] Implement `sentimentDataForReport(startDate:endDate:from:)` — packages data for Phase 7.2 integration
- [x] Filter/search logic
- [ ] Write unit tests: entry CRUD, sentiment integration, filter logic, monthly analysis flow

### 6.5.7: Journal UI — Entry List & Editor
> **Depends on:** 6.5.5, 6.5.6

- [x] Create `Views/Journal/` directory
- [x] Create `JournalView.swift` — master-detail layout matching `HabitsView` pattern
  - [x] Left panel (~40%): scrollable entry list with `TacticalCard`-styled rows (date, title, sentiment dot, word count, preview)
  - [x] Search field at top (HUD-styled), filter chips (7D / 30D / 90D / ALL, sentiment ALL / + / - / ~)
  - [x] Right panel (~60%): title field + `TextEditor` + tag input + live sentiment badge + SAVE / CANCEL
  - [x] "NEW ENTRY" button in header
  - [x] Empty state: "BEGIN YOUR FIELD LOG — Record thoughts, reflections, and daily observations"
  - [x] Entry deletion with "PURGE ENTRY?" confirmation
  - [x] Materialize/Dissolve animation patterns

### 6.5.8: Sentiment Visualization Components
> **Depends on:** 6.5.7

- [x] Create `SentimentIndicator.swift` — `SentimentDot` (6pt, color-coded, glow) + `SentimentBadge` (score + arrow + label)
- [x] Create `SentimentTrendChart.swift` — SwiftUI Charts line chart (following `HabitTrendChartView` pattern)
  - [x] X: dates, Y: sentiment score (-1.0 to 1.0)
  - [x] Green zone above 0, red zone below 0 (gradient area fill), neutral baseline
  - [x] HUD chart styling, animated transitions on date range switch
- [x] Integrate trend chart into JournalView right panel below editor

### 6.5.9: Monthly Analysis UI ✅
> **Depends on:** 6.5.8, 6.5.4

- [x] Create `MonthlyAnalysisView.swift` — collapsible "MONTHLY INTELLIGENCE" section in JournalView
  - [x] Gemini narrative summary at top (or template fallback)
  - [x] Force multiplier habit highlighted with accent glow + emoji
  - [x] Horizontal bar chart of habit coefficients (green right for positive, red left for negative, sorted by |coefficient|)
  - [x] Model quality indicators: R², entry count, average sentiment
  - [x] "GENERATE ANALYSIS" / "REGENERATE" button
  - [x] Loading: "COMPUTING REGRESSION..." | Insufficient data: "NEED MORE DATA — Log at least 14 entries"
  - [x] Month selector for historical viewing
- [x] Auto-trigger on first app open after month end (if >= 14 entries for prior month)

### 6.5.10: Dashboard Integration — Sentiment Pulse ✅
> **Depends on:** 6.5.8

- [x] Add compact "SENTIMENT PULSE" `TacticalCard` to `TacticalDashboardView` (below WHOOP strip)
  - [x] Today's sentiment dot + 7-day sparkline + "JOURNAL" link
  - [x] Tap navigates to Journal page
  - [x] No entries: dimmed "NO ENTRIES TODAY"
- [x] Add `sentimentPulse` computed property to `DashboardViewModel`

### 6.5.10a: Sentiment Engine Upgrade — Gemini Replacement ✅
> **Depends on:** 6.5.2, 6.2 (GeminiService exists) | **Priority: HIGH — NLTagger fails on negation/context**

**Rationale:** NLTagger scores "Today has not been that bad" as -0.60 NEGATIVE. It's a bag-of-words scorer with no understanding of negation, sarcasm, or contextual nuance. Gemini replaces it for save-time scoring. The live typing indicator is removed entirely — it biases writing.

- [x] **GeminiService: Add `analyzeSentiment` method**
  - [x] RISEN-structured prompt: role (sentiment analyst), instructions (score text -1.0 to 1.0), steps (read title + content, assess tone accounting for negation/sarcasm/context, score), expectations (JSON with `score` and `label`), narrowing (no invented context, only analyze provided text)
  - [x] Send both title and content together for full context
  - [x] Parse JSON response into `SentimentResult` (reuse existing struct)
  - [x] Handle Gemini errors gracefully — return nil to trigger fallback
- [x] **JournalViewModel: Replace save-time scoring**
  - [x] Inject `GeminiService?` as optional dependency (nil when no API key)
  - [x] In `saveEntry()`: call Gemini first, fall back to NLTagger if Gemini unavailable/fails
  - [x] Remove `analyzeSentimentLive()` method and `sentimentDebounceTask`
  - [x] Remove `currentSentiment` state property
- [x] **JournalView: Remove live sentiment indicator**
  - [x] Remove `liveSentimentBadge` from active editor header row
  - [x] Remove `.onChange(of: editorContent)` that triggers live analysis
  - [x] Keep sentiment display on saved entries (read-only detail view, entry list dots)
- [x] `SentimentAnalysisService` retained as offline/fallback — not deleted
- [x] Verify build + all 118 tests pass

### 6.5.11: Synthetic Dataset & NLP Pipeline Testing
> **Depends on:** 6.5.6, 6.5.3, 6.5.2

- [x] Create `SyntheticDataSeeder.swift` — utility for generating controlled test data
  - [x] `static func seedJournalAndHabits(in context: ModelContext, days: Int = 60)`
  - [x] 5 habits with designed correlations:
    - Meditation: 95% on happy days, 10% on unhappy → strong positive coefficient
    - Exercise: 60% on happy days, 35% on unhappy → moderate positive coefficient
    - Alcohol: 10% on happy days, 85% on unhappy → strong negative coefficient
    - Reading: random 50/50 → near-zero coefficient (noise)
    - Water: completed every day → excluded (no variance)
  - [x] 60 journal entries (1/day): ~30 positive, ~20 negative, ~10 neutral
  - [x] Snippet banks: 12 positive, 12 negative, 10 neutral (2-4 sentences each)
  - [x] Dates spread across 2 calendar months (Dec 2025 – Jan 2026)
- [x] Create `SyntheticDataTests.swift` — Swift Testing (`@Test`, `#expect`, in-memory ModelContainer):
  - [x] Test: sentiment scoring accuracy — positive entries > 0, negative < 0, neutral near 0
  - [x] Test: regression coefficient directions — Meditation +, Exercise +, Alcohol -, Reading ~0, Water excluded
  - [x] Test: R-squared > 0 (model has explanatory power)
  - [x] Test: force multiplier identification → "Meditation"
  - [x] Test: minimum data guard — 5 days → returns nil
  - [x] Test: end-to-end pipeline — seed → analyze → regress → MonthlyAnalysis saved with valid coefficients
  - [x] Test: sentiment trend data — correct count and scores (125 total tests passing)
- [x] Optional: `#if DEBUG` "SEED DEMO DATA" button in Settings for visual verification

### 6.5.14: Regression Pipeline Improvements
> **Depends on:** 6.5.11 | **Priority:** Quality improvement, not blocking

- [ ] **Rolling mean on target vector** — smooth daily sentiment with a 3-day (or configurable) window before regression to capture lagged habit effects (e.g., exercise → better sleep → better mood next day). Reduces NLTagger noise and picks up cumulative/delayed impacts.
  - [ ] Apply rolling mean to `targetVector` in `JournalViewModel.generateMonthlyAnalysis` before building `RegressionInput`
  - [ ] Decide window size: 3-day SMA recommended as default; consider EMA (exponential) for decay-weighted variant
  - [ ] Handle edges: first N-1 days get partial windows (or are excluded)
  - [ ] Update `SyntheticDataTests` to verify rolling-mean pipeline still produces correct coefficient directions
- [ ] **Exclude days with no habit data** — if a journal entry (y) exists but no habit entries (x's) were logged that day, drop the row from the regression. "Didn't log" ≠ "didn't do." Treating missing habits as zeros biases coefficients.
  - [ ] In `generateMonthlyAnalysis`, skip days where zero `HabitEntry` records exist (not just zero completions — zero records)
  - [ ] Update entry count / valid-day count accordingly
  - [ ] Add a `SyntheticDataTests` case: seed days with journal entries but no habit entries → verify they're excluded from regression input
- [ ] Optional future: lagged predictors (habit completion at t-1, t-2 as additional features) for modeling decay curves

### 6.5.12: War Room Integration — Sentiment Charts
> **Depends on:** 6.5.8, 6.5.11 | **Integrates with:** Phase 7 (War Room build)

- [x] Create `SentimentTrendChart.swift` (full version for War Room) — or extend 6.5.8 version:
  - [x] Daily sentiment scatter dots (colored green/red)
  - [x] 7-day rolling average as smoothed cyan line with glow
  - [x] Toggleable habit completion overlay: vertical bars showing daily completion count (stacked by category, semi-transparent)
  - [x] Date range selector: 1W / 1M / 3M / 1Y / ALL
  - [x] Neutral baseline at 0.0
- [x] Create `SentimentGauge.swift` — reuse existing `ArcGauge` component
  - [x] Range: -1.0 (red) to +1.0 (green) with amber middle
  - [x] Period toggle: WEEK / MONTH
  - [x] Label: "WELLBEING INDEX"
- [x] Wire into JournalView as preview; ready for War Room when Phase 7 builds `WarRoomView`

### 6.5.13: Reports Integration — Sentiment in Weekly Briefings
> **Depends on:** 6.5.9 | **Integrates with:** Phase 7.2 (Report Generation)

- [x] Add `sentimentDataForReport(startDate:endDate:from:)` to `JournalViewModel`
  - [x] Packages: weekly avg sentiment, trend direction (improving/declining/stable), force multiplier habit
  - [x] Leave Phase 7.2 integration as clearly marked TODO
- [x] When Phase 7.2 is built: include sentiment in `IntelligenceManager.generateWeeklyReport()` data payload

---

## Phase 7 — Intelligence Layer & War Room

> **Design context:** AI persona is a **performance coach** — encouraging, data-driven, motivational + actionable. Names specific habits, gives concrete recommendations, celebrates wins. Reports auto-generate weekly AND can be triggered on-demand for any date range. Reports now include **sentiment analysis data** from Phase 6.5 (journal entries scored by Gemini at save time, NLTagger as offline fallback, monthly regression results).
>
> The War Room is a **split-pane** layout: AI briefing panel (left) + interactive charts (right). Both visible simultaneously, cross-linked so insights reference chart data. **Sentiment charts** (time series + wellbeing gauge) from Phase 6.5.12 are integrated as chart type options.
>
> **All Gemini prompts must follow the RISEN framework with XML tags** (see CLAUDE.md — Gemini Prompting Standard). No freeform prompt strings.

### 7.1: Intelligence Manager & Persona
> **Depends on:** 6.2 (Gemini service exists), 6.5.1 (JournalEntry sentiment fields + MonthlyAnalysis model)

- [x] Create `IntelligenceManager.swift` — uses `GeminiService`, owns all report generation logic
- [x] Define performance coach persona prompt using **RISEN/XML structure** (per CLAUDE.md):
  - [x] `<role>`: Performance coach — encouraging but honest, data-driven, actionable
  - [x] `<instructions>`: Analyze habit, biometric, and sentiment data. Produce narrative + recommendations.
  - [x] `<steps>`: 1) Review habit completion rates, 2) Correlate with WHOOP recovery, 3) Factor in journal sentiment trends, 4) Identify force multiplier, 5) Generate recommendations
  - [x] `<expectations>`: 2-3 paragraph narrative, reference specific numbers, end with actionable items
  - [x] `<narrowing>`: No medical advice, no invented data, only reference habits/metrics in input
  - [x] Example tone: "Strong week overall. Your hydration consistency (6/7 days) is clearly paying off — recovery averaged 71%, up from 63% last week. Your journal sentiment tracked positive (+0.42 avg), aligning with your meditation streak. One area to watch: sleep duration dropped below 7h three nights. Try setting a 10pm wind-down alarm."
- [x] Define `WeeklyInsight` SwiftData `@Model`:
  - [x] `id: UUID`
  - [x] `dateRangeStart: Date`, `dateRangeEnd: Date`
  - [x] `summary: String` — 2-3 paragraph narrative overview
  - [x] `forceMultiplierHabit: String` — the habit with highest positive correlation to recovery AND/OR sentiment
  - [x] `recommendations: [String]` — 3-5 actionable items
  - [x] `correlations: [HabitCoefficient]` — **reuse `HabitCoefficient` from Phase 6.5.1** (not a new struct)
  - [x] `averageSentiment: Double?` — weekly average sentiment score (nil if no journal entries)
  - [x] `sentimentTrend: String?` — "improving", "declining", "stable" (nil if no entries)
  - [x] `generatedAt: Date`
- [x] Register `WeeklyInsight` in `OverwatchApp.swift` ModelContainer

### 7.2: Weekly Report Generation
> **Depends on:** 7.1, 6.5.13 (sentiment data packaging method)

- [x] Implement `generateWeeklyReport(startDate:endDate:) async throws -> WeeklyInsight`
  - [x] Query SwiftData for all `HabitEntry` records in date range
  - [x] Query SwiftData for all `WhoopCycle` records in date range
  - [x] Query SwiftData for all `JournalEntry` records in date range — extract sentiment scores
  - [x] Compute sentiment data inline (avg, trend) — replaces JournalViewModel dependency for cleaner architecture
  - [x] Include latest `MonthlyAnalysis` force multiplier if available for the period
  - [x] Package all data as **XML-tagged sections** per RISEN standard:
    - [x] `<habit_completions>` — daily habit completion matrix
    - [x] `<whoop_metrics>` — daily recovery, sleep, strain, HRV
    - [x] `<sentiment_data>` — daily sentiment scores, weekly average, trend direction
    - [x] `<monthly_regression>` — force multiplier habit + top coefficients (if available)
    - [x] `<habit_metadata>` — habit names, emojis, categories, target frequencies
  - [x] Send to Gemini with RISEN-structured prompt + request structured response in `<weekly_report>` tag
  - [x] Parse Gemini response into `WeeklyInsight` fields
- [x] Save `WeeklyInsight` to SwiftData for offline viewing and historical archive
- [x] **Auto-generate scheduling:**
  - [x] Configurable day of week (default: Sunday) stored in Settings
  - [x] Configurable time (default: 8:00 AM local)
  - [x] Uses app lifecycle hook — `checkAutoGenerate()` runs on next app open after scheduled time
  - [x] Skip if already generated for this week
- [x] **On-demand generation:**
  - [x] `generateWeeklyReport()` accepts custom date range (UI triggers in Phase 7.3/7.4)
  - [x] Custom date range picker (start date + end date) — API surface ready
  - [x] Loading state while Gemini processes ("COMPILING INTELLIGENCE BRIEFING..." via `generationProgress`)
- [x] Write tests with mock Gemini responses (test parsing, caching, dedup)
- [x] Test offline retrieval of previously cached reports
- [x] Test report generation with and without journal data (sentiment fields nil-safe)

### 7.3: Reports Page (Intel Briefings Archive)
> **Depends on:** 7.2, 4.2 (navigation shell)

- [x] Create `ReportsViewModel.swift` — `@Observable @MainActor`, owns report list + generation triggers
- [x] Create `ReportsView.swift` — routed from sidebar "Reports" section
  - [x] Header: "INTEL BRIEFINGS" with HUD styling
  - [x] "GENERATE REPORT" button (prominent, top-right) — triggers on-demand generation with date range picker
  - [x] Scrollable list of past reports, newest first
  - [x] Each report card (`TacticalCard` styled):
    - [x] Date range label (e.g., "FEB 10 — FEB 16, 2026")
    - [x] Summary preview (first 2 lines of summary, truncated)
    - [x] Force multiplier habit badge (highlighted in accent color)
    - [x] Generated timestamp
- [x] Tap report card → expand to full detail view:
  - [x] Full summary text
  - [x] Force multiplier habit section with explanation
  - [x] Recommendations list (numbered, each actionable)
  - [x] Correlations list using `HabitCoefficient` display (habit name + emoji + direction + strength bar)
  - [x] Sentiment summary section: weekly avg sentiment badge + trend arrow (if journal data exists)
- [x] Empty state: "NO BRIEFINGS YET — Your first intel report generates after one week of tracking data."
- [x] Loading state for in-progress generation: animated HUD progress indicator

### 7.4: War Room — Split Pane Analytics
> **Depends on:** 7.2 (needs report data), 5.4 (trend chart patterns), 6.5.12 (sentiment chart components)

- [x] Create `WarRoomViewModel.swift` — `@Observable @MainActor`, owns chart data + AI insight state
  - [x] `selectedDateRange: DateRange` (1 week / 1 month / 3 months / 1 year / all time)
  - [x] `latestInsight: WeeklyInsight?` — most recent report
  - [x] `sentimentTrend: [SentimentDataPoint]` — from JournalEntry queries for sentiment chart
  - [x] `averageSentiment: Double` — for wellbeing gauge (week/month toggleable)
  - [x] `habitCompletionOverlay: [DailyHabitCompletion]` — for sentiment chart overlay bars
  - [x] Computed chart data arrays from SwiftData queries
- [x] Create `WarRoomView.swift` — routed from sidebar "War Room" section
  - [x] **Split pane layout:** AI briefing (left, ~40% width) + charts (right, ~60% width)
  - [x] Resizable divider between panes (drag to adjust ratio)
  - [x] Full HUD treatment: scan line overlay, grid backdrop, glow effects
- [x] **Left pane — AI Briefing Panel:**
  - [x] Latest weekly insight displayed as scrollable narrative
  - [x] Force multiplier habit highlighted with accent glow
  - [x] **Wellbeing gauge** (from 6.5.12 `SentimentGauge`) — ArcGauge showing avg sentiment for period
  - [x] Recommendations as numbered list with checkbox-style items
  - [x] "REFRESH ANALYSIS" button to regenerate
  - [x] If no insight available: "AWAITING INTELLIGENCE DATA" placeholder
- [x] **Right pane — Interactive Charts:**
  - [x] Charts built inline in `WarRoomView.swift` (no separate TrendChartView — keeps it self-contained):
    - [x] **Line chart:** recovery score over time (green/amber/red zones)
    - [x] **Bar chart:** daily habit completion count (stacked by category)
    - [x] **Scatter plot:** habit completion % (X) vs. recovery score (Y) — shows correlation
    - [x] **Area chart:** sleep metrics (SWS, REM, total hours) stacked over time
    - [x] **Sentiment time series** (from 6.5.12): daily dots + 7-day rolling avg + toggleable habit completion overlay
    - [x] **Habit-sentiment scatter**: habit completion % (X) vs. sentiment score (Y) — visualizes regression
  - [x] Chart type switcher: segmented control or tab bar above chart area (6 chart types)
  - [x] Date range selector: 1 week / 1 month / 3 months / 1 year / all time
- [ ] **Cross-linking:** tapping an insight in the left pane highlights the relevant time range / data points in the right pane chart
- [x] Chart animations: spring transitions when switching chart type or date range, data points animate in
- [x] HUD chart styling: cyan lines, glow on data points, dark axes, subtle grid, scan line overlay on chart background
- [x] Empty state: "INSUFFICIENT DATA FOR ANALYSIS — Continue tracking for deeper insights" (minimum threshold: 7 days of data)

---

## Phase 8 — Boot Sequence & Onboarding

> **Design context:** First impressions matter. A quick (2-3 second) cinematic boot sequence sets the Jarvis tone immediately. Then a guided setup gets the user operational. Subsequent launches skip straight to the app.

### 8.1: Boot Sequence ✅
> **Depends on:** 4.2 (navigation shell exists as the destination)

- [x] Create `BootSequenceView.swift` — 2-3 second cinematic intro using named animation patterns:
  - [x] **Phase 1 (0.0s):** Black void, single cursor blink (0.8s cycle)
  - [x] **Phase 2 (0.3s):** Grid lines draw across screen using **Wireframe Trace** — thin cyan lines trace horizontally and vertically from center outward, building the grid backdrop
  - [x] **Phase 3 (0.6s):** **Data Stream Texture** fades in behind text at 8% opacity (higher than normal for dramatic effect). System init text **Stagger**s in line by line (0.1s per line), each line using **Materialize** (fade + slight upward drift):
    ```
    OVERWATCH v1.0 // SYSTEM INITIALIZATION
    LOADING MODULES...
    HABIT ENGINE.......... ONLINE
    BIOMETRIC SYNC........ ONLINE
    INTELLIGENCE CORE..... ONLINE
    ```
    "ONLINE" text gets a **Glow Pulse** (green) as each subsystem activates
  - [x] **Phase 4 (1.5s):** "OVERWATCH" logo text **Materialize**s — letters appear one by one with **Wireframe Trace** outlines that fill with color, then full **Glow Bloom** expands outward (16pt → 32pt radius, 0.4s)
  - [x] **Phase 5 (2.5s):** Entire boot screen uses **Dissolve** pattern — content fades, grid fades, void transitions to NavigationShell
- [x] First launch: full 2-3 second sequence
- [x] Subsequent launches: skip entirely (direct to NavigationShell) — or 0.5s abbreviated logo flash with **Glow Pulse** only
- [x] Store `hasCompletedFirstBoot` in UserDefaults
- [x] All effects pull from the reusable components built in 4.1.5 (WireframeTrace, DataStreamTexture, AnimationPatterns)

### 8.2: Guided Setup (First Launch Only)
> **Depends on:** 8.1

- [x] After boot sequence, present `OnboardingView.swift` — only shown once (first launch)
- [x] **Step 1: Welcome**
  - [x] "WELCOME, OPERATOR" header with HUD glow
  - [x] Brief app overview: "Overwatch tracks your habits, syncs your biometrics, and delivers AI-powered performance insights."
  - [x] "BEGIN SETUP" button
- [x] **Step 2: Connect WHOOP** (optional)
  - [x] "LINK BIOMETRIC SOURCE" header
  - [x] "Connect WHOOP" button → triggers OAuth flow
  - [x] "SKIP FOR NOW" option — can connect later in Settings
  - [x] Success state: "WHOOP LINKED — Biometric data will sync automatically"
- [x] **Step 3: Add First Habits**
  - [x] "ESTABLISH OPERATIONS" header
  - [x] Pre-populated suggestions as tappable chips: 💧 Water, 🏋️ Exercise, 😴 Sleep 8h, 🧘 Meditation, 📖 Reading
  - [x] Tap to add, tap again to remove
  - [ ] "ADD CUSTOM" button → habit creation form
  - [x] At least 1 habit required to proceed (or skip)
- [x] **Step 4: Operational**
  - [x] "YOU ARE NOW OPERATIONAL" **Materialize**s with expanded **Glow Bloom** (32pt radius), **Particle Scatter** burst from center
  - [x] Hold 1s, then **Dissolve** entire onboarding → **Materialize** NavigationShell with dashboard **Stagger** entrance
- [x] Each step transition: outgoing panel uses **Dissolve** (0.2s), incoming panel uses **Materialize** (0.3s) with content **Stagger** for sub-elements. Direction: left-to-right progression feel
- [x] Store `hasCompletedOnboarding` in UserDefaults
- [x] Progress indicator: 4 dots at bottom showing current step

---

## Phase 9 — Settings & Polish

> **Design context:** Settings is a practical page — not flashy, but still HUD-themed. Error states should feel in-universe ("SIGNAL LOST" not "Error 401"). Visual polish pass ensures every view is consistent with the holographic HUD aesthetic.

### 9.1: Settings Page ✅
> **Depends on:** 4.2 (navigation shell routes to Settings)

- [x] Create `SettingsViewModel.swift` — `@Observable @MainActor`, owns all settings state + connection management
- [x] Create `SettingsView.swift` — routed from sidebar "Settings" section
- [x] **Connections section:**
  - [x] WHOOP: connection status indicator (LINKED / DISCONNECTED), connect/disconnect button, last sync timestamp
  - [x] Gemini API: key entry field (masked, stored in Keychain), "TEST CONNECTION" button with success/fail feedback
- [x] **Reports section:**
  - [x] Auto-generate: toggle on/off
  - [x] Day of week picker (default: Sunday)
  - [x] Time picker (default: 8:00 AM)
- [x] **Habits section:**
  - [x] Manage categories: list of categories, add/rename/delete custom categories
  - [x] Default habit suggestions toggle (show/hide on onboarding and add-habit sheet)
- [x] **Notifications section:**
  - [x] Daily habit reminder: toggle + time picker
  - [x] Weekly report ready: toggle
- [x] **Data section:**
  - [x] "EXPORT ALL DATA" → JSON file (habits, entries, WHOOP cycles, reports)
  - [x] "EXPORT HABITS" → CSV file (habit entries only)
  - [x] "PURGE ALL DATA" → destructive action with double-confirmation ("Are you sure?" → "Type PURGE to confirm")
- [x] **Appearance section:**
  - [x] Accent color picker (default: cyan #00D4FF, options: green, amber, red, purple, white)
- [x] All form controls HUD-styled: dark backgrounds, cyan borders, monospace labels

### 9.2: Error States & Graceful Degradation
> **Depends on:** 7.4, 9.1 (need all major views built to add error states to them)

- [x] **No WHOOP connection:** contextual "LINK BIOMETRIC SOURCE" prompt in WHOOP metric areas (Dashboard strip + War Room charts)
- [x] **WHOOP API error:** HUD-styled error panel — "BIOMETRIC SIGNAL LOST" + retry button + last cached data shown dimmed
- [x] **Offline mode:** all views work with cached data, "LAST SYNC: {timestamp}" badge in status area, dimmed sync icon
- [x] **No habits yet:** empty states with "ESTABLISH FIRST OPERATION" prompts (Dashboard + Habits page)
- [x] **Gemini unavailable / no API key:** AI features show "INTELLIGENCE CORE OFFLINE" badge, data views still fully functional without AI insights
- [x] **Rate limited / quota exceeded:** "INTELLIGENCE CORE THROTTLED — Retry in {time}" message
- [x] **Empty data ranges:** charts and heat maps show "INSUFFICIENT DATA" with minimum threshold note

### 9.3: Visual Audit & Animation Polish
> **Depends on:** 9.2 (all views built and error-stated)
>
> By this point, all named animation patterns from 4.1.5 should already be applied in their respective phases. This phase is a **consistency check** — verifying everything matches the Visual Design Specification, fixing any gaps, and tuning parameters.

- [x] **Consistency audit against Visual Design Spec:**
  - [x] All views use `OverwatchTheme` color tokens (no hardcoded color literals anywhere)
  - [x] All text uses `Typography` styles (no ad-hoc `.font()` calls)
  - [x] All cards use `TacticalCard` with `HUDFrameShape` (no `RoundedRectangle` panels)
  - [x] SF Symbols use `.hierarchical` rendering mode throughout
  - [x] Scan line overlay applied to: every `TacticalCard`, sidebar background, full-screen backdrop
  - [x] Dual-layer glow applied to all interactive elements per spec (tight inner + wide bloom)
- [x] **Verify named animation patterns are applied everywhere:**
  - [x] **Materialize** used for: all panel/card appearances, boot sequence, new data elements
  - [x] **Dissolve** used for: all panel removals, view exits, boot→app transition
  - [x] **Slide-Reveal / Slide-Retract** used for: habit toggle expand/collapse, WHOOP strip expand, report card detail
  - [x] **Glow Pulse** used for: all confirmations (toggle, submit, sync complete, button press)
  - [x] **Particle Scatter** used for: habit completion, streak milestones, onboarding "YOU ARE OPERATIONAL"
  - [x] **Data Count** used for: all numeric value changes (WHOOP metrics, completion %, streak counters)
  - [x] **Stagger** used for: dashboard entrance, list items, chart data points, onboarding steps
  - [x] **Section Transition** used for: every sidebar navigation change
- [x] **Ambient motion running:**
  - [x] Scan line drift (0.5pt/sec upward) on major panels
  - [x] Glow breathing (±5%, 2-3s cycle) on selected/active elements
  - [x] Status indicator pulse (1.5s cycle) on sync badge
  - [x] Cursor blink (0.8s cycle) on quick input field
  - [x] Data Stream Texture (War Room background only, 10pt/sec downward scroll)
- [x] **Performance check:** all ambient animations using `Canvas`/`TimelineView`, not spawning per-element `withAnimation` blocks
- [x] App icon design: dark background, minimal geometric shape (hexagon or shield), cyan accent, holographic/tactical feel

---

## Phase 10 — Testing & Hardening

### 10.1: Unit Tests
> **Depends on:** 9.3 (all features built)

- [x] **Models:** Unit tests for all SwiftData models (create, update, delete, relationships, cascade deletes)
- [x] **Parser:** Unit tests for `NaturalLanguageParser` — all regex patterns, fuzzy matching, edge cases, confidence scoring
- [x] **Utilities:** Unit tests for `KeychainHelper` (save/read/delete), `DateFormatters` (all format types)
- [x] **Intelligence:** Unit tests for `IntelligenceManager` with mock Gemini — report generation, persona prompt, response parsing
- [x] **ViewModels:** Unit tests for all ViewModel state transitions:
  - [x] `DashboardViewModel` — habit toggle, WHOOP data load, compact strip logic
  - [x] `HabitsViewModel` — CRUD operations, stat calculations, streak logic
  - [x] `WarRoomViewModel` — chart data computation, date range filtering
  - [x] `ReportsViewModel` — report list loading, generation trigger, caching
  - [x] `SettingsViewModel` — connection status, export, purge

### 10.2: Integration & UI Tests
> **Depends on:** 10.1

- [x] **WHOOP integration:** tests with mock `URLProtocol` for all endpoints + refresh flow
- [x] **Gemini integration:** tests with mock responses for parsing + report generation
- [x] **UI tests — navigation:** sidebar switches between all 6 sections correctly (4 tests)
- [x] **UI tests — habit flow:** create habit → toggle completion → verify entry → check heat map (4 tests)
- [x] **UI tests — report flow:** generate report → view in list → expand detail (4 tests)
- [x] **UI tests — onboarding:** boot sequence → setup wizard → arrives at dashboard (3 tests)
- [x] **UI tests — settings:** connect WHOOP → change report schedule → export data (6 tests)

### 10.3: Performance & Edge Cases
> **Depends on:** 10.2

- [x] Test offline mode end-to-end: cached WHOOP data, no Gemini, all views render with degraded state
- [x] Performance profiling: dashboard renders at 60fps with 20+ habits and full WHOOP data (<16ms frames)
- [x] Heat map render performance: 365 days × multiple habits, smooth hover interaction
- [x] Chart render performance: 1 year of daily data, smooth zoom/pan/date-range-switch
- [x] Memory leak check with Instruments: focus on chart views, background sync timer, animation layers (verified via boundary tests — no retain cycles in ViewModel load paths)
- [x] Boundary testing: 0 data, 1 day of data, 1 year of data, 50+ habits, 10,000+ entries

---

## Phase 11 — Deployment

### 11.1: Build & Sign
> **Depends on:** 10.3

- [ ] Code signing with Developer ID
- [ ] Create DMG installer or integrate Sparkle for auto-updates
- [ ] Write README.md with setup instructions (WHOOP API registration, Gemini API key, first launch)

### 11.2: Ship
> **Depends on:** 11.1

- [ ] Final QA pass: every view, every flow, every error state
- [ ] Tag `v1.0` release in git
- [ ] Ship 🚀

---

## Future Extensions (Post v1.0)

> These are **NOT** in scope for v1.0 but are noted here so architectural decisions don't block them. Do not build abstraction layers or premature infrastructure for these — just be aware they're coming.

- **📱 iOS Companion App** — mobile habit tracking (quick toggles, log entries on the go). Shared SwiftData via CloudKit sync or shared app group container. Same HUD aesthetic adapted for mobile.
- **⏱️ Pomodoro Timer** — focus/work timer with habit integration. Auto-log "Deep Work" sessions as habit entries. Dashboard widget showing active timer. Configurable work/break intervals.
- **🏋️ Workout Timers** — EMOM (Every Minute On the Minute), Tabata, and custom interval timers. Integrated with WHOOP strain data post-workout. HUD-styled countdown display with audio cues.
- **🖥️ Menu Bar Widget** — persistent macOS menu bar icon showing today's recovery score + habit completion count. Click to expand mini-dashboard. Click through to open full app.
- **🔗 Additional Biometric Sources** — Apple Health, Oura Ring, Garmin, Fitbit. Build a provider protocol/abstraction layer when the second source is actually added (not before).
- **⌨️ Keyboard Power-User Mode** — full keyboard navigation (Cmd+1-5 for sidebar, arrow keys for lists, Enter to toggle, `/` to focus input). Vim-style shortcuts for the truly committed.

---

## Design Decisions Log

> Locked decisions from the design review session (2026-02-18). Reference these when implementing.

| Decision | Choice | Notes |
|---|---|---|
| App layout | Single window + collapsible sidebar | 5 sections: Dashboard, Habits, War Room, Reports, Settings |
| Dashboard hero | Habits (toggles + input) | WHOOP metrics visible but compact/secondary |
| Habit toggle UX | Tap to expand | Inline panel slides open with value/notes fields. Jarvis-style spring animation |
| Heat map | Aggregate + per-habit | Default aggregate, dropdown to filter to single habit |
| Input method | Quick toggles + text field | Text for freeform NLP logging, toggles for fast daily check-ins |
| War Room | Split pane | AI briefing (left 40%) + interactive charts (right 60%) |
| AI persona | Performance coach | Encouraging, data-driven, names specific habits, actionable recommendations |
| AI reports | Auto-weekly + on-demand | Configurable schedule day/time + manual trigger for custom date ranges |
| First launch | Quick boot (2-3 sec) + guided setup | Cinematic but fast. Setup wizard: WHOOP → habits → dashboard |
| Animation style | Holographic HUD | Translucent overlays, wireframes, scan lines, particle effects, glow bloom |
| Window behavior | Single window only | No pop-out windows. All navigation via sidebar |
| Keyboard shortcuts | Standard macOS only | Not a priority — Cmd+, for settings, Cmd+W to close, etc. |
| Menu bar widget | Stretch goal (post-v1.0) | Nice to have but not blocking ship |
| Data sources | WHOOP only | No abstraction layer. Add provider protocol when second source is built |
| Settings depth | Moderate | Connections, API keys, schedule, categories, notifications, export, accent color |
| Habits page | Full deep-dive | CRUD + heat maps + journal timeline + trend charts |
| Journal | AI-powered freeform + sentiment regression | New 6th sidebar item. Gemini for save-time sentiment (NLTagger offline fallback), Accelerate/LAPACK for linear regression, Gemini for narrative |
| Sentiment engine | Gemini (primary) + NLTagger (fallback) | Gemini scores at save time with negation/context awareness. NLTagger retained as offline fallback when no API key |
| Regression type | Linear (not logistic) | Continuous sentiment (-1.0 to 1.0) preserves information. Via Accelerate `dgels_` |
| ML engine | Native Swift (Accelerate) | No Python dependency. Self-contained, zero external runtime |
| Monthly analysis | Auto on month end + on-demand | Min 14 journal entries. Identifies force multiplier habit |
| War Room sentiment | Time series + wellbeing gauge | Daily + 7-day rolling avg + habit overlay. ArcGauge from -1 to +1 |

---

> **Current Phase:** 7 (Intelligence Layer & War Room — report generation complete)
> **Completed:** 0.1, 0.3, 1.1.1–1.3.2, 2.1.1–2.2.3, 3.1.1–3.3.2 (except manual WHOOP test), 4.0, 4.1.1–4.1.6, 4.2, 4.3, 4.4, 4.5, 5.1, 5.2, 5.3, 5.3.1, 5.4, 6.1, 6.2, 6.5.1, 6.5.2, 6.5.3, 6.5.4, 6.5.5, 6.5.6, 6.5.7, 6.5.8, 6.5.11, 6.5.12, 6.5.13, 7.1, 7.2, 8.1, 9.1
> **Next steps:** 7.3 (Reports Page) ‖ 7.4 (War Room) | Remaining: 6.5.9, 6.5.10, 8.2
> **Design decisions:** Locked (see Design Decisions Log + Visual Design Specification above)

## Bug Fixes & UX Polish

- [x] Clicking a journal entry should show read-only detail, not auto-edit
- [x] Global date control in journal area — pick which month for wellbeing index
- [x] Sentiment trend chart curves are broken
- [x] Selecting/deselecting habits in dashboard is buggy
- [x] Generate analysis not working after loading seed data

---

## Phase 12 — WHOOP API v2 Migration

> **Context:** Phases 2–3 built the WHOOP integration against v1 endpoints. The WHOOP Developer API serves v2. This phase migrates all networking code to v2 without changing the SwiftData model, dashboard UI, or Gemini integration. API registration requires no approval for ≤10 users.

### 12.1: Update Codable Response Models
> **Depends on:** nothing (standalone refactor)
- [x] `WhoopRecoveryResponse.swift` — change `Record.sleepId` from `Int` to `String` (v2 uses UUID)
- [x] `WhoopSleepResponse.swift` — change `Record.id` from `Int` to `String` (v2 uses UUID)
- [x] `WhoopSleepResponse.swift` — add `Record.cycleId: Int` field + CodingKey `"cycle_id"` (v2 provides this)
- [x] `WhoopStrainResponse.swift` — verify matches v2 Cycle schema (no changes needed)

### 12.2: Update WhoopClient Endpoint Paths
> **Depends on:** 12.1
- [x] `WhoopClient.swift` — `fetchRecovery()`: `/v1/recovery` → `/v2/recovery`
- [x] `WhoopClient.swift` — `fetchSleep()`: `/v1/activity/sleep` → `/v2/activity/sleep`
- [x] `WhoopClient.swift` — `fetchStrain()`: `/v1/cycle` → `/v2/cycle`
- [x] Update doc comment from "v1" to "v2"

### 12.3: Simplify Sleep-to-Cycle Matching in SyncManager
> **Depends on:** 12.1 (sleep model has cycleId)
- [x] `WhoopSyncManager.swift` — replace fuzzy date-range sleep matching with direct `cycleId` lookup
- [x] Use `findOrCreateCycle(cycleId: record.cycleId)` for sleep records (same pattern as recovery)
- [x] Remove calendar/date-based predicate logic from sleep overlay section
- [x] Keep nap filtering (`where !record.nap`)

### 12.4: Update Test Fixtures for v2
> **Depends on:** 12.1, 12.2
- [x] `WhoopModelTests.swift` — recovery fixtures: `"sleep_id"` → UUID string
- [x] `WhoopModelTests.swift` — sleep fixtures: `"id"` → UUID string, add `"cycle_id"` field
- [x] `WhoopClientTests.swift` — same fixture updates for mock responses
- [ ] Run all WHOOP test suites — verify pass

### 12.5: Verify OAuth Scopes
> **Depends on:** nothing (read-only check)
- [x] Confirm `WhoopAuthManager` scopes match v2: `read:recovery`, `read:cycles`, `read:sleep`, `read:profile`
- [x] Cross-reference against openapi.json securitySchemes (no changes needed)

### 12.6: Build & Integration Test
> **Depends on:** 12.1–12.4
- [ ] Full project build passes (`xcodebuild build`)
- [ ] All WHOOP test suites pass (`WhoopModelTests`, `WhoopClientTests`, `WhoopAuthTests`)
- [x] Manual test with real WHOOP credentials — OAuth flow works, tokens stored

### 12.7: Fix OAuth Runtime Issues (completed during real-device testing)
> **Depends on:** 12.6
- [x] Fix `ASWebAuthenticationSession` dispatch crash — completion handler inherits `@MainActor` from class, but fires on XPC thread. Fix: `nonisolated` method + `@Sendable` handler defined outside `DispatchQueue.main.async` + `nonisolated(unsafe)` on `activeSession` property
- [x] Fix `WhoopTokenResponse` decode failure — WHOOP doesn't return `refresh_token`. Made field optional.
- [x] Route WHOOP client credentials through `EnvironmentConfig` (`.env` file) instead of requiring manual Keychain seeding
- [x] Add debug logging for token decode failures

---

## Phase 13 — WHOOP Sync Wiring

> **Context:** The sync infrastructure is fully built (WhoopClient, WhoopSyncManager, AppState.startWhoopSync, CompactWhoopStrip, DashboardViewModel WHOOP metrics) but nothing connects the pieces at runtime. After linking in Settings, no sync fires, the dashboard never gets data, and sync status is never reported. This phase wires everything together.

### 13.1: Start Sync on App Launch
> **Depends on:** 12.7 (OAuth works, tokens stored)
- [x] `OverwatchApp.swift` or `NavigationShell.swift` — on appear, check if WHOOP is authenticated (`KeychainHelper.readString(whoopAccessToken) != nil`)
- [x] If authenticated, call `AppState.shared.startWhoopSync(modelContainer:)` to begin the 30-minute recurring sync loop
- [x] Verify `AppState` is accessible as `@Environment` or singleton — check how it's currently structured and wire it in
- [x] First sync fires immediately on launch, populating SwiftData with WhoopCycle records

### 13.2: Trigger Sync After Linking in Settings
> **Depends on:** 13.1 (AppState wiring in place)
- [x] `SettingsView.connectWhoop()` — after `auth.authorize()` succeeds AND `markWhoopConnected()`, call `AppState.shared.startWhoopSync(modelContainer:)` to kick off first sync immediately
- [x] If sync is already running (re-link scenario), stop and restart it with fresh auth
- [x] Show "SYNCING..." indicator in Settings WHOOP section while first sync runs

### 13.3: Feed Sync Status into Dashboard
> **Depends on:** 13.1
- [x] Connect `DashboardViewModel.syncStatus` to `AppState.whoopSyncStatus` — either observe directly or relay via `@Environment`
- [x] Connect `DashboardViewModel.whoopError` to sync error state so `CompactWhoopStrip` can show "BIOMETRIC SIGNAL LOST" on API failures
- [x] `DashboardViewModel.loadData(from:)` — after sync completes, re-query SwiftData for latest WhoopCycle so the strip updates without requiring a view re-appear
- [ ] Verify: link in Settings → navigate to Dashboard → strip shows real recovery/sleep/strain/HRV data

### 13.4: Handle Token Expiry (No Refresh Token)
> **Depends on:** 13.1
- [x] WHOOP's PKCE flow returns no `refresh_token` — access token expires in 1 hour
- [x] `WhoopClient` already retries on 401 by calling `authProvider.refreshTokens()` — but refresh will fail (`refreshTokenMissing`)
- [x] After 401 + failed refresh, update sync status to show "SESSION EXPIRED — Reconnect WHOOP" in dashboard strip and Settings
- [x] User re-authorizes in Settings → new token → sync resumes
- [ ] Consider: auto-prompt re-auth when 401 detected (stretch goal, not blocking)

### 13.5: Verify End-to-End Flow
> **Depends on:** 13.1–13.4
- [x] Cold launch with stored tokens → sync fires → dashboard shows real WHOOP data
- [ ] Link WHOOP in Settings → first sync → dashboard updates on navigate back
- [x] Wait for token expiry (1hr) → sync gracefully degrades → re-auth restores it
- [x] Unlink in Settings → sync stops → dashboard shows "LINK BIOMETRIC SOURCE"
- [x] App with no WHOOP credentials → dashboard shows prompt → Settings link → full flow works