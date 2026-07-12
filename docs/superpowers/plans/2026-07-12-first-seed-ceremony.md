# First Seed Ceremony Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a polished, accessible first-run journey that creates a real grow, saves a Day-1 growth memory, delivers the existing reward sequence, and lands on Today in under 60 seconds.

**Architecture:** Add a pure onboarding policy and an `@Observable` coordinator for transient state, keeping persistence behind an explicit confirmation boundary in `GrowStore`. Extract the existing camera and reward UI from `CaptureScreen.swift` into shared focused views, then compose the approved five-beat ceremony around those components and route first launch/resume states from `RootView`.

**Tech Stack:** SwiftUI, SwiftData, Observation `@Observable`, AVFoundation, PhotosUI, XCTest, Swift 5.0, iOS 26.2, XcodeBuildMCP.

## Global Constraints

- Work directly on `main`; commit and push every verified checkpoint.
- Keep the deployment target at iOS 26.2.
- Use native SwiftUI, SwiftData, Swift 5.0, and `@Observable` services injected through `.environment()`.
- Use `GrowPalette`, `GrowType`, `GrowSpacing`, `GrowRadius`, `SpecimenJar`, and existing design-system primitives before adding visual primitives.
- Use Apple system typography only.
- Keep full photos in App Group `group.com.sviftstudios.Grow`; store only file references and small thumbnails in SwiftData.
- Do not prompt for account creation, sign-in, purchase, rating, review, notifications, or location during this milestone.
- Keep reels free and unlimited; do not add a paywall.
- Liquid Glass is allowed only on functional camera chrome and compact floating controls.
- Every UI state must support Dynamic Type, VoiceOver, Reduce Motion, Reduce Transparency, Increased Contrast, 44-point hit targets, and color-plus-glyph-plus-label state communication.
- Every UI checkpoint requires XcodeBuildMCP screenshots and semantic snapshots on iPhone 17 Pro, iOS 26.2.
- Required build after Swift changes:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

---

## Living Todo

- [ ] Task 1: Add onboarding policy and coordinator with focused tests.
- [ ] Task 2: Add recoverable grow and photo persistence.
- [ ] Task 3: Extract shared guided camera and reward sequence.
- [ ] Task 4: Build Promise, Choose, Setup, and sample-mode UI.
- [ ] Task 5: Integrate Day-1 capture, reward, and completion routing.
- [ ] Task 6: Complete accessibility, simulator QA, verification, commit, and push.

## Change Log

- 2026-07-12: Plan created from the approved First Seed Ceremony design spec and high-fidelity storyboard.

## File Structure

- Create `Grow/Domain/OnboardingPolicy.swift`
  - Pure steps, setup choices, resume route, launch crop IDs, completion version, and transition rules.
- Create `Grow/Services/OnboardingCoordinator.swift`
  - Transient ceremony selections and explicit navigation/persistence transitions.
- Create `Grow/Views/FirstSeedFlow.swift`
  - Ceremony routing, shared chrome, completion callback, and sample presentation.
- Create `Grow/Views/FirstSeedPromiseView.swift`
  - Promise beat and session-only sample entry.
- Create `Grow/Views/FirstSeedCropView.swift`
  - Three accessible crop choices.
- Create `Grow/Views/FirstSeedSetupView.swift`
  - Three setup choices and explicit persistence action.
- Create `Grow/Views/GuidedPlantCameraView.swift`
  - Shared camera sheet, preview, guide, permission recovery, and simulator fallback currently embedded in `CaptureScreen.swift`.
- Create `Grow/Views/CaptureRewardSequenceView.swift`
  - Shared reward receipt, memory, twin, streak, and future-reel UI currently embedded in `CaptureScreen.swift`.
- Modify `Grow/Views/CaptureScreen.swift`
  - Use extracted camera/reward components and remove their private duplicates.
- Modify `Grow/Views/RootView.swift`
  - Route new, resumed, and completed users without creating a grow from the old empty state.
- Modify `Grow/GrowApp.swift`
  - Inject `OnboardingCoordinator`; preserve debug launch scenarios.
