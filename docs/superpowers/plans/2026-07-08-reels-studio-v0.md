# Reels Studio v0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing Reels tab into a polished native share-ready studio for rendering and sharing Grow time-lapse reels.

**Architecture:** Keep rendering in `ReelRenderingService`, move Reels presentation out of `RootView.swift` into a focused `ReelsScreen.swift`, and add pure policy/visual-contract helpers so readiness, sharing, and anti-slop layout constants are testable. The UI remains SwiftUI-first and uses native `ShareLink` for exported `.mov` files.

**Tech Stack:** SwiftUI, SwiftData, Swift 5.0, iOS 26.2, `@Observable` services, AVFoundation renderer already present, XcodeBuildMCP for simulator screenshots.

## Global Constraints

- Work directly on `main`.
- Skip widget work for this slice.
- Apple system fonts only. No serif or non-system display treatment in app screens.
- Use `GrowType`, `GrowPalette`, `GrowSpacing`, and `GrowRadius` instead of one-off styling.
- Keep photos and rendered reels as files in App Group storage; do not store full video bytes in SwiftData.
- Sharing must use SwiftUI `ShareLink` with a local `.mov` file URL.
- Share affordance appears only when an export URL exists on disk.
- Every UI modification must get XcodeBuildMCP screenshot QA for padding, hierarchy, optical sizing, and anti-slop design.
- Required build after implementation:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

---

## Living Todo

- [x] Task 1: Add Reels studio policy and visual contract with focused tests.
- [x] Task 2: Extract and polish the Reels studio UI.
- [x] Task 3: Verify share/export behavior and simulator visual quality.
- [ ] Task 4: Commit and push the verified implementation.

## Change Log

- 2026-07-08: Initial plan created from approved Reels Studio v0 design spec.
- 2026-07-08: Started Task 1, adding pure Reels readiness/share policy and visual contract tests.
- 2026-07-08: Completed Task 1. Added `ReelStudioPolicy`, `ReelStudioVisualContract`, and focused tests for progress, status, share URL eligibility, and anti-slop layout constants. All 7 focused tests passed on iPhone 17 Pro.
- 2026-07-08: Started Task 2. Extracting Reels views from `RootView.swift` and applying the share-ready studio layout.
- 2026-07-08: Task 2 visual QA failed the first pass. The 258pt poster pushed status below the tab bar, and the framed readiness strip truncated copy and read as a generic stacked card. Revising to a 208pt poster, 16pt studio rhythm, and unframed readiness/status rows.
- 2026-07-08: Task 2 Accessibility Medium QA failed. The masthead wrapped safely, but readiness labels split mid-word and status fell behind the tab bar. Adding accessibility-specific 164pt poster geometry, 12pt rhythm, and compact metric copy.
- 2026-07-09: Task 2 Accessibility Medium QA still exposed poster-overlay wrapping: `captured` split inside the preview card. Adding compact poster overlay typography so decorative media chrome does not inherit oversized text.
- 2026-07-11: Completed Task 2. Extracted the studio into `ReelsScreen.swift`, kept poster/action/status in the first viewport, added compact Dynamic Type geometry, validated local export URLs before presenting share actions, and removed the generic nested-card treatment.
- 2026-07-11: Completed Task 3. Sosumi confirmed native `ShareLink` file sharing and the AVFoundation pixel-buffer writer approach. XcodeBuildMCP passed all 21 tests and built/launched on iPhone 17 Pro (iOS 26.2). Standard, exported, and Accessibility Large screenshots passed visual QA. The rendered six-frame `.mov` was 78,015 bytes, and semantic UI snapshots exposed both latest-reel and per-export share actions.

## File Structure

- Create `Grow/Domain/ReelStudioPolicy.swift`
  - Owns pure progress, duration, status, share URL, and visual-contract constants.
  - Has no SwiftData dependency.
- Create `Grow/Views/ReelsScreen.swift`
  - Owns `ReelsScreen`, `ReelStudio`, preview, status, action, export list, and empty state.
  - Imports `SwiftUI`, `SwiftData`, and `UIKit` for thumbnail rendering only.
- Modify `Grow/Views/RootView.swift`
  - Keep the Reels tab entry that initializes `ReelsScreen()`.
  - Remove Reels-specific view structs after extraction.
  - Remove `import UIKit` if no longer needed in `RootView.swift`.
- Create `GrowTests/ReelStudioPolicyTests.swift`
  - Tests pure readiness/progress/duration/share URL logic.
- Create `GrowTests/ReelStudioVisualContractTests.swift`
  - Tests layout constants and anti-slop checklist.
- Modify `docs/superpowers/plans/2026-07-08-reels-studio-v0.md`
  - Update todo and change log after each meaningful implementation step.

## Task 1: Add Reels Studio Policy And Visual Contract

**Files:**
- Create: `Grow/Domain/ReelStudioPolicy.swift`
- Create: `GrowTests/ReelStudioPolicyTests.swift`
- Create: `GrowTests/ReelStudioVisualContractTests.swift`
- Modify: `docs/superpowers/plans/2026-07-08-reels-studio-v0.md`

