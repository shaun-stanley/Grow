# AGENTS.md

## Product Direction

- Grow is a standalone, software-only hydroponics companion for beginner urban growers by Svift Studios.
- iOS 26.2 is intentional. Do not lower the deployment target unless the user explicitly asks.
- North star: Tamagotchi x Strava x Planta, but hydroponics-native. The experience should make a beginner feel "I actually grew this."
- Core launch pillars, in priority order: auto time-lapse grow reels, living digital twin, AI Plant Doctor, gamified streaks plus collectible dex.
- Freemium plan: reels remain free and unlimited because they are the organic growth engine.
- Community/social features are deferred to v1.1 unless the user redirects.
- For fuller product, GTM, monetization, and sequencing context, read `docs/PRODUCT_BUILD_PLAN.md`.

## Taste And Design

- Aim for Apple Design Award-level craft: polished, calm, tactile, and emotionally rewarding.
- Current visual language is "Living Field Journal": botanical, editorial, warm, and modern rather than generic SaaS or dated garden-log UI.
- Use the existing design system in `Grow/DesignSystem/` before adding new visual primitives.
- Keep the "Living Green" palette anchored by sprout green, warm soil neutrals, and the apricot Bloom accent for reward/harvest moments.
- Confine Liquid Glass to functional chrome such as tab bars, action capsules, capture HUDs, and milestone cards; keep plant/content surfaces clear.
- Design for accessibility from the start: Dynamic Type, VoiceOver labels, Reduce Motion/Transparency fallbacks, 44pt hit targets, and color plus glyph plus label for health states.
- The capture reward loop is not polish. It is a first-class product requirement because Days 1-7 are the highest churn risk.

## Current Build Sequence

- Foundation is present: SwiftUI app shell, SwiftData model graph, `GrowModelContainer`, `GrowStore`, `PlantCatalogService`, bundled plant catalog, and the first "Living Field Journal" UI pass.
- Next recommended milestone: capture loop plus reward sequence.
- Capture-loop milestone should ship `PhotoService`, guided camera/ghost overlay, App Group media storage, Vision alignment scoring, `RewardSequenceView`, `StreakService`, `NotificationService`, modeled twin micro-progress, future-reel preview, and the Day 1-7 danger-zone arc together.
- Validate App Group access from a widget extension early; cross-process file access is a known risk.
- Build the reel CoreAnimation overlay harness before the full reel feature so overlay/export issues surface early.

## Architecture Rules

- Use native SwiftUI, SwiftData, Swift 5.0, and `@Observable` services injected through `.environment()`.
- Before implementing Apple platform APIs or behavior, verify current guidance with the Sosumi Apple-docs MCP when it is available. If Sosumi is not exposed in the current session, use official Apple Developer documentation as the fallback source.
- Keep this as a single Xcode project unless the user asks for modularization.
- Follow CloudKit-safe SwiftData style: defaults on stored properties, enums stored as raw strings, value structs stored as JSON `Data`, and optional relationships with explicit inverses/delete rules.
- `PlantSpecies` is a plain `Codable` catalog type loaded from bundled JSON, not a synced SwiftData model.
- Store photos and rendered reels as files in the App Group container `group.com.sviftstudios.Grow`; keep only small thumbnails/poster frames in SwiftData via external storage.
- Do not put full image or video bytes into the synced SwiftData store.
- Bundle IDs: app `com.sviftstudios.Grow`, widget `com.sviftstudios.Grow.GrowWidget`.
- Prefer small, focused services that match the plan: `PhotoService`, `ReelRenderingService`, `PlantDoctorService`, `CareService`, `StreakService`, `AchievementService`/`DexService`, `NotificationService`, `StoreService`, `WidgetSyncService`, `LiveActivityManager`, and `DeepLinkRouter`.

## Verification

- For Swift, Xcode project, asset catalog, plist, entitlement, or bundled-resource changes, run:

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

- Docs-only changes do not need the Xcode build.
- In Codex sandboxed runs, simulator/asset-catalog work can fail because CoreSimulator services are unavailable. If that happens, rerun the same Xcode build with an approval request.
- When capture-loop work begins, manually verify the emotional reward lands even when Day 1 and Day 2 photos have almost no visible plant change.

## Git Workflow

- Work directly on `main` by default for Codex sessions in this repo.
- Create `codex/...` branches only when the user explicitly asks for branch-based work or pull-request review.
- Commit directly to `main` after verification when the requested work is complete.
- Keep changes scoped to the requested task and do not revert unrelated user changes.
