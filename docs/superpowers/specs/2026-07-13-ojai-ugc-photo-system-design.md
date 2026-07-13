# Ojai UGC Photo System Design

**Date:** 2026-07-13
**Status:** Approved visual direction; revised after external review; awaiting written-spec re-review
**Product:** Grow for iOS 26.2

## Objective

Replace every synthetic illustration currently standing in for user-generated photography with a cohesive, aspirational, believable photo story. Sample captures, memories, reel previews, poster frames, and demo reels must look like they came from one tasteful beginner grower's iPhone camera roll, not from a vector generator or a lifestyle advertising campaign.

This system does not replace Grow's living digital twin. `SpecimenJar`, the modeled plant, and the widget twin remain intentionally code-native wherever the product is communicating expected growth rather than recorded reality.

## Approved Creative Direction

The bundled demo content follows one woman's basil grow across 30 days in a sun-washed Ojai kitchen.

### Story world

- One amber-glass Kratky vessel sits on a pale oak counter against a softly imperfect limewashed wall.
- A cream linen curtain, handmade ceramic catch tray, and a small number of restrained personal objects establish the location without making the scene feel staged.
- The grower is implied through fingertips, a cream linen sleeve, slim vintage gold jewelry, pruning scissors, a half-finished coffee, or a market tote. Her face is not shown.
- Natural light changes plausibly across the month: cool early morning, bright late morning, occasional overcast softness, and warm harvest light.
- The same camera anchor and vessel orientation remain recognizable across the sequence. Small handheld shifts, minor exposure changes, and natural cropping keep the source believable as elevated iPhone UGC.
- Styling communicates quiet affluence through material quality and restraint rather than visible brands.

### Plant continuity

The basil must progress botanically and spatially without resets:

1. Basil seed seated in a compact warm-tan coir starter plug inside the net cup, with no visible shoot.
2. Emerging radicle or germination cue where photographically plausible.
3. Cotyledons.
4. First true leaves.
5. Additional leaf pairs and visible root growth.
6. Early branching.
7. First-week milestone frame.
8. Denser Day-14 canopy.
9. Structured Day-21 plant.
10. Mature Day-30 canopy.
11. Hands pruning or harvesting.
12. Final harvested basil beside the still-recognizable vessel.

Leaf count, stem geometry, root development, vessel marks, countertop grain, background objects, and light direction must remain coherent from frame to frame. Later images are derived from the last approved frame rather than independently generated from text.

### Hydroponic physical continuity

- The seed is never shown loose inside an empty plastic basket. A single compact coir propagation plug fills the center of the black net cup and remains the same shape, color, and position throughout the story.
- In setup and the earliest frames, the nutrient solution visibly reaches the lower portion of the starter plug so capillary action can keep it moist.
- As roots emerge and lengthen, the nutrient line drops gradually below the net cup, leaving an expanding humid air gap. Later roots extend naturally from the plug toward and into the solution.
- The plug may darken slightly where wet but must never read as loose soil, decorative gravel, or an unexplained pale object.
- Water-level progression, plug wetness, and root length are continuity invariants reviewed alongside leaf and stem growth.

### Image character

- Elevated iPhone camera roll, not studio campaign photography.
- Natural depth of field without exaggerated portrait-mode edge errors.
- Fine texture and subtle grain; no plastic skin, waxy leaves, excessive HDR, or synthetic bokeh.
- A calm warm-neutral palette with healthy basil green as the strongest chromatic element.
- No faces, logos, brand packaging, captions, watermarks, UI, or embedded text.
- No impossible roots, duplicated leaves, merged fingers, floating objects, ornamental soil in the hydroponic vessel, or inconsistent hardware.

## Master Asset Set

The app ships fourteen portrait master photographs under one versioned sample story. Days 1–7 each receive a distinct master because that danger-zone arc must never imply daily capture while silently reusing yesterday's image. The later month remains intentionally sparse. Suggested logical identifiers are:

