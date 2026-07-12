# Ojai UGC Photo System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every illustration currently standing in for user photography with a truthful, provenance-aware Ojai basil photo story that flows through capture memories, previews, and exported reels without altering genuine user media.

**Architecture:** Add durable raw-string media origin fields to `GrowPhoto`, an immutable manifest-backed demo library, explicit resolution policies, a bounded Image I/O decoder, and one shared SwiftUI photo surface. Simulator capture writes bundled samples through the same atomic App Group and SwiftData transaction as genuine capture, while genuine reel export fails rather than substituting sample media.

**Tech Stack:** SwiftUI, SwiftData, Foundation, ImageIO, UIKit, AVFoundation, XCTest, built-in image generation, iOS 26.2, Swift 5.0, XcodeBuildMCP.

## Global Constraints

- Work directly on `main`; commit and push every verified task.
- Keep the deployment target at iOS 26.2.
- Use native SwiftUI, SwiftData, Swift 5.0, and `@Observable` services.
- Store photos and reels as files in `group.com.sviftstudios.Grow`; store only thumbnails/posters in SwiftData external storage.
- Store enum values as raw strings with defaults; keep new SwiftData properties CloudKit-safe.
- Genuine media always outranks sample media and receives no aesthetic filter or exposure/color adjustment.
- Camera, Photos Picker, legacy, demo, recovery, and neutral fallback provenance must remain distinguishable in UI, accessibility, and export logic.
- Genuine reel export must not substitute sample content.
- Visual QA uses iPhone 17 Pro at the standard/default content size only; accessibility variants are checked without changing text size.
- Use the approved sun-washed Ojai kitchen art direction and one internally consistent basil grow.
- Keep the living digital twin and widget twin code-native; change only surfaces semantically representing photography.
- Required build after Swift, resource, or Xcode changes:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

---

## File Structure

- Create `Grow/Models/GrowPhotoOrigin.swift` — stored origin enum, provenance enum, quality enum, and stable photo ordering.
- Modify `Grow/Models/GrowModels.swift` — durable `originRaw` and `sourceSampleID` fields plus computed origin.
- Create `Grow/Resources/DemoGrow/OjaiBasil/OjaiBasilManifest.json` — uniquely named versioned sample manifest with IDs, days, sequences, crop focal points, and String Catalog keys.
- Create `Grow/Resources/DemoGrow/OjaiBasil/*.jpg` — twelve optimized portrait masters.
- Create `DesignSources/OjaiBasil/*.png` — non-target generation masters retained for derivatives.
- Create `Grow/Localizable.xcstrings` — twelve sample accessibility descriptions and recovery labels.
- Create `Grow/Services/DemoGrowPhotoLibrary.swift` — manifest validation and deterministic selection.
- Create `Grow/Services/GrowImageDecoder.swift` — Image I/O downsampling, orientation normalization, bounded caching, and cancellation.
- Create `Grow/Services/GrowPhotoSourceResolver.swift` — policy-bound media resolution and typed failures.
- Create `Grow/Views/GrowPhotoSurface.swift` — shared aspect-ratio/crop/provenance SwiftUI renderer.
- Modify `Grow/Services/PhotoService.swift` — origin-aware genuine capture and throwing transactional demo capture.
- Modify `Grow/Services/StreakService.swift` — transaction-compatible streak mutation and rollback snapshot.
- Modify `Grow/Services/ReelRenderingService.swift` — deterministic ordering and genuine-only export resolution.
- Modify `Grow/Views/FirstSeedFlow.swift` — photographic sample/captured memory surfaces.
- Modify `Grow/Views/CaptureScreen.swift` — photographic preview, reward, strip, recap, and simulator capture.
- Modify `Grow/Views/ReelsScreen.swift` — photographic promise, poster, and export surfaces.
- Create focused tests under `GrowTests/` for origin persistence, manifest validation, resolver policies, crop behavior, transaction rollback, reel ordering, and memory.

## Task 1: Persist Exact Media Origin and Stable Ordering

**Files:**
- Create: `Grow/Models/GrowPhotoOrigin.swift`
- Modify: `Grow/Models/GrowModels.swift:59-91`
- Create: `GrowTests/GrowPhotoOriginTests.swift`

**Interfaces:**
- Produces: `GrowPhotoOrigin`, `GrowPhotoProvenance`, `GrowPhotoQuality`, `GrowPhotoOrdering.areInIncreasingOrder(_:_:)`, `GrowPhoto.origin`.
- Consumes: existing `GrowPhoto.id`, `dayIndex`, and `capturedAt`.

- [x] **Step 1: Write failing origin and ordering tests**

Create `GrowTests/GrowPhotoOriginTests.swift`:

```swift
import SwiftData
import UIKit
import XCTest
@testable import Grow

@MainActor
final class GrowPhotoOriginTests: XCTestCase {
    func testLegacyOriginIsMigrationSafeDefault() {
        let photo = GrowPhoto()
        XCTAssertEqual(photo.origin, .legacyUserMedia)
        XCTAssertNil(photo.sourceSampleID)
    }

    func testDemoOriginAndSourceIDSurviveContainerReconstruction() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        defer { try? FileManager.default.removeItem(at: url) }

        let schema = GrowModelContainer.schema
        let first = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let photo = GrowPhoto(dayIndex: 7)
        photo.origin = .demoSample
        photo.sourceSampleID = "ojai-basil-day-07"
        first.mainContext.insert(photo)
        try first.mainContext.save()
        let id = photo.id

        let second = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: url)]
        )
        let fetched = try XCTUnwrap(
            second.mainContext.fetch(FetchDescriptor<GrowPhoto>()).first { $0.id == id }
        )
        XCTAssertEqual(fetched.origin, .demoSample)
        XCTAssertEqual(fetched.sourceSampleID, "ojai-basil-day-07")
    }

    func testStableOrderingUsesDayThenDateThenUUID() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let laterDay = GrowPhoto(capturedAt: date.addingTimeInterval(-10), dayIndex: 2)
        let earlierDay = GrowPhoto(capturedAt: date, dayIndex: 1)
        let firstID = GrowPhoto(capturedAt: date, dayIndex: 1)
        let secondID = GrowPhoto(capturedAt: date, dayIndex: 1)
        firstID.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        secondID.id = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let sorted = [laterDay, secondID, earlierDay, firstID]
            .sorted(by: GrowPhotoOrdering.areInIncreasingOrder)
        XCTAssertEqual(sorted.first?.id, firstID.id)
        XCTAssertEqual(sorted.last?.id, laterDay.id)
    }
}
```