**Interfaces:**
- Produces:
  - `enum ReelStudioPolicy`
  - `enum ReelStudioStatus: Equatable`
  - `enum ReelStudioVisualContract`
  - `ReelStudioPolicy.progress(frameCount:targetFrameCount:) -> Double`
  - `ReelStudioPolicy.progressPercent(frameCount:targetFrameCount:) -> Int`
  - `ReelStudioPolicy.progressText(frameCount:targetFrameCount:) -> String`
  - `ReelStudioPolicy.durationText(_:) -> String`
  - `ReelStudioPolicy.status(frameCount:isRendering:renderedFrameCount:renderedDurationSeconds:errorMessage:) -> ReelStudioStatus`
  - `ReelStudioPolicy.shareURL(localFileName:containerURL:fileExists:) -> URL?`
- Consumes:
  - `Foundation.URL`
  - `CoreGraphics.CGFloat`

- [ ] **Step 1: Update this plan before changing source**

Change the Living Todo section:

```markdown
- [x] Task 1: Add Reels studio policy and visual contract with focused tests. _(in progress)_
- [ ] Task 2: Extract and polish the Reels studio UI.
- [ ] Task 3: Verify share/export behavior and simulator visual quality.
- [ ] Task 4: Commit and push the verified implementation.
```

Append to Change Log:

```markdown
- 2026-07-08: Started Task 1, adding pure Reels readiness/share policy and visual contract tests.
```

- [ ] **Step 2: Write the failing policy tests**

Create `GrowTests/ReelStudioPolicyTests.swift`:

```swift
import XCTest
@testable import Grow

final class ReelStudioPolicyTests: XCTestCase {
    func testProgressCapsAtFirstThirtyFrames() {
        XCTAssertEqual(ReelStudioPolicy.progress(frameCount: 0), 0)
        XCTAssertEqual(ReelStudioPolicy.progress(frameCount: 15), 0.5)
        XCTAssertEqual(ReelStudioPolicy.progress(frameCount: 45), 1)
    }

    func testProgressTextDescribesFirstThirtyFrameReel() {
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 0), "Frame 1 is waiting")
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 8), "27% of the first 30-frame reel")
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 30), "First 30-frame reel ready")
        XCTAssertEqual(ReelStudioPolicy.progressText(frameCount: 42), "First 30-frame reel ready")
    }

    func testDurationTextUsesSingleDecimalSecond() {
        XCTAssertEqual(ReelStudioPolicy.durationText(5.36), "5.4s")
        XCTAssertEqual(ReelStudioPolicy.durationText(12), "12.0s")
    }

    func testStatusPriority() {
        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 0,
                isRendering: false,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: nil
            ),
            .noFrames
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: true,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: "Previous error"
            ),
            .rendering
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: false,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: "Writer failed"
            ),
            .failed("Writer failed")
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: false,
                renderedFrameCount: 8,
                renderedDurationSeconds: 5.36,
                errorMessage: nil
            ),
            .rendered(frameCount: 8, durationText: "5.4s")
        )

        XCTAssertEqual(
            ReelStudioPolicy.status(
                frameCount: 8,
                isRendering: false,
                renderedFrameCount: nil,
                renderedDurationSeconds: nil,
                errorMessage: nil
            ),
            .ready(progressPercent: 27)
        )
    }

    func testShareURLRequiresNonEmptyExistingLocalFile() {
        let container = URL(fileURLWithPath: "/tmp/GrowShareRoot", isDirectory: true)

        XCTAssertNil(
            ReelStudioPolicy.shareURL(
                localFileName: "",
                containerURL: container,
                fileExists: { _ in true }
            )
        )

        XCTAssertNil(
            ReelStudioPolicy.shareURL(
                localFileName: "Reels/missing.mov",
                containerURL: container,
                fileExists: { _ in false }
            )
        )

        let url = ReelStudioPolicy.shareURL(
            localFileName: "Reels/grow/reel.mov",
            containerURL: container,
            fileExists: { $0.path.hasSuffix("/Reels/grow/reel.mov") }
        )

        XCTAssertEqual(url?.path, "/tmp/GrowShareRoot/Reels/grow/reel.mov")
    }
}
```

- [ ] **Step 3: Write the failing visual contract tests**

Create `GrowTests/ReelStudioVisualContractTests.swift`:

```swift
import XCTest
@testable import Grow

final class ReelStudioVisualContractTests: XCTestCase {
    func testStudioLayoutConstantsProtectFirstViewport() {
        XCTAssertEqual(ReelStudioVisualContract.previewMaxWidth, 258)
        XCTAssertEqual(ReelStudioVisualContract.previewAspectRatio, 9.0 / 16.0)
        XCTAssertEqual(ReelStudioVisualContract.primaryActionHeight, 52)
        XCTAssertEqual(ReelStudioVisualContract.shareButtonSize, 52)
        XCTAssertEqual(ReelStudioVisualContract.exportThumbnailWidth, 40)
        XCTAssertEqual(ReelStudioVisualContract.exportThumbnailHeight, 54)
        XCTAssertEqual(ReelStudioVisualContract.exportRowVerticalPadding, 10)
        XCTAssertEqual(ReelStudioVisualContract.exportRowHorizontalPadding, 12)
        XCTAssertEqual(ReelStudioVisualContract.bottomScrollPadding, 96)
    }

    func testAntiSlopChecklistCoversReelsSpecificDesignRisks() {
        let checklist = ReelStudioVisualContract.antiSlopChecklist

        XCTAssertTrue(checklist.contains("Apple native system typography only"))
        XCTAssertTrue(checklist.contains("Preview, action, and status visible in first viewport"))
        XCTAssertTrue(checklist.contains("Even padding inside Reels surfaces"))
        XCTAssertTrue(checklist.contains("No nested-card effect"))
        XCTAssertTrue(checklist.contains("Share icon aligned to primary action height"))
        XCTAssertTrue(checklist.contains("Export rows use fixed 9:16 thumbnails"))
        XCTAssertTrue(checklist.contains("No generic AI-generated mobile card stack"))
    }
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run:

```bash
xcodebuild test -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GrowTests/ReelStudioPolicyTests -only-testing:GrowTests/ReelStudioVisualContractTests
```

Expected: FAIL because `ReelStudioPolicy`, `ReelStudioStatus`, and `ReelStudioVisualContract` are not defined. If sandboxed CoreSimulator access blocks the command, rerun the exact command with approval.

- [ ] **Step 5: Add the policy and visual contract**

Create `Grow/Domain/ReelStudioPolicy.swift`:

```swift
import CoreGraphics
import Foundation

enum ReelStudioStatus: Equatable {
    case noFrames
    case ready(progressPercent: Int)
    case rendering
    case rendered(frameCount: Int, durationText: String)
    case failed(String)
}

enum ReelStudioPolicy {
    static let defaultTargetFrameCount = 30

    static func progress(
        frameCount: Int,
        targetFrameCount: Int = defaultTargetFrameCount
    ) -> Double {
        guard targetFrameCount > 0 else { return 0 }
        return min(1, max(0, Double(frameCount) / Double(targetFrameCount)))
    }

    static func progressPercent(
        frameCount: Int,
        targetFrameCount: Int = defaultTargetFrameCount
    ) -> Int {
        Int((progress(frameCount: frameCount, targetFrameCount: targetFrameCount) * 100).rounded())
    }

    static func progressText(
        frameCount: Int,
        targetFrameCount: Int = defaultTargetFrameCount
    ) -> String {
        if frameCount <= 0 {
            return "Frame 1 is waiting"
        }
        if frameCount >= targetFrameCount {
            return "First \(targetFrameCount)-frame reel ready"
        }
        return "\(progressPercent(frameCount: frameCount, targetFrameCount: targetFrameCount))% of the first \(targetFrameCount)-frame reel"
    }

    static func durationText(_ duration: Double) -> String {
        String(format: "%.1fs", duration)
    }

    static func status(
        frameCount: Int,
        isRendering: Bool,
        renderedFrameCount: Int?,
        renderedDurationSeconds: Double?,
        errorMessage: String?
    ) -> ReelStudioStatus {
        if isRendering {
            return .rendering
        }
        if let errorMessage {
            return .failed(errorMessage)
        }
        if let renderedFrameCount, let renderedDurationSeconds {
            return .rendered(
                frameCount: renderedFrameCount,
                durationText: durationText(renderedDurationSeconds)
            )
        }
        if frameCount <= 0 {
            return .noFrames
        }
        return .ready(progressPercent: progressPercent(frameCount: frameCount))
    }

    static func shareURL(
        localFileName: String,
        containerURL: URL,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL? {
        guard !localFileName.isEmpty else { return nil }
        let url = containerURL.appendingPathComponent(localFileName)
        guard fileExists(url) else { return nil }
        return url
    }
}

enum ReelStudioVisualContract {
    static let previewMaxWidth: CGFloat = 258
    static let previewAspectRatio: CGFloat = 9.0 / 16.0
    static let primaryActionHeight: CGFloat = 52
    static let shareButtonSize: CGFloat = 52
    static let exportThumbnailWidth: CGFloat = 40
    static let exportThumbnailHeight: CGFloat = 54
    static let exportRowVerticalPadding: CGFloat = 10
    static let exportRowHorizontalPadding: CGFloat = 12
    static let bottomScrollPadding: CGFloat = 96

