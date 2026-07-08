# Capture Loop v0.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Grow's Day 1-7 capture ritual emotionally rewarding and camera-trustworthy, with honest alignment metadata, deterministic QA states, accessible reward UI, and focused tests.

**Architecture:** Keep the existing SwiftUI + SwiftData app shell and `@Observable` service pattern. Extract pure capture/reward policy into small domain files so tests can cover the Day 1-7 emotional logic without SwiftData, then keep `PhotoService` as the single persistence/media write path and `CameraCaptureService` as the only hardware configuration boundary.

**Tech Stack:** SwiftUI, SwiftData, Observation, AVFoundation, Vision, XCTest, iOS 26.2, XcodeBuildMCP, Sosumi Apple docs.

## Global Constraints

- iOS 26.2 is intentional. Do not lower the deployment target.
- Work directly on `main`; create `codex/...` branches only if explicitly requested.
- Use native SwiftUI, SwiftData, Swift 5.0, and `@Observable` services injected through `.environment()`.
- Verify Apple platform APIs and behavior with Sosumi before implementation work in each platform task.
- Use the existing design system in `Grow/DesignSystem/` before adding new visual primitives.
- Store photos and rendered reels as files in the App Group container `group.com.sviftstudios.Grow`; keep only thumbnails/poster frames in SwiftData.
- Do not put full image or video bytes into the synced SwiftData store.
- Keep Liquid Glass in functional chrome; prioritize legibility, Dynamic Type, Reduce Motion, and Reduce Transparency.
- WidgetKit extension validation is out of scope for this plan.
- After Swift/project/resource changes, run `xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build`.
- Use XcodeBuildMCP for simulator build/run/screenshot verification when available.

---

## Living To-Do

- [x] Task 1: Create test harness and clean agent scratch status.
- [ ] Task 2: Extract capture reward policy and alignment metadata.
- [x] Task 3: Add deterministic first-week QA launch states.
- [x] Task 4: Improve camera confidence service/UI.
- [x] Task 5: Improve reward accessibility and visual polish.
- [ ] Task 6: Build, run, screenshot, and update this plan with final verification.
- [x] Task 7: Redesign reward surface as a Field Journal Receipt.

## Change Log

| Time | Update |
| --- | --- |
| 2026-07-07 | Plan created from approved spec `docs/superpowers/specs/2026-07-07-capture-loop-v02-design.md`. |
| 2026-07-07 | Added GrowTests harness and ignored Superpowers scratch output. Escalated test run now reaches the expected failing assertion path: `CaptureRewardPolicy` is not defined yet. |
| 2026-07-07 | Implemented `CaptureRewardPolicy`, alignment source metadata, and streak tests. Fixed `Grow.xcscheme` test `MacroExpansion` so hosted unit tests launch correctly; isolated a SwiftData test-harness crash to a local `ModelContainer` lifetime issue and retained containers in `StreakServiceTests`. |
| 2026-07-07 | Added deterministic first-week launch seeding for `-seedFirstWeekGrow` / `-seedFirstWeekDay` and Day 7 policy coverage. Build and screenshot verification remain open until escalated Xcode runs are available again. |
| 2026-07-07 | Sosumi checked AVFoundation camera controls: `videoZoomFactor`, `focusMode`, and `exposureMode` require `lockForConfiguration()` / `unlockForConfiguration()`, and HIG Camera Control guidance favors short symbol-led controls that avoid cluttering the viewfinder. Added camera zoom/focus/exposure capability state and a compact confidence HUD. |
| 2026-07-07 | Sosumi checked HIG accessibility/color guidance: support larger text, use sufficient contrast, avoid color-only meaning, and keep controls at comfortable touch sizes. Reward cards now use policy-backed micro-moments, honest alignment copy, adaptive Twin/Streak layout, and higher-contrast surfaces. |
| 2026-07-07 | Tightened source hygiene after implementation: made first-week launch seeding static/parameterized, used the `Text` accessibility label overload for camera zoom, and confirmed `git diff --check` is clean. Formal shell test/build verification remains blocked by sandboxing and the environment usage limit. |
| 2026-07-07 | XcodeBuildMCP Day 2 screenshot revealed stale simulator data defeating deterministic seeding. Added DEBUG-only `GrowStore.resetDebugSampleData()` and made `-seedFirstWeekGrow` reset grow/streak rows before creating the requested QA state. |
| 2026-07-07 | Corrected Day 2 visual QA scroll position after screenshot review: reward autoscroll now targets a settled spacer above the reward so navigation chrome does not crowd the header. |
| 2026-07-07 | XcodeBuildMCP build/run passed with no diagnostics for Day 2 reward, Day 7 reward, and no-reward Capture fallback. Screenshots reviewed: `/var/folders/gk/w7mrg4_s4p70csf9bngwply40000gn/T/screenshot_optimized_e0930722-e8ba-4514-8f21-a40e386eeb05.jpg`, `/var/folders/gk/w7mrg4_s4p70csf9bngwply40000gn/T/screenshot_optimized_b9a02af2-d592-4bec-8dbb-7ff73fbff547.jpg`, `/var/folders/gk/w7mrg4_s4p70csf9bngwply40000gn/T/screenshot_optimized_c956abc7-2abe-4a8a-87ff-52a810410922.jpg`. |
| 2026-07-07 | Formal shell verification split: `git diff --check` passed; sandboxed `xcodebuild test` failed before test execution because CoreSimulator devices were unavailable; escalated retry was rejected by environment usage limit until July 8, 2026 2:21 AM; sandboxed required `xcodebuild ... build` failed on SwiftData macro plugin/CoreSimulator sandbox behavior already covered by the successful XcodeBuildMCP builds. |
| 2026-07-07 | Final verification status recorded: XcodeBuildMCP visual builds/screenshots and diff hygiene passed; shell tests/build remain open until escalated Xcode usage is available. |
| 2026-07-08 | User visual review rejected the reward surface: unequal metric card sizing/padding, broken header/body hierarchy, and generic AI-slop card stacking. Approved Option 2, Field Journal Receipt. Added Task 7 with an explicit visual QA gate for hierarchy, equal sizing, spacing rhythm, and non-generic design quality after each UI modification. |
| 2026-07-08 | Removed the app-wide custom display/rounded type choices from `GrowType` and switched display, body, labels, and numerals to Apple's default system font. Added visual contract coverage for native system typography, single-line metric values, and safe reward scroll positioning. |
| 2026-07-08 | Reworked the reward receipt header into matched Day/match columns and moved metric units below primary values so `Day 2`/`Day 7`, `90%`/`89%`, `+7%`, and `2`/`7` no longer fight on mismatched baselines. XcodeBuildMCP screenshots passed visual QA: Day 2 `/var/folders/gk/w7mrg4_s4p70csf9bngwply40000gn/T/screenshot_optimized_fd749461-be1a-41e9-8718-3c03396437b1.jpg`; Day 7 `/var/folders/gk/w7mrg4_s4p70csf9bngwply40000gn/T/screenshot_optimized_a24f401f-4579-4306-bd81-d72044b7ef41.jpg`. |
| 2026-07-08 | Task 7 verification complete: focused `CaptureRewardVisualContractTests` passed, `git diff --check` passed, no non-default font design references remain in source, XcodeBuildMCP Day 2/Day 7 build-runs passed, and the repo-required `xcodebuild ... CODE_SIGNING_ALLOWED=NO build` passed after the expected sandbox escalation. |