- [x] **Step 2: Run the focused tests and verify RED**

Run with XcodeBuildMCP:

```text
test_sim(extraArgs: ["-only-testing:GrowTests/GrowPhotoOriginTests"])
```

Expected: compile failure because `GrowPhotoOrigin`, `origin`, and `GrowPhotoOrdering` do not exist.

- [x] **Step 3: Implement origin, provenance, quality, and ordering**

Create `Grow/Models/GrowPhotoOrigin.swift`:

```swift
import Foundation

enum GrowPhotoOrigin: String, Codable, Sendable {
    case legacyUserMedia
    case camera
    case photoLibrary
    case demoSample
}

enum GrowPhotoProvenance: Equatable, Sendable {
    case legacyUserMedia
    case camera
    case photoLibrary
    case demoSample(sampleID: String)
    case recoverySample(sampleID: String)
    case neutralFallback
}

enum GrowPhotoQuality: Equatable, Sendable {
    case fullSize
    case thumbnail
    case fallback
}

enum GrowPhotoOrdering {
    static func areInIncreasingOrder(_ lhs: GrowPhoto, _ rhs: GrowPhoto) -> Bool {
        if lhs.dayIndex != rhs.dayIndex { return lhs.dayIndex < rhs.dayIndex }
        if lhs.capturedAt != rhs.capturedAt { return lhs.capturedAt < rhs.capturedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
```

Add to `GrowPhoto` in `Grow/Models/GrowModels.swift`:

```swift
var originRaw: String = GrowPhotoOrigin.legacyUserMedia.rawValue
var sourceSampleID: String? = nil

var origin: GrowPhotoOrigin {
    get { GrowPhotoOrigin(rawValue: originRaw) ?? .legacyUserMedia }
    set { originRaw = newValue.rawValue }
}
```

- [x] **Step 4: Run focused and full tests**

Run the focused test, then `test_sim()` through XcodeBuildMCP.

Expected: all existing tests plus the three new tests pass.

- [x] **Step 5: Commit and push**

```bash
git add Grow/Models/GrowPhotoOrigin.swift Grow/Models/GrowModels.swift GrowTests/GrowPhotoOriginTests.swift
git commit -m "Persist grow photo origin"
git push origin main
```

## Task 2: Add and Validate the Demo Story Manifest

**Files:**
- Create: `Grow/Services/DemoGrowPhotoLibrary.swift`
- Create: `GrowTests/DemoGrowPhotoLibraryTests.swift`

**Interfaces:**
- Produces: `NormalizedPoint`, `DemoGrowCropIntent`, `DemoGrowStoryMoment`, `DemoGrowPhotoFrame`, `DemoGrowPhotoManifest`, `DemoGrowPhotoLibrary`, `DemoGrowPhotoLibraryError`.
- Consumes: `Foundation.Data`, injected asset lookup `(String) -> Data?`.

- [x] **Step 1: Write failing manifest contract tests**

Create `GrowTests/DemoGrowPhotoLibraryTests.swift` with an in-memory asset loader:

```swift
import XCTest
@testable import Grow

final class DemoGrowPhotoLibraryTests: XCTestCase {
    func testSparseDayChoosesNearestPriorFrame() throws {
        let library = try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "d1", day: 1, sequence: 0), frame(id: "d7", day: 7, sequence: 1)]),
            assetData: { _ in Self.validJPEG }
        )
        XCTAssertEqual(try library.frame(forDay: 5).id, "d1")
        XCTAssertEqual(try library.frame(forDay: 40).id, "d7")
    }

    func testDayBeforeFirstMasterFails() throws {
        let library = try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "d1", day: 1, sequence: 0)]),
            assetData: { _ in Self.validJPEG }
        )
        XCTAssertThrowsError(try library.frame(forDay: 0)) {
            XCTAssertEqual($0 as? DemoGrowPhotoLibraryError, .noPriorMaster)
        }
    }

    func testDuplicateIDAndSequenceRejectManifest() {
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "same", day: 1, sequence: 0), frame(id: "same", day: 2, sequence: 1)]),
            assetData: { _ in Self.validJPEG }
        ))
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "a", day: 1, sequence: 0), frame(id: "b", day: 2, sequence: 0)]),
            assetData: { _ in Self.validJPEG }
        ))
    }

    func testMissingOrCorruptReferencedAssetRejectsManifest() {
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "d1", day: 1, sequence: 0)]),
            assetData: { _ in nil }
        ))
        XCTAssertThrowsError(try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "d1", day: 1, sequence: 0)]),
            assetData: { _ in Data("not-image".utf8) }
        ))
    }

    func testDuplicateDayOrdersBySequence() throws {
        let library = try DemoGrowPhotoLibrary(
            manifestData: manifestData(frames: [frame(id: "harvest", day: 30, sequence: 11), frame(id: "mature", day: 30, sequence: 9)]),
            assetData: { _ in Self.validJPEG }
        )
        XCTAssertEqual(try library.reelFrames().map(\.id), ["mature", "harvest"])
    }
}
```

Add these deterministic helpers inside `DemoGrowPhotoLibraryTests`:

```swift
private func frame(id: String, day: Int, sequence: Int) -> DemoGrowPhotoFrame {
    DemoGrowPhotoFrame(
        id: id,
        fileName: "\(id).jpg",
        day: day,
        sequence: sequence,
        moment: .ordinary,
        focalPoints: Dictionary(
            uniqueKeysWithValues: DemoGrowCropIntent.allCases.map {
                ($0, NormalizedPoint(x: 0.5, y: 0.5))
            }
        ),
        accessibilityKey: "\(id)_accessibility"
    )
}

private func manifestData(frames: [DemoGrowPhotoFrame]) -> Data {
    try! JSONEncoder().encode(
        DemoGrowPhotoManifest(
            schemaVersion: 1,
            storyID: "test-story",
            maximumOrdinaryDay: 30,
            frames: frames
        )
    )
}

private static let validJPEG: Data = {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
        UIColor.systemGreen.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    return image.jpegData(compressionQuality: 0.9)!
}()
```

- [x] **Step 2: Run the focused tests and verify RED**

Run:

```text
test_sim(extraArgs: ["-only-testing:GrowTests/DemoGrowPhotoLibraryTests"])
```

Expected: compile failure because the manifest and library types do not exist.

- [x] **Step 3: Implement the manifest contract and validator**

Create `Grow/Services/DemoGrowPhotoLibrary.swift` with these public-to-module contracts:

```swift
import Foundation
import ImageIO

struct NormalizedPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double

    var isValid: Bool { (0...1).contains(x) && (0...1).contains(y) }
}

enum DemoGrowCropIntent: String, Codable, CaseIterable, Sendable {
    case reelPortrait
    case memorySquare
    case timelineStrip
    case posterThumbnail
}

enum DemoGrowStoryMoment: String, Codable, Sendable {
    case setup, ordinary, harvest, finale
}

struct DemoGrowPhotoFrame: Codable, Equatable, Sendable {
    let id: String
    let fileName: String
    let day: Int
    let sequence: Int
    let moment: DemoGrowStoryMoment
    let focalPoints: [DemoGrowCropIntent: NormalizedPoint]
    let accessibilityKey: String
}

struct DemoGrowPhotoManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let storyID: String
    let maximumOrdinaryDay: Int
    let frames: [DemoGrowPhotoFrame]
}

enum DemoGrowPhotoLibraryError: Error, Equatable {
    case malformedManifest
    case duplicateID(String)
    case duplicateSequence(Int)
    case invalidFrame(String)
    case assetUnavailable(sampleID: String)
    case invalidRequestedDay
    case noPriorMaster
    case missingStoryMoment(DemoGrowStoryMoment)
}

struct DemoGrowPhotoAsset: Sendable {
    let frame: DemoGrowPhotoFrame
    let data: Data
}

struct DemoGrowPhotoLibrary: Sendable {
    private let manifest: DemoGrowPhotoManifest
    private let assets: [String: Data]

    init(manifestData: Data, assetData: (String) -> Data?) throws {
        guard let decoded = try? JSONDecoder().decode(DemoGrowPhotoManifest.self, from: manifestData),
              decoded.schemaVersion == 1,
              !decoded.frames.isEmpty else { throw DemoGrowPhotoLibraryError.malformedManifest }

        var ids = Set<String>()
        var sequences = Set<Int>()
        var loaded: [String: Data] = [:]
        for frame in decoded.frames {
            guard ids.insert(frame.id).inserted else { throw DemoGrowPhotoLibraryError.duplicateID(frame.id) }
            guard sequences.insert(frame.sequence).inserted else { throw DemoGrowPhotoLibraryError.duplicateSequence(frame.sequence) }
            guard frame.day >= 0,
                  frame.sequence >= 0,
                  Set(frame.focalPoints.keys) == Set(DemoGrowCropIntent.allCases),
                  frame.focalPoints.values.allSatisfy(\.isValid) else {
                throw DemoGrowPhotoLibraryError.invalidFrame(frame.id)
            }
            guard let data = assetData(frame.fileName),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
                throw DemoGrowPhotoLibraryError.assetUnavailable(sampleID: frame.id)
            }
            loaded[frame.id] = data
        }
        manifest = decoded
        assets = loaded
    }

    func frame(forDay day: Int) throws -> DemoGrowPhotoFrame {
        guard day >= 0 else { throw DemoGrowPhotoLibraryError.invalidRequestedDay }
        let clamped = min(day, manifest.maximumOrdinaryDay)
        guard let frame = manifest.frames
            .filter({ $0.moment == .ordinary && $0.day <= clamped })
            .max(by: { $0.day == $1.day ? $0.sequence < $1.sequence : $0.day < $1.day }) else {
            throw DemoGrowPhotoLibraryError.noPriorMaster
        }
        return frame
    }

    func asset(forDay day: Int) throws -> DemoGrowPhotoAsset {
        let frame = try frame(forDay: day)
        guard let data = assets[frame.id] else { throw DemoGrowPhotoLibraryError.assetUnavailable(sampleID: frame.id) }
        return DemoGrowPhotoAsset(frame: frame, data: data)
    }

    func reelFrames() throws -> [DemoGrowPhotoFrame] {
        manifest.frames.sorted { $0.sequence < $1.sequence }
    }
}
```

- [x] **Step 4: Run focused and full tests**

Expected: all manifest tests and the full suite pass.

- [ ] **Step 5: Commit and push**

```bash
git add Grow/Services/DemoGrowPhotoLibrary.swift GrowTests/DemoGrowPhotoLibraryTests.swift
git commit -m "Define Ojai demo photo manifest"
git push origin main
```

## Task 3: Generate, Curate, and Bundle the Twelve-Frame Ojai Story

**Files:**
- Create: `DesignSources/OjaiBasil/*.png`
- Create: `Grow/Resources/DemoGrow/OjaiBasil/*.jpg`
- Create: `Grow/Resources/DemoGrow/OjaiBasil/OjaiBasilManifest.json`
- Create: `Grow/Localizable.xcstrings`
- Modify: `GrowTests/DemoGrowPhotoLibraryTests.swift`

**Interfaces:**
- Produces: twelve files referenced by manifest IDs, `DemoGrowPhotoLibrary.bundled`, localization keys.
- Consumes: `DemoGrowPhotoManifest` and `DemoGrowPhotoFrame` from Task 2.

- [ ] **Step 1: Generate the continuity anchor with the built-in image generation tool**

Generate `ojai-basil-setup` with this exact production prompt:

```text
Use case: photorealistic-natural
Asset type: portrait iPhone UGC source for an iOS hydroponic grow journal and 9:16 reel
Primary request: the first frame of one affluent but understated California woman's month-long basil grow, before the shoot emerges
Scene/backdrop: sun-washed Ojai kitchen, softly imperfect warm limewash wall, pale oak counter, cream linen curtain at frame left, handmade off-white ceramic catch tray
Subject: one amber glass Kratky jar in the exact center-lower portion of frame; black net cup holding one compact warm-tan coir starter plug; basil seed slightly recessed in the plug; no visible green shoot; the nutrient solution visibly wets the lower portion of the plug
Style/medium: believable elevated iPhone 17 Pro camera-roll photograph, not commercial advertising
Composition/framing: portrait 9:16, fixed eye-level camera anchor, vessel fully visible, subject inside central 70 percent width and central 80 percent height, negative space above for day overlay
Lighting/mood: soft cool early-morning window light, quiet optimism, slight realistic exposure falloff
Color palette: limewash cream, pale oak, amber glass, restrained healthy green only if naturally present in a tiny background herb
Materials/textures: real glass refraction, clearly readable nutrient line, fibrous compressed coir plug with a subtly darker wetted base, oak grain, rumpled linen, imperfect handmade ceramic
Constraints: establish immutable vessel shape, coir plug geometry and position, initial nutrient contact depth, counter grain, curtain folds, wall texture, camera lens and perspective for every later frame; no face; no text; no logo; no watermark
Avoid: empty net cup, loose seed in plastic basket, unexplained pale object, submerged whole plug, glossy product lighting, HDR halos, fake portrait blur, soil inside the jar, plastic leaves, extra vessels, impossible reflections, duplicated objects
```