    static let antiSlopChecklist = [
        "Apple native system typography only",
        "Preview, action, and status visible in first viewport",
        "Even padding inside Reels surfaces",
        "No nested-card effect",
        "Share icon aligned to primary action height",
        "Export rows use fixed 9:16 thumbnails",
        "No generic AI-generated mobile card stack"
    ]
}
```

- [ ] **Step 6: Run focused tests and verify they pass**

Run:

```bash
xcodebuild test -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GrowTests/ReelStudioPolicyTests -only-testing:GrowTests/ReelStudioVisualContractTests
```

Expected: PASS for `ReelStudioPolicyTests` and `ReelStudioVisualContractTests`.

- [ ] **Step 7: Update plan and commit Task 1**

Change Living Todo:

```markdown
- [x] Task 1: Add Reels studio policy and visual contract with focused tests.
- [ ] Task 2: Extract and polish the Reels studio UI.
- [ ] Task 3: Verify share/export behavior and simulator visual quality.
- [ ] Task 4: Commit and push the verified implementation.
```

Append Change Log:

```markdown
- 2026-07-08: Completed Task 1. Added `ReelStudioPolicy`, `ReelStudioVisualContract`, and focused tests for progress, status, share URL eligibility, and anti-slop layout constants.
```

Run:

```bash
git diff --check
git add Grow/Domain/ReelStudioPolicy.swift GrowTests/ReelStudioPolicyTests.swift GrowTests/ReelStudioVisualContractTests.swift docs/superpowers/plans/2026-07-08-reels-studio-v0.md
git commit -m "Add Reels studio policy"
```

Expected: commit succeeds.

## Task 2: Extract And Polish The Reels Studio UI

**Files:**
- Create: `Grow/Views/ReelsScreen.swift`
- Modify: `Grow/Views/RootView.swift`
- Modify: `docs/superpowers/plans/2026-07-08-reels-studio-v0.md`
- Test: `GrowTests/ReelStudioPolicyTests.swift`
- Test: `GrowTests/ReelStudioVisualContractTests.swift`

**Interfaces:**
- Consumes:
  - `ReelStudioPolicy.progress(frameCount:)`
  - `ReelStudioPolicy.progressText(frameCount:)`
  - `ReelStudioPolicy.status(frameCount:isRendering:renderedFrameCount:renderedDurationSeconds:errorMessage:)`
  - `ReelStudioPolicy.shareURL(localFileName:containerURL:)`
  - `ReelStudioVisualContract` constants
  - `ReelRenderingService.renderPreview(for:species:)`
  - `AppGroup.containerURL`
- Produces:
  - `struct ReelsScreen: View` in `Grow/Views/ReelsScreen.swift`
  - Cleaner `RootView.swift` that only references `ReelsScreen` from the tab

- [ ] **Step 1: Update this plan before changing UI**

Change Living Todo:

```markdown
- [x] Task 1: Add Reels studio policy and visual contract with focused tests.
- [x] Task 2: Extract and polish the Reels studio UI. _(in progress)_
- [ ] Task 3: Verify share/export behavior and simulator visual quality.
- [ ] Task 4: Commit and push the verified implementation.
```

Append Change Log:

```markdown
- 2026-07-08: Started Task 2. Extracting Reels views from `RootView.swift` and applying the share-ready studio layout.
```

- [ ] **Step 2: Move Reels-specific views into a new file**

Create `Grow/Views/ReelsScreen.swift` with this file header and public screen shell:

```swift
import SwiftUI
import SwiftData
import UIKit

struct ReelsScreen: View {
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(ReelRenderingService.self) private var reelRenderingService
    @Query(
        filter: #Predicate<Grow> { $0.isActive && $0.archivedDate == nil },
        sort: \Grow.startDate, order: .reverse
    ) private var grows: [Grow]

    var body: some View {
        ZStack {
            PaperBackground(light: 0.48)
            if let grow = grows.first {
                ReelStudio(grow: grow, species: catalog.species(id: grow.speciesID))
                    .environment(reelRenderingService)
            } else {
                FirstReelEmptyState()
            }
        }
    }
}
```

Move these existing Reels-related declarations from `RootView.swift` into this file before editing their layout:

- `private struct ReelStudio: View`
- `private struct ReelPosterPreview: View`
- `private struct ReelExportRow: View`
- `private struct StatusRow: View`
- `private struct FirstReelEmptyState: View`

Do not move unrelated placeholder views, home/today/dex views, or capture views.

- [ ] **Step 3: Remove moved Reels structs from `RootView.swift`**

Modify `Grow/Views/RootView.swift`:

```swift
import SwiftUI
import SwiftData
```

Keep this tab unchanged:

```swift
Tab("Reels", systemImage: "play.rectangle", value: .reels) { ReelsScreen() }
```

Delete only the moved Reels block, starting at:

```swift
struct ReelsScreen: View {
```

and ending immediately before:

```swift
struct DexScreen: View {
```

If `RootView.swift` still needs `UIKit` after deletion, keep the import; otherwise remove it.

- [ ] **Step 4: Replace the `ReelStudio` body with the polished first-viewport layout**

In `Grow/Views/ReelsScreen.swift`, implement `ReelStudio` with these computed values and body shape:

```swift
private struct ReelStudio: View {
    @Environment(ReelRenderingService.self) private var reelRenderingService
    let grow: Grow
    let species: PlantSpecies?