| Identifier | Story moment | Primary use |
|---|---|---|
| `ojai-basil-setup` | Coir starter plug and seed setup | Empty/sample capture invitation |
| `ojai-basil-day-01` | First saved frame | Onboarding and Day 1 memory |
| `ojai-basil-day-02` | Near-identical early frame | Early reward and continuity QA |
| `ojai-basil-day-03` | Cotyledon cue | Day 3 streak milestone |
| `ojai-basil-day-04` | Cotyledons expanding, true leaves peeking | Unique Day 4 memory |
| `ojai-basil-day-05` | First true leaves | Future-reel strip |
| `ojai-basil-day-06` | Established first true-leaf pair | Unique Day 6 memory |
| `ojai-basil-day-07` | First-week frame | Day 7 recap and share artifact |
| `ojai-basil-day-10` | Early branching | Intermediate demo capture |
| `ojai-basil-day-14` | Denser canopy | Mid-grow poster |
| `ojai-basil-day-21` | Structured mature plant | Mid/late reel continuity |
| `ojai-basil-day-30` | Full canopy | Mature poster and reel climax |
| `ojai-basil-harvest` | Hands pruning basil | Harvest memory |
| `ojai-basil-finale` | Harvested leaves and vessel | Reel end-frame source |

Each manifest entry has a unique ID, a grow day, and a unique monotonically increasing sequence index. Sequence, rather than day alone, defines sample-reel order and permits multiple explicit story moments on one day. Each master is composed safely for a 9:16 crop. The plant, vessel, and important hand gesture stay within the central 70% width and central 80% height. The bundled version is an optimized wide-gamut-safe JPEG without EXIF or location metadata. Full-resolution generation masters remain in a non-target repository asset-source directory for future derivatives.

## Surface Boundary

### Photo-bearing surfaces that use genuine or sample photography

- Onboarding capture preview.
- Guided camera ghost overlay once a prior image exists.
- Day 1 saved-memory card and subsequent reward memories.
- Capture workspace composition preview.
- Capture timeline thumbnails.
- Future-reel strip and Day 1–7 recap.
- Reel Studio poster preview.
- Reel example/empty state where a photographic promise is being shown.
- Reel export poster thumbnails.
- Sample and simulator-generated reel frames.
- Missing-media recovery for photo or reel records.

### Surfaces that remain code-native

- Home living digital twin.
- Widget living twin.
- Modeled-growth reward animation.
- Decorative botanical marks and non-media empty-state ornament.

The distinction is semantic: photographs are evidence or an explicit sample of evidence; the living twin is modeled progress. The app never presents an illustration as if it were the user's saved photo.

## Architecture

### `DemoGrowPhotoLibrary`

A focused service owns the versioned sample-story manifest and bundled file lookup. It exposes deterministic selection by grow day and story moment. It does not know about SwiftUI, SwiftData, or reel layout.

Responsibilities:

- Decode a bundled JSON manifest.
- Resolve logical photo identifiers to bundle URLs.
- Return the closest chronological sample for a requested day.
- Return ordered frames for a sample reel.
- Provide String Catalog keys for localized accessibility descriptions.
- Detect missing or undecodable files and return a typed failure.

Manifest validation is all-or-nothing. Duplicate IDs, duplicate sequence indexes, nonmonotonic sequence order, negative days, invalid crop metadata, absent files, or undecodable images reject the shipped manifest with a typed error; runtime selection never hides an invalid manifest.

Selection behavior is explicit:

- A valid day without an exact master returns the nearest prior master, never a later growth stage.
- A request before the earliest day returns `.noPriorMaster`.
- A request after Day 30 clamps to the Day-30 master for ordinary capture. Harvest and finale frames require an explicit story-moment request and are never selected merely because time advanced.
- A negative day returns `.invalidRequestedDay`.
- A referenced missing or corrupt asset returns `.assetUnavailable(sampleID:)`.

These rules distinguish expected sparse chronology from invalid shipped data and prevent the plant from shrinking when simulator capture is invoked repeatedly.

### `GrowPhotoSourceResolver`

A small resolver establishes source precedence for any photo-bearing UI or render path. Provenance is durable model data, never inferred from a file URL.

`GrowPhoto` adds CloudKit-safe raw-string metadata with defaults so existing records remain valid:

```swift
enum GrowPhotoOrigin: String, Codable {
    case legacyUserMedia
    case camera
    case photoLibrary
    case demoSample
}

// Stored GrowPhoto fields
var originRaw: String = GrowPhotoOrigin.legacyUserMedia.rawValue
var sourceSampleID: String? = nil
```