Inspect the generated image for the approved invariants. Copy the selected built-in output to `DesignSources/OjaiBasil/ojai-basil-setup.png`.

- [ ] **Step 2: Derive the eleven later masters sequentially**

For each row, edit the immediately preceding approved source image with the built-in image generation tool. Repeat this invariant block in every prompt:

```text
Input image: edit target and continuity reference.
Preserve exactly: amber jar geometry and blemishes, net cup, compact coir plug geometry and position, ceramic tray, oak grain, wall texture, curtain folds, lens, camera height, perspective, and overall composition.
Change only: the listed plant growth, gradual nutrient-level progression, light variation, and listed human/lifestyle detail.
Keep the basil botanically plausible and continuous with the preceding frame.
The early nutrient line wets the plug's lower portion; as roots develop, lower it gradually below the net cup to create a plausible air gap.
No empty basket, loose seed, face, text, logo, watermark, soil, extra jar, duplicated leaves, merged fingers, or artificial HDR.
```

| Output | Change only |
|---|---|
| `ojai-basil-day-01.png` | Same coir plug and initial nutrient contact; one barely visible germination cue; a cream linen cuff and two fingertips gently steady the net cup; cool morning light. |
| `ojai-basil-day-02.png` | Same coir plug and near-identical nutrient level; minuscule emerging pale-green hook; remove hand; shift exposure by less than one third stop. |
| `ojai-basil-day-03.png` | Two small cotyledons open above the net cup; fine pale roots just visible through amber glass; nutrient line begins its gradual drop; soft overcast light. |
| `ojai-basil-day-05.png` | First true leaf pair appears; roots lengthen naturally; half-finished handmade coffee cup enters far-right background, softly out of focus. |
| `ojai-basil-day-07.png` | Healthy first-week seedling with two cotyledons and two true-leaf pairs; slim vintage gold bracelet and linen sleeve near jar without touching plant; bright late-morning sun. |
| `ojai-basil-day-10.png` | One additional leaf pair and early branching cue; hand absent; subtle sun stripe moves across counter. |
| `ojai-basil-day-14.png` | Denser but still young basil canopy with plausible stem spacing and stronger root mass; small pruning scissors rest at far left. |
| `ojai-basil-day-21.png` | Structured mature basil with multiple branches, no flowers, jar and net cup still visible; warm neutral midday light. |
| `ojai-basil-day-30.png` | Full healthy harvest-ready canopy, natural leaf variation and minor imperfections, no flowers; warm golden late-afternoon light. |
| `ojai-basil-harvest.png` | Same mature plant; linen-sleeved hands with anatomically correct fingers use small scissors to prune above a node; no face. |
| `ojai-basil-finale.png` | Same jar with a responsibly pruned plant; harvested basil rests on the handmade tray beside a folded linen napkin and market tote edge; warm calm finale light. |

Save each approved master to `DesignSources/OjaiBasil/` before deriving the next image. Reject and regenerate any frame that changes a continuity invariant.

- [ ] **Step 3: Produce optimized bundled JPEGs**

For each selected PNG, create a 2160×3840 portrait JPEG in `Grow/Resources/DemoGrow/OjaiBasil/` with sRGB conversion, stripped metadata, and quality 0.88. Use the workspace's bundled image runtime or `sips` for mechanical conversion; do not apply exposure, color, sharpening, or beauty adjustments. Verify:

```bash
sips -g pixelWidth -g pixelHeight -g format Grow/Resources/DemoGrow/OjaiBasil/*.jpg
```

Expected: twelve JPEG files, each 2160×3840. Inspect every JPEG after conversion.

- [ ] **Step 4: Add the exact production manifest**

Create `Grow/Resources/DemoGrow/OjaiBasil/OjaiBasilManifest.json` with this exact initial content:

```json
{
  "schemaVersion": 1,
  "storyID": "ojai-basil-v1",
  "maximumOrdinaryDay": 30,
  "frames": [
    {"id":"ojai-basil-setup","fileName":"ojai-basil-setup.jpg","day":0,"sequence":0,"moment":"setup","focalPoints":{"reelPortrait":{"x":0.50,"y":0.56},"memorySquare":{"x":0.50,"y":0.52},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.56}},"accessibilityKey":"demo_ojai_setup_accessibility"},
    {"id":"ojai-basil-day-01","fileName":"ojai-basil-day-01.jpg","day":1,"sequence":1,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.56},"memorySquare":{"x":0.50,"y":0.52},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.56}},"accessibilityKey":"demo_ojai_day_01_accessibility"},
    {"id":"ojai-basil-day-02","fileName":"ojai-basil-day-02.jpg","day":2,"sequence":2,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.56},"memorySquare":{"x":0.50,"y":0.52},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.56}},"accessibilityKey":"demo_ojai_day_02_accessibility"},
    {"id":"ojai-basil-day-03","fileName":"ojai-basil-day-03.jpg","day":3,"sequence":3,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.56},"memorySquare":{"x":0.50,"y":0.52},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.56}},"accessibilityKey":"demo_ojai_day_03_accessibility"},
    {"id":"ojai-basil-day-05","fileName":"ojai-basil-day-05.jpg","day":5,"sequence":4,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.56},"memorySquare":{"x":0.50,"y":0.52},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.56}},"accessibilityKey":"demo_ojai_day_05_accessibility"},
    {"id":"ojai-basil-day-07","fileName":"ojai-basil-day-07.jpg","day":7,"sequence":5,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.56},"memorySquare":{"x":0.50,"y":0.52},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.56}},"accessibilityKey":"demo_ojai_day_07_accessibility"},
    {"id":"ojai-basil-day-10","fileName":"ojai-basil-day-10.jpg","day":10,"sequence":6,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.56},"memorySquare":{"x":0.50,"y":0.52},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.56}},"accessibilityKey":"demo_ojai_day_10_accessibility"},
    {"id":"ojai-basil-day-14","fileName":"ojai-basil-day-14.jpg","day":14,"sequence":7,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.54},"memorySquare":{"x":0.50,"y":0.50},"timelineStrip":{"x":0.50,"y":0.55},"posterThumbnail":{"x":0.50,"y":0.54}},"accessibilityKey":"demo_ojai_day_14_accessibility"},
    {"id":"ojai-basil-day-21","fileName":"ojai-basil-day-21.jpg","day":21,"sequence":8,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.51},"memorySquare":{"x":0.50,"y":0.48},"timelineStrip":{"x":0.50,"y":0.53},"posterThumbnail":{"x":0.50,"y":0.51}},"accessibilityKey":"demo_ojai_day_21_accessibility"},
    {"id":"ojai-basil-day-30","fileName":"ojai-basil-day-30.jpg","day":30,"sequence":9,"moment":"ordinary","focalPoints":{"reelPortrait":{"x":0.50,"y":0.49},"memorySquare":{"x":0.50,"y":0.47},"timelineStrip":{"x":0.50,"y":0.51},"posterThumbnail":{"x":0.50,"y":0.49}},"accessibilityKey":"demo_ojai_day_30_accessibility"},
    {"id":"ojai-basil-harvest","fileName":"ojai-basil-harvest.jpg","day":30,"sequence":10,"moment":"harvest","focalPoints":{"reelPortrait":{"x":0.55,"y":0.48},"memorySquare":{"x":0.57,"y":0.47},"timelineStrip":{"x":0.58,"y":0.50},"posterThumbnail":{"x":0.55,"y":0.48}},"accessibilityKey":"demo_ojai_harvest_accessibility"},
    {"id":"ojai-basil-finale","fileName":"ojai-basil-finale.jpg","day":30,"sequence":11,"moment":"finale","focalPoints":{"reelPortrait":{"x":0.50,"y":0.57},"memorySquare":{"x":0.50,"y":0.54},"timelineStrip":{"x":0.50,"y":0.58},"posterThumbnail":{"x":0.50,"y":0.57}},"accessibilityKey":"demo_ojai_finale_accessibility"}
  ]
}
```