    private var photos: [GrowPhoto] {
        (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    private var reels: [Reel] {
        (grow.reels ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var latestShareURL: URL? {
        if let result = reelRenderingService.lastResult,
           let url = ReelStudioPolicy.shareURL(
                localFileName: result.localFileName,
                containerURL: AppGroup.containerURL
           ) {
            return url
        }

        guard let latestReel = reels.first else { return nil }
        return ReelStudioPolicy.shareURL(
            localFileName: latestReel.localFileName,
            containerURL: AppGroup.containerURL
        )
    }

    private var status: ReelStudioStatus {
        ReelStudioPolicy.status(
            frameCount: photos.count,
            isRendering: reelRenderingService.isRendering,
            renderedFrameCount: reelRenderingService.lastResult?.frameCount,
            renderedDurationSeconds: reelRenderingService.lastResult?.durationSeconds,
            errorMessage: reelRenderingService.lastErrorMessage
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GrowSpacing.lg) {
                masthead
                    .growEntrance(0)

                ReelPosterPreview(
                    grow: grow,
                    species: species,
                    latestPhoto: photos.last,
                    frameCount: photos.count
                )
                .frame(maxWidth: ReelStudioVisualContract.previewMaxWidth)
                .frame(maxWidth: .infinity)
                .growEntrance(1)

                ReelReadinessStrip(
                    latestDay: photos.last?.dayIndex ?? grow.dayCount,
                    frameCount: photos.count
                )
                .growEntrance(2)

                ReelActionCluster(
                    frameCount: photos.count,
                    status: status,
                    shareURL: latestShareURL,
                    displayName: displayName,
                    isRendering: reelRenderingService.isRendering,
                    render: {
                        Task {
                            await reelRenderingService.renderPreview(for: grow, species: species)
                        }
                    }
                )
                .growEntrance(3)

                if !reels.isEmpty {
                    ReelExportsList(reels: reels)
                        .growEntrance(4)
                }
            }
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.top, GrowSpacing.lg)
            .padding(.bottom, ReelStudioVisualContract.bottomScrollPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            Text("Reel studio")
                .fieldLabel()
            HStack(alignment: .firstTextBaseline, spacing: GrowSpacing.sm) {
                Text(displayName)
                    .growStyle(GrowType.displayHeadline())
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: GrowSpacing.sm)
                Text("\(photos.count)")
                    .growStyle(GrowType.numeral(34, weight: .semibold), color: GrowPalette.sprout600)
                    .monospacedDigit()
                Text("frames")
                    .fieldLabel()
            }
            Hairline()
        }
    }

    private var displayName: String {
        grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname
    }
}
```

- [ ] **Step 5: Add the readiness strip**

Add to `Grow/Views/ReelsScreen.swift`:

```swift
private struct ReelReadinessStrip: View {
    let latestDay: Int
    let frameCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: GrowSpacing.md) {
            ReadinessMetric(label: "Latest day", value: "\(latestDay)")
            Divider()
                .frame(height: 28)
            ReadinessMetric(label: "Progress", value: "\(ReelStudioPolicy.progressPercent(frameCount: frameCount))%")
            Spacer(minLength: GrowSpacing.sm)
            Text(ReelStudioPolicy.progressText(frameCount: frameCount))
                .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.86)
        }
        .padding(.horizontal, GrowSpacing.sm)
        .padding(.vertical, GrowSpacing.xs)
        .background(GrowPalette.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.64), lineWidth: 1)
        )
    }
}

private struct ReadinessMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).fieldLabel()
            Text(value)
                .growStyle(GrowType.numeral(24, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(minWidth: 68, alignment: .leading)
    }
}
```

- [ ] **Step 6: Add the action cluster with native sharing**

Add to `Grow/Views/ReelsScreen.swift`:

```swift
private struct ReelActionCluster: View {
    let frameCount: Int
    let status: ReelStudioStatus
    let shareURL: URL?
    let displayName: String
    let isRendering: Bool
    let render: () -> Void