## File Structure

- Modify `.gitignore`: ignore `.superpowers/` scratch output created by the brainstorming visual companion.
- Modify `Grow.xcodeproj/project.pbxproj`: add a `GrowTests` unit-test target if Xcode accepts the minimal target cleanly.
- Modify `Grow.xcodeproj/xcshareddata/xcschemes/Grow.xcscheme`: include `GrowTests` in the scheme's test action.
- Create `Grow/Domain/CaptureRewardPolicy.swift`: pure Day 1-7 reward/milestone/caption logic and `ModeledGrowthCurve`.
- Modify `Grow/Services/PhotoService.swift`: consume `CaptureRewardPolicy`, extend `CaptureAlignment`, keep media persistence in service.
- Modify `Grow/Services/CameraCaptureService.swift`: expose zoom/focus/exposure/lock capability state and methods.
- Modify `Grow/Services/GrowStore.swift`: provide DEBUG-only deterministic sample data reset for launch QA.
- Modify `Grow/GrowApp.swift`: add deterministic first-week launch seeding arguments.
- Modify `Grow/Views/CaptureScreen.swift`: render honest alignment copy, stronger first-week states, camera confidence controls, and accessible reward cards.
- Create `GrowTests/CaptureRewardPolicyTests.swift`: test Day 1-7 policy and modeled growth.
- Create `GrowTests/CaptureAlignmentTests.swift`: test Codable compatibility and source-specific copy.
- Create `GrowTests/CaptureRewardVisualContractTests.swift`: test layout contract constants and the anti-slop visual QA checklist.
- Create `GrowTests/StreakServiceTests.swift`: test daily streak/freeze behavior with in-memory SwiftData.
- Update this plan file after every completed task with checked boxes and a change-log entry.

---

### Task 1: Test Harness And Scratch Status

**Files:**
- Modify: `.gitignore`
- Modify: `Grow.xcodeproj/project.pbxproj`
- Modify: `Grow.xcodeproj/xcshareddata/xcschemes/Grow.xcscheme`
- Create: `GrowTests/CaptureRewardPolicyTests.swift`

**Interfaces:**
- Consumes: current Xcode project with filesystem-synchronized `Grow` app target.
- Produces: `GrowTests` target that can import the app module using `@testable import Grow`.

- [x] **Step 1: Ignore Superpowers scratch output**

Add this line to `.gitignore` under the agent scratch section:

```gitignore
.superpowers/
```

Expected: `git status --short` no longer shows `?? .superpowers/`.

- [x] **Step 2: Add the smallest useful failing test file**

Create `GrowTests/CaptureRewardPolicyTests.swift`:

```swift
import XCTest
@testable import Grow

final class CaptureRewardPolicyTests: XCTestCase {
    func testDaySevenMilestoneIsFirstWeekRecap() {
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 7), "First week recap unlocked")
    }
}
```

Expected before implementation: the test target may not exist yet, or `CaptureRewardPolicy` is not defined.

- [x] **Step 3: Add `GrowTests` to the Xcode project**

Add a unit-test native target named `GrowTests` with:

```text
PRODUCT_BUNDLE_IDENTIFIER = com.sviftstudios.GrowTests
PRODUCT_NAME = "$(TARGET_NAME)"
SDKROOT = iphoneos
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"
IPHONEOS_DEPLOYMENT_TARGET = 26.2
SWIFT_VERSION = 5.0
TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Grow.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Grow"
BUNDLE_LOADER = "$(TEST_HOST)"
GENERATE_INFOPLIST_FILE = YES
```

Use a `PBXFileSystemSynchronizedRootGroup` for `GrowTests` matching the app target's current project style. Add the test target to the `PBXProject.targets` list and the `Grow.xcscheme` `TestAction`.

- [x] **Step 4: Run the failing test**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: FAIL because `CaptureRewardPolicy` does not exist yet. If sandboxed CoreSimulator access fails before compiling, rerun with approval exactly as `AGENTS.md` permits.