After inspecting the four crop previews for every master, adjust only the focal-point numbers that visibly cut off a plant tip, vessel base, or harvest gesture. Re-run manifest tests after each adjustment.

- [ ] **Step 5: Add String Catalog accessibility copy**

Create English catalog entries with this exact copy:

```text
demo_ojai_setup_accessibility = "Setup sample photo of an amber hydroponic jar with a basil seed in a coir starter plug on a pale oak counter."
demo_ojai_day_01_accessibility = "Day 1 sample photo of a newly planted basil seed in an amber hydroponic jar."
demo_ojai_day_02_accessibility = "Day 2 sample photo of the first tiny basil sprout in an amber hydroponic jar."
demo_ojai_day_03_accessibility = "Day 3 sample photo of basil cotyledons opening above an amber hydroponic jar."
demo_ojai_day_05_accessibility = "Day 5 sample photo of basil's first true leaves on a sunlit oak counter."
demo_ojai_day_07_accessibility = "Day 7 sample photo of young basil in an amber hydroponic jar on a sunlit oak counter."
demo_ojai_day_10_accessibility = "Day 10 sample photo of a branching young basil plant in an amber hydroponic jar."
demo_ojai_day_14_accessibility = "Day 14 sample photo of a denser basil canopy and visible hydroponic roots."
demo_ojai_day_21_accessibility = "Day 21 sample photo of structured mature basil in an amber hydroponic jar."
demo_ojai_day_30_accessibility = "Day 30 sample photo of full harvest-ready basil in warm afternoon light."
demo_ojai_harvest_accessibility = "Harvest sample photo of linen-sleeved hands pruning mature basil above a node."
demo_ojai_finale_accessibility = "Final sample photo of harvested basil beside the pruned plant and amber jar."
```

Also add:

```text
sample_frame_badge = "Sample frame"
sample_frame_recovery_accessibility = "Sample recovery frame; the original photo is unavailable."
missing_reel_frame_error = "A photo in this reel is unavailable. Restore it before exporting."
```

- [ ] **Step 6: Add bundled initialization and resource contract test**

Add to `DemoGrowPhotoLibrary`:

```swift
static func bundled(bundle: Bundle = .main) throws -> DemoGrowPhotoLibrary {
    guard let manifestURL = bundle.url(
        forResource: "OjaiBasilManifest",
        withExtension: "json",
        subdirectory: nil
    ) else { throw DemoGrowPhotoLibraryError.malformedManifest }
    let manifestData = try Data(contentsOf: manifestURL)
    return try DemoGrowPhotoLibrary(manifestData: manifestData) { fileName in
        guard let url = bundle.url(
            forResource: fileName.replacingOccurrences(of: ".jpg", with: ""),
            withExtension: "jpg",
            subdirectory: nil
        ) else { return nil }
        return try? Data(contentsOf: url)
    }
}
```

Add `testBundledStoryLoadsAllTwelveFramesInSequence()` using `DemoGrowPhotoLibrary.bundled(bundle: .main)` and assert the IDs exactly match the manifest order from setup through finale.

- [ ] **Step 7: Visually review the contact sheet and crop matrix**

Create a non-shipping contact sheet in `/tmp` showing all twelve frames and a crop matrix for 9:16, 1:1, strip, and poster intents. Inspect continuity, human anatomy, growth direction, water/root plausibility, overlay safe area, and absence of embedded text.

- [ ] **Step 8: Run tests/build, commit, and push**

Run focused manifest tests, full tests, XcodeBuildMCP build, and the exact required build. Then:

```bash
git add DesignSources/OjaiBasil Grow/Resources/DemoGrow/OjaiBasil Grow/Localizable.xcstrings Grow/Services/DemoGrowPhotoLibrary.swift GrowTests/DemoGrowPhotoLibraryTests.swift
git commit -m "Add Ojai basil photo story"
git push origin main
```

## Task 4: Resolve, Downsample, and Crop Media by Explicit Policy

**Files:**
- Create: `Grow/Services/GrowImageDecoder.swift`
- Create: `Grow/Services/GrowPhotoSourceResolver.swift`
- Create: `GrowTests/GrowPhotoSourceResolverTests.swift`
- Create: `GrowTests/GrowImageDecoderTests.swift`

**Interfaces:**
- Produces: `GrowPhotoResolutionPolicy`, `ResolvedGrowPhoto`, `GrowPhotoSourceResolver.resolve(photo:policy:targetMaxPixel:)`, `GrowImageDecoder.image(data:maxPixelSize:)`.
- Consumes: origin/provenance types from Task 1 and `DemoGrowPhotoLibrary` from Task 2.

