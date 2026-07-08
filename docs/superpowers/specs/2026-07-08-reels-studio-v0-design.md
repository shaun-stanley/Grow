# Reels Studio v0 Design

Date: 2026-07-08
Status: Approved direction, pending implementation plan
Scope: Reels tab share-ready studio polish

## Context

Grow's launch priority after the capture reward loop is the auto time-lapse grow reel. The renderer foundation already exists: `ReelRenderingService` can create a portrait `.mov`, the app can seed sample captures, and the Reels tab has a first-pass studio surface. The next product risk is not whether a movie can be written; it is whether the Reels tab feels native, trustworthy, and emotionally clear enough that a beginner understands the payoff of daily capture.

The user explicitly chose the share-ready studio direction for this slice and asked to skip widget work. This spec therefore focuses on the Reels user surface and only touches renderer internals where required to support clear state, validation, or sharing.

## Apple And Design Sources

The design is anchored in the current Apple documentation checked with Sosumi on 2026-07-08:

- SwiftUI `ShareLink`: use the system sharing presentation for transferable content such as file URLs; provide custom labels and share previews when helpful.
- HIG Collaboration and sharing: place the Share affordance in a convenient, prominent location and keep sharing options simple.
- HIG Progress indicators: communicate rendering as an active task, keep status feedback concise, and prefer determinate progress when the app can report it honestly.
- HIG Layout: place the most important content first, align components to aid scanning, group related items clearly, respect safe areas, and design for Dynamic Type and device variation.

The app-specific design constraints are:

- Apple system fonts only. No serif or non-system display treatment in app screens.
- Use `GrowType`, `GrowPalette`, `GrowSpacing`, and `GrowRadius` instead of one-off styling.
- Keep Living Field Journal warm and tactile, but make the Reels tab feel like a focused native production surface, not a decorative landing page.
- Avoid "AI slop": no generic oversized cards, no mismatched padding, no arbitrary gradients, no ornamental text hierarchy that competes with the primary task.

## Product Goal

Make the Reels tab answer three questions immediately:

1. What reel am I building?
2. Is it ready enough to render or share?
3. What happens when I tap the primary action?

Success means a seeded grow can open directly to Reels and the first viewport feels balanced on an iPhone 17 Pro simulator: preview, progress, render/share action, and status are all visible, optically aligned, and hierarchy is obvious.

## Non-Goals

- No WidgetKit, Live Activity, or App Group extension validation in this slice.
- No AI Plant Doctor work.
- No social/community feed.
- No music picker or watermark settings.
- No full renderer architecture rewrite unless current service state makes the studio impossible to support.
- No non-system fonts.

## User Experience

### Screen Structure

The Reels tab becomes a single-purpose studio:

1. Masthead: compact title, active grow name, and frame count.
2. Preview: a portrait 9:16 reel poster that reads as content, not a card inside a card.
3. Readiness strip: frame count, first-30 progress, latest capture day, and latest export state.
4. Action cluster: one primary render button and one native share affordance when a valid export exists.
5. Exports: a compact history list for previous renders.

The first viewport must avoid burying the primary action below the tab bar. On compact iPhone heights, the preview can scale down, but the visual relationship must remain stable: masthead above preview, action directly below preview, status below action.

### Visual Hierarchy

The preview is the hero. The masthead identifies the grow. The action cluster owns the decision. Export history is secondary.

Typography uses native system styles:

- Masthead title: `GrowType.displayHeadline()` or smaller if the active grow name is long.
- Numbers: `GrowType.numeral` only where a number is the data point, with consistent optical sizing for adjacent numbers.
- Labels: `fieldLabel()` only for true labels, not paragraph copy.
- Status copy: `GrowType.callout()` with one line preferred and two lines maximum.

Spacing must use a predictable rhythm:

- Outer horizontal margin: `GrowSpacing.lg`.
- Section gaps: `GrowSpacing.lg`.
- Internal group gaps: `GrowSpacing.sm` or `GrowSpacing.md`.
- Primary controls: minimum 44 pt hit target.
- Surface corners: 8 pt for content cards unless an existing reusable component requires otherwise; avoid nested-card styling.

### States

The studio supports these states:

- No active grow: calm empty state that points back to planting without pretending a reel exists.
- Active grow, zero frames: preview shell plus "Frame 1 is waiting"; render disabled.
- Frames captured, no export: render enabled; progress toward first 30-frame reel shown.
- Rendering: primary action disabled, spinner in button, stable status text; no layout jump.
- Render success: share affordance visible, status includes frame count and duration.
- Render failure: concise error row with a recovery path via render retry.
- Existing export: latest share affordance visible even before rendering again.

### Sharing

Sharing uses `ShareLink` with the local `.mov` file URL. The share affordance should be prominent but not compete with the primary render action. If a latest export exists, share is available. If no export exists, share is hidden rather than disabled to avoid a dead control.