- Modify `Grow/Services/GrowStore.swift`
  - Surface save failure and provide explicit grow creation rollback.
- Modify `Grow/Services/PhotoService.swift`
  - Surface SwiftData save failure and remove a written photo if metadata persistence fails.
- Create `GrowTests/OnboardingPolicyTests.swift`
- Create `GrowTests/OnboardingCoordinatorTests.swift`
- Create `GrowTests/GrowStoreCreationTests.swift`
- Create `GrowTests/FirstSeedVisualContractTests.swift`
- Modify `docs/superpowers/plans/2026-07-12-first-seed-ceremony.md`
  - Keep todo and change log current before each source checkpoint.

## Task 1: Add Onboarding Policy and Coordinator

**Files:**
- Create: `Grow/Domain/OnboardingPolicy.swift`
- Create: `Grow/Services/OnboardingCoordinator.swift`
- Create: `GrowTests/OnboardingPolicyTests.swift`
- Create: `GrowTests/OnboardingCoordinatorTests.swift`
- Modify: `docs/superpowers/plans/2026-07-12-first-seed-ceremony.md`

**Interfaces:**
- Produces:
  - `enum OnboardingStep: Int, CaseIterable, Equatable`
  - `enum OnboardingSetupChoice: String, CaseIterable, Identifiable`
  - `enum OnboardingLaunchRoute: Equatable`
  - `enum OnboardingPolicy`
  - `@Observable @MainActor final class OnboardingCoordinator`
  - `OnboardingPolicy.launchSpeciesIDs: [String]`
  - `OnboardingPolicy.defaultSpeciesID: String`
  - `OnboardingPolicy.system(for:) -> GrowSystem`
  - `OnboardingPolicy.launchRoute(completedVersion:hasActiveGrow:activePhotoCount:) -> OnboardingLaunchRoute`
- Consumes: `GrowSystem`, `Foundation.UUID`.

- [ ] **Step 1: Mark Task 1 in progress**

Update Living Todo and append:

```markdown
- 2026-07-12: Started Task 1, defining pure onboarding state and transition contracts before UI work.
```

- [ ] **Step 2: Write failing policy tests**

Create `GrowTests/OnboardingPolicyTests.swift`:

```swift
import XCTest
@testable import Grow

final class OnboardingPolicyTests: XCTestCase {
    func testLaunchCropsStayFocusedAndDefaultToBasil() {
        XCTAssertEqual(OnboardingPolicy.launchSpeciesIDs, ["basil", "lettuce", "mint"])
        XCTAssertEqual(OnboardingPolicy.defaultSpeciesID, "basil")
    }

    func testSetupChoicesMapToLaunchSystems() {
        XCTAssertEqual(OnboardingPolicy.system(for: .simpleJar), .kratky)
        XCTAssertEqual(OnboardingPolicy.system(for: .countertopGarden), .dwc)
        XCTAssertEqual(OnboardingPolicy.system(for: .somethingElse), .other)
    }

    func testLaunchRoutingResumesInterruptedGrow() {
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(completedVersion: 0, hasActiveGrow: false, activePhotoCount: 0),
            .ceremony
        )
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(completedVersion: 0, hasActiveGrow: true, activePhotoCount: 0),
            .resumeCapture
        )
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(completedVersion: 0, hasActiveGrow: true, activePhotoCount: 1),
            .app
        )
        XCTAssertEqual(
            OnboardingPolicy.launchRoute(completedVersion: 1, hasActiveGrow: false, activePhotoCount: 0),
            .app
        )
    }
}
```

- [ ] **Step 3: Write failing coordinator tests**

Create `GrowTests/OnboardingCoordinatorTests.swift`:

```swift
import XCTest
@testable import Grow

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {
    func testSelectionsAndBackNavigationRemainStable() {
        let coordinator = OnboardingCoordinator()

        coordinator.begin()
        coordinator.selectSpecies("mint")
        coordinator.advanceFromCrop()
        coordinator.selectSetup(.countertopGarden)
        coordinator.goBack()

        XCTAssertEqual(coordinator.step, .crop)
        XCTAssertEqual(coordinator.selectedSpeciesID, "mint")
        XCTAssertEqual(coordinator.selectedSetup, .countertopGarden)
    }

    func testSampleModeNeverRequestsPersistence() {
        let coordinator = OnboardingCoordinator()

        coordinator.showSample()

        XCTAssertEqual(coordinator.step, .sample)
        XCTAssertNil(coordinator.pendingGrowRequest)
    }

    func testSetupConfirmationProducesOneExplicitRequest() {
        let coordinator = OnboardingCoordinator()
        coordinator.begin()
        coordinator.selectSpecies("lettuce")
        coordinator.advanceFromCrop()
        coordinator.selectSetup(.simpleJar)
        coordinator.confirmSetup()

        XCTAssertEqual(
            coordinator.pendingGrowRequest,
            OnboardingGrowRequest(speciesID: "lettuce", system: .kratky)
        )
        XCTAssertEqual(coordinator.step, .capture)
    }
}
```

- [ ] **Step 4: Run focused tests and verify RED**

Run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:GrowTests/OnboardingPolicyTests -only-testing:GrowTests/OnboardingCoordinatorTests test
```

Expected: compile failure because the onboarding types do not exist.

- [ ] **Step 5: Implement the pure policy**

Create `Grow/Domain/OnboardingPolicy.swift`:

```swift
import Foundation

enum OnboardingStep: Int, CaseIterable, Equatable {
    case promise
    case crop
    case setup
    case capture
    case reward
    case sample
}

enum OnboardingSetupChoice: String, CaseIterable, Identifiable, Equatable {
    case simpleJar
    case countertopGarden
    case somethingElse

    var id: String { rawValue }
}

enum OnboardingLaunchRoute: Equatable {
    case ceremony
    case resumeCapture
    case app
}

struct OnboardingGrowRequest: Equatable {
    let speciesID: String
    let system: GrowSystem
}

enum OnboardingPolicy {
    static let completedVersionKey = "grow.onboarding.completedVersion"
    static let currentVersion = 1
    static let launchSpeciesIDs = ["basil", "lettuce", "mint"]
    static let defaultSpeciesID = "basil"

    static func system(for choice: OnboardingSetupChoice) -> GrowSystem {
        switch choice {
        case .simpleJar: .kratky
        case .countertopGarden: .dwc
        case .somethingElse: .other
        }
    }