- [ ] **Step 1: Write failing resolver-policy tests**

Create tests for these exact cases:

```swift
func testFullSizeRetainsStoredDemoProvenance() async throws
func testGenuineThumbnailOutranksRecoverySample() async throws
func testGenuineOnlyRejectsMissingUserMedia() async throws
func testDemoPolicyRejectsCameraRecordSampleSubstitution() async throws
func testInteractiveRecoveryLabelsSampleWithoutMutatingRecord() async throws
func testAppGroupLocationDoesNotReclassifyDemoSample() async throws
```

Each test constructs a `GrowPhoto` with explicit origin, injects `fullSizeData`, `thumbnailData`, and a deterministic demo-library closure, and asserts provenance plus quality.

- [ ] **Step 2: Write failing decoder tests**

Add EXIF-rotated, Display-P3, and grayscale fixture data created in test code. Assert the returned `CGImage` respects maximum pixel size, normalized orientation, and valid color output. Add a cancellation test that cancels a resolver task before decode completion and asserts `CancellationError`.

- [ ] **Step 3: Run focused tests and verify RED**

Expected: compile failure because resolver/decoder types do not exist.

- [ ] **Step 4: Implement policy and result contracts**

Create in `GrowPhotoSourceResolver.swift`:

```swift
enum GrowPhotoResolutionPolicy: Equatable, Sendable {
    case genuineMediaOnly
    case demoAllowed
    case interactiveRecoveryAllowed(day: Int)
}

struct ResolvedImage: @unchecked Sendable {
    let cgImage: CGImage
}

struct ResolvedGrowPhoto: Sendable {
    let image: ResolvedImage
    let provenance: GrowPhotoProvenance
    let quality: GrowPhotoQuality
    let sampleID: String?
}

enum GrowPhotoResolutionError: LocalizedError, Equatable {
    case missingGenuineMedia
    case policyViolation
    case decodeFailed
}
```

Implement the decision table exactly:

| Record origin | Policy | Full/thumbnail behavior | Sample behavior |
|---|---|---|---|
| legacy/camera/photoLibrary | genuine only | full then thumbnail | never |
| legacy/camera/photoLibrary | demo allowed | full then thumbnail | never; policy violation if both absent |
| legacy/camera/photoLibrary | interactive recovery | full then thumbnail | labeled recovery only when both absent |
| demo sample | demo allowed | full then thumbnail, retain demo provenance | source ID may reload bundle if both absent |
| demo sample | genuine only | reject | never |

- [ ] **Step 5: Implement Image I/O downsampling and bounded cache**

`GrowImageDecoder` is an actor containing an `NSCache<NSString, CGImageBox>`. It computes cache cost as `bytesPerRow * height`, sets `totalCostLimit = 64 * 1_024 * 1_024`, clears on `UIApplication.didReceiveMemoryWarningNotification`, and creates images with:

```swift
let options: [CFString: Any] = [
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceCreateThumbnailWithTransform: true,
    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    kCGImageSourceShouldCacheImmediately: true
]
```

Call `Task.checkCancellation()` before source creation, before thumbnail creation, and before returning/caching. Cache keys include source identity and target max-pixel bucket.

- [ ] **Step 6: Implement the resolver**

Inject closures for App Group full-size data and demo assets so tests never touch global storage. Derive provenance only from `photo.origin` and `sourceSampleID`. Decode full-size near the caller's target size, then thumbnail, then permitted sample. Do not mutate `GrowPhoto` during recovery.

- [ ] **Step 7: Run focused/full tests and a memory harness**

Expected: resolver and decoder tests pass; a loop resolving 30 2160×3840 fixtures stays under the 64 MB decoded cache cost limit.

- [ ] **Step 8: Commit and push**

```bash
git add Grow/Services/GrowImageDecoder.swift Grow/Services/GrowPhotoSourceResolver.swift GrowTests/GrowImageDecoderTests.swift GrowTests/GrowPhotoSourceResolverTests.swift
git commit -m "Resolve grow photos by provenance"
git push origin main
```

## Task 5: Make Camera, Import, and Demo Capture Transactional

**Files:**
- Modify: `Grow/Services/PhotoService.swift`
- Modify: `Grow/Services/StreakService.swift`
- Modify: `Grow/Views/CaptureScreen.swift`
- Modify: `Grow/Views/FirstSeedFlow.swift`
- Modify: `GrowTests/PhotoServiceTransactionTests.swift`
- Create: `GrowTests/PhotoServiceOriginTests.swift`

**Interfaces:**
- Produces: `PhotoService.recordCapture(imageData:origin:for:species:)`, `PhotoService.recordDemoCapture(for:species:capturedAt:) async throws`, `StreakService.stageCapture(at:) -> StreakTransaction`.
- Consumes: `DemoGrowPhotoLibrary.asset(forDay:)`, `GrowPhotoOrigin`, and App Group photo paths.

- [ ] **Step 1: Write failing origin and demo persistence tests**

Add tests asserting camera writes `.camera`, Photos Picker writes `.photoLibrary`, demo writes `.demoSample` plus the selected ID, and a reconstructed container retains demo provenance.

- [ ] **Step 2: Extend transaction-failure tests**

Add injected failures for thumbnail creation and `saveContext`. Assert no file, no photo model, unchanged cover/stage, and unchanged streak. Add a success test asserting photo, grow, and streak are saved in one context commit.

- [ ] **Step 3: Run focused tests and verify RED**

Expected: origin parameter, demo method, and streak transaction contracts are missing.

- [ ] **Step 4: Add transaction-compatible streak mutation**

Create a value snapshot:

```swift
struct StreakTransaction {
    let state: StreakState
    let previousCurrent: Int
    let previousLongest: Int
    let previousLastDate: Date?
    let previousFreezeTokens: Int
    let update: StreakUpdate

    func rollback() {
        state.currentStreak = previousCurrent
        state.longestStreak = previousLongest
        state.lastCareDate = previousLastDate
        state.freezeTokensRemaining = previousFreezeTokens
    }
}
```

`stageCapture(at:)` applies the existing calendar logic without saving. Keep `recordCapture(at:)` as the public convenience that stages and then saves for non-photo callers.

- [ ] **Step 5: Consolidate capture into one throwing transaction**

Change genuine capture signature to require exact origin:

```swift
func recordCapture(
    imageData: Data,
    origin: GrowPhotoOrigin,
    for grow: Grow,
    species: PlantSpecies?
) throws -> CaptureReward
```