The migration default is `.legacyUserMedia`, not `.camera`, because existing records do not durably reveal whether they came from the camera, Photos Picker, or the old prototype path. It is treated as genuine for source precedence but receives a generic contextual label. Every newly written record stores an exact origin. Pre-release seeded simulator data is reset when validating the new sample story.

`recoverySample` is not a stored origin because recovery content does not replace or mutate the original `GrowPhoto`; it is provenance of a particular resolution result. The resolver returns both provenance and quality:

```swift
struct ResolvedGrowPhoto {
    let image: ResolvedImage
    let provenance: GrowPhotoProvenance
    let quality: GrowPhotoQuality
}

enum GrowPhotoProvenance {
    case legacyUserMedia
    case camera
    case photoLibrary
    case demoSample(sampleID: String)
    case recoverySample(sampleID: String)
    case neutralFallback
}

enum GrowPhotoQuality {
    case fullSize
    case thumbnail
    case fallback
}
```

The caller must choose an explicit resolution policy:

```swift
enum GrowPhotoResolutionPolicy {
    case genuineMediaOnly
    case demoAllowed
    case interactiveRecoveryAllowed
}
```

- `.genuineMediaOnly` permits only the record's full-size file or genuine thumbnail and otherwise fails.
- `.demoAllowed` permits the stored `.demoSample` source identifier and is used only for sample/demo records.
- `.interactiveRecoveryAllowed` may show a clearly labeled chronological sample without mutating the genuine record; it is limited to interactive recovery UI.

Within the permitted policy, source precedence is:

1. The record's full-size media from the App Group file, retaining its stored provenance.
2. The record's synced thumbnail from SwiftData, retaining the same provenance.
3. Explicit sample-story image only when allowed by the selected policy.
4. A neutral photographic fallback treatment with a clear "Sample" label if the referenced sample asset cannot decode.

The resolver never silently replaces an available user image with sample content. A genuine reel export always uses `.genuineMediaOnly`; if neither the full-size file nor genuine thumbnail is usable, export fails with an actionable missing-frame error. A future user-invoked recovery export may be added separately, but must visibly mark every substituted frame in the exported pixels. It is not part of this milestone.

### `GrowPhotoSurface`

A single SwiftUI primitive renders resolved sources with consistent crop behavior, loading state, provenance labeling, accessibility, and failure treatment. It accepts an aspect-ratio intent rather than arbitrary resizing rules:

- `.reelPortrait` — 9:16 aspect-fill.
- `.memorySquare` — 1:1 aspect-fill.
- `.timelineStrip` — compact landscape aspect-fill.
- `.posterThumbnail` — export-list 9:16 thumbnail with poster-overlay safe-area metadata distinct from the full reel canvas.

Every manifest entry stores a normalized focal point per crop intent. The crop renderer centers the requested aspect ratio on that art-directed focal point while clamping to image bounds. This is more precise than assuming one center crop survives portrait, square, and landscape presentation. This primitive does not apply a global beauty filter. Genuine user media receives no aesthetic exposure, color, skin, or detail adjustment. Required orientation normalization, encoding, downsampling, and aspect-ratio cropping remain permitted. Any overlay gradient belongs to the consuming poster or memory component, not the source resolver.

### Decode and memory behavior

Manifest metadata is immutable and `Sendable`. Image decoding runs through a concurrency-safe, cancellation-aware decoder rather than retaining full-resolution `UIImage` values in view state. UI thumbnails and strips use Image I/O downsampling near their display dimensions. Reel frames decode near the render canvas dimensions. A bounded `NSCache` uses decoded pixel cost and is purged on memory pressure. EXIF orientation is normalized consistently before crop or render.

Apple documents `CGImageSourceCreateThumbnailAtIndex` as the Image I/O API for creating a thumbnail directly from an image source. Grow uses it with maximum-pixel-size and transform options so small surfaces do not first decode the full-resolution source.

### `PhotoService` demo capture

Simulator/prototype capture stops drawing a `UIGraphicsImageRenderer` plant. It requests the correct chronological master from `DemoGrowPhotoLibrary`, normalizes it through the same production image path, and persists `originRaw = demoSample` plus `sourceSampleID`. A copied sample therefore remains distinguishable after relaunch, sync, UI resolution, accessibility, and export.

Capture is transactional:

1. Decode and validate the selected master.
2. Normalize orientation and encode the full-size JPEG.
3. Produce the required thumbnail `Data` before inserting the model.
4. Write the full-size JPEG using `Data.write(options: .atomic)`.
5. Stage `GrowPhoto`, its externally stored thumbnail data, origin metadata, alignment, grow mutations, and streak mutation in the shared `ModelContext`.
6. Save the staged SwiftData mutations once, then construct and return the reward payload from the committed values.
7. If SwiftData save fails, delete the created full-size file, delete the inserted model, and restore the grow and streak state to their prior values.

Thumbnails remain `@Attribute(.externalStorage)` SwiftData data, not separately managed App Group files. A thumbnail-generation failure is a capture failure and no model is inserted. `StreakService` exposes a transaction-compatible mutation used by `PhotoService` rather than independently swallowing a second save failure. The prototype path no longer catches file errors or uses `try?` for persistence.

### `ReelRenderingService`

Reel rendering continues to use `GrowPhoto` records as its source of truth. Genuine records are sorted by `dayIndex`, then `capturedAt`, then `id.uuidString`. The source resolver supplies full-size files first and genuine thumbnails second under `.genuineMediaOnly`; a missing genuine frame fails export. The renderer never substitutes `fallbackImage()` vector art or recovery photography into a genuine reel. Sample reels sort the manifest's unique sequence index and use the same Core Animation overlay path as user reels.

## Data Flow

### Genuine capture

Camera or Photos Picker → explicit `.camera` or `.photoLibrary` origin → normalized full-size JPEG in App Group → SwiftData `GrowPhoto` metadata plus thumbnail → policy-bound source resolver → capture/reward/reel UI → reel renderer.

### Simulator capture

Requested grow day → validated sample manifest → bundled Ojai master → production normalization and atomic file write → `.demoSample` origin plus source ID in SwiftData → the same downstream UI and reel renderer as genuine capture.

### Missing media

SwiftData photo record → missing/corrupt full-size file → genuine thumbnail when available → explicit recovery state. Interactive recovery UI may request `.interactiveRecoveryAllowed` and display a visibly and accessibly labeled chronological sample. Genuine reel export requests `.genuineMediaOnly` and fails rather than substituting another plant.

## Error Handling and Truthfulness

- A corrupt genuine full-size image falls back to its genuine thumbnail before any sample is considered.
- Sample substitution is limited to explicit `.demoAllowed` or `.interactiveRecoveryAllowed` calls and exposes durable sample provenance.
- User-facing recovery surfaces say "Sample frame" or equivalent; they never imply that the bundled photo was captured by the user.
- Genuine reel rendering logs source-resolution failures and reports a clear render error instead of exporting an empty, illustrated, or substituted frame.
- Sparse chronology uses the nearest prior master. Invalid manifests, unavailable referenced assets, and requests before the first master remain typed failures and are never concealed by sparse-day selection.
- No network fetch is required for shipped sample imagery.

## Accessibility

- Each sample manifest entry stores a localization key. Human-authored descriptions such as "Day 7 sample photo of young basil in an amber hydroponic jar on a sunlit oak counter" live in the app's String Catalog so localization tooling can detect omissions.
- Genuine user photos use contextual labels derived from grow name and day rather than attempting an unverified visual description.
- Sample provenance is included in VoiceOver labels whenever it is visible or used as recovery content.
- Overlaid day/status copy maintains contrast against the real image via local gradients rather than destructive full-image dimming.
- Visual QA for this milestone uses the standard/default content size, per the current testing direction. This is not a Dynamic Type coverage claim. VoiceOver, Increased Contrast, Differentiate Without Color, Reduce Transparency, and Reduce Motion are still verified at the default text size.

## Verification

### Automated