    static func launchRoute(
        completedVersion: Int,
        hasActiveGrow: Bool,
        activePhotoCount: Int
    ) -> OnboardingLaunchRoute {
        if completedVersion >= currentVersion { return .app }
        if hasActiveGrow { return activePhotoCount > 0 ? .app : .resumeCapture }
        return .ceremony
    }
}
```

- [ ] **Step 6: Implement coordinator transitions**

Create `Grow/Services/OnboardingCoordinator.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class OnboardingCoordinator {
    private(set) var step: OnboardingStep = .promise
    private(set) var selectedSpeciesID = OnboardingPolicy.defaultSpeciesID
    private(set) var selectedSetup: OnboardingSetupChoice = .simpleJar
    private(set) var pendingGrowRequest: OnboardingGrowRequest?
    private(set) var createdGrowID: UUID?
    private(set) var reward: CaptureReward?
    var errorMessage: String?

    func begin() { step = .crop }
    func selectSpecies(_ id: String) { selectedSpeciesID = id }
    func advanceFromCrop() { step = .setup }
    func selectSetup(_ setup: OnboardingSetupChoice) { selectedSetup = setup }

    func confirmSetup() {
        pendingGrowRequest = OnboardingGrowRequest(
            speciesID: selectedSpeciesID,
            system: OnboardingPolicy.system(for: selectedSetup)
        )
        step = .capture
    }

    func didCreateGrow(id: UUID) {
        createdGrowID = id
        pendingGrowRequest = nil
    }

    func didCapture(_ reward: CaptureReward) {
        self.reward = reward
        step = .reward
    }

    func showSample() { step = .sample; pendingGrowRequest = nil }
    func leaveSample() { step = .promise }
    func retryCapture() { errorMessage = nil; step = .capture }

    func goBack() {
        switch step {
        case .crop: step = .promise
        case .setup: step = .crop
        case .capture where createdGrowID == nil: step = .setup
        case .sample: step = .promise
        case .promise, .capture, .reward: break
        }
    }
}
```

- [ ] **Step 7: Run focused tests and verify GREEN**

Run the Step 4 command. Expected: all onboarding policy and coordinator tests pass.

- [ ] **Step 8: Commit and push Task 1**

```bash
git add Grow/Domain/OnboardingPolicy.swift Grow/Services/OnboardingCoordinator.swift GrowTests/OnboardingPolicyTests.swift GrowTests/OnboardingCoordinatorTests.swift docs/superpowers/plans/2026-07-12-first-seed-ceremony.md
git commit -m "Add onboarding state foundation"
git push origin main
```

## Task 2: Add Recoverable Grow and Photo Persistence

**Files:**
- Modify: `Grow/Services/GrowStore.swift`
- Modify: `Grow/Services/PhotoService.swift`
- Modify: `Grow/GrowApp.swift`
- Modify: `Grow/Views/RootView.swift`
- Create: `GrowTests/GrowStoreCreationTests.swift`
- Modify: `docs/superpowers/plans/2026-07-12-first-seed-ceremony.md`

**Interfaces:**
- Produces:
  - `enum GrowStoreError: LocalizedError`
  - `GrowStore.createGrow(speciesID:nickname:system:) throws -> Grow`
  - `GrowStore.delete(_:) throws`
  - `PhotoService.recordCapture(imageData:for:species:) throws -> CaptureReward` with transactional metadata save.
- Consumes: existing `Grow`, `GrowPhoto`, `GrowModelContainer`, and catalog contracts.

- [ ] **Step 1: Mark Task 2 in progress**

Append:

```markdown
- 2026-07-12: Started Task 2, making grow and photo persistence recoverable before UI integration.
```

- [ ] **Step 2: Write failing grow-creation tests**

Create `GrowTests/GrowStoreCreationTests.swift` with an in-memory container and these assertions:

```swift
import SwiftData
import XCTest
@testable import Grow

@MainActor
final class GrowStoreCreationTests: XCTestCase {
    func testCreateGrowPersistsSelectedSpeciesAndSeedsCareTasks() throws {
        let schema = GrowModelContainer.schema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let catalog = PlantCatalogService()
        let store = GrowStore(context: container.mainContext, catalog: catalog)

        let grow = try store.createGrow(speciesID: "basil", nickname: "", system: .kratky)

        XCTAssertEqual(grow.speciesID, "basil")
        XCTAssertEqual(grow.system, .kratky)
        XCTAssertFalse((grow.careTasks ?? []).isEmpty)
        XCTAssertEqual(store.activeGrows().map(\.id), [grow.id])
    }