    var body: some View {
        VStack(spacing: GrowSpacing.sm) {
            HStack(spacing: GrowSpacing.sm) {
                Button(action: render) {
                    HStack(spacing: GrowSpacing.xs) {
                        if isRendering {
                            ProgressView()
                                .controlSize(.small)
                                .tint(GrowPalette.bloomInk)
                        } else {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                        }
                        Text(isRendering ? "Rendering" : "Render preview")
                    }
                    .font(GrowType.headline())
                    .foregroundStyle(GrowPalette.bloomInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: ReelStudioVisualContract.primaryActionHeight)
                    .background(GrowPalette.bloom, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(frameCount == 0 || isRendering)
                .opacity(frameCount == 0 ? 0.52 : 1)

                if let shareURL {
                    ShareLink(
                        item: shareURL,
                        subject: Text("\(displayName) grow reel"),
                        message: Text("My Grow time-lapse is ready.")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(GrowPalette.sprout800)
                            .frame(
                                width: ReelStudioVisualContract.shareButtonSize,
                                height: ReelStudioVisualContract.shareButtonSize
                            )
                            .background(GrowPalette.sprout100, in: Circle())
                    }
                    .accessibilityLabel("Share latest reel")
                }
            }

            ReelStatusRow(status: status)
        }
    }
}
```

- [ ] **Step 7: Replace `StatusRow` with `ReelStatusRow`**

Add to `Grow/Views/ReelsScreen.swift`:

```swift
private struct ReelStatusRow: View {
    let status: ReelStudioStatus

    var body: some View {
        HStack(spacing: GrowSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, GrowSpacing.sm)
        .padding(.vertical, 10)
        .background(GrowPalette.surface.opacity(0.76), in: Capsule())
        .overlay(
            Capsule()
                .stroke(GrowPalette.separator.opacity(0.6), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch status {
        case .noFrames:
            "camera.fill"
        case .ready:
            "play.rectangle.fill"
        case .rendering:
            "hourglass"
        case .rendered:
            "checkmark.seal.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var text: String {
        switch status {
        case .noFrames:
            "Frame 1 is waiting"
        case .ready(let progressPercent):
            "\(progressPercent)% of the first 30-frame reel"
        case .rendering:
            "Rendering your latest reel"
        case .rendered(let frameCount, let durationText):
            "\(frameCount) frames rendered in \(durationText)"
        case .failed(let message):
            message
        }
    }

    private var tint: Color {
        switch status {
        case .noFrames:
            GrowPalette.info
        case .ready:
            GrowPalette.sprout600
        case .rendering:
            GrowPalette.bloom
        case .rendered:
            GrowPalette.healthy
        case .failed:
            GrowPalette.needsCare
        }
    }
}
```

- [ ] **Step 8: Tighten the poster preview**

Update `ReelPosterPreview` in `Grow/Views/ReelsScreen.swift` so it uses the visual contract constants and does not look like a card inside a card:

```swift
private struct ReelPosterPreview: View {
    let grow: Grow
    let species: PlantSpecies?
    let latestPhoto: GrowPhoto?
    let frameCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            posterImage
                .frame(maxWidth: .infinity)
                .aspectRatio(ReelStudioVisualContract.previewAspectRatio, contentMode: .fit)
                .clipped()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: GrowSpacing.xs) {
                Text("Future reel")
                    .fieldLabel(color: .white.opacity(0.74))
                Text("Day \(latestPhoto?.dayIndex ?? grow.dayCount)")
                    .growStyle(GrowType.numeral(52, weight: .semibold), color: .white)
                    .monospacedDigit()
                HStack(spacing: GrowSpacing.xs) {
                    Image(systemName: frameCount > 0 ? "checkmark.seal.fill" : "camera.fill")
                    Text(frameCount > 0 ? "\(frameCount) frames captured" : "Frame 1 is waiting")
                }
                .font(GrowType.callout(.semibold))
                .foregroundStyle(.white.opacity(0.86))

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.28))
                        Capsule()
                            .fill(GrowPalette.bloom)
                            .frame(width: proxy.size.width * max(0.04, ReelStudioPolicy.progress(frameCount: frameCount)))
                    }
                }
                .frame(height: 9)
                .padding(.top, 4)
            }
            .padding(GrowSpacing.md)
        }
        .background(GrowPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reel preview for \(displayName), Day \(latestPhoto?.dayIndex ?? grow.dayCount), \(frameCount) frames")
    }

    @ViewBuilder
    private var posterImage: some View {
        if let data = latestPhoto?.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                GrowPalette.groundRaised
                SpecimenJar(
                    progress: grow.currentStage.growthProgress,
                    hasBloom: grow.currentStage.hasBloom,
                    size: 240
                )
            }
        }
    }

    private var displayName: String {
        grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname
    }
}
```

- [ ] **Step 9: Replace exports with fixed row metrics and file-gated share**

Add `ReelExportsList` and update `ReelExportRow`:

```swift
private struct ReelExportsList: View {
    let reels: [Reel]

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.sm) {
            HStack {
                Text("Exports").fieldLabel()
                Spacer()
                Text("\(reels.count)")
                    .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                    .monospacedDigit()
            }

            VStack(spacing: 0) {
                ForEach(reels) { reel in
                    ReelExportRow(reel: reel)
                    if reel.id != reels.last?.id {
                        Hairline()
                            .padding(.leading, ReelStudioVisualContract.exportThumbnailWidth + GrowSpacing.lg)
                    }
                }
            }
            .background(GrowPalette.surface.opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(GrowPalette.separator.opacity(0.74), lineWidth: 1)
            )
        }
    }
}

private struct ReelExportRow: View {
    let reel: Reel

    private var shareURL: URL? {
        ReelStudioPolicy.shareURL(
            localFileName: reel.localFileName,
            containerURL: AppGroup.containerURL
        )
    }