- [x] **Step 5: Update this plan**

Check off completed Task 1 steps and add a change-log entry:

```markdown
| 2026-07-07 | Added GrowTests harness and ignored Superpowers scratch output. |
```

---

### Task 2: Reward Policy And Alignment Metadata

**Files:**
- Create: `Grow/Domain/CaptureRewardPolicy.swift`
- Modify: `Grow/Services/PhotoService.swift`
- Modify: `GrowTests/CaptureRewardPolicyTests.swift`
- Create: `GrowTests/CaptureAlignmentTests.swift`
- Create: `GrowTests/StreakServiceTests.swift`

**Interfaces:**
- Produces: `enum CaptureRewardPolicy` with static methods:
  - `milestoneTitle(dayIndex: Int) -> String?`
  - `firstWeekNote(dayIndex: Int) -> String?`
  - `caption(dayIndex: Int, alignment: CaptureAlignment) -> String`
  - `microMoment(for reward: CaptureReward) -> CaptureRewardPolicy.MicroMoment`
  - `futureReelProgress(frameCount: Int, targetFrameCount: Int) -> Double`
- Produces: `enum AlignmentSource: String, Codable, Equatable` with cases `visionTranslation`, `fallbackEstimate`, `prototype`.
- Produces: extended `CaptureAlignment` initializer with default source for compatibility:
  `init(score:xOffset:yOffset:rotationDegrees:source:)`.
- Consumes: existing `CaptureReward`, `GrowStage`, `PlantSpecies`, and `ModeledGrowthCurve` behavior.

- [x] **Step 1: Write policy tests**

Replace `GrowTests/CaptureRewardPolicyTests.swift` with:

```swift
import XCTest
@testable import Grow

final class CaptureRewardPolicyTests: XCTestCase {
    func testFirstWeekMilestones() {
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 1), "Your reel starts here")
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 3), "First streak milestone")
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 5), "Ahead of the curve")
        XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 7), "First week recap unlocked")
        XCTAssertNil(CaptureRewardPolicy.milestoneTitle(dayIndex: 8))
    }

    func testDayTwoNoteReassuresInvisibleGrowth() {
        let note = CaptureRewardPolicy.firstWeekNote(dayIndex: 2)
        XCTAssertEqual(note, "No visible change is normal. The reel is already getting steadier.")
    }

    func testFutureReelProgressCapsAtOne() {
        XCTAssertEqual(CaptureRewardPolicy.futureReelProgress(frameCount: 15, targetFrameCount: 30), 0.5)
        XCTAssertEqual(CaptureRewardPolicy.futureReelProgress(frameCount: 45, targetFrameCount: 30), 1)
    }

    func testModeledGrowthStageBoundaries() {
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.10), .germination)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.20), .seedling)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.50), .vegetative)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.75), .flowering)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.90), .fruiting)
        XCTAssertEqual(ModeledGrowthCurve.stage(for: 0.98), .harvest)
    }
}
```

- [x] **Step 2: Write alignment metadata tests**

Create `GrowTests/CaptureAlignmentTests.swift`:

```swift
import XCTest
@testable import Grow

final class CaptureAlignmentTests: XCTestCase {
    func testDecodesLegacyAlignmentWithoutSource() throws {
        let json = #"{"score":0.94,"xOffset":0.01,"yOffset":-0.02,"rotationDegrees":0}"#.data(using: .utf8)!
        let alignment = try JSONDecoder().decode(CaptureAlignment.self, from: json)
        XCTAssertEqual(alignment.source, .fallbackEstimate)
        XCTAssertEqual(alignment.sourceLabel, "Estimated match")
    }

    func testVisionAlignmentCopyIsHonest() {
        let alignment = CaptureAlignment(
            score: 0.98,
            xOffset: 0.001,
            yOffset: -0.001,
            rotationDegrees: 0,
            source: .visionTranslation
        )
        XCTAssertEqual(alignment.sourceLabel, "Vision matched")
        XCTAssertEqual(alignment.guidanceCopy, "Frame locked from the previous photo")
    }

    func testFallbackAlignmentCopyAvoidsOverclaiming() {
        let alignment = CaptureAlignment(
            score: 0.88,
            xOffset: 0.02,
            yOffset: 0.02,
            rotationDegrees: 0,
            source: .fallbackEstimate
        )
        XCTAssertEqual(alignment.sourceLabel, "Estimated match")
        XCTAssertEqual(alignment.guidanceCopy, "Saved with a steady-angle estimate")
    }
}
```

- [x] **Step 3: Write streak service tests**

Create `GrowTests/StreakServiceTests.swift`:

```swift
import SwiftData
import XCTest
@testable import Grow

@MainActor
final class StreakServiceTests: XCTestCase {
    func testSameDayCaptureDoesNotAdvanceTwice() throws {
        let service = try makeService()
        let first = service.recordCapture(at: date(day: 1, hour: 9))
        let second = service.recordCapture(at: date(day: 1, hour: 17))

        XCTAssertEqual(first.current, 1)
        XCTAssertEqual(second.current, 1)
        XCTAssertFalse(second.didAdvance)
    }

    func testNextDayCaptureAdvancesStreak() throws {
        let service = try makeService()
        _ = service.recordCapture(at: date(day: 1))
        let update = service.recordCapture(at: date(day: 2))

        XCTAssertEqual(update.current, 2)
        XCTAssertTrue(update.didAdvance)
        XCTAssertFalse(update.spentFreezeToken)
    }

    func testMissedDayUsesFreezeToken() throws {
        let service = try makeService()
        _ = service.recordCapture(at: date(day: 1))
        let update = service.recordCapture(at: date(day: 3))

        XCTAssertEqual(update.current, 2)
        XCTAssertEqual(update.freezeTokensRemaining, 1)
        XCTAssertTrue(update.spentFreezeToken)
    }

    func testMissedDayWithoutFreezeResetsStreak() throws {
        let service = try makeService()
        _ = service.recordCapture(at: date(day: 1))
        _ = service.recordCapture(at: date(day: 3))
        _ = service.recordCapture(at: date(day: 5))
        let update = service.recordCapture(at: date(day: 7))

        XCTAssertEqual(update.current, 1)
        XCTAssertEqual(update.freezeTokensRemaining, 0)
        XCTAssertFalse(update.spentFreezeToken)
    }

    private func makeService() throws -> StreakService {
        let schema = Schema([StreakState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return StreakService(context: ModelContext(container), calendar: calendar)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(day: Int, hour: Int = 9) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 7,
            day: day,
            hour: hour
        ).date!
    }
}
```

- [x] **Step 4: Run tests to verify failure**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: FAIL because `CaptureRewardPolicy`, `AlignmentSource`, `sourceLabel`, and `guidanceCopy` are not implemented.

- [x] **Step 5: Implement `CaptureRewardPolicy`**

Create `Grow/Domain/CaptureRewardPolicy.swift`:

```swift
import SwiftUI

enum CaptureRewardPolicy {
    struct MicroMoment: Equatable {
        let title: String
        let body: String
        let icon: String
        let tintRole: TintRole
    }

    enum TintRole: String, Equatable {
        case bloom
        case info
        case sprout
        case healthy
    }

    static func milestoneTitle(dayIndex: Int) -> String? {
        switch dayIndex {
        case 1: "Your reel starts here"
        case 3: "First streak milestone"
        case 5: "Ahead of the curve"
        case 7: "First week recap unlocked"
        default: nil
        }
    }

    static func firstWeekNote(dayIndex: Int) -> String? {
        switch dayIndex {
        case 1:
            "The first frame matters because it gives every future leaf a real before."
        case 2:
            "No visible change is normal. The reel is already getting steadier."
        case 3...6:
            "Quiet growth counts. Keep the angle steady and the reveal will do the talking."
        case 7:
            "One week of frames is enough to start seeing the story."
        default:
            nil
        }
    }

    static func futureReelProgress(frameCount: Int, targetFrameCount: Int) -> Double {
        guard targetFrameCount > 0 else { return 1 }
        return min(1, max(0, Double(frameCount) / Double(targetFrameCount)))
    }

    static func caption(dayIndex: Int, alignment: CaptureAlignment) -> String {
        "\(alignment.percent)% aligned - \(alignment.adjective). \(alignment.sourceLabel) for Day \(dayIndex)."
    }

    static func microMoment(for reward: CaptureReward) -> MicroMoment {
        switch reward.dayIndex {
        case 1:
            MicroMoment(title: "Reel seed planted", body: "The before-frame is now anchored. Every future leaf has somewhere to return to.", icon: "record.circle", tintRole: .bloom)
        case 2:
            MicroMoment(title: "Germination is mostly invisible", body: "Today is about roots, moisture, and patience. The twin moves so the habit has a pulse.", icon: "water.waves", tintRole: .info)
        case 3:
            MicroMoment(title: "First streak marker", body: "Three steady frames is the first real signal that this grow has a rhythm.", icon: "flame.fill", tintRole: .bloom)
        case 5:
            MicroMoment(title: "Ahead of the average beginner", body: "Most first grows lose consistency here. Five frames means your recap already has structure.", icon: "chart.line.uptrend.xyaxis", tintRole: .sprout)
        case 7:
            MicroMoment(title: "First-week recap ready", body: "Seven frames is enough to make the quiet first week feel like a story.", icon: "film.stack.fill", tintRole: .bloom)
        default:
            if reward.alignment.score >= 0.96 && reward.alignment.source == .visionTranslation {
                MicroMoment(title: "Frame locked", body: "That match will make the future time-lapse feel calmer and more cinematic.", icon: "scope", tintRole: .sprout)
            } else {
                MicroMoment(title: "Memory banked", body: "Even imperfect frames count. The reel gets stronger because the day was captured.", icon: "checkmark.seal.fill", tintRole: .healthy)
            }
        }
    }
}

extension CaptureRewardPolicy.TintRole {
    var color: Color {
        switch self {
        case .bloom: GrowPalette.bloom
        case .info: GrowPalette.info
        case .sprout: GrowPalette.sprout600
        case .healthy: GrowPalette.healthy
        }
    }
}
```

- [x] **Step 6: Extend alignment metadata**

Modify `CaptureAlignment` in `Grow/Services/PhotoService.swift` to:

```swift
enum AlignmentSource: String, Codable, Equatable {
    case visionTranslation
    case fallbackEstimate
    case prototype
}

struct CaptureAlignment: Codable, Equatable {
    let score: Double
    let xOffset: Double
    let yOffset: Double
    let rotationDegrees: Double
    let source: AlignmentSource

    init(
        score: Double,
        xOffset: Double,
        yOffset: Double,
        rotationDegrees: Double,
        source: AlignmentSource = .fallbackEstimate
    ) {
        self.score = score
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.rotationDegrees = rotationDegrees
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case score
        case xOffset
        case yOffset
        case rotationDegrees
        case source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Double.self, forKey: .score)
        xOffset = try container.decode(Double.self, forKey: .xOffset)
        yOffset = try container.decode(Double.self, forKey: .yOffset)
        rotationDegrees = try container.decode(Double.self, forKey: .rotationDegrees)
        source = try container.decodeIfPresent(AlignmentSource.self, forKey: .source) ?? .fallbackEstimate
    }

    var percent: Int { Int((score * 100).rounded()) }

    var adjective: String {
        switch score {
        case 0.97...: "buttery"
        case 0.93...: "steady"
        case 0.88...: "close"
        default: "needs a nudge"
        }
    }

    var sourceLabel: String {
        switch source {
        case .visionTranslation: "Vision matched"
        case .fallbackEstimate: "Estimated match"
        case .prototype: "Simulator match"
        }
    }

    var guidanceCopy: String {
        switch source {
        case .visionTranslation: "Frame locked from the previous photo"
        case .fallbackEstimate: "Saved with a steady-angle estimate"
        case .prototype: "Simulator frame saved for QA"
        }
    }
}
```