    func testDeleteRemovesAbandonedGrow() throws {
        let schema = GrowModelContainer.schema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = GrowStore(context: container.mainContext, catalog: PlantCatalogService())
        let grow = try store.createGrow(speciesID: "basil", nickname: "", system: .kratky)

        try store.delete(grow)

        XCTAssertTrue(store.activeGrows().isEmpty)
    }
}
```

- [ ] **Step 3: Verify RED**

Run only `GrowStoreCreationTests`. Expected: compile failure because `createGrow` and `delete` are not throwing contracts.

- [ ] **Step 4: Make `GrowStore` surface failures**

Implement `GrowStoreError.saveFailed(String)` and make `save()` throwing. In `createGrow`, insert the aggregate and tasks, call `try save()`, and on failure delete the newly inserted objects before rethrowing. Add `delete(_:) throws` for an abandoned confirmed grow. Update debug/sample call sites in `GrowApp`, `RootView`, and `CaptureScreen` with explicit `do/catch` or `try?` only where the path is debug-only.

Use this public shape:

```swift
enum GrowStoreError: LocalizedError {
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .saveFailed(_): "Grow could not save your plant. Please try again."
        }
    }
}
```

- [ ] **Step 5: Make `PhotoService` transactional**

Change its private `save()` to throw. If context save fails after the image file is written, delete the file through `FileManager`, delete the inserted `GrowPhoto`, restore `coverPhotoID` and `currentStage`, and rethrow. Keep successful media in the App Group and never store full bytes in SwiftData.

- [ ] **Step 6: Update existing persistence call sites**

Update production call sites in `GrowApp`, `RootView`, and `CaptureScreen` for the new throwing contracts. Keep explicit `do/catch` handling on user-facing paths so failures remain visible and retryable. Use `try?` only for deterministic DEBUG-only seed data, where failure is already surfaced by the debug scenario not appearing. Do not add onboarding routing in this task; Task 4 introduces `FirstSeedFlow` and wires the route after the destination exists.

- [ ] **Step 7: Run focused and full tests**

Run `GrowStoreCreationTests`, then the full GrowTests suite. Expected: all pass.

- [ ] **Step 8: Commit and push Task 2**

```bash
git add Grow/Services/GrowStore.swift Grow/Services/PhotoService.swift Grow/GrowApp.swift Grow/Views/RootView.swift Grow/Views/CaptureScreen.swift GrowTests/GrowStoreCreationTests.swift docs/superpowers/plans/2026-07-12-first-seed-ceremony.md
git commit -m "Make onboarding persistence recoverable"
git push origin main
```

## Task 3: Extract Shared Guided Camera and Reward Sequence

**Files:**
- Create: `Grow/Views/GuidedPlantCameraView.swift`
- Create: `Grow/Views/CaptureRewardSequenceView.swift`
- Modify: `Grow/Views/CaptureScreen.swift`
- Create: `GrowTests/FirstSeedVisualContractTests.swift`
- Modify: `docs/superpowers/plans/2026-07-12-first-seed-ceremony.md`

**Interfaces:**
- Produces:
  - `struct GuidedPlantCameraView: View`
  - `struct GuidedPlantCameraConfiguration: Equatable`
  - `struct CaptureRewardSequenceView: View`
- Consumes: `CameraCaptureService`, `CaptureReward`, `GrowPhoto`, `PlantSpecies`, existing design-system tokens.

- [ ] **Step 1: Mark Task 3 in progress and write visual-contract tests**

The test file asserts exact shared contracts:

```swift
import XCTest
@testable import Grow

final class FirstSeedVisualContractTests: XCTestCase {
    func testCeremonyProtectsNativeInteractionGeometry() {
        XCTAssertEqual(FirstSeedVisualContract.primaryActionHeight, 52)
        XCTAssertGreaterThanOrEqual(FirstSeedVisualContract.optionMinHeight, 64)
        XCTAssertEqual(FirstSeedVisualContract.launchCropCount, 3)
        XCTAssertEqual(FirstSeedVisualContract.launchSetupCount, 3)
    }

