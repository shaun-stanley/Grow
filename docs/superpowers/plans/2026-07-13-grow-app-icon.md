# Grow App Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the user-selected generated seed-water-shoot artwork as Grow's production iOS app icon and verify it across system appearances and small sizes.

**Architecture:** Preserve the 1254×1254 generated source under `DesignSources`, create a deterministic opaque sRGB 1024×1024 production derivative, and reference it from the existing universal iOS app-icon slot. Use the system-provided icon mask and generated appearance treatments.

**Tech Stack:** Asset catalogs, PNG, XcodeBuildMCP, iOS 26.2 Simulator.

## Global Constraints

- Work directly on `main`; commit and push after verification.
- Use the selected raster source at `DesignSources/AppIcon/GrowAppIconConcept-01.png` without generative reinterpretation or procedural redrawing.
- Do not bake rounded corners, text, watermarks, device frames, or additional effects into the production file.
- Visual QA uses iPhone 17 Pro at the standard/default content size.
- Verify the installed default-system rendering and retain one universal source so iOS owns dark, clear, and tinted treatments.
- Run the repository-required exact `xcodebuild` command after asset-catalog changes.

---

## Task 1: Produce and Validate the Asset-Catalog Derivative

**Files:**
- Create: `Grow/Assets.xcassets/AppIcon.appiconset/GrowAppIcon.png`
- Modify: `Grow/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `GrowTests/AppIconContractTests.swift`

**Interfaces:**
- Produces: one opaque sRGB 1024×1024 PNG associated with the universal iOS icon slot.
- Consumes: approved 1254×1254 generated source.

- [x] **Step 1: Write a failing asset contract test**

Create `GrowTests/AppIconContractTests.swift`:

```swift
import Foundation
import ImageIO
import XCTest

final class AppIconContractTests: XCTestCase {
    func testProductionIconIsOpaqueSquare1024PNG() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let icon = root.appendingPathComponent("Grow/Assets.xcassets/AppIcon.appiconset/GrowAppIcon.png")
        let data = try Data(contentsOf: icon)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 1024)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1024)
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.png")
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertTrue([.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo))
    }

    func testAssetCatalogReferencesProductionIcon() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent().deletingLastPathComponent()
        let contents = try String(
            contentsOf: root.appendingPathComponent("Grow/Assets.xcassets/AppIcon.appiconset/Contents.json"),
            encoding: .utf8
        )
        XCTAssertTrue(contents.contains("GrowAppIcon.png"))
    }
}
```

- [x] **Step 2: Run focused tests and verify RED**

Run XcodeBuildMCP `test_sim(extraArgs: ["-only-testing:GrowTests/AppIconContractTests"])`.

Expected: missing production PNG and failed filename assertion.

- [x] **Step 3: Normalize the selected generated source**

Use the local image toolchain to convert the source to opaque sRGB PNG and resize exactly to 1024×1024 without changing composition, color, or geometry. Write `GrowAppIcon.png` into the app icon set. Verify with `sips -g pixelWidth -g pixelHeight -g format -g hasAlpha`.

- [x] **Step 4: Reference the filename**

Set the universal slot to:

```json
{
  "images" : [
    {
      "filename" : "GrowAppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [x] **Step 5: Run focused and full tests**

Expected: the icon contract and full suite pass.

## Task 2: Build and Visually Verify the Installed Icon

**Files:**
- Modify implementation only if asset validation exposes a concrete defect.
- Modify this plan with a dated evidence entry.

**Interfaces:**
- Consumes: Task 1 production icon.
- Produces: visually verified installed app icon.

- [x] **Step 1: Run build gates**

Run XcodeBuildMCP `build_run_sim()`, then:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

Expected: both builds succeed.

- [x] **Step 2: Inspect the installed default-system icon**

On iPhone 17 Pro, inspect the installed icon at normal system scale in Spotlight/default rendering. Confirm the system mask is clean and the composition remains immediately legible. Do not add hand-authored appearance variants unless the universal source exposes a concrete contrast defect.

- [x] **Step 3: Validate small-size legibility**

Inspect representative large, medium, and smallest derivatives at 180, 60, and 29 pixels. Confirm the white shoot, orange seed, and blue water semicircle remain distinct and the system mask does not clip them.

- [x] **Step 4: Run hygiene checks**

```bash
git diff --check
git status --short --branch
```

- [x] **Step 5: Commit and push**

```bash
git add Grow/Assets.xcassets/AppIcon.appiconset GrowTests/AppIconContractTests.swift docs/superpowers/plans/2026-07-13-grow-app-icon.md
git commit -m "Ship geometric Grow app icon"
git push origin main
```

## Evidence — 2026-07-13

- Focused contract tests failed before integration because the production PNG and asset-catalog filename were absent, then passed after integration.
- Full XcodeBuildMCP suite passed: 50 tests, 0 failures, 0 skips.
- XcodeBuildMCP built, installed, and launched Grow on iPhone 17 Pro at the default content size.
- The repository-required iOS 26.2 simulator build completed with `** BUILD SUCCEEDED **`, including asset-catalog and embedded-widget validation.
- Production asset inspection confirmed a 1024×1024 opaque PNG in sRGB IEC61966-2.1.
- Installed Spotlight/default-system rendering was visually inspected and approved by the user. The catalog intentionally supplies one universal source so iOS owns masking and appearance treatments rather than baking custom variants into the artwork.
- 29, 60, and 180 pixel derivatives were visually inspected; the shoot, seed, and water remain distinct with no clipping.

## Plan Self-Review

- Spec coverage: generated-source fidelity, unmasked opaque PNG, asset catalog integration, small sizes, system appearances, builds, simulator QA, commit, and push are covered.
- Type consistency: the production filename is `GrowAppIcon.png` in every task and test.
- Placeholder scan: no `TBD`, `TODO`, or unspecified implementation step remains.