- [x] **Step 7: Wire policy into `PhotoService` and `CaptureReward`**

In `CaptureReward`, replace computed `futureReelProgress`, `milestoneTitle`, and `firstWeekNote` bodies with calls to `CaptureRewardPolicy`. In `PhotoService`, replace `rewardCaption(dayIndex:alignment:)` with `CaptureRewardPolicy.caption(dayIndex:alignment:)`. Set real Vision alignment source to `.visionTranslation`, fallback source to `.fallbackEstimate`, and prototype source to `.prototype`.

- [ ] **Step 8: Run tests and build**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: test and build pass, with sandbox escalation only if CoreSimulator blocks the run before meaningful compile/test output.

- [x] **Step 9: Update this plan**

Check off completed Task 2 steps and add:

```markdown
| 2026-07-07 | Extracted reward policy and added honest alignment source metadata. |
```

---

### Task 3: Deterministic First-Week QA Launch States

**Files:**
- Modify: `Grow/GrowApp.swift`
- Modify: `Grow/Services/GrowStore.swift`
- Modify: `Grow/Views/CaptureScreen.swift`
- Modify: `GrowTests/CaptureRewardPolicyTests.swift`

**Interfaces:**
- Produces launch arguments:
  - `-seedFirstWeekGrow`
  - `-seedFirstWeekDay <1...7>`
  - `-openCapture`
  - `-simulateCaptureReward`
- Consumes: `PhotoService.recordPrototypeCapture(for:species:capturedAt:)`.

- [x] **Step 1: Add launch-argument parser tests for day policy**

Append to `GrowTests/CaptureRewardPolicyTests.swift`:

```swift
func testDaySevenIsShareableFirstWeekArtifact() {
    XCTAssertEqual(CaptureRewardPolicy.firstWeekNote(dayIndex: 7), "One week of frames is enough to start seeing the story.")
    XCTAssertEqual(CaptureRewardPolicy.milestoneTitle(dayIndex: 7), "First week recap unlocked")
}
```

- [x] **Step 2: Add debug seed helper in `GrowApp`**

Add private helper methods to `GrowApp`:

```swift
private static func launchValue(after flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}

private static func seedFirstWeekIfRequested(
    arguments: [String],
    store: GrowStore,
    catalog: PlantCatalogService,
    photoService: PhotoService
) {
    #if DEBUG
    guard arguments.contains("-seedFirstWeekGrow") else { return }
    store.resetDebugSampleData()
    let targetDay = Int(launchValue(after: "-seedFirstWeekDay", in: arguments) ?? "2") ?? 2
    let clampedDay = min(7, max(1, targetDay))
    let startDate = Calendar.current.date(byAdding: .day, value: -(clampedDay - 1), to: Date()) ?? Date()
    let grow = store.createGrow(speciesID: "basil", nickname: "First Week Basil", system: .kratky)
    grow.startDate = Calendar.current.startOfDay(for: startDate)
    grow.currentStage = .germination
    let species = catalog.species(id: grow.speciesID)
    for dayOffset in 0..<max(0, clampedDay - 1) {
        let captureDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: grow.startDate)?
            .addingTimeInterval(9 * 60 * 60) ?? Date()
        _ = photoService.recordPrototypeCapture(for: grow, species: species, capturedAt: captureDate)
    }
    store.save()
    #endif
}
```

Call `Self.seedFirstWeekIfRequested(arguments:store:catalog:photoService:)` after existing sample grow setup and before `-renderSampleReel`.

- [x] **Step 3: Preserve existing sample paths**

Run `xcodebuild` build after adding helpers to ensure `-seedSampleGrow`, `-seedSampleCaptures`, and `-renderSampleReel` still compile and remain unchanged.

- [x] **Step 4: Verify simulator Day 2 and Day 7 states**

Using XcodeBuildMCP, launch:

```text
-seedFirstWeekGrow -seedFirstWeekDay 2 -openCapture -simulateCaptureReward
```

Then launch:

```text
-seedFirstWeekGrow -seedFirstWeekDay 7 -openCapture -simulateCaptureReward
```

Expected screenshots:

- Day 2 shows invisible-growth reassurance and no misleading "visible growth" promise.
- Day 7 shows first-week recap milestone copy.

- [x] **Step 5: Update this plan**

Check off completed Task 3 steps and add:

```markdown
| 2026-07-07 | Added deterministic first-week launch states for Day 2 and Day 7 reward QA. |
```

---

### Task 4: Camera Confidence Service And Viewfinder UI

**Files:**
- Modify: `Grow/Services/CameraCaptureService.swift`
- Modify: `Grow/Views/CaptureScreen.swift`

**Interfaces:**
- Produces in `CameraCaptureService`:
  - `var zoomFactor: CGFloat`
  - `var minZoomFactor: CGFloat`
  - `var maxZoomFactor: CGFloat`
  - `var supportsZoom: Bool`
  - `var supportsFocusExposureLock: Bool`
  - `var isFocusExposureLocked: Bool`
  - `func setZoomFactor(_ factor: CGFloat)`
  - `func toggleFocusExposureLock()`