Reject `.demoSample` from this method. Create a private `persistCapture(imageData:origin:sourceSampleID:capturedAt:grow:species:alignment:) throws` used by genuine and demo paths. Generate thumbnail before model insertion, atomically write the JPEG, stage model/grow/streak, save once, and roll back file/model/grow/streak on failure.

- [ ] **Step 6: Replace prototype drawing with deterministic demo capture**

Implement:

```swift
func recordDemoCapture(
    for grow: Grow,
    species: PlantSpecies?,
    capturedAt: Date = .now
) async throws -> CaptureReward {
    let day = max(growDayIndex(for: grow, at: capturedAt), sortedPhotos(for: grow).count + 1)
    let asset = try demoLibrary.asset(forDay: day)
    return try persistCapture(
        imageData: asset.data,
        origin: .demoSample,
        sourceSampleID: asset.frame.id,
        capturedAt: capturedAt,
        grow: grow,
        species: species,
        alignment: prototypeAlignment(frameCount: sortedPhotos(for: grow).count + 1)
    )
}
```

Delete `prototypeImage`, `drawPrototypePlant`, `drawPrototypeLeaf`, and `drawPrototypePebbles`.

- [ ] **Step 7: Update callers with exact origins and throwing UI state**

- Camera callbacks pass `.camera`.
- Photos Picker imports pass `.photoLibrary`.
- Simulator buttons call `recordDemoCapture` in a `Task`, disable while awaiting, and show the existing capture error alert on failure.
- Onboarding simulator capture follows the same path.

- [ ] **Step 8: Run focused/full tests, exact build, commit, and push**

```bash
git add Grow/Services/PhotoService.swift Grow/Services/StreakService.swift Grow/Views/CaptureScreen.swift Grow/Views/FirstSeedFlow.swift GrowTests/PhotoServiceTransactionTests.swift GrowTests/PhotoServiceOriginTests.swift
git commit -m "Make demo photo capture truthful"
git push origin main
```

## Task 6: Replace All Photo Placeholders with `GrowPhotoSurface`

**Files:**
- Create: `Grow/Views/GrowPhotoSurface.swift`
- Modify: `Grow/Views/FirstSeedFlow.swift`
- Modify: `Grow/Views/CaptureScreen.swift`
- Modify: `Grow/Views/ReelsScreen.swift`
- Create: `GrowTests/GrowPhotoCropTests.swift`

**Interfaces:**
- Produces: `GrowPhotoAspectIntent`, `GrowPhotoCrop.cropRect(imageSize:containerAspect:focalPoint:)`, `GrowPhotoSurface`.
- Consumes: `GrowPhotoSourceResolver`, manifest focal points, `ResolvedGrowPhoto`.

- [ ] **Step 1: Write failing crop geometry tests**

Test portrait, square, landscape strip, focal points near every edge, bounds clamping, and zero-size rejection. Example:

```swift
func testSquareCropCentersOnArtDirectedFocalPointAndClamps() throws {
    let rect = try GrowPhotoCrop.cropRect(
        imageSize: CGSize(width: 2160, height: 3840),
        containerAspect: 1,
        focalPoint: NormalizedPoint(x: 0.8, y: 0.5)
    )
    XCTAssertEqual(rect.width, rect.height, accuracy: 0.001)
    XCTAssertLessThanOrEqual(rect.maxX, 2160)
    XCTAssertGreaterThanOrEqual(rect.minX, 0)
}
```

- [ ] **Step 2: Run crop tests and verify RED**

Expected: `GrowPhotoCrop` does not exist.

- [ ] **Step 3: Implement crop geometry and shared surface**

`GrowPhotoSurface` accepts a `GrowPhoto?`, explicit resolution policy, semantic aspect intent, fallback sample day, and accessibility context. It resolves in `.task(id:)`, cancels prior tasks, renders `Image(decorative:scale:orientation:)` from `CGImage`, clips to the computed crop, and overlays a persistent `Sample frame` capsule for recovery provenance. Demo sample records include sample provenance in VoiceOver but do not need a noisy visual badge inside explicit demo/debug flows.

Use these exact intents:

```swift
enum GrowPhotoAspectIntent: String, Sendable {
    case reelPortrait
    case memorySquare
    case timelineStrip
    case posterThumbnail

    var aspectRatio: CGFloat {
        switch self {
        case .reelPortrait, .posterThumbnail: 9.0 / 16.0
        case .memorySquare: 1
        case .timelineStrip: 1.62
        }
    }
}
```

- [ ] **Step 4: Replace onboarding photo substitutes**

In `FirstSeedFlow.swift`, keep `SpecimenJar` only for the modeled twin/progress moments. Replace capture preview, saved Day 1 memory, sample reel frames, and any thumbnail fallback semantically representing a photo with `GrowPhotoSurface` or an explicit manifest asset.

- [ ] **Step 5: Replace Capture photo substitutes**

In `CaptureScreen.swift`, replace `SpecimenJar` in the composition preview, memory card fallback, future-reel strip frames, recap, and camera fallback where the surface promises a recorded frame. Keep the modeled-progress twin inside the reward sequence.

- [ ] **Step 6: Replace Reels photo substitutes**

In `ReelsScreen.swift`, replace `ReelPosterPreview`'s `SpecimenJar` fallback, the photographic promise/empty state, and export-thumbnail fallback with resolved photo/sample content. Keep SF Symbols for non-photo control affordances only.

- [ ] **Step 7: Add a semantic guard test**

Add a source scan test or contract test asserting the named photo components do not contain `SpecimenJar`, `WidgetPlantTwin`, or `fallbackImage`. The scan targets only photo-bearing component bodies so intended digital-twin usage remains legal.

- [ ] **Step 8: Run tests/build and visually verify named surfaces**

Use XcodeBuildMCP to build/run the iPhone 17 Pro. At default text size, capture screenshots of onboarding preview, Day 1 memory, Capture before/after demo capture, future-reel strip, Day 7 recap, Reel Studio empty/one/seven frames, and export row. Verify light and dark appearance plus Increased Contrast and Reduce Transparency without changing text size.

- [ ] **Step 9: Commit and push**

```bash
git add Grow/Views/GrowPhotoSurface.swift Grow/Views/FirstSeedFlow.swift Grow/Views/CaptureScreen.swift Grow/Views/ReelsScreen.swift GrowTests/GrowPhotoCropTests.swift
git commit -m "Show real photography across Grow"
git push origin main
```

## Task 7: Make Reel Export Deterministic and Truthful

