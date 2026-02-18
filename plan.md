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
Phases 0–3: COMPLETE (foundation, models, WHOOP integration)
Phase 4.0–4.1: COMPLETE (HUD theme, initial dashboard, habit panel)

Current flow (Phase 4.1.5 onward):

4.1.5 (Effects Lib) ──→ 4.2 (Nav Shell) ──→ 4.3 (Dashboard Redesign) ──→ 4.4 (Heat Map) ──→ 4.5 (Quick Input)
      │                                                                      │
      ├──→ 5.1 (Habit Management) ──→ 5.2 (Stats) ──→ 5.3 (Journal)       │
      │                                                    │                 │
      │                                              5.4 (Trend Charts)     │
      │                                                                      │
      ├──→ 8.1 (Boot Sequence) ──→ 8.2 (Onboarding)                        │
      │                                                                      │
      ├──→ 9.1 (Settings) ←────────────────────────────────────────────┐    │
      │                                                                 │    │
      │    6.1 (Local Parser) ←─────────────────────────────────────────┼────┘
      │         │                                                       │
      │    6.2 (Gemini Parser) ──→ 7.1 (Intel Manager) ──→ 7.2 (Reports Gen)
      │                                                          │
      │                                                    7.3 (Reports Page)
      │                                                          │
      │                                               7.4 (War Room Split Pane)
      │                                                          │
      └──→ 9.2 (Error States) ←─────────────────────────────────┘
                  │
            9.3 (Visual Audit) ──→ 10.1 (Unit Tests) ──→ 10.2 (Integration)
                                                                │
                                                          10.3 (Performance)
                                                                │
                                                    11.1 (Build) ──→ 11.2 (Ship)