- Consumes Apple AVFoundation docs verified via Sosumi for `lockForConfiguration()`, `videoZoomFactor`, focus modes, and exposure modes.

- [x] **Step 1: Check Sosumi docs before code**

Use Sosumi to fetch or search:

```text
AVCaptureDevice lockForConfiguration focusMode exposureMode videoZoomFactor minAvailableVideoZoomFactor maxAvailableVideoZoomFactor
```

Record any API caveats in this plan's change log.

- [x] **Step 2: Add camera state properties**

Add state properties to `CameraCaptureService`:

```swift
var zoomFactor: CGFloat = 1
var minZoomFactor: CGFloat = 1
var maxZoomFactor: CGFloat = 1
var supportsZoom = false
var supportsFocusExposureLock = false
var isFocusExposureLocked = false
```

Add a private property:

```swift
private var activeCamera: AVCaptureDevice?
```

Set `activeCamera = camera` in `configureSession()`. After configuring output, update capability values on the main actor.

- [x] **Step 3: Implement camera controls**

Add methods:

```swift
func setZoomFactor(_ factor: CGFloat) {
    sessionQueue.async { [weak self] in
        guard let self, let camera = self.activeCamera else { return }
        let clamped = min(max(factor, camera.minAvailableVideoZoomFactor), min(camera.maxAvailableVideoZoomFactor, 4))
        do {
            try camera.lockForConfiguration()
            camera.videoZoomFactor = clamped
            camera.unlockForConfiguration()
            Task { @MainActor in self.zoomFactor = clamped }
        } catch {
            Task { @MainActor in self.status = .failed("Grow could not adjust zoom.") }
        }
    }
}

func toggleFocusExposureLock() {
    sessionQueue.async { [weak self] in
        guard let self, let camera = self.activeCamera else { return }
        do {
            try camera.lockForConfiguration()
            let shouldLock = !self.isFocusExposureLocked
            if shouldLock {
                if camera.isFocusModeSupported(.locked) {
                    camera.focusMode = .locked
                }
                if camera.isExposureModeSupported(.locked) {
                    camera.exposureMode = .locked
                }
            } else {
                if camera.isFocusModeSupported(.continuousAutoFocus) {
                    camera.focusMode = .continuousAutoFocus
                }
                if camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposureMode = .continuousAutoExposure
                }
            }
            camera.unlockForConfiguration()
            Task { @MainActor in self.isFocusExposureLocked = shouldLock }
        } catch {
            Task { @MainActor in self.status = .failed("Grow could not lock focus and exposure.") }
        }
    }
}
```

Adjust for Swift concurrency warnings while preserving the same interface.

- [x] **Step 4: Add camera confidence HUD**

In `PlantCameraView` within `CaptureScreen.swift`, add:

- A stronger ghost opacity state when `latestThumbnailData` exists.
- A small "Same angle" guide label.
- Zoom slider only when `cameraService.supportsZoom`.
- Lock button only when `cameraService.supportsFocusExposureLock`.
- Passive "Hold steady" level cue in simulator or unsupported-device cases.

Use icon buttons and labels; keep hit targets at least 44 pt.

- [x] **Step 5: Build and visually check camera fallback**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Then XcodeBuildMCP launch with `-seedFirstWeekGrow -seedFirstWeekDay 2 -openCapture`.

Expected: simulator capture fallback still appears, camera unavailable copy is calm, and no controls overlap.

- [x] **Step 6: Update this plan**

Check off completed Task 4 steps and add:

```markdown
| 2026-07-07 | Added camera zoom/focus/exposure capability state and confidence HUD affordances. |
```

---

### Task 5: Reward Accessibility And Visual Polish

**Files:**
- Modify: `Grow/Views/CaptureScreen.swift`
- Modify: `Grow/Domain/CaptureRewardPolicy.swift`

**Interfaces:**
- Consumes: `CaptureRewardPolicy.MicroMoment`, `CaptureAlignment.sourceLabel`, and `CaptureAlignment.guidanceCopy`.
- Produces: reward cards that are legible in dark/light mode and resilient to larger Dynamic Type.

- [x] **Step 1: Move micro-moment rendering to policy**

Replace `RewardMicroMoment`'s switch body in `CaptureScreen.swift` with a wrapper over `CaptureRewardPolicy.microMoment(for:)`:

```swift
private struct RewardMicroMoment {
    let title: String
    let body: String
    let icon: String
    let tint: Color

    init(reward: CaptureReward) {
        let moment = CaptureRewardPolicy.microMoment(for: reward)
        title = moment.title
        body = moment.body
        icon = moment.icon
        tint = moment.tintRole.color
    }
}
```

- [x] **Step 2: Make alignment badge honest and readable**

Update `AlignmentBadge` to include `alignment.sourceLabel` and `alignment.guidanceCopy`, with the percent and adjective still primary. Use `accessibilityLabel`:

```swift
"Alignment \(alignment.percent) percent, \(alignment.adjective). \(alignment.guidanceCopy)."
```

- [x] **Step 3: Make Twin/Streak cards stack adaptively**

Replace the fixed `HStack` wrapping `TwinAdvanceCard` and `StreakCard` with `ViewThatFits`:

```swift
ViewThatFits(in: .horizontal) {
    HStack(spacing: GrowSpacing.md) {
        twinCard
        streakCard
    }
    VStack(spacing: GrowSpacing.md) {
        twinCard
        streakCard
    }
}
```

