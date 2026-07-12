# Living Twin Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a glanceable Living Field Journal widget that reads the active grow snapshot from `group.com.sviftstudios.Grow`, renders a living twin in small and medium families, and deep-links to capture.

**Architecture:** Add one native WidgetKit extension (`com.sviftstudios.Grow.GrowWidget`) to the existing Xcode project. Keep the cross-process payload Foundation-only in a shared source file compiled into the app and extension; app-module tests exercise the same type through `@testable import Grow`. The app remains the sole writer and the widget remains a read-only `TimelineProvider` consumer. Use `StaticConfiguration` because launch supports one active grow and needs no configuration UI.

**Tech Stack:** SwiftUI, WidgetKit, Foundation, App Groups, XCTest, Swift 5.0, iOS 26.2, XcodeBuildMCP.

## Global Constraints

- Work directly on `main`; commit and push every verified checkpoint.
- Keep iOS 26.2 and bundle IDs `com.sviftstudios.Grow` / `com.sviftstudios.Grow.GrowWidget`.
- Keep the App Group exactly `group.com.sviftstudios.Grow` on app and widget.
- The widget reads only `WidgetGrowSnapshot` JSON from shared `UserDefaults`; it does not open SwiftData or mutate app state.
- Use `StaticConfiguration`, a single-entry timeline, and `.after` refresh; app mutations continue to call `WidgetCenter.reloadAllTimelines()`.
- Support `.systemSmall` and `.systemMedium` only for v1.
- Keep the widget glanceable: plant, crop, Day N, streak, and next capture; no scrolling, nested cards, controls, or generic dashboard grid.
- Use color plus glyph plus label, semantic text, widget rendering modes, and system typography.
- Use `.containerBackground(for: .widget)` and `widgetURL(URL(string: "grow://capture"))`.
- Visual QA uses iPhone 17 Pro at the default content size only.
- Required build after Swift/project changes:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

---

## Living Todo

- [x] Task 1: Add and test the cross-process snapshot contract.
- [x] Task 2: Add the WidgetKit extension target and Living Twin widget.
- [x] Task 3: Add capture deep-link routing and widget reload behavior.
- [ ] **Task 4: Verify signed App Group reads, widget rendering, tests, build, commit, and push.** _(in progress)_

## Change Log

- 2026-07-13: Plan created and self-reviewed against the approved product plan and current Apple WidgetKit/App Group guidance from Sosumi.
- 2026-07-13: Started Task 1 with app-writer/widget-reader round-trip, corrupt payload, and schema-version tests.
- 2026-07-13: Completed Task 1 with a Foundation-only shared payload and reader, centralized App Group keys, 3 focused contract tests, 45 full-suite tests, and an XcodeBuildMCP simulator build passing. Commit/push waits on the active Git approval quota window.
- 2026-07-13: Started Task 2 with the native extension target, shared App Group entitlement, static timeline provider, and small/medium Living Field Journal layouts.
- 2026-07-13: Completed Task 2 with an embedded `GrowWidget.appex`, valid WidgetKit extension metadata, static App Group timeline provider, small and medium Living Twin gallery previews, and a live Day-7 medium widget installed on the iPhone 17 Pro Home Screen.
- 2026-07-13: Started Task 3 with pure `grow://capture` and `grow://today` routing tests before app navigation changes.
- 2026-07-13: Completed Task 3 with case-insensitive pure URL routing, deferred onboarding-safe navigation, registered `grow` scheme metadata, 3 focused passing tests, and a simulator proof that `grow://capture` opens the active Day-7 Capture screen at standard content size.
- 2026-07-13: Started Task 4 release-gate verification across the full test suite, exact build, embedded extension, shared entitlements, runtime logs, and widget rendering.
- 2026-07-13: Release-gate checkpoint passes 48 tests and the exact required build. The built app embeds a validated `com.apple.widgetkit-extension`, registers `grow`, and both target entitlement sources declare `group.com.sviftstudios.Grow`. Signed simulator bundles expose empty entitlements by platform convention, while the earlier live Day-7 widget read proves cross-process App Group access. Runtime logs contain no widget/App Group/decode failures. Full-color small and medium previews plus the live medium widget were visually checked at standard content size; appearance-variant QA remains before closing Task 4.