- Manifest decodes and every referenced bundled asset exists.
- Duplicate manifest IDs, duplicate sequence indexes, invalid crop metadata, missing files, corrupt files, and malformed manifests are rejected.
- Day selection is deterministic, never chooses a future growth stage, returns `.noPriorMaster` before the earliest master, and clamps ordinary post-Day-30 requests to Day 30.
- Duplicate-day samples order by manifest sequence.
- Full-size user media outranks thumbnail and sample media.
- Genuine thumbnail outranks sample recovery.
- Corrupt full-size media falls back without crashing.
- A simulator-written sample remains `.demoSample` with the same source ID after SwiftData save, container reconstruction, and resolver use.
- A sample copied into the App Group is never reclassified as camera or photo-library media.
- Every resolution policy permits only its documented sources.
- Genuine reel export fails on an unrecoverable genuine frame; interactive recovery returns visibly and accessibly labeled sample provenance.
- Simulator capture writes a real JPEG from the correct sample master and records durable origin.
- Atomic-write and SwiftData-save failure injection proves file/model/grow-state rollback, including thumbnail-generation failure.
- Genuine reel source ordering is stable by day, date, and UUID; sample ordering is stable by sequence.
- Reel rendering never uses the legacy drawn fallback.
- Crop metadata and bounds-clamping cover all four semantic intents.
- EXIF-rotated, wide-gamut, and grayscale fixtures normalize and render correctly.
- Cancellation during rapid scrolling does not publish a stale decode.
- Accessibility labels are correct for legacy-user, camera, photo-library, demo-sample, recovery-sample, and neutral-fallback provenance.

### Performance and memory

- A 30-frame mature reel is profiled with Instruments and a repeatable XCTest performance harness.
- Peak decoded-image memory stays bounded by the cache cost limit rather than scaling with full-resolution source count.
- Rapid strip scrolling and canceled decode tasks release work and do not grow the cache without bound.

### Visual simulator QA

At standard/default text size, verify in light and dark appearance:

- Onboarding capture and Day 1 saved memory.
- Capture workspace before and after a simulator capture.
- Day 2 near-identical reward, ensuring the emotional payoff still lands.
- Future-reel strip through Day 7.
- Day 7 recap.
- Reel Studio with no frames, one frame, seven frames, and a mature sample grow.
- Export list poster thumbnail.
- A rendered 9:16 sample video from start through harvest.

Inspect the exported video for plant continuity, camera drift, exposure flicker, temporal order, overlay contrast, crop safety, poster-frame quality, and absence of illustrated frames.

At default text size, verify VoiceOver reading and focus order, visible sample labeling, Increased Contrast, Differentiate Without Color, Reduce Transparency, and Reduce Motion. Dynamic Type expansion is explicitly outside this milestone's visual matrix.

## Acceptance Criteria

- No photo-bearing surface uses `SpecimenJar`, `PlantSpecimen`, `WidgetPlantTwin`, or a programmatically drawn plant as a substitute for UGC.
- Every sample/photo recovery surface uses the shared resolver and communicates sample provenance when required.
- A simulator grow produces a believable chronological camera roll and a cohesive photographic reel.
- Genuine media always takes precedence over sample media and receives no aesthetic filtering. Required orientation normalization, encoding, downsampling, and aspect-ratio cropping remain permitted.
- A sample persisted through the ordinary App Group path retains its `.demoSample` origin and source ID across relaunch.
- Genuine reel export never silently substitutes sample photography.
- The fourteen master photographs meet the approved Ojai art direction and survive all required crops.
- Days 1–7 resolve to seven distinct sample IDs and never reuse a prior day's photograph.
- Tests and the required Xcode build pass.
- All named surfaces and one exported reel are visually approved in the iPhone 17 Pro simulator at standard/default content size.

## Out of Scope

- Replacing the living digital twin or widget twin with photography.
- Applying automatic filters to genuine user photos.
- Downloadable sample packs or multiple demo personas.
- Marketing-site photography.
- The app icon, which is a separate visual-design project and will be designed next against the same Living Field Journal brand.

## Apple Platform Guidance Verified

- SwiftData persists noncomputed compatible properties and supports `Codable` value types; Grow still follows the repository's stricter CloudKit-safe convention of stored raw strings with defaults for origin metadata: [Preserving your app's model data across launches](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches).
- Foundation's `.atomic` data-writing option writes through an auxiliary file and exchanges it with the destination: [NSData.WritingOptions.atomicWrite](https://developer.apple.com/documentation/foundation/nsdata/writingoptions/atomicwrite). The current spelling used in Swift is `.atomic`.
- Image I/O provides direct source thumbnail creation through `CGImageSourceCreateThumbnailAtIndex`, supporting dimension-appropriate decode rather than full-image decode for small surfaces: [CGImageSourceCreateThumbnailAtIndex](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)).
