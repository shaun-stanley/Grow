# Ojai UGC Photo System Design

**Date:** 2026-07-13  
**Status:** Approved visual direction; awaiting written-spec review  
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

1. Seed or net-cup setup with no visible shoot.
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

### Image character

- Elevated iPhone camera roll, not studio campaign photography.
- Natural depth of field without exaggerated portrait-mode edge errors.
- Fine texture and subtle grain; no plastic skin, waxy leaves, excessive HDR, or synthetic bokeh.
- A calm warm-neutral palette with healthy basil green as the strongest chromatic element.
- No faces, logos, brand packaging, captions, watermarks, UI, or embedded text.
- No impossible roots, duplicated leaves, merged fingers, floating objects, ornamental soil in the hydroponic vessel, or inconsistent hardware.

## Master Asset Set

The app ships twelve portrait master photographs under one versioned sample story. Suggested logical identifiers are:

| Identifier | Story moment | Primary use |
|---|---|---|
| `ojai-basil-setup` | Net cup and seed setup | Empty/sample capture invitation |
| `ojai-basil-day-01` | First saved frame | Onboarding and Day 1 memory |
| `ojai-basil-day-02` | Near-identical early frame | Early reward and continuity QA |
| `ojai-basil-day-03` | Cotyledon cue | Day 3 streak milestone |
| `ojai-basil-day-05` | First true leaves | Future-reel strip |
| `ojai-basil-day-07` | First-week frame | Day 7 recap and share artifact |
| `ojai-basil-day-10` | Early branching | Intermediate demo capture |
| `ojai-basil-day-14` | Denser canopy | Mid-grow poster |
| `ojai-basil-day-21` | Structured mature plant | Mid/late reel continuity |
| `ojai-basil-day-30` | Full canopy | Mature poster and reel climax |
| `ojai-basil-harvest` | Hands pruning basil | Harvest memory |
| `ojai-basil-finale` | Harvested leaves and vessel | Reel end-frame source |

Each master is composed safely for a 9:16 center crop. The plant, vessel, and important hand gesture stay within the central 70% width and central 80% height so the same source also survives square memory cards and narrow horizontal strips. The bundled version is an optimized wide-gamut-safe JPEG without EXIF or location metadata. Full-resolution generation masters remain in a non-target repository asset-source directory for future derivatives.

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
- Provide localized accessibility descriptions.
- Detect missing or undecodable files and return a typed failure.

Selection is deterministic. Days without a dedicated master use the nearest prior master, never a later growth stage. This prevents the plant from appearing to shrink when a user repeatedly invokes simulator capture.

### `GrowPhotoSourceResolver`

A small resolver establishes source precedence for any photo-bearing UI or render path:

1. Full-size user photo from the App Group file.
2. Synced user thumbnail from SwiftData.
3. Explicit sample-story image when the surface is a demo, preview, simulator capture, or missing-media recovery state.
4. A neutral photographic fallback treatment with a clear "Sample" label if the referenced sample asset cannot decode.

The resolver never silently replaces an available user image with sample content. It returns source provenance alongside the image so UI and accessibility can identify sample content when necessary.

### `GrowPhotoSurface`

A single SwiftUI primitive renders resolved sources with consistent crop behavior, loading state, provenance labeling, accessibility, and failure treatment. It accepts an aspect-ratio intent rather than arbitrary resizing rules:

- `.reelPortrait` — 9:16 aspect-fill.
- `.memorySquare` — 1:1 aspect-fill.
- `.timelineStrip` — compact landscape aspect-fill.
- `.posterThumbnail` — export-list 9:16 thumbnail.

This primitive does not apply a global beauty filter. Genuine user media retains its color and exposure. Any overlay gradient belongs to the consuming poster or memory component, not the source resolver.

### `PhotoService` demo capture

Simulator/prototype capture stops drawing a `UIGraphicsImageRenderer` plant. It requests the correct chronological master from `DemoGrowPhotoLibrary`, writes an ordinary JPEG through the same App Group path as a camera/import capture, creates the same thumbnail, and persists the same metadata and reward payload. This keeps the demo path honest and exercises the production storage/reel pipeline.

### `ReelRenderingService`

Reel rendering continues to use the ordered `GrowPhoto` records as its source of truth. The source resolver supplies full-size files first, thumbnails second, and sample recovery only when required. The renderer never substitutes `fallbackImage()` vector art into a photo reel. Sample reels use the ordered master sequence and the same Core Animation overlay path as user reels.

## Data Flow

### Genuine capture

Camera or Photos Picker → normalized full-size JPEG in App Group → SwiftData `GrowPhoto` metadata plus thumbnail → source resolver → capture/reward/reel UI → reel renderer.

### Simulator capture

Requested grow day → sample manifest → bundled Ojai master → normal `PhotoService` file and metadata write → the same downstream UI and reel renderer as genuine capture.

### Missing media

SwiftData photo record → missing/corrupt full-size file → valid thumbnail if available → otherwise provenance-labeled chronological sample → neutral labeled fallback only if the sample itself is unavailable.

## Error Handling and Truthfulness

- A corrupt genuine full-size image falls back to its genuine thumbnail before any sample is considered.
- Sample substitution is limited to explicit demo/sample/recovery contexts and exposes `.sample` provenance.
- User-facing recovery surfaces say "Sample frame" or equivalent; they never imply that the bundled photo was captured by the user.
- Reel rendering logs source-resolution failures and continues only when a valid ordered frame can be supplied. It reports a clear render error instead of exporting an empty or illustrated frame.
- Missing manifest entries fail deterministically in tests and use the closest prior valid master at runtime.
- No network fetch is required for shipped sample imagery.

## Accessibility

- Each sample master has a human-authored description, such as "Day 7 sample photo of young basil in an amber hydroponic jar on a sunlit oak counter."
- Genuine user photos use contextual labels derived from grow name and day rather than attempting an unverified visual description.
- Sample provenance is included in VoiceOver labels whenever it is visible or used as recovery content.
- Overlaid day/status copy maintains contrast against the real image via local gradients rather than destructive full-image dimming.
- All visual QA for this milestone uses the standard/default content size, per the current testing direction.

## Verification

### Automated

- Manifest decodes and every referenced bundled asset exists.
- Day selection is deterministic and never chooses a future growth stage.
- Full-size user media outranks thumbnail and sample media.
- Genuine thumbnail outranks sample recovery.
- Corrupt full-size media falls back without crashing.
- Sample provenance survives through the resolver.
- Simulator capture writes a real JPEG from the correct sample master.
- Reel source ordering matches grow-photo ordering.
- Reel rendering never uses the legacy drawn fallback.
- Crop metadata covers all four aspect-ratio intents.

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

## Acceptance Criteria

- No photo-bearing surface uses `SpecimenJar`, `PlantSpecimen`, `WidgetPlantTwin`, or a programmatically drawn plant as a substitute for UGC.
- Every sample/photo recovery surface uses the shared resolver and communicates sample provenance when required.
- A simulator grow produces a believable chronological camera roll and a cohesive photographic reel.
- Genuine user photos pass through unchanged and always take precedence.
- The twelve master photographs meet the approved Ojai art direction and survive all required crops.
- Tests and the required Xcode build pass.
- All named surfaces and one exported reel are visually approved in the iPhone 17 Pro simulator at standard/default content size.

## Out of Scope

- Replacing the living digital twin or widget twin with photography.
- Applying automatic filters to genuine user photos.
- Downloadable sample packs or multiple demo personas.
- Marketing-site photography.
- The app icon, which is a separate visual-design project and will be designed next against the same Living Field Journal brand.