## File Structure

- Create `GrowShared/WidgetGrowSnapshot.swift`
  - Foundation-only payload, keys, sample/empty values, and injected-defaults reader.
- Modify `Grow/Services/WidgetSyncService.swift`
  - Use the shared payload and keys; remain the only writer.
- Create `GrowTests/WidgetSnapshotContractTests.swift`
  - Round-trip, missing/corrupt payload, and schema assertions.
- Create `GrowWidget/GrowWidget.swift`
  - Widget entry point, provider, small/medium layouts, and widget twin primitive.
- Create `GrowWidget-Info.plist` outside the synchronized source folder so Xcode processes the nested WidgetKit extension metadata exactly once.
- Create `GrowWidget/GrowWidget.entitlements`
  - App Group entitlement.
- Modify `Grow.xcodeproj/project.pbxproj`
  - Widget target, shared synchronized group, extension embedding, dependency, and build configurations.
- Modify `Info.plist`
  - Register the `grow` URL scheme.
- Modify `Grow/Views/RootView.swift`
  - Route `grow://capture` to Capture after onboarding.
- Create `GrowTests/DeepLinkRoutingTests.swift`
  - Pure URL-to-tab policy tests.

## Task 1: Add and Test the Cross-Process Snapshot Contract

**Files:**
- Create: `GrowShared/WidgetGrowSnapshot.swift`
- Create: `GrowTests/WidgetSnapshotContractTests.swift`
- Modify: `Grow/Services/WidgetSyncService.swift`
- Modify: `Grow.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces `WidgetSnapshotKeys`, `WidgetGrowSnapshot`, and `WidgetSnapshotReader`.
- Consumes `Foundation.UserDefaults`, `Foundation.JSONDecoder`, and App Group suite data.

- [ ] **Step 1: Write failing contract tests**

Create tests asserting:

```swift
func testAppPayloadRoundTripsThroughWidgetReader() throws {
    let suite = "WidgetSnapshotContractTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let snapshot = WidgetGrowSnapshot.sample
    defaults.set(try JSONEncoder().encode(snapshot), forKey: WidgetSnapshotKeys.activeGrowSnapshot)
    XCTAssertEqual(WidgetSnapshotReader(defaults: defaults).read(), snapshot)
}

func testReaderReturnsNilForMissingOrCorruptPayload() {
    let defaults = UserDefaults(suiteName: "WidgetSnapshotCorrupt.\(UUID().uuidString)")!
    XCTAssertNil(WidgetSnapshotReader(defaults: defaults).read())
    defaults.set(Data("not-json".utf8), forKey: WidgetSnapshotKeys.activeGrowSnapshot)
    XCTAssertNil(WidgetSnapshotReader(defaults: defaults).read())
}

func testSnapshotSchemaStartsAtVersionOne() {
    XCTAssertEqual(WidgetGrowSnapshot.sample.schemaVersion, 1)
}
```

- [ ] **Step 2: Verify RED**

Run only `GrowTests/WidgetSnapshotContractTests`; expect missing shared types.

- [ ] **Step 3: Implement the Foundation-only shared contract**

Move the existing `WidgetGrowSnapshot` fields unchanged into `GrowShared/WidgetGrowSnapshot.swift`. Add:

```swift
enum WidgetSnapshotKeys {
    static let suiteName = "group.com.sviftstudios.Grow"
    static let activeGrowSnapshot = "widget.activeGrowSnapshot"
    static let activeGrowID = "widget.activeGrowID"
    static let validationStamp = "widget.validationStamp"
}