    var body: some View {
        HStack(spacing: GrowSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(GrowPalette.sprout50)
                if let data = reel.posterFrameData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout600)
                }
            }
            .frame(
                width: ReelStudioVisualContract.exportThumbnailWidth,
                height: ReelStudioVisualContract.exportThumbnailHeight
            )
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(reel.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .growStyle(GrowType.callout(.semibold))
                    .lineLimit(1)
                Text("\(reel.photoCount) frames - \(ReelStudioPolicy.durationText(reel.durationSeconds))")
                    .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }

            Spacer(minLength: GrowSpacing.sm)

            if let shareURL {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout600)
                        .frame(width: GrowSpacing.touchTargetMin, height: GrowSpacing.touchTargetMin)
                }
                .accessibilityLabel("Share reel")
            }
        }
        .padding(.horizontal, ReelStudioVisualContract.exportRowHorizontalPadding)
        .padding(.vertical, ReelStudioVisualContract.exportRowVerticalPadding)
    }
}
```

- [ ] **Step 10: Keep the no-grow empty state native and quiet**

Update `FirstReelEmptyState`:

```swift
private struct FirstReelEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.md) {
            Text("Reel studio").fieldLabel().growEntrance(0)
            Text("Plant first, then motion follows.")
                .growStyle(GrowType.displayTitle())
                .fixedSize(horizontal: false, vertical: true)
                .growEntrance(1)
            Hairline().growEntrance(2)
            SpecimenJar(progress: 0.08, size: 260)
                .frame(maxWidth: .infinity)
                .growEntrance(3)
            ReelStatusRow(status: .noFrames)
                .growEntrance(4)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GrowSpacing.lg)
        .padding(.top, GrowSpacing.xl)
    }
}
```

- [ ] **Step 11: Run focused tests and build**

Run focused tests:

```bash
xcodebuild test -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GrowTests/ReelStudioPolicyTests -only-testing:GrowTests/ReelStudioVisualContractTests
```

Expected: PASS.

Run required build:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **`. If sandboxed CoreSimulator access blocks either command, rerun the same command with approval.

- [ ] **Step 12: Update plan and commit Task 2**

Change Living Todo:

```markdown
- [x] Task 1: Add Reels studio policy and visual contract with focused tests.
- [x] Task 2: Extract and polish the Reels studio UI.
- [ ] Task 3: Verify share/export behavior and simulator visual quality.
- [ ] Task 4: Commit and push the verified implementation.
```

Append Change Log:

```markdown
- 2026-07-08: Completed Task 2. Extracted Reels views to `Grow/Views/ReelsScreen.swift`, applied the share-ready studio layout, and gated share links on existing export files.
```

Run:

```bash
git diff --check
git add Grow/Views/RootView.swift Grow/Views/ReelsScreen.swift docs/superpowers/plans/2026-07-08-reels-studio-v0.md
git commit -m "Polish Reels studio UI"
```

Expected: commit succeeds.

## Task 3: Verify Share, Export, And Visual QA

**Files:**
- Modify: `docs/superpowers/plans/2026-07-08-reels-studio-v0.md`

**Interfaces:**
- Consumes:
  - XcodeBuildMCP simulator defaults/build/run/screenshot tools.
  - Launch args: `-seedSampleGrow -seedSampleCaptures -renderSampleReel -openReels`
  - Bundle ID: `com.sviftstudios.Grow`

- [ ] **Step 1: Update this plan before verification**

Change Living Todo:

```markdown
- [x] Task 1: Add Reels studio policy and visual contract with focused tests.
- [x] Task 2: Extract and polish the Reels studio UI.
- [x] Task 3: Verify share/export behavior and simulator visual quality. _(in progress)_
- [ ] Task 4: Commit and push the verified implementation.
```

Append Change Log:

```markdown
- 2026-07-08: Started Task 3. Running build, export, and mandatory visual QA checks for Reels.
```

- [ ] **Step 2: Use XcodeBuildMCP to build and launch**

Use XcodeBuildMCP in this order:

1. `session_show_defaults`
2. If defaults are missing, set:
   - project: `/Users/shaun/Documents/Code/Svift Studios/Apps/Grow/Grow.xcodeproj`
   - scheme: `Grow`
   - simulator: iPhone 17 Pro
   - derived data: `/tmp/GrowDerivedData`
   - launch args: `-seedSampleGrow -seedSampleCaptures -renderSampleReel -openReels`
3. `build_run_sim`

Expected: build/install/launch succeeds with no diagnostics.

- [ ] **Step 3: Take and inspect the primary screenshot**

Use XcodeBuildMCP screenshot. Save or note the path in the Change Log.

Visual QA checklist:

```markdown
- [ ] Grow identity, preview, action, and status are visible in the first viewport.
- [ ] Preview, action, and status have equal optical alignment.
- [ ] Primary render button is above the tab bar.
- [ ] Share button aligns to the primary action height.
- [ ] Export rows have equal horizontal and vertical padding.
- [ ] Export thumbnails are fixed 9:16 crops.
- [ ] System font hierarchy feels native.
- [ ] Adjacent numbers are optically consistent and use monospaced digits where helpful.
- [ ] No nested-card effect.
- [ ] No generic AI-generated mobile card stack.
- [ ] No clipped, overlapping, or crowded text.
```