If the current file URL does not exist, the studio should not offer sharing and should show an export-missing state only if that missing file is user-visible through the export row.

### Export History

Exports appear as a compact native list:

- Poster thumbnail.
- Render date.
- Frame count and duration.
- Share icon if file exists.

Rows must have equal padding and stable heights. If thumbnails vary, they are cropped into a fixed 9:16 miniature.

## Architecture

### Existing Boundaries

Keep `ReelRenderingService` responsible for rendering and persistence. Keep `ReelsScreen`/`ReelStudio` responsible for presentation and user actions. Do not move renderer drawing logic into SwiftUI views.

### Proposed Additions

Introduce small value helpers when they make the Reels surface more testable or prevent repeated view logic:

- A `ReelStudioState` or computed state helper for UI readiness, share URL, progress text, and latest export.
- A visual contract helper if layout constants need test coverage.
- A file-existence helper for export rows if repeated checks become noisy.

The implementation should avoid growing `RootView.swift` indefinitely. If the slice changes more than three Reels-specific view structs or adds a pure Reels state helper, extract Reels-specific views into `Grow/Views/ReelsScreen.swift` while keeping the public `ReelsScreen` name stable.

### Data Flow

1. `ReelsScreen` queries the active grow.
2. `ReelStudio` derives sorted photos and reels from the grow.
3. Render taps call `await ReelRenderingService.renderPreview(for:species:)`.
4. `ReelRenderingService` writes the `.mov` to App Group storage, persists a `Reel`, and publishes `lastResult` or `lastErrorMessage`.
5. `ReelStudio` exposes a `ShareLink` only for the latest existing export URL.

No full video bytes are stored in SwiftData.

## Error Handling

Errors should be human and specific:

- No frames: "Capture a plant photo before rendering a reel."
- Missing export file: do not share; offer render again.
- Render failure: show the localized renderer error and leave the render button available after the task completes.

The UI should not present technical details like pixel buffers, writer status, or App Group internals.

## Accessibility

- All controls must have 44 pt minimum hit targets.
- Share buttons need explicit accessibility labels.
- Preview should combine into a clear accessibility label that includes grow name, day, and frame count.
- Dynamic Type must not cause button text, status text, or export row labels to clip.
- Reduce Motion must not be required for functionality; this slice can preserve current entrance animations if they do not create layout instability.
- Color must not be the only indicator of status; use icon plus text plus tint.

## Visual QA Requirements

Every UI modification in this slice must be visually checked with XcodeBuildMCP screenshots. The QA checklist is mandatory:

- Padding is even inside each surface and between sibling surfaces.
- The first viewport has a clear reading order: grow identity, preview, action, status.
- Buttons and share icons align to the same optical grid.
- The portrait preview does not push the render action under the tab bar.
- System font hierarchy feels native; no serif fonts, no custom-looking display treatment.
- Adjacent numbers look optically consistent.
- No nested-card effect.
- No text clipping, overlap, or awkward truncation at the tested size.
- The screen does not read as generic AI-generated mobile UI.

Primary visual pass:

- iPhone 17 Pro simulator
- Launch args: `-seedSampleGrow -seedSampleCaptures -renderSampleReel -openReels`
- Capture screenshot after launch and inspect the Reels first viewport.

Secondary visual pass is required if the implementation changes the Reels preview sizing, masthead typography, action cluster, or export row layout:

- A compact iPhone-height simulator or Dynamic Type accessibility size, if available through the active XcodeBuildMCP toolset.

## Testing And Verification

Docs-only spec work does not require an Xcode build. Implementation must run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Implementation should also run focused tests where added:

- Reels studio state/readiness tests if a pure helper is introduced.
- Renderer file-existence/share URL tests only if they can be reliable without simulator file-system coupling.

Manual verification must include:

- XcodeBuildMCP build/run on iPhone 17 Pro.
- Screenshot of the seeded Reels screen.
- Rendered `.mov` file exists and is non-empty when auto-render launch arg is used.
- `git diff --check`.

## Implementation Plan Requirements

The implementation plan must include a living todo and a change log. Every time a meaningful implementation step changes files, update the plan before continuing. The plan must explicitly track:

- Design-system and typography constraints.
- Reels UI extraction or non-extraction decision.
- Rendering/share state changes.
- Tests and visual QA screenshots.
- Commits and pushes.

## Acceptance Criteria

- Reels tab presents a polished share-ready studio for the active grow.
- The seeded first viewport on iPhone 17 Pro is optically balanced and not card-heavy.
- Primary render and share affordances follow current Apple sharing and progress guidance.
- No serif fonts or non-system app typography are introduced.
- Share affordance appears only when an export URL exists.
- Exports list has consistent row padding, thumbnail sizing, and action placement.
- Visual QA explicitly passes the anti-slop checklist above.
- Required Xcode build passes after implementation.
- Changes are committed and pushed to `main` after verification.