**Files:**
- Modify: `Grow/Services/ReelRenderingService.swift`
- Modify: `Grow/Domain/ReelStudioPolicy.swift`
- Create: `GrowTests/ReelRenderingSourceTests.swift`
- Create: `GrowTests/ReelRenderingPerformanceTests.swift`

**Interfaces:**
- Produces: `ReelSourceFrameResolver.frames(for:policy:)`, `ReelRenderingError.missingSourceFrame(photoID:)`.
- Consumes: stable ordering from Task 1 and `.genuineMediaOnly` resolution from Task 4.

- [ ] **Step 1: Write failing reel-source tests**

Cover:

```swift
func testGenuineFramesSortByDayDateAndUUID() async throws
func testDemoFramesSortByManifestSequence() async throws
func testMissingGenuineFrameFailsInsteadOfSubstitutingSample() async throws
func testDemoFrameKeepsDemoProvenanceAfterAppGroupWrite() async throws
func testNoLegacyDrawnFallbackIsReachable() async throws
```

- [ ] **Step 2: Run focused tests and verify RED**

Expected: missing source-frame resolver and error contracts.

- [ ] **Step 3: Implement the reel source resolver**

For a real grow, sort photos using `GrowPhotoOrdering.areInIncreasingOrder`, then resolve each under `.demoAllowed` only when `photo.origin == .demoSample`; all other origins use `.genuineMediaOnly`. If any frame fails, throw `ReelRenderingError.missingSourceFrame(photoID:)` before creating the output file.

For the explicit sample-story reel, enumerate `DemoGrowPhotoLibrary.reelFrames()` by sequence and resolve their bundled assets with `.demoSample` provenance.

- [ ] **Step 4: Remove the illustrated fallback**

Delete `fallbackImage()` and change `image(for:)` from returning a nonoptional image to throwing resolution errors. Update Reel Studio error copy to the localized `missing_reel_frame_error` string.

- [ ] **Step 5: Decode near render size and release frames incrementally**

Do not map all records to full `UIImage` values before writing. Resolve and composite each source near `canvasSize`, append its pixel buffer, then release the decoded source before advancing. Keep only the first composited poster and bounded decoder cache.

- [ ] **Step 6: Add performance coverage**

Render a 30-frame fixture reel and use `measure(metrics: [XCTMemoryMetric(), XCTClockMetric()])`. Assert output exists, contains 30 frames, and cache cost never exceeds 64 MB. Cancellation removes an incomplete output file and does not insert a `Reel` record.

- [ ] **Step 7: Run focused/full tests and exact build**

Expected: no drawn fallback, deterministic order, genuine missing media fails, and 30-frame performance harness passes.

- [ ] **Step 8: Commit and push**

```bash
git add Grow/Services/ReelRenderingService.swift Grow/Domain/ReelStudioPolicy.swift GrowTests/ReelRenderingSourceTests.swift GrowTests/ReelRenderingPerformanceTests.swift
git commit -m "Make reel media resolution truthful"
git push origin main
```

## Task 8: Release-Gate the Ojai Photo System

**Files:**
- Modify implementation only for defects found during QA.
- Modify focused tests for each corrected contract.
- Modify this plan's checkboxes and add a dated evidence log.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: verified photo system and sample reel on `main`.

- [ ] **Step 1: Run the full automated suite**

Use XcodeBuildMCP `test_sim()` on the configured iPhone 17 Pro.

Expected: all tests pass with zero failures/skips, including origin persistence, manifest validation, resolver policy, transaction rollback, crop, reel, cancellation, accessibility copy, and performance contracts.

- [ ] **Step 2: Run both build gates**

Run XcodeBuildMCP `build_sim()`, then the exact required shell build from Global Constraints. Expected: both succeed.

- [ ] **Step 3: Verify genuine-media precedence and recovery**

Import a real plant photo, verify it is labeled/contextualized as imported media and visually unchanged apart from orientation/encoding/crop. Remove its full-size file and verify the genuine thumbnail wins. Remove both and verify interactive UI shows a visible/VoiceOver `Sample frame` recovery state while genuine reel export refuses to render.

- [ ] **Step 4: Walk the coherent Day 1–7 story**

Reset debug seed data, use simulator capture seven times, and verify source IDs, stored origins, chronological growth, day captions, reward memory, future strip, and Day 7 recap. Relaunch after Day 3 and confirm earlier samples remain `.demoSample`.

- [ ] **Step 5: Render and inspect the sample reel**

Render the twelve-frame start-to-harvest story. Inspect the 9:16 movie frame by frame for jar/background continuity, plausible plant growth, stable crop, exposure flicker, overlay contrast, temporal order, and absence of synthetic drawings. Verify poster and export thumbnail use the same photo story.

- [ ] **Step 6: Run default-size accessibility and appearance QA**

At standard/default text size, verify light/dark, VoiceOver order and provenance language, Increased Contrast, Differentiate Without Color, Reduce Transparency, and Reduce Motion. Do not switch to Accessibility Large.

- [ ] **Step 7: Inspect runtime logs and resource footprint**

Search for decode failures, missing sample IDs, policy violations, App Group failures, memory warnings, and reel errors. Confirm twelve masters are bundled exactly once and record their installed size.

- [ ] **Step 8: Run final repository hygiene checks**

```bash
git diff --check
git status --short --branch
```

Expected: no whitespace errors and only the intended plan evidence update remains.

- [ ] **Step 9: Commit evidence and push**

```bash
git add Grow GrowTests DesignSources docs/superpowers/plans/2026-07-13-ojai-ugc-photo-system.md
git commit -m "Verify Ojai UGC photo system"
git push origin main
```

## Plan Self-Review

- Spec coverage: durable provenance, explicit policies, genuine-export truthfulness, manifest invariants/boundaries, stable ordering, atomic capture, crop metadata, String Catalog copy, Image I/O downsampling, cache/cancellation, all named surfaces, reel performance, accessibility variants at default text size, and visual reel QA each map to a task.
- Scope: the app icon remains a separate brand-design project; living twins remain code-native.
- Type consistency: `GrowPhotoOrigin`, `GrowPhotoProvenance`, `GrowPhotoQuality`, `GrowPhotoResolutionPolicy`, `ResolvedGrowPhoto`, `DemoGrowPhotoLibrary`, `GrowPhotoAspectIntent`, and `GrowPhotoOrdering` retain one spelling and responsibility throughout.
- Placeholder scan: the plan contains no `TBD`, `TODO`, unspecified error handling, or unnamed implementation steps.