If any item fails, return to Task 2, update the plan Change Log with the failure, patch the UI, rebuild, and repeat the screenshot.

- [ ] **Step 4: Run secondary visual pass if required**

This implementation changes preview sizing, masthead typography, action cluster, and export rows, so a secondary pass is required.

Use whichever XcodeBuildMCP support is available:

- Preferred: Dynamic Type accessibility size screenshot.
- Fallback: compact-height iPhone simulator screenshot.
- If neither is exposed, record the tooling limitation and run the iPhone 17 Pro screenshot after increasing relevant text stress through launch state if possible.

Apply the same visual QA checklist from Step 3.

- [ ] **Step 5: Verify the exported movie exists**

Use simulator/app-container inspection. If XcodeBuildMCP has a file helper, use it. Otherwise run:

```bash
xcrun simctl get_app_container booted com.sviftstudios.Grow data
```

Expected: prints the app data container path.

Then inspect for rendered movie files under the app's fallback Documents path or App Group container if available:

```bash
find <APP_DATA_CONTAINER> -path '*Reels/*.mov' -type f -size +0 -print
```

Expected: at least one non-empty `.mov` file.

Do not use a destructive cleanup command. If stale files make the result ambiguous, uninstall/reinstall through XcodeBuildMCP or `simctl uninstall booted com.sviftstudios.Grow` only after confirming the simulator target.

- [ ] **Step 6: Run final command verification**

Run:

```bash
git diff --check
xcodebuild test -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO -only-testing:GrowTests/ReelStudioPolicyTests -only-testing:GrowTests/ReelStudioVisualContractTests
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected:

- `git diff --check` prints no output.
- Focused tests pass.
- Required build succeeds.

If sandboxed CoreSimulator access blocks tests/build, rerun the same command with approval.

- [ ] **Step 7: Update plan and commit Task 3**

Change Living Todo:

```markdown
- [x] Task 1: Add Reels studio policy and visual contract with focused tests.
- [x] Task 2: Extract and polish the Reels studio UI.
- [x] Task 3: Verify share/export behavior and simulator visual quality.
- [ ] Task 4: Commit and push the verified implementation.
```

Append Change Log:

```markdown
- 2026-07-08: Completed Task 3. XcodeBuildMCP visual QA passed on iPhone 17 Pro, secondary visual pass completed, export file verified non-empty, focused tests passed, and required build passed.
```

Run:

```bash
git add docs/superpowers/plans/2026-07-08-reels-studio-v0.md
git commit -m "Verify Reels studio visual QA"
```

Expected: commit succeeds if the plan has verification notes. If no plan changes remain, skip this commit and proceed to Task 4.

## Task 4: Push Verified Implementation

**Files:**
- No source files expected unless verification exposes a defect.

**Interfaces:**
- Consumes:
  - Verified local commits from Tasks 1-3.
- Produces:
  - Remote `main` updated with the Reels Studio v0 implementation.

- [ ] **Step 1: Confirm clean status and latest commits**

Run:

```bash
git status --short
git log -4 --oneline
```

Expected:

- `git status --short` prints no unstaged source changes.
- Latest commits include:
  - `Verify Reels studio visual QA` if Task 3 had plan updates to commit.
  - `Polish Reels studio UI`
  - `Add Reels studio policy`

- [ ] **Step 2: Push main**

Run:

```bash
git push
```

Expected:

```text
main -> main
```

If network sandboxing blocks the push, rerun `git push` with approval.

- [ ] **Step 3: Mark plan complete if changed**

If `docs/superpowers/plans/2026-07-08-reels-studio-v0.md` still has uncommitted status after updating Task 4, change Living Todo:

```markdown
- [x] Task 1: Add Reels studio policy and visual contract with focused tests.
- [x] Task 2: Extract and polish the Reels studio UI.
- [x] Task 3: Verify share/export behavior and simulator visual quality.
- [x] Task 4: Commit and push the verified implementation.
```

Append Change Log:

```markdown
- 2026-07-08: Completed Task 4. Pushed verified Reels Studio v0 implementation to `main`.
```

Then run:

```bash
git add docs/superpowers/plans/2026-07-08-reels-studio-v0.md
git commit -m "Complete Reels studio implementation plan"
git push
```

Expected: final plan status is committed and pushed.

## Self-Review Notes

- Spec coverage: covered studio layout, native sharing, state handling, export history, accessibility, visual QA, required build, and no-widget scope.
- Placeholder scan: no implementation placeholders are intentional; every code-producing task includes concrete code or exact commands.
- Type consistency: `ReelStudioPolicy`, `ReelStudioStatus`, and `ReelStudioVisualContract` names are consistent across tests, UI, and commands.
- Scope: one subsystem, Reels Studio v0 polish. Widget, AI, social, music, and renderer rewrite work are excluded.