Use private computed views for `twinCard` and `streakCard` inside `RewardSequenceView`.

- [x] **Step 4: Improve reward card contrast**

Change `TwinAdvanceCard` background to:

```swift
.background(GrowPalette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous)
        .stroke(GrowPalette.sprout300.opacity(0.32), lineWidth: 1)
)
```

Change `StreakCard` background to:

```swift
.background(GrowPalette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))
.overlay(
    RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous)
        .stroke(GrowPalette.bloom.opacity(0.36), lineWidth: 1)
)
```

Keep the Bloom and Sprout colors in icons/progress, not low-contrast text backgrounds.

- [x] **Step 5: Run visual QA**

Use XcodeBuildMCP screenshots for:

```text
-seedFirstWeekGrow -seedFirstWeekDay 2 -openCapture -simulateCaptureReward
-seedFirstWeekGrow -seedFirstWeekDay 7 -openCapture -simulateCaptureReward
```

Expected:

- Day 2 reward text fits and feels reassuring.
- Day 7 milestone is visible without scrolling into an awkward position.
- Twin/Streak cards do not become unreadable in dark mode.
- Alignment source copy is visible but secondary.

- [x] **Step 6: Update this plan**

Check off completed Task 5 steps and add:

```markdown
| 2026-07-07 | Polished reward contrast, Dynamic Type behavior, and honest alignment copy. |
```

---

### Task 6: Final Verification And Handoff

**Files:**
- Modify: `docs/superpowers/plans/2026-07-07-capture-loop-v02.md`

**Interfaces:**
- Consumes: all previous task outputs.
- Produces: verified implementation with plan checkboxes and change log updated.

- [x] **Step 1: Run formatting/diff hygiene**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors. Only intentional files are modified.

- [ ] **Step 2: Run tests**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: `TEST SUCCEEDED`. If the test target cannot be made reliable inside this Xcode project, record the exact blocker in this plan and run the most specific build-only verification available.

Actual: sandboxed test run failed before execution because CoreSimulator devices were unavailable; escalated retry was rejected by the environment usage limit until July 8, 2026 2:21 AM.

- [ ] **Step 3: Run required build**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: `BUILD SUCCEEDED`, rerun with approval if the sandbox blocks CoreSimulator/asset-catalog work.

Actual: XcodeBuildMCP build/run passed with no diagnostics; the exact sandboxed shell build failed on SwiftData macro plugin/CoreSimulator sandbox behavior, and escalation is currently blocked by the usage limit recorded above.

- [x] **Step 4: Run simulator visual verification**

Use XcodeBuildMCP:

1. `session_show_defaults`
2. Set defaults if missing: project `Grow.xcodeproj`, scheme `Grow`, simulator `iPhone 17 Pro` on iOS 26.2.
3. Build/run Day 2 reward state.
4. Capture screenshot.
5. Build/run Day 7 reward state.
6. Capture screenshot.

Expected: screenshots show the first-week ritual, honest alignment copy, and no obvious overlap/clipping.

- [x] **Step 5: Update living plan verification status**

Mark completed boxes in this file and add:

```markdown
| 2026-07-07 | Final verification status recorded: XcodeBuildMCP visual builds/screenshots and diff hygiene passed; shell tests/build blocked by sandbox and usage limit. |
```

- [ ] **Step 6: Commit implementation**

Commit after verification:

```bash
git add .gitignore Grow GrowTests Grow.xcodeproj docs/superpowers/plans/2026-07-07-capture-loop-v02.md
git commit -m "Polish capture loop first-week ritual"
```

Expected: commit succeeds on `main`. Do not include `.superpowers/` contents.

---

## Self-Review Notes

- Spec coverage: all approved Capture Loop v0.2 requirements map to Tasks 1-6.
- Scope check: widget extension validation, Live Activity, AI, care scheduling, monetization, and social features remain out of scope.
- Type consistency: `CaptureRewardPolicy`, `AlignmentSource`, and camera service interfaces are defined before later tasks consume them.
- Verification coverage: plan includes tests, required Xcode build, XcodeBuildMCP screenshots, and plan change-log updates.

---

### Task 7: Field Journal Receipt Reward Redesign

**Files:**
- Create: `Grow/Domain/CaptureRewardVisualContract.swift`
- Create: `GrowTests/CaptureRewardVisualContractTests.swift`
- Modify: `Grow/DesignSystem/GrowTypography.swift`
- Modify: `Grow/Views/CaptureScreen.swift`
- Modify: `docs/superpowers/plans/2026-07-07-capture-loop-v02.md`

**Interfaces:**
- Produces: `enum CaptureRewardVisualContract`
  - `static let receiptPadding: CGFloat`
  - `static let receiptHeaderMinHeight: CGFloat`
  - `static let sectionSpacing: CGFloat`
  - `static let metricCellMinHeight: CGFloat`
  - `static let metricCellPadding: CGFloat`
  - `static let metricCellIconSize: CGFloat`
  - `static let metricValueLineHeight: CGFloat`
  - `static let rewardScrollLeadIn: CGFloat`
  - `static let antiSlopChecklist: [String]`
- Produces: a single receipt-style `RewardSequenceView` surface where internal sections define hierarchy.
- Produces: app-wide default-system typography through `GrowType`; no explicit non-default font designs remain in source.
- Consumes: existing `CaptureReward`, `CaptureAlignment`, `RewardMicroMoment`, `GrowthMemoryCard`, `TwinAdvanceCard`, `StreakCard`, `FirstWeekArcNote`, and `MicroRewardCard` concepts.