```

### Parallelization Guide

| After completing... | You can run in parallel... |
|---------------------|---------------------------|
| 4.2 (nav shell) | **4.3** (dashboard redesign) ‖ **5.1** (habit management) ‖ **8.1** (boot sequence) ‖ **9.1** (settings) |
| 4.3 (dashboard) | **4.4** (heat map) ‖ **4.5** (quick input) |
| 4.5 (quick input) | **6.1** (local parser) — needs input field wired |
| 5.1 (habit mgmt) | **5.2** (stats) ‖ **5.3** (journal) — both need habit CRUD |
| 6.2 (Gemini parser) | **7.1** (intel manager) — needs Gemini service |
| 7.2 (report gen) | **7.3** (reports page) ‖ **7.4** (war room) |
| 7.4 + 9.1 (all views built) | **9.2** (error states) |
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

- [ ] Create `HabitHeatMapView.swift` — configurable grid component
  - [ ] Full mode: 52×7 grid (weeks × days), trailing 12 months
  - [ ] Compact mode: ~4×7 grid, trailing 30 days (for dashboard preview)
  - [ ] Mode set via init parameter, same component for both
- [ ] Create `HeatMapCell.swift` — rounded rect, color intensity from completion percentage
  - [ ] 0%: dark/empty (#1C1C1E)
  - [ ] 1-33%: dim cyan
  - [ ] 34-66%: medium cyan
  - [ ] 67-99%: bright cyan
  - [ ] 100%: full glow with subtle pulse
- [ ] Use `Canvas` for rendering performance (365+ cells must render at 60fps)
- [ ] **Aggregate mode** (default): shows overall daily completion % across all habits
- [ ] **Per-habit filter mode**: dropdown or segmented control to switch to a single habit's heat map
- [ ] Hover interaction:
  - [ ] Tooltip slides in showing: date, habits completed that day, completion percentage
  - [ ] Cell glow intensifies on hover
- [ ] Legend bar showing color intensity scale (0% → 100%) with HUD styling
- [ ] Wire to `@Query` on `HabitEntry` data, computed by `DashboardViewModel` or `HabitsViewModel`
- [ ] Verify performance: smooth scrolling/hover with 365 days of sample data

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

### 5.1: Habit Management
> **Depends on:** 4.2 (navigation shell routes to Habits page)

- [ ] Create `HabitsViewModel.swift` — `@Observable @MainActor`, owns all habit CRUD + computed stats
  - [ ] `habits: [Habit]` — all tracked habits from SwiftData
  - [ ] `selectedHabit: Habit?` — currently selected for detail view
  - [ ] `addHabit(name:emoji:category:targetFrequency:)` method
  - [ ] `updateHabit(_:)` method
  - [ ] `deleteHabit(_:)` method with entry cascade
  - [ ] `reorderHabits(_:)` method
- [ ] Create `HabitsView.swift` — main habits page routed from sidebar
  - [ ] Master-detail layout: habit list (left/top) + selected habit detail (right/bottom)
  - [ ] Or: scrollable single-column with expandable rows
- [ ] Habit list items: emoji + name + category badge + current streak count + weekly completion rate bar
- [ ] Add Habit sheet: HUD-styled form
  - [ ] Name field (DESIGNATION)
  - [ ] Emoji picker (ICON)
  - [ ] Category dropdown (Health, Fitness, Mindfulness, Productivity, or custom)
  - [ ] Target frequency picker (Daily, X times per week, X times per month)
  - [ ] Unit type (boolean / quantity with unit label)
  - [ ] ACTIVATE / CANCEL buttons
- [ ] Edit Habit: same form as Add, pre-populated, triggered by edit button on habit row
- [ ] Delete Habit: confirmation dialog ("DECOMMISSION {habit name}?"), cascade deletes all entries
- [ ] Reorder habits via drag-and-drop (custom drag handle with HUD styling)
- [ ] Category filtering: filter bar at top to show all / specific category
- [ ] Empty state: "NO ACTIVE OPERATIONS — Add your first habit to begin tracking"

### 5.2: Per-Habit Heat Maps & Stats
> **Depends on:** 5.1, 4.4 (heat map component built)

- [ ] Habit detail panel (when a habit is selected or row is expanded):
  - [ ] Individual heat map using `HabitHeatMapView` in per-habit mode (full 12-month view)
  - [ ] Stats card showing:
    - [ ] Current streak (consecutive days/occurrences)
    - [ ] Longest streak (all time)
    - [ ] Total completions
    - [ ] Weekly completion rate (last 7 days)
    - [ ] Monthly completion rate (last 30 days)
    - [ ] All-time completion rate
- [ ] Streak milestone celebrations: HUD-style glow burst animation at 7-day, 30-day, 100-day, 365-day milestones
- [ ] Stats displayed as `MetricTile` components for visual consistency

### 5.3: Journal Timeline
> **Depends on:** 5.1

- [ ] Create `JournalTimelineView.swift` — scrollable timeline of all `HabitEntry` logs
  - [ ] Newest entries first
  - [ ] Each entry row: timestamp + habit emoji + habit name + value/notes if present
  - [ ] HUD-styled vertical timeline line connecting entries (thin cyan line with node dots at each entry)
- [ ] Filters:
  - [ ] By habit (dropdown showing all habits)
  - [ ] By date range (preset: today, last 7 days, last 30 days, custom)
  - [ ] By category
- [ ] Tap entry to edit: inline expand with value/notes fields + save/delete buttons
- [ ] Delete entry: swipe-to-delete or delete button, with "ENTRY PURGED" confirmation
- [ ] Lazy loading for performance with large datasets

### 5.4: Per-Habit Trend Charts
> **Depends on:** 5.2

- [ ] Create `HabitTrendChartView.swift` using SwiftUI Charts
  - [ ] For boolean habits: line chart of completion rate over time (7-day rolling average)
  - [ ] For quantity habits: line chart of actual values over time (e.g., water intake in liters)
- [ ] WHOOP correlation overlay: option to overlay recovery score on the same chart
  - [ ] Dual Y-axis: habit metric (left) + recovery % (right)
  - [ ] Visual correlation — do good habit weeks align with high recovery?
- [ ] Date range selector: 1 week / 1 month / 3 months / 1 year
- [ ] HUD chart styling: cyan line, dark background, subtle grid lines, glow on data points
- [ ] Animated transitions when switching date ranges (spring animation on data points)
- [ ] Empty state: "INSUFFICIENT DATA — Log more entries to see trends" (minimum 7 data points)

---

## Phase 6 — Natural Language Parsing

> **Design context:** The quick input field on the Dashboard routes text through a parser. Local regex-based parsing handles common patterns instantly. Gemini is a fallback for ambiguous or complex inputs. The goal: type naturally, habits get logged automatically.

### 6.1: ParsedHabit & Local Parser
> **Depends on:** 4.5 (quick input wired with stub)

- [ ] Define `ParsedHabit` struct:
  - [ ] `habitName: String` — matched or inferred habit name
  - [ ] `value: Double?` — numeric value if present (e.g., 3.0 for "3L water")
  - [ ] `unit: String?` — unit label if present (e.g., "L", "hours", "min")
  - [ ] `confidence: Double` — 0.0 to 1.0, how sure the parser is
  - [ ] `rawInput: String` — original user text
  - [ ] `matchedHabit: Habit?` — reference to existing habit if fuzzy-matched
- [ ] Create `NaturalLanguageParser.swift` — `@MainActor` class (needs SwiftData access for fuzzy matching)
  - [ ] `func parse(_ input: String) async -> ParsedHabit` — main entry point
  - [ ] `func parseLocally(_ input: String) -> ParsedHabit?` — regex-based, synchronous
- [ ] Implement quantity patterns:
  - [ ] "Drank 3L water" → water, 3.0, "L"
  - [ ] "Slept 8 hours" → sleep, 8.0, "hours"
  - [ ] "Meditated 20 min" → meditation, 20.0, "min"
  - [ ] "Ran 5k" → running, 5.0, "km"
  - [ ] Handle decimal values: "Drank 2.5L water"
- [ ] Implement boolean patterns:
  - [ ] "Worked out" → exercise, completed = true
  - [ ] "No alcohol" → alcohol, completed = true (inverted habit)
  - [ ] "Skipped sugar" → sugar, completed = true (inverted habit)
  - [ ] "Did yoga" → yoga, completed = true
- [ ] Implement fuzzy matching against existing `Habit.name` values in SwiftData
  - [ ] Case-insensitive contains match
  - [ ] Common abbreviation handling (e.g., "med" → "Meditation")
- [ ] Write unit tests for all regex patterns + edge cases (empty string, numbers only, emoji only)

### 6.2: Gemini Parsing Fallback
> **Depends on:** 6.1

- [ ] Create `GeminiService.swift` actor — centralizes all Gemini API communication
  - [ ] Init with API key from Keychain
  - [ ] Manages `GenerativeModel` instance
  - [ ] Rate limiting / request queuing
- [ ] Add `parseWithGemini(_ input: String, existingHabits: [String]) async throws -> ParsedHabit`
  - [ ] Prompt includes list of user's existing habit names for context
  - [ ] Response format: structured JSON matching `ParsedHabit` fields
- [ ] Implement hybrid logic in `NaturalLanguageParser.parse()`:
  - [ ] Step 1: Try local parser
  - [ ] Step 2: If local confidence < 0.7, call Gemini
  - [ ] Step 3: If Gemini also fails, return low-confidence result with "UNRECOGNIZED" flag
- [ ] Cache Gemini mappings: store `rawInput → ParsedHabit` in UserDefaults for repeat inputs
  - [ ] Cache TTL: 30 days
  - [ ] Avoid redundant API calls for the same phrasing
- [ ] Replace stub in `QuickInputView` with real `NaturalLanguageParser`
- [ ] Write integration tests with mock Gemini response
- [ ] Test edge cases: gibberish input, multi-habit in one sentence, emoji-only, very long input

---

## Phase 7 — Intelligence Layer & War Room

> **Design context:** AI persona is a **performance coach** — encouraging, data-driven, motivational + actionable. Names specific habits, gives concrete recommendations, celebrates wins. Reports auto-generate weekly AND can be triggered on-demand for any date range.
>
> The War Room is a **split-pane** layout: AI briefing panel (left) + interactive charts (right). Both visible simultaneously, cross-linked so insights reference chart data.

### 7.1: Intelligence Manager & Persona
> **Depends on:** 6.2 (Gemini service exists)

- [ ] Create `IntelligenceManager.swift` — uses `GeminiService`, owns all report generation logic
- [ ] Define system prompt for performance coach persona:
  - [ ] Encouraging but honest — celebrates wins, flags regressions without being harsh
  - [ ] Data-driven — always references specific numbers (e.g., "Your meditation streak hit 14 days and HRV climbed 8% over that period")
  - [ ] Actionable — every insight ends with a concrete recommendation
  - [ ] Example tone: "Strong week overall. Your hydration consistency (6/7 days) is clearly paying off — recovery averaged 71%, up from 63% last week. One area to watch: sleep duration dropped below 7h three nights. Try setting a 10pm wind-down alarm."
- [ ] Define `WeeklyInsight` SwiftData `@Model`:
  - [ ] `id: UUID`
  - [ ] `dateRangeStart: Date`, `dateRangeEnd: Date`
  - [ ] `summary: String` — 2-3 paragraph narrative overview
  - [ ] `forceMultiplierHabit: String` — the habit with highest positive correlation to recovery
  - [ ] `recommendations: [String]` — 3-5 actionable items
  - [ ] `correlations: [HabitCorrelation]` — habit name + correlation coefficient + direction
  - [ ] `generatedAt: Date`
- [ ] Define `HabitCorrelation` struct: `habitName: String`, `coefficient: Double`, `direction: String` ("positive"/"negative")

### 7.2: Weekly Report Generation
> **Depends on:** 7.1

- [ ] Implement `generateWeeklyReport(startDate:endDate:) async throws -> WeeklyInsight`
  - [ ] Query SwiftData for all `HabitEntry` records in date range
  - [ ] Query SwiftData for all `WhoopCycle` records in date range
  - [ ] Package as structured JSON: daily habit completions, daily WHOOP metrics, habit metadata
  - [ ] Send to Gemini with performance coach system prompt + structured output request
  - [ ] Parse Gemini response into `WeeklyInsight` fields
- [ ] Save `WeeklyInsight` to SwiftData for offline viewing and historical archive
- [ ] **Auto-generate scheduling:**
  - [ ] Configurable day of week (default: Sunday) stored in Settings
  - [ ] Configurable time (default: 8:00 AM local)
  - [ ] Uses `Timer` or app lifecycle hook — generate on next app open after scheduled time
  - [ ] Skip if already generated for this week
- [ ] **On-demand generation:**
  - [ ] "Generate Report" action available from Reports page and War Room
  - [ ] Custom date range picker (start date + end date)
  - [ ] Loading state while Gemini processes ("COMPILING INTELLIGENCE BRIEFING...")
- [ ] Write tests with mock Gemini responses (test parsing, caching, dedup)
- [ ] Test offline retrieval of previously cached reports

### 7.3: Reports Page (Intel Briefings Archive)
> **Depends on:** 7.2, 4.2 (navigation shell)

- [ ] Create `ReportsViewModel.swift` — `@Observable @MainActor`, owns report list + generation triggers
- [ ] Create `ReportsView.swift` — routed from sidebar "Reports" section
  - [ ] Header: "INTEL BRIEFINGS" with HUD styling
  - [ ] "GENERATE REPORT" button (prominent, top-right) — triggers on-demand generation with date range picker
  - [ ] Scrollable list of past reports, newest first
  - [ ] Each report card (`TacticalCard` styled):
    - [ ] Date range label (e.g., "FEB 10 — FEB 16, 2026")
    - [ ] Summary preview (first 2 lines of summary, truncated)
    - [ ] Force multiplier habit badge (highlighted in accent color)
    - [ ] Generated timestamp
- [ ] Tap report card → expand to full detail view:
  - [ ] Full summary text
  - [ ] Force multiplier habit section with explanation
  - [ ] Recommendations list (numbered, each actionable)
  - [ ] Correlations list (habit name + direction + strength indicator)
- [ ] Empty state: "NO BRIEFINGS YET — Your first intel report generates after one week of tracking data."
- [ ] Loading state for in-progress generation: animated HUD progress indicator

### 7.4: War Room — Split Pane Analytics
> **Depends on:** 7.2 (needs report data), 5.4 (trend chart patterns)

- [ ] Create `WarRoomViewModel.swift` — `@Observable @MainActor`, owns chart data + AI insight state
  - [ ] `selectedDateRange: DateRange` (1 week / 1 month / 3 months / 1 year / all time)
  - [ ] `latestInsight: WeeklyInsight?` — most recent report
  - [ ] Computed chart data arrays from SwiftData queries
- [ ] Create `WarRoomView.swift` — routed from sidebar "War Room" section
  - [ ] **Split pane layout:** AI briefing (left, ~40% width) + charts (right, ~60% width)
  - [ ] Resizable divider between panes (drag to adjust ratio)
  - [ ] Full HUD treatment: scan line overlay, grid backdrop, glow effects
- [ ] **Left pane — AI Briefing Panel:**
  - [ ] Latest weekly insight displayed as scrollable narrative
  - [ ] Force multiplier habit highlighted with accent glow
  - [ ] Recommendations as numbered list with checkbox-style items
  - [ ] "REFRESH ANALYSIS" button to regenerate
  - [ ] If no insight available: "AWAITING INTELLIGENCE DATA" placeholder
- [ ] **Right pane — Interactive Charts:**
  - [ ] Create `TrendChartView.swift` — SwiftUI Charts container, switchable chart types:
    - [ ] **Line chart:** recovery score over time (green/amber/red zones)
    - [ ] **Bar chart:** daily habit completion count (stacked by category)
    - [ ] **Scatter plot:** habit completion % (X) vs. recovery score (Y) — shows correlation
    - [ ] **Area chart:** sleep metrics (SWS, REM, total hours) stacked over time
  - [ ] Chart type switcher: segmented control or tab bar above chart area
  - [ ] Date range selector: 1 week / 1 month / 3 months / 1 year / all time
- [ ] **Cross-linking:** tapping an insight in the left pane highlights the relevant time range / data points in the right pane chart
- [ ] Chart animations: spring transitions when switching chart type or date range, data points animate in
- [ ] HUD chart styling: cyan lines, glow on data points, dark axes, subtle grid, scan line overlay on chart background
- [ ] Empty state: "INSUFFICIENT DATA FOR ANALYSIS — Continue tracking for deeper insights" (minimum threshold: 7 days of data)

---

## Phase 8 — Boot Sequence & Onboarding

> **Design context:** First impressions matter. A quick (2-3 second) cinematic boot sequence sets the Jarvis tone immediately. Then a guided setup gets the user operational. Subsequent launches skip straight to the app.

### 8.1: Boot Sequence
> **Depends on:** 4.2 (navigation shell exists as the destination)

- [ ] Create `BootSequenceView.swift` — 2-3 second cinematic intro using named animation patterns:
  - [ ] **Phase 1 (0.0s):** Black void, single cursor blink (0.8s cycle)
  - [ ] **Phase 2 (0.3s):** Grid lines draw across screen using **Wireframe Trace** — thin cyan lines trace horizontally and vertically from center outward, building the grid backdrop
  - [ ] **Phase 3 (0.6s):** **Data Stream Texture** fades in behind text at 8% opacity (higher than normal for dramatic effect). System init text **Stagger**s in line by line (0.1s per line), each line using **Materialize** (fade + slight upward drift):
    ```
    OVERWATCH v1.0 // SYSTEM INITIALIZATION
    LOADING MODULES...
    HABIT ENGINE.......... ONLINE
    BIOMETRIC SYNC........ ONLINE
    INTELLIGENCE CORE..... ONLINE
    ```
    "ONLINE" text gets a **Glow Pulse** (green) as each subsystem activates
  - [ ] **Phase 4 (1.5s):** "OVERWATCH" logo text **Materialize**s — letters appear one by one with **Wireframe Trace** outlines that fill with color, then full **Glow Bloom** expands outward (16pt → 32pt radius, 0.4s)
  - [ ] **Phase 5 (2.5s):** Entire boot screen uses **Dissolve** pattern — content fades, grid fades, void transitions to NavigationShell
- [ ] First launch: full 2-3 second sequence
- [ ] Subsequent launches: skip entirely (direct to NavigationShell) — or 0.5s abbreviated logo flash with **Glow Pulse** only
- [ ] Store `hasCompletedFirstBoot` in UserDefaults
- [ ] All effects pull from the reusable components built in 4.1.5 (WireframeTrace, DataStreamTexture, AnimationPatterns)

### 8.2: Guided Setup (First Launch Only)
> **Depends on:** 8.1

- [ ] After boot sequence, present `OnboardingView.swift` — only shown once (first launch)
- [ ] **Step 1: Welcome**
  - [ ] "WELCOME, OPERATOR" header with HUD glow
  - [ ] Brief app overview: "Overwatch tracks your habits, syncs your biometrics, and delivers AI-powered performance insights."
  - [ ] "BEGIN SETUP" button
- [ ] **Step 2: Connect WHOOP** (optional)
  - [ ] "LINK BIOMETRIC SOURCE" header
  - [ ] "Connect WHOOP" button → triggers OAuth flow
  - [ ] "SKIP FOR NOW" option — can connect later in Settings
  - [ ] Success state: "WHOOP LINKED — Biometric data will sync automatically"
- [ ] **Step 3: Add First Habits**
  - [ ] "ESTABLISH OPERATIONS" header
  - [ ] Pre-populated suggestions as tappable chips: 💧 Water, 🏋️ Exercise, 😴 Sleep 8h, 🧘 Meditation, 📖 Reading
  - [ ] Tap to add, tap again to remove
  - [ ] "ADD CUSTOM" button → habit creation form
  - [ ] At least 1 habit required to proceed (or skip)
- [ ] **Step 4: Operational**
  - [ ] "YOU ARE NOW OPERATIONAL" **Materialize**s with expanded **Glow Bloom** (32pt radius), **Particle Scatter** burst from center
  - [ ] Hold 1s, then **Dissolve** entire onboarding → **Materialize** NavigationShell with dashboard **Stagger** entrance
- [ ] Each step transition: outgoing panel uses **Dissolve** (0.2s), incoming panel uses **Materialize** (0.3s) with content **Stagger** for sub-elements. Direction: left-to-right progression feel
- [ ] Store `hasCompletedOnboarding` in UserDefaults
- [ ] Progress indicator: 4 dots at bottom showing current step

---

## Phase 9 — Settings & Polish

> **Design context:** Settings is a practical page — not flashy, but still HUD-themed. Error states should feel in-universe ("SIGNAL LOST" not "Error 401"). Visual polish pass ensures every view is consistent with the holographic HUD aesthetic.

### 9.1: Settings Page
> **Depends on:** 4.2 (navigation shell routes to Settings)

- [ ] Create `SettingsViewModel.swift` — `@Observable @MainActor`, owns all settings state + connection management
- [ ] Create `SettingsView.swift` — routed from sidebar "Settings" section
- [ ] **Connections section:**
  - [ ] WHOOP: connection status indicator (LINKED / DISCONNECTED), connect/disconnect button, last sync timestamp
  - [ ] Gemini API: key entry field (masked, stored in Keychain), "TEST CONNECTION" button with success/fail feedback
- [ ] **Reports section:**
  - [ ] Auto-generate: toggle on/off
  - [ ] Day of week picker (default: Sunday)
  - [ ] Time picker (default: 8:00 AM)
- [ ] **Habits section:**
  - [ ] Manage categories: list of categories, add/rename/delete custom categories
  - [ ] Default habit suggestions toggle (show/hide on onboarding and add-habit sheet)
- [ ] **Notifications section:**
  - [ ] Daily habit reminder: toggle + time picker
  - [ ] Weekly report ready: toggle
- [ ] **Data section:**
  - [ ] "EXPORT ALL DATA" → JSON file (habits, entries, WHOOP cycles, reports)
  - [ ] "EXPORT HABITS" → CSV file (habit entries only)
  - [ ] "PURGE ALL DATA" → destructive action with double-confirmation ("Are you sure?" → "Type PURGE to confirm")
- [ ] **Appearance section:**
  - [ ] Accent color picker (default: cyan #00D4FF, options: green, amber, red, purple, white)
- [ ] All form controls HUD-styled: dark backgrounds, cyan borders, monospace labels

### 9.2: Error States & Graceful Degradation
> **Depends on:** 7.4, 9.1 (need all major views built to add error states to them)

- [ ] **No WHOOP connection:** contextual "LINK BIOMETRIC SOURCE" prompt in WHOOP metric areas (Dashboard strip + War Room charts)
- [ ] **WHOOP API error:** HUD-styled error panel — "BIOMETRIC SIGNAL LOST" + retry button + last cached data shown dimmed
- [ ] **Offline mode:** all views work with cached data, "LAST SYNC: {timestamp}" badge in status area, dimmed sync icon
- [ ] **No habits yet:** empty states with "ESTABLISH FIRST OPERATION" prompts (Dashboard + Habits page)
- [ ] **Gemini unavailable / no API key:** AI features show "INTELLIGENCE CORE OFFLINE" badge, data views still fully functional without AI insights
- [ ] **Rate limited / quota exceeded:** "INTELLIGENCE CORE THROTTLED — Retry in {time}" message
- [ ] **Empty data ranges:** charts and heat maps show "INSUFFICIENT DATA" with minimum threshold note

### 9.3: Visual Audit & Animation Polish
> **Depends on:** 9.2 (all views built and error-stated)
>
> By this point, all named animation patterns from 4.1.5 should already be applied in their respective phases. This phase is a **consistency check** — verifying everything matches the Visual Design Specification, fixing any gaps, and tuning parameters.

- [ ] **Consistency audit against Visual Design Spec:**
  - [ ] All views use `OverwatchTheme` color tokens (no hardcoded color literals anywhere)
  - [ ] All text uses `Typography` styles (no ad-hoc `.font()` calls)
  - [ ] All cards use `TacticalCard` with `HUDFrameShape` (no `RoundedRectangle` panels)
  - [ ] SF Symbols use `.hierarchical` rendering mode throughout
  - [ ] Scan line overlay applied to: every `TacticalCard`, sidebar background, full-screen backdrop
  - [ ] Dual-layer glow applied to all interactive elements per spec (tight inner + wide bloom)
- [ ] **Verify named animation patterns are applied everywhere:**
  - [ ] **Materialize** used for: all panel/card appearances, boot sequence, new data elements
  - [ ] **Dissolve** used for: all panel removals, view exits, boot→app transition
  - [ ] **Slide-Reveal / Slide-Retract** used for: habit toggle expand/collapse, WHOOP strip expand, report card detail
  - [ ] **Glow Pulse** used for: all confirmations (toggle, submit, sync complete, button press)
  - [ ] **Particle Scatter** used for: habit completion, streak milestones, onboarding "YOU ARE OPERATIONAL"
  - [ ] **Data Count** used for: all numeric value changes (WHOOP metrics, completion %, streak counters)
  - [ ] **Stagger** used for: dashboard entrance, list items, chart data points, onboarding steps
  - [ ] **Section Transition** used for: every sidebar navigation change
- [ ] **Ambient motion running:**
  - [ ] Scan line drift (0.5pt/sec upward) on major panels
  - [ ] Glow breathing (±5%, 2-3s cycle) on selected/active elements
  - [ ] Status indicator pulse (1.5s cycle) on sync badge
  - [ ] Cursor blink (0.8s cycle) on quick input field
  - [ ] Data Stream Texture (War Room background only, 10pt/sec downward scroll)
- [ ] **Performance check:** all ambient animations using `Canvas`/`TimelineView`, not spawning per-element `withAnimation` blocks
- [ ] App icon design: dark background, minimal geometric shape (hexagon or shield), cyan accent, holographic/tactical feel

---

## Phase 10 — Testing & Hardening

### 10.1: Unit Tests
> **Depends on:** 9.3 (all features built)

- [ ] **Models:** Unit tests for all SwiftData models (create, update, delete, relationships, cascade deletes)
- [ ] **Parser:** Unit tests for `NaturalLanguageParser` — all regex patterns, fuzzy matching, edge cases, confidence scoring
- [ ] **Utilities:** Unit tests for `KeychainHelper` (save/read/delete), `DateFormatters` (all format types)
- [ ] **Intelligence:** Unit tests for `IntelligenceManager` with mock Gemini — report generation, persona prompt, response parsing
- [ ] **ViewModels:** Unit tests for all ViewModel state transitions:
  - [ ] `DashboardViewModel` — habit toggle, WHOOP data load, compact strip logic
  - [ ] `HabitsViewModel` — CRUD operations, stat calculations, streak logic
  - [ ] `WarRoomViewModel` — chart data computation, date range filtering
  - [ ] `ReportsViewModel` — report list loading, generation trigger, caching
  - [ ] `SettingsViewModel` — connection status, export, purge

### 10.2: Integration & UI Tests
> **Depends on:** 10.1

- [ ] **WHOOP integration:** tests with mock `URLProtocol` for all endpoints + refresh flow
- [ ] **Gemini integration:** tests with mock responses for parsing + report generation
- [ ] **UI tests — navigation:** sidebar switches between all 5 sections correctly
- [ ] **UI tests — habit flow:** create habit → toggle completion → verify entry → check heat map
- [ ] **UI tests — report flow:** generate report → view in list → expand detail
- [ ] **UI tests — onboarding:** boot sequence → setup wizard → arrives at dashboard
- [ ] **UI tests — settings:** connect WHOOP → change report schedule → export data

### 10.3: Performance & Edge Cases
> **Depends on:** 10.2

- [ ] Test offline mode end-to-end: cached WHOOP data, no Gemini, all views render with degraded state
- [ ] Performance profiling: dashboard renders at 60fps with 20+ habits and full WHOOP data (<16ms frames)
- [ ] Heat map render performance: 365 days × multiple habits, smooth hover interaction
- [ ] Chart render performance: 1 year of daily data, smooth zoom/pan/date-range-switch
- [ ] Memory leak check with Instruments: focus on chart views, background sync timer, animation layers
- [ ] Boundary testing: 0 data, 1 day of data, 1 year of data, 50+ habits, 10,000+ entries

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

---

> **Current Phase:** 4.4 — Heat Map Component (next up)
> **Completed:** 0.1, 0.3, 1.1.1–1.3.2, 2.1.1–2.2.3, 3.1.1–3.3.2 (except manual WHOOP test), 4.0, 4.1.1–4.1.6, 4.2, 4.3, 4.5
> **Next steps:** 4.4 (heat map) → 5.1 (habit management) ‖ 8.1 (boot sequence) ‖ 9.1 (settings)
> **Design decisions:** Locked (see Design Decisions Log + Visual Design Specification above)