    func testSharedCameraUsesDayOneCopyWithoutGhostOverclaim() {
        let config = GuidedPlantCameraConfiguration.dayOne(speciesName: "Genovese basil")
        XCTAssertEqual(config.title, "Frame one")
        XCTAssertNil(config.ghostThumbnailData)
        XCTAssertEqual(config.guidance, "Center the jar inside the guide")
    }
}
```

- [ ] **Step 2: Verify RED**

Run `FirstSeedVisualContractTests`. Expected: missing visual-contract and camera-configuration types.

- [ ] **Step 3: Add exact shared contracts**

Create `FirstSeedVisualContract` with 52-point primary actions, 64-point option rows, three launch crops/setups, 24-point outer spacing, and a 44-point minimum secondary control. Create `GuidedPlantCameraConfiguration` with `dayOne(speciesName:)` and `daily(speciesName:frameCount:ghostThumbnailData:progress:)` factories.

- [ ] **Step 4: Move camera components without behavioral edits**

Move `PlantCameraView`, `CameraPreview`, `CameraGuideOverlay`, `CameraConfidenceHUD`, `CameraZoomControl`, `CameraSteadyCue`, and `CameraStatusPill` from `CaptureScreen.swift` into `GuidedPlantCameraView.swift`. Rename only the public entry view to `GuidedPlantCameraView`; preserve `CameraCaptureService` calls and accessibility labels.

- [ ] **Step 5: Move reward components without behavioral edits**

Move `RewardSequenceView`, `GrowthMemoryCard`, reward metric/receipt rows, `FutureReelStrip`, and `ReelThumb` into `CaptureRewardSequenceView.swift`. Rename the public entry to `CaptureRewardSequenceView`. Keep the six-stage sequence, Reduce Motion shortcut, sensory feedback, and current copy behavior.

- [ ] **Step 6: Update `CaptureScreen` to shared views**

Replace its private camera/reward construction with the shared types. Verify the existing `-seedFirstWeekGrow -seedFirstWeekDay 2 -openCapture` simulator path is visually unchanged before ceremony-specific styling is added.

- [ ] **Step 7: Run tests, build, and XcodeMCP screenshot**

Run focused visual-contract tests, full tests, and required build. Build/run the existing capture seed path on iPhone 17 Pro and compare screenshot hierarchy, actions, reward receipt, and semantic targets to the baseline.

- [ ] **Step 8: Commit and push Task 3**

```bash
git add Grow/Views/GuidedPlantCameraView.swift Grow/Views/CaptureRewardSequenceView.swift Grow/Views/CaptureScreen.swift GrowTests/FirstSeedVisualContractTests.swift docs/superpowers/plans/2026-07-12-first-seed-ceremony.md
git commit -m "Share guided capture and reward views"
git push origin main
```

## Task 4: Build Promise, Choose, Setup, and Sample UI

**Files:**
- Create: `Grow/Views/FirstSeedFlow.swift`
- Create: `Grow/Views/FirstSeedPromiseView.swift`
- Create: `Grow/Views/FirstSeedCropView.swift`
- Create: `Grow/Views/FirstSeedSetupView.swift`
- Modify: `Grow/Views/RootView.swift`
- Modify: `Grow/GrowApp.swift`
- Modify: `GrowTests/FirstSeedVisualContractTests.swift`
- Modify: `docs/superpowers/plans/2026-07-12-first-seed-ceremony.md`

**Interfaces:**
- Produces ceremony SwiftUI views, `FirstSeedFlow(initialStep:onCompleted:)`, coordinator injection, and launch/resume routing.
- Consumes Tasks 1–3 coordinator, policy, shared camera/reward, catalog, store, and design system.

- [ ] **Step 1: Mark Task 4 in progress and expand visual-contract tests**

Assert the approved anti-slop checklist contains: system typography, one primary action per beat, specimen-first composition, no nested cards, Bloom only after success, explicit selection glyph/label, and sample mode persistence-free.

- [ ] **Step 2: Build the Promise beat**

Implement the approved copy and composition using `SpecimenJar`, future Day-30 annotation, warm paper background, one `Plant your first seed` capsule, and `Explore with a sample grow`. The specimen remains content, not glass. Use `ViewThatFits` so the primary action remains visible at accessibility sizes.

- [ ] **Step 3: Build the Choose beat**

Filter the catalog by `OnboardingPolicy.launchSpeciesIDs` in that exact order. Each row combines crop visual/emoji, common name, concise benefit, harvest range, and checkmark plus selected label. `Choose for me` calls `selectSpecies(defaultSpeciesID)` before advancing. Do not use radio-circle styling for a multi-select mental model; this is an explicit single-selection list.

- [ ] **Step 4: Build the Setup beat and persistence action**

Render the three approved setup rows with clear icon, label, supporting copy, and selected state. `Start my grow` calls the throwing `GrowStore.createGrow`, sends the ID to the coordinator, and advances only on success. Surface `GrowStoreError` inline without losing selections.

- [ ] **Step 5: Build session-only sample mode**

Render a read-only basil specimen, sample Day-7 timeline, and sample future-reel strip from value data only. Provide `Start my own grow` and `Back`. Do not call `GrowStore`, `PhotoService`, `StreakService`, or `ReelRenderingService`.

- [ ] **Step 6: Add deterministic debug launch arguments**

Add DEBUG-only arguments:

```text
-resetOnboarding
-openFirstSeed
-firstSeedStep promise|crop|setup|capture|reward|sample
```

These must reset only simulator sample data and `grow.onboarding.completedVersion` when explicitly requested.

In `GrowApp`, create and inject one `OnboardingCoordinator`. In `RootView`, add `@AppStorage(OnboardingPolicy.completedVersionKey)` and derive `OnboardingLaunchRoute` from completion version, the active grow, and its photo count. Route `.ceremony` to the Promise beat, `.resumeCapture` to `FirstSeedFlow(initialStep: .capture, ...)`, and `.app` to the existing tab experience. Do not mark onboarding complete until Task 5 reward completion.

- [ ] **Step 7: Verify UI in XcodeBuildMCP**

Capture Promise, Choose, Setup, and Sample screenshots plus semantic snapshots on iPhone 17 Pro. Repeat Promise and Choose at Accessibility Large. Reject clipping, low contrast, invisible actions, nested-card styling, or generic questionnaire aesthetics.

- [ ] **Step 8: Commit and push Task 4**

```bash
git add Grow/Views/FirstSeedFlow.swift Grow/Views/FirstSeedPromiseView.swift Grow/Views/FirstSeedCropView.swift Grow/Views/FirstSeedSetupView.swift Grow/Views/RootView.swift Grow/GrowApp.swift GrowTests/FirstSeedVisualContractTests.swift docs/superpowers/plans/2026-07-12-first-seed-ceremony.md
git commit -m "Build first seed ceremony setup"
git push origin main
```

## Task 5: Integrate Day-1 Capture, Reward, and Completion

**Files:**
- Modify: `Grow/Views/FirstSeedFlow.swift`
- Modify: `Grow/Views/GuidedPlantCameraView.swift`
- Modify: `Grow/Views/CaptureRewardSequenceView.swift`
- Modify: `Grow/Services/OnboardingCoordinator.swift`
- Modify: `Grow/Views/RootView.swift`
- Modify: `Grow/GrowApp.swift`
- Modify: `GrowTests/OnboardingCoordinatorTests.swift`
- Modify: `docs/superpowers/plans/2026-07-12-first-seed-ceremony.md`

**Interfaces:**
- Produces the real Day-1 completion path and versioned completion write.
- Consumes created `Grow`, `PhotoService.recordCapture`, shared guided camera/reward, and `@AppStorage` completion version.

- [ ] **Step 1: Mark Task 5 in progress and add failing completion tests**

Add coordinator tests proving: capture failure keeps `.capture` and exposes retry copy; successful reward moves to `.reward`; completion is allowed only with both a created grow ID and reward.

- [ ] **Step 2: Add explicit completion eligibility**

Expose:

```swift
var canComplete: Bool { createdGrowID != nil && reward != nil && step == .reward }
```

Add `complete() -> Bool` that returns `false` without changing state when eligibility is unmet.

- [ ] **Step 3: Wire Day-1 live camera and import paths**

Use `GuidedPlantCameraConfiguration.dayOne`. Live capture and `PhotosPicker` import both call `PhotoService.recordCapture`. On success call `coordinator.didCapture(reward)`. On failure keep capture visible, show human copy, and offer retry/import. For denied permission show import and `UIApplication.openSettingsURLString` only after the user chooses Settings.

- [ ] **Step 4: Present the approved reward conclusion**

Compose `CaptureRewardSequenceView` with ceremony-specific header `Growth memory saved`, the real captured thumbnail when available, the existing twin/streak/future-reel content, and primary action `Meet your basil`. Bloom apricot appears on this earned completion action, not before.

- [ ] **Step 5: Mark completion and route to Today**

On the primary reward action, require `canComplete`, write `OnboardingPolicy.currentVersion` to `grow.onboarding.completedVersion`, then invoke `onCompleted` so `RootView` shows Today. If an active grow already has a photo on relaunch, set the completion version and route to app without replaying the reward.

- [ ] **Step 6: Verify cross-feature Day-1 consistency**

Complete the ceremony using simulator capture, then inspect Today, Capture, and Reels. All three must show the same crop, system, Day 1, one frame, and 3% first-reel progress. Fix singular copy to `1 frame`, never `1 frames`.

- [ ] **Step 7: Run focused tests, full tests, build, and screenshots**

Capture live/simulator Day-1 camera, reward, and Today destination. Use semantic snapshots to confirm shutter, import, retry, and completion labels.

- [ ] **Step 8: Commit and push Task 5**

```bash
git add Grow/Views/FirstSeedFlow.swift Grow/Views/GuidedPlantCameraView.swift Grow/Views/CaptureRewardSequenceView.swift Grow/Services/OnboardingCoordinator.swift Grow/Views/RootView.swift Grow/GrowApp.swift Grow/Views/ReelsScreen.swift GrowTests/OnboardingCoordinatorTests.swift docs/superpowers/plans/2026-07-12-first-seed-ceremony.md
git commit -m "Complete day one onboarding reward"
git push origin main
```

## Task 6: Accessibility, Simulator QA, and Release Verification

**Files:**
- Modify ceremony/shared view files only where QA finds concrete defects.
- Modify relevant focused tests for every corrected contract.
- Modify `docs/superpowers/plans/2026-07-12-first-seed-ceremony.md`.

**Interfaces:**
- Consumes all prior tasks.
- Produces verified ship-ready activation slice.

- [ ] **Step 1: Mark Task 6 in progress and record QA matrix**

Append each scenario and its result to Change Log before making corrections.

- [ ] **Step 2: Run the full unit suite**

Use XcodeBuildMCP `test_sim`. Expected: all existing and new tests pass with zero failures.

- [ ] **Step 3: Run the required clean build**

Run the exact required build command. If sandboxed CoreSimulator services fail, rerun with approval as required by `AGENTS.md`.

- [ ] **Step 4: Execute the simulator flow matrix**

Verify clean basil/Kratky/simulator capture; lettuce/countertop/import; denied-camera recovery; sample exit; interruption after grow creation; and completed Day-1 cross-tab consistency.

- [ ] **Step 5: Execute accessibility visual matrix**

Verify standard and Accessibility Large text, Reduce Motion, Reduce Transparency, Increased Contrast, and Differentiate Without Color. Take XcodeBuildMCP screenshots and semantic snapshots for Promise, Choose, Setup, Capture, Reward, and Today.

- [ ] **Step 6: Inspect runtime logs and durable media**

Confirm no runtime errors, the Day-1 photo file exists and is nonempty in the app group, the SwiftData record contains a relative filename and thumbnail rather than full image bytes, and relaunch preserves/resumes the correct state.

- [ ] **Step 7: Run repository checks**

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; only intended implementation/plan changes before the final commit.

- [ ] **Step 8: Complete plan, commit, and push**

Mark all todos complete, record test/build/simulator evidence, then:

```bash
git add Grow GrowTests docs/superpowers/plans/2026-07-12-first-seed-ceremony.md
git commit -m "Polish first seed onboarding ceremony"
git push origin main
```

## Plan Self-Review

- Spec coverage: Tasks 1–6 cover every product beat, persistence boundary, sample mode, error/recovery case, accessibility requirement, shared-camera/reward constraint, simulator scenario, build command, commit, and push requirement.
- Placeholder scan: no `TBD`, `TODO`, generic error-handling instruction, or forward reference to an undefined UI destination remains.
- Type consistency: `OnboardingStep`, `OnboardingSetupChoice`, `OnboardingLaunchRoute`, `OnboardingGrowRequest`, `OnboardingPolicy`, `OnboardingCoordinator`, `GuidedPlantCameraConfiguration`, `GuidedPlantCameraView`, and `CaptureRewardSequenceView` retain the same names across tasks.
- Scope check: Care, Dex, widget, Live Activity, Plant Doctor, monetization, accounts, and hardware pairing remain outside this milestone.