**Visual QA Gate After Every UI Modification:**
- Equal sizing: Twin and Streak metric cells must share the same min height, padding, title row, progress row, and caption row.
- Hierarchy: the first readable unit must be the Day/reward title, then alignment as metadata, then saved frame, then metrics, then note/milestone.
- Rhythm: receipt padding, internal section spacing, and dividers must look intentional and consistent; no random card pile.
- HIG fit: use system type styles/weights, SF Symbols, readable contrast, 44 pt controls where interactive, and content-layer surfaces instead of Liquid Glass.
- Optical numeric fit: receipt header columns must be matched, primary numeric values must use Apple system monospaced digits, and units like `expected` / `days` must stay secondary to the primary value.
- Anti-slop check: no generic translucent card stack, no decorative icon bubbles without semantic purpose, no mixed random accent backgrounds, no text squeezed under chrome, no hierarchy created only with color/glow.

- [x] **Step 1: Write failing visual contract tests**

Create `GrowTests/CaptureRewardVisualContractTests.swift`:

```swift
import XCTest
@testable import Grow

final class CaptureRewardVisualContractTests: XCTestCase {
    func testMetricCellsShareEqualLayoutContract() {
        XCTAssertEqual(CaptureRewardVisualContract.metricCellMinHeight, 112)
        XCTAssertEqual(CaptureRewardVisualContract.metricCellPadding, 16)
        XCTAssertEqual(CaptureRewardVisualContract.metricCellIconSize, 28)
    }

    func testVisualQAChecklistRejectsGenericCardSlop() {
        let checklist = CaptureRewardVisualContract.antiSlopChecklist

        XCTAssertTrue(checklist.contains("Equal metric sizing and padding"))
        XCTAssertTrue(checklist.contains("Clear editorial reading order"))
        XCTAssertTrue(checklist.contains("No generic translucent card stack"))
        XCTAssertTrue(checklist.contains("No decorative icon bubbles without semantic purpose"))
    }
}
```

- [x] **Step 2: Run tests to verify RED**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: FAIL because `CaptureRewardVisualContract` is not defined. If sandboxed shell testing cannot reach compilation, use XcodeBuildMCP `test_sim` with the same scheme defaults.

- [x] **Step 3: Add the visual contract**

Create `Grow/Domain/CaptureRewardVisualContract.swift`:

```swift
import CoreGraphics

enum CaptureRewardVisualContract {
    static let receiptPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let metricCellMinHeight: CGFloat = 112
    static let metricCellPadding: CGFloat = 16
    static let metricCellIconSize: CGFloat = 28

    static let antiSlopChecklist = [
        "Equal metric sizing and padding",
        "Clear editorial reading order",
        "No generic translucent card stack",
        "No decorative icon bubbles without semantic purpose"
    ]
}
```

- [x] **Step 4: Redesign `RewardSequenceView` as one receipt surface**

Replace the current loose stack of reward cards with:

- A single rounded receipt container using `GrowPalette.surface.opacity(0.94)`.
- Header row: matched receipt columns for `Memory saved` / `Day N` and alignment source / percent match.
- Hairline divider.
- Saved frame section.
- Equal two-column metric grid using shared `RewardMetricCell`.
- First-week note and micro-moment as receipt rows, not separate cards.
- Milestone as final stamped row inside the receipt.

- [x] **Step 5: Normalize metric cell component**

Create a private `RewardMetricCell` in `CaptureScreen.swift` and rewrite `TwinAdvanceCard` and `StreakCard` to use it. Both cards must apply:

```swift
.frame(maxWidth: .infinity, minHeight: CaptureRewardVisualContract.metricCellMinHeight, alignment: .leading)
.padding(CaptureRewardVisualContract.metricCellPadding)
```

- [x] **Step 6: Simplify note and micro-moment rows**

Remove standalone tinted card backgrounds from `FirstWeekArcNote` and `MicroRewardCard`. Use a shared row style with:

- semantic SF Symbol
- field label
- body copy
- optional top hairline divider
- no glow, no decorative bubble

- [x] **Step 7: Run GREEN tests and build**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2' -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO test
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

If sandboxed shell commands fail due CoreSimulator/SwiftData macro sandboxing, record the exact failure and use XcodeBuildMCP `test_sim` / `build_sim` / `build_run_sim` as the meaningful verification path.

Completed:
- XcodeBuildMCP focused `CaptureRewardVisualContractTests` passed.
- XcodeBuildMCP Day 2 and Day 7 `build_run_sim` passed without diagnostics.
- Sandboxed shell build failed on known CoreSimulator/SwiftData macro sandbox behavior.
- Escalated repo-required shell build passed.

- [x] **Step 8: Visual QA Day 2 after modification**

Use XcodeBuildMCP with:

```text
-seedFirstWeekGrow -seedFirstWeekDay 2 -openCapture -simulateCaptureReward
```

Screenshot passed the Visual QA Gate above:
`/var/folders/gk/w7mrg4_s4p70csf9bngwply40000gn/T/screenshot_optimized_fd749461-be1a-41e9-8718-3c03396437b1.jpg`

- [x] **Step 9: Visual QA Day 7 after modification**

Use XcodeBuildMCP with:

```text
-seedFirstWeekGrow -seedFirstWeekDay 7 -openCapture -simulateCaptureReward
```

Screenshot passed the Visual QA Gate above:
`/var/folders/gk/w7mrg4_s4p70csf9bngwply40000gn/T/screenshot_optimized_a24f401f-4579-4306-bd81-d72044b7ef41.jpg`

- [x] **Step 10: Update this plan**

Check off completed Task 7 steps and add:

```markdown
| 2026-07-08 | Replaced reward card stack with Field Journal Receipt, normalized metric sizing/padding, and verified Day 2/Day 7 screenshots against hierarchy and anti-slop checklist. |
```