struct WidgetSnapshotReader {
    let defaults: UserDefaults
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: WidgetSnapshotKeys.suiteName) ?? .standard
    }

    func read() -> WidgetGrowSnapshot? {
        guard let data = defaults.data(forKey: WidgetSnapshotKeys.activeGrowSnapshot) else { return nil }
        return try? decoder.decode(WidgetGrowSnapshot.self, from: data)
    }
}
```

Provide deterministic `sample` and `empty` snapshots with Basil, Day 7, seven frames, 23% reel progress, and a 7-day streak.

- [ ] **Step 4: Add `GrowShared` to app and test compilation**

Add a `PBXFileSystemSynchronizedRootGroup` named `GrowShared` to the project. Include it in the `Grow` target’s `fileSystemSynchronizedGroups`; Task 2 will also include it in `GrowWidget`. The test target imports these shared types from the app module and must not compile a duplicate copy. Remove the payload struct and private key duplicates from `WidgetSyncService`; use `WidgetSnapshotKeys` and `WidgetSnapshotReader`.

- [ ] **Step 5: Verify GREEN and commit**

Run focused and full tests, required build, then commit/push:

```bash
git add GrowShared Grow/Services/WidgetSyncService.swift GrowTests/WidgetSnapshotContractTests.swift Grow.xcodeproj/project.pbxproj
git commit -m "Share widget snapshot contract"
git push origin main
```

## Task 2: Add the WidgetKit Extension and Living Twin Widget

**Files:**
- Create: `GrowWidget/GrowWidget.swift`
- Create: `GrowWidget/GrowWidget.entitlements`
- Create: `GrowWidget-Info.plist`
- Modify: `Grow.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes `WidgetSnapshotReader.read() -> WidgetGrowSnapshot?`.
- Produces `GrowTwinWidget`, `GrowWidgetProvider`, `GrowWidgetEntry`, and the embedded `GrowWidget.appex`.

- [ ] **Step 1: Add extension metadata and entitlements**

`GrowWidget-Info.plist` must contain `NSExtensionPointIdentifier = com.apple.widgetkit-extension`. It stays outside the synchronized source folder to avoid resource-copy duplication. `GrowWidget.entitlements` must contain `com.apple.security.application-groups = [group.com.sviftstudios.Grow]`.

- [ ] **Step 2: Add the Xcode target**

Add a `com.apple.product-type.app-extension` native target named `GrowWidget`, product `GrowWidget.appex`, bundle ID `com.sviftstudios.Grow.GrowWidget`, iOS 26.2, `APPLICATION_EXTENSION_API_ONLY = YES`, `SKIP_INSTALL = YES`, `CODE_SIGN_ENTITLEMENTS = GrowWidget/GrowWidget.entitlements`, and `INFOPLIST_FILE = GrowWidget-Info.plist`. Include `GrowWidget` and `GrowShared` synchronized groups. Add an app target dependency and an Embed App Extensions copy phase with `CodeSignOnCopy` and `RemoveHeadersOnCopy`.

- [ ] **Step 3: Implement the provider**

Use `TimelineProvider` with placeholder/sample, fast snapshot, and one real entry refreshed after 30 minutes:

```swift
struct GrowWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetGrowSnapshot?
}

struct GrowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GrowWidgetEntry {
        GrowWidgetEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (GrowWidgetEntry) -> Void) {
        completion(GrowWidgetEntry(date: .now, snapshot: context.isPreview ? .sample : WidgetSnapshotReader().read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GrowWidgetEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [GrowWidgetEntry(date: now, snapshot: WidgetSnapshotReader().read())], policy: .after(now.addingTimeInterval(1_800))))
    }
}
```

- [ ] **Step 4: Implement Living Field Journal layouts**

Create a widget-only parametric twin using SwiftUI shapes. Small shows crop, Day N, twin, and streak. Medium adds stage, frame/reel progress, and the next-capture line. Use `.containerBackground(for: .widget)`, adaptive warm ground/forest ink, Sprout green, Bloom only for streak/reward, `.widgetAccentable()`, and `widgetURL(grow://capture)`.

- [ ] **Step 5: Build, preview, commit, and push**

Build the `Grow` and `GrowWidget` schemes, render small/medium Xcode previews or widget-host screenshots, then:

```bash
git add GrowWidget Grow.xcodeproj/project.pbxproj
git commit -m "Add living twin widget"
git push origin main
```

## Task 3: Add Capture Deep-Link Routing and Reload Behavior

**Files:**
- Create: `Grow/Domain/DeepLinkPolicy.swift`
- Create: `GrowTests/DeepLinkRoutingTests.swift`
- Modify: `Grow/Views/RootView.swift`
- Modify: `Info.plist`

**Interfaces:**
- Produces `DeepLinkDestination` and `DeepLinkPolicy.destination(for:)`.
- Consumes URLs using scheme `grow` and host `capture`.

- [ ] **Step 1: Write failing routing tests**

Assert `grow://capture` maps to `.capture`, `grow://today` maps to `.today`, and unrelated schemes/hosts return `nil`.

- [ ] **Step 2: Verify RED, then implement the pure policy**

```swift
enum DeepLinkDestination: Equatable { case today, capture }

enum DeepLinkPolicy {
    static func destination(for url: URL) -> DeepLinkDestination? {
        guard url.scheme == "grow" else { return nil }
        return switch url.host {
        case "today": .today
        case "capture": .capture
        default: nil
        }
    }
}
```

- [ ] **Step 3: Register and route the URL**

Add `CFBundleURLTypes` for scheme `grow`. In `RootView`, handle `.onOpenURL`; after onboarding completes, set the selected tab to Capture or Today. During an unfinished ceremony, keep the ceremony visible and preserve the destination for completion.

- [ ] **Step 4: Verify and commit**

Launch `grow://capture` in simulator, confirm Capture opens with the active grow, run tests/build, then commit/push:

```bash
git add Grow/Domain/DeepLinkPolicy.swift Grow/Views/RootView.swift GrowTests/DeepLinkRoutingTests.swift Info.plist
git commit -m "Route widget capture deep links"
git push origin main
```

## Task 4: Signed Cross-Process QA and Release Gate

**Files:**
- Modify implementation files only for concrete QA defects.
- Modify focused tests for every corrected contract.
- Modify this plan’s Living Todo and Change Log.

- [ ] **Step 1: Run full tests and exact required build**

Expected: all tests pass, and the required build exits 0.

- [ ] **Step 2: Prove extension embedding and App Group parity**

Inspect the built app for `PlugIns/GrowWidget.appex`. Confirm app and widget entitlements contain the identical App Group. Seed Day 1, read the shared JSON from both app-side test code and widget provider, and compare active grow ID, crop, day, frame count, and streak.

- [ ] **Step 3: Visually verify widget states at default content size**

Capture small and medium: sample/placeholder, no active grow, Day 1, and Day 7. Verify full color and accented rendering, light/dark appearance, no clipping, and a single capture deep link.

- [ ] **Step 4: Inspect logs and restore simulator**

Confirm no widget crash, decode failure, App Group fallback, or missing-kind error. Restore standard content size and normal app launch.

- [ ] **Step 5: Complete plan, commit, and push**

Run `git diff --check`, mark all tasks complete, record evidence, then:

```bash
git add Grow GrowShared GrowWidget GrowTests Info.plist Grow.xcodeproj/project.pbxproj docs/superpowers/plans/2026-07-13-living-twin-widget.md
git commit -m "Verify living twin widget integration"
git push origin main
```

## Plan Self-Review

- Spec coverage: static WidgetKit target, App Group read path, payload contract, small/medium Living Field Journal UI, reloads, capture deep link, signed embedding, and visual/runtime verification are covered.
- Placeholder scan: no `TBD`, `TODO`, or undefined implementation destination remains.
- Type consistency: `WidgetSnapshotKeys`, `WidgetGrowSnapshot`, `WidgetSnapshotReader`, `GrowWidgetEntry`, `GrowWidgetProvider`, `GrowTwinWidget`, `DeepLinkDestination`, and `DeepLinkPolicy` retain one name and signature throughout.
- Scope check: Live Activities, configurable multi-grow widgets, interactive capture controls, and lock-screen accessory families remain separate later milestones.
