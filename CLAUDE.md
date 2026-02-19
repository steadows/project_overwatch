# Dev Journal Protocol

You are a session scribe. In addition to completing the user's coding tasks, you maintain a running dev journal that captures the narrative and technical details of each work session. This journal feeds a blog content pipeline — the user will later mine these entries for blog post ideas.

## When to Journal

Append a journal entry automatically (without being asked) every time you:

- Complete a feature, fix a bug, or finish a meaningful chunk of work
- Make a significant architectural or design decision
- Solve a non-trivial problem (especially if it involved debugging or research)
- Discover something interesting, surprising, or worth sharing
- Reach the end of a session or the user says "wrap up"

You do NOT need to journal for trivial changes (typo fixes, formatting, minor tweaks).

## Where to Write

Append entries to: `~/dev-journal/{YYYY-MM-DD}.md`

One file per day. If the file already exists, append to it. If not, create it with the daily header.

Use UTC or the user's local date — whichever is apparent from system context.

## Daily File Format

```markdown
# Dev Journal — {YYYY-MM-DD}

---

## {HH:MM} — {Short Title}

**Project:** {project name or repo}
**Tags:** {comma-separated tags relevant to the work — e.g., Next.js, debugging, API design, performance, refactoring}

### What happened

{2-4 sentences in narrative style. What was the goal? What was the challenge? What made this interesting? Write like you're telling a friend about your day — casual but informative.}

### Technical details

{Bullet points covering: what changed, key files touched, patterns or tools used, any gotchas or edge cases encountered. Keep it concise but specific enough to recreate context later.}

### Takeaway

{1-2 sentences: the insight, lesson, or "aha moment" — the thing that would make a good blog paragraph. If there's nothing profound, a simple summary is fine.}

### Blog potential

{Rate 1-5 and a brief note on why. Example: "4/5 — debugging story with a satisfying twist, good tutorial material" or "2/5 — routine CRUD, not much to write about"}

---
```

## Writing Style Guidelines

- Be a narrator, not a commit log. "I spent 40 minutes chasing a hydration mismatch that turned out to be a date formatting issue" is better than "Fixed hydration error."
- Capture the emotional arc. Frustration, curiosity, satisfaction — these make blog posts compelling.
- Name specific technologies and patterns. Future-you needs enough context to reconstruct the story.
- Include the dead ends. What you tried that didn't work is often more interesting than what did.
- Keep each entry focused. One entry per meaningful unit of work. Multiple entries per session is fine.

## Important Rules

- ALWAYS journal silently as part of your workflow. Do not ask "should I journal this?" — just do it.
- If you're unsure whether something is journal-worthy, journal it. Better to have too much than too little.
- Never skip journaling because the user didn't explicitly ask for it. This is a standing instruction.
- The journal file is **strictly append-only**. NEVER overwrite or delete previous entries — even if they're rough or redundant. Multiple entries on the same day are expected and fine. Use timestamps in the `## {HH:MM}` headers to distinguish them.
- When appending, always use the Edit tool to add content after the last `---` separator, or use Bash with `>>` to append. Never use the Write tool on an existing journal file.
- If the `~/dev-journal/` directory doesn't exist, create it.

---

# GSD Build Methodology

When building features or systems, follow the **Get Stuff Done (GSD)** method. All work is driven by a highly detailed checklist maintained in `plan.md` at the project root.

## Plan Structure

`plan.md` is organized into **phases**. Each phase represents a logical stage of the build (e.g., scaffolding, core logic, integrations, testing, polish). Phases are worked through iteratively — complete one phase before moving to the next unless the user directs otherwise.

### Format

```markdown
# Plan — {Project or Feature Name}

## Phase 1: {Phase Title}
- [ ] Task description (specific, actionable, single unit of work)
- [ ] Task description
- [x] Completed task

## Phase 2: {Phase Title}
- [ ] Task description
- [ ] Task description

...
```

## Rules

- **Always reference `plan.md` before starting work.** Read it, understand the current phase, and pick up where we left off.
- **Check off tasks as they are completed.** Keep the plan in sync with reality at all times.
- **Be granular.** Each task should be a single, concrete action — not a vague goal. "Create `UserService` class with `getById` and `create` methods" not "Build user service."
- **Phases are iterative.** We may revisit earlier phases if new requirements emerge. Add tasks or sub-phases as needed, but never delete completed items.
- **When creating a plan**, think through the full scope before writing. Consider dependencies, edge cases, and integration points. The plan should be detailed enough that someone unfamiliar with the project could follow it.
- **If no `plan.md` exists**, prompt the user to define the scope and create one before building.

---

# Architecture: MVVM

Overwatch uses **MVVM (Model-View-ViewModel)** with SwiftUI's native reactive primitives.

## Conventions

- **Models:** SwiftData `@Model` classes. These are the source of truth.
- **ViewModels:** `@Observable` classes. One per major view/feature. They own business logic, transform model data for display, and call services.
- **Views:** SwiftUI views. They bind to ViewModels via `@State` or `@Environment`. Views are dumb — no business logic.
- **Services:** Standalone actors/classes for external concerns (API clients, sync managers, parsers). ViewModels call services, not views.

## Naming

- `{Feature}ViewModel.swift` — e.g., `DashboardViewModel.swift`, `WhoopSyncViewModel.swift`
- ViewModels live alongside their views in the same folder group
- Services live in `Services/`

## Data Flow

```
SwiftData @Model ←→ ViewModel (@Observable) ←→ View (@Query / @State)
                        ↕
                    Service (actor)
                        ↕
                   External API / Keychain
```

## Rules

- Views never call services directly — always go through a ViewModel
- ViewModels never import SwiftUI — they work with plain Swift types
- `@Query` is the exception: Views can use `@Query` directly for simple read-only lists (SwiftData makes this idiomatic)
- Keep ViewModels testable — inject service dependencies via init

---

# Gemini Prompting Standard — RISEN with XML Tags

All prompts sent to the Gemini API (via `GeminiService`) must follow the **RISEN** framework with **XML tags** for section headers and data passing. This is a hard rule — no freeform prompt strings.

## RISEN Structure

Every Gemini prompt must include these sections, wrapped in XML tags:

```
<role>
Who Gemini is in this context. Define the persona, expertise, and tone.
Example: "You are a performance coach who analyzes habit and wellbeing data. You are encouraging but honest, data-driven, and always actionable."
</role>

<instructions>
What Gemini should do. Clear, specific directives. Include output format requirements.
Example: "Analyze the following habit-sentiment regression results. Produce a 2-3 paragraph narrative summary. Highlight the force multiplier habit. End with one actionable recommendation."
</instructions>

<steps>
Ordered steps Gemini should follow to complete the task.
Example:
1. Review the habit coefficients and identify the strongest positive and negative drivers.
2. Summarize the overall sentiment trend for the month.
3. Call out the force multiplier habit with specific data.
4. Provide one concrete, actionable recommendation.
</steps>

<expectations>
Output format, length, tone, and constraints.
Example: "Respond in 2-3 paragraphs. Use a motivational but data-grounded tone. Reference specific habit names and coefficient values. Do not use bullet points — narrative prose only."
</expectations>

<narrowing>
Boundaries and guardrails. What NOT to do.
Example: "Do not invent data points not present in the input. Do not provide medical advice. Do not reference habits not included in the data."
</narrowing>
```

## Data Passing

All structured data passed to Gemini must be wrapped in descriptive XML tags:

```
<habit_coefficients>
[{"habitName": "Meditation", "coefficient": 0.34, "direction": "positive"}, ...]
</habit_coefficients>

<sentiment_summary>
{"averageScore": 0.42, "entryCount": 28, "month": "February 2026"}
</sentiment_summary>

<existing_habits>
["Meditation", "Exercise", "Water", "Reading"]
</existing_habits>
```

## Rules

- **Every** `GeminiService` method that builds a prompt must use all five RISEN tags.
- **Every** data payload must be in its own named XML tag — never inline raw JSON in the instructions.
- Keep `<role>` consistent across the app (performance coach persona) unless the task specifically requires a different persona.
- `<expectations>` must always specify the output format (JSON schema, prose, etc.) so responses are parseable.
- When Gemini returns structured data, request it inside a specific XML tag (e.g., `<analysis_result>`) for reliable parsing.

---

# Skills & References

When the user uploads or defines **skills** (reusable prompts, patterns, or domain-specific instructions), they will be added to this file or referenced here. Skills augment the build process and should be consulted when relevant work begins.

When starting any build task:
1. Read `CLAUDE.md` for active skills and protocols
2. Read `plan.md` for the current phase and task list
3. Execute against the plan, journaling as you go

---

## Skill: SwiftUI Expert (avdlee/swiftui-agent-skill)

> Source: https://skills.sh/avdlee/swiftui-agent-skill/swiftui-expert-skill

### State Management Rules

- Always use `@Observable` (never `ObservableObject` for new code)
- Mark `@Observable` classes with `@MainActor` unless using a different actor isolation
- Keep `@State` and `@StateObject` properties `private`
- Use `@Binding` only when children need to write back to parent state
- Never declare passed-in values as `@State` or `@StateObject`

### Modern API Enforcement

Always use the current API — never the deprecated version:

| Use this | Not this |
|---|---|
| `foregroundStyle()` | `foregroundColor()` |
| `clipShape(.rect(cornerRadius:))` | `cornerRadius()` |
| `NavigationStack` | `NavigationView` |
| `Button` with action | `onTapGesture()` (unless you need location/count) |
| `containerRelativeFrame` | `GeometryReader` (when possible) |
| `toolbar` with placement | Manual navigation bar items |

### View Composition

- Prefer modifiers over conditional views for state changes (preserves view identity)
- Extract complex view bodies into subviews
- Keep views small — one responsibility per view
- Pass only necessary values to child views (not whole models when a string will do)

### Performance

- Use stable identity for `ForEach` (never `.indices` for dynamic content)
- Avoid `AnyView` in list rows
- Check for value changes before updating state in hot paths
- Separate business logic into testable models (our MVVM pattern handles this)

### Animations

- Use `.animation(_:value:)` with an explicit value parameter
- Use `withAnimation` for event-driven animations
- Prefer transforms (offset, scale, rotation) over layout changes for smooth animation

### Not Applicable to Overwatch

- Liquid Glass / iOS 26 styling — we are macOS only, dark tactical aesthetic
- `NavigationSplitView` patterns — we use `WindowGroup` multi-window instead

---

## Skill: Swift MVVM (tobitech/swift-mvvm)

> Source: https://skills.sh/tobitech/swift-mvvm/swift-mvvm

### Core Stance

- **Keep the ViewModel UI-framework agnostic.** ViewModels should **not** import `SwiftUI`, `UIKit`, or `AppKit`.
- The ViewModel should be mostly **(1) state**, **(2) intent methods**, and **(3) dependency coordination**.
- Push work into **smaller, testable units** (pure structs/functions, use cases, controllers, repositories, mappers, formatters).
- Use **dependency injection** with protocols so everything is mockable.
- Extensions are encouraged for organization (especially protocol conformances).

### Hard Rule: No UI Framework Imports in ViewModels

If a ViewModel needs a platform behavior, define a tiny protocol in a non-UI module (Foundation-only), and provide a platform implementation in the View layer or a platform adapter module.

```swift
// Foundation-only target
protocol FileRevealing {
  func reveal(_ url: URL)
}

// AppKit layer
import AppKit
struct WorkspaceFileRevealer: FileRevealing {
  func reveal(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}
```

### ViewModel Patterns

**Pattern A — Simple screen:** `State` struct (nested), intent methods, async `load()` with cancellation.

**Pattern B — Complex screen:** `State` struct (nested), `Action` enum + `send(_:)`, reducer-like switch for state transitions, side effects delegated to injected units.

### Structured State (avoid 30 loose vars)

```swift
struct State: Equatable {
  var view = ViewState()
  var content = ContentState()
  var alerts = AlertsState()
}
```

### Refactoring a Massive ViewModel (priority order)

1. **Extract pure logic first** — filtering, sorting, mapping, formatting, validation, reducers → pure structs/functions
2. **Extract side effects into controllers** — IO and orchestration behind protocols → `UseCase`, `Controller`, `Repository`
3. **Leave the VM as state + intents** — forward intents to pure logic/effect units, assign state

### Concurrency & Cancellation

- UI state changes on the **main actor**
- Store ongoing tasks and cancel them on new requests or view disappearance

### Dependency Injection

- ViewModel takes dependencies in its initializer
- Dependencies are protocols; provide production impl and mock/fake for tests
- Inject small units: pure logic (`RowBuilder`, `Validator`), effects (`UseCase`, `Controller`), platform adapters (`FileRevealing`, `URLOpening`)

### Naming Conventions

- `FooViewModel`, `FooState`, `FooUseCase`, `FooRepository`, `FooController`, `FooRowBuilder`

### Testing

- Prefer **Swift Testing** (`import Testing`, `@Test`, `#expect`, `#require`) for new tests
- Test pure logic units directly (fast, deterministic)
- Test ViewModel state transitions (success/failure/cancellation) by injecting mocks

### ViewModel Smells (avoid these)

- Imports UI frameworks
- Does URLSession/JSON decoding directly
- Builds NSAlert/UIAlertController
- Knows about NSWorkspace/UIApplication
- Formats everything inline with complex logic
- Handles navigation, analytics, networking, caching all together

### Reference Material

Full references and templates available at: `~/.claude/skills/swift-mvvm/`
- MVVM Overview, Module Structure, File Naming, Where Things Go
- Common Patterns, Adding New Features, Integration Patterns, Anti-Patterns
- Testing Considerations, Services vs Feature Services, Controller vs Coordinator
- State Management
- Templates: ObservationViewModel, CombineViewModel, AppKitViewController, ProtocolAdapters, ViewModelTests
