# Grow - Product & Build Plan

Source: user-provided Claude plan, captured for Codex on 2026-06-30.

A standalone, software-only **hydroponics companion for beginner urban growers**, by Svift Studios. iOS 26.2, SwiftUI. Engineered to go viral (TikTok/IG) and contend for an Apple Design Award, while being a *complete* hydroponics app - not just four viral tricks.

---

## Context

The home-hydroponics market is growing fast (~$1.8B -> $3.77B by 2030, 16% CAGR) and the software layer is the battleground, but there's a clear gap: **Planta** owns general plant care (paywall-heavy, not hydroponics-specific), dedicated hydroponic apps are dated documentation tools, and the good experiences are locked to specific hardware (Gardyn, LetPot, Rise). **No beautiful, modern, standalone hydroponics-first app exists.** Grow fills that gap with a delight-led experience whose shareable outputs manufacture organic growth.

Decisions locked with the user:
- **Software-only, standalone** - works with any setup (or none); no hardware dependency.
- **Beginner urban first-timers** - delight-led, "I actually grew this!".
- **Viral pillars in priority order:** 1. Auto time-lapse grow reels (the share engine) -> 2. Living digital twin (Home Screen widget + Live Activity) -> 3. AI Plant Doctor -> 4. Gamified streaks + collectible "dex".
- **Full-featured v1**, polished, shipping late summer 2026 (Aug/Sep), with a July beta/teaser building anticipation. The pillars are the marketing; the app must also cover all table-stakes hydroponics features.
- **AI Plant Doctor: cloud-only**, Claude two-tier (Sonnet 4.6 default -> Opus 4.8 escalation).
- **Community/social layer deferred to v1.1** (native share-sheet reels carry virality at launch).
- **Monetization: freemium, reels always free + unlimited.**

---

## Product Concept

**Tamagotchi x Strava x Planta, hydroponics-native.** The daily loop is: snap one photo -> the app aligns it, advances your living plant twin, updates your streak, and (on demand) auto-stitches a stunning before -> after time-lapse reel built for TikTok/IG. Underneath sits a complete grow-management toolkit. Mascot: **"Sprout,"** a seedling that grows with the user's real plant (cloned from Anchor's companion system).

---

## Core Retention Design - The Capture Reward Loop

**The risk:** the whole model assumes beginners take a photo daily, but that habit isn't guaranteed - and **Days 1-7 are the danger zone**. A seedling barely changes, so the reel isn't impressive yet and the visual payoff that motivates capture #30 doesn't exist on capture #2. If the early days feel like a chore with no reward, users churn long before the time-lapse becomes compelling.

**Principle: deliver the emotional payoff on every capture, starting Day 1 - never make the user wait until Day 30.** Every capture fires a sub-2s reward sequence:

1. **Alignment score** - a satisfying snap + haptic the instant the frame matches the ghost overlay, plus a score ("98% aligned - buttery"). Gamifies precision and trains the good framing the reel depends on.
2. **"Growth memory saved"** - the photo flips into a dated Day-N card with a tactile flip + sound; a tangible artifact created every single time.
3. **Sprout reacts and the twin visibly advances** - the mascot bounces/glows, and the illustrated twin shows micro-progress every day. This decouples visible reward from real-plant change: the twin advances on a **modeled growth curve** (species data + days elapsed), honestly framed as "expected growth," so there is forward motion even when the seedling looks identical to yesterday.
4. **Streak progress** - flame animation + progress toward the next milestone (Day 3, Day 7...).
5. **Future-reel preview** - a 1-2s micro-reel of the frames so far, with the timeline visibly filling toward Day 30 so the user watches the future payoff accrue. The promise is made tangible on Day 2, not deferred.
6. **Variable micro-reward** - an occasional surprise: a crop fun-fact, "you're ahead of the average grower," a dex teaser, a Sprout sticker.

**Day 1-7 danger-zone arc** - each early day delivers a distinct engineered moment so the story carries the days the visuals cannot: Day 1 instant teaser reel; Day 2 Sprout micro-growth + "what's happening at germination"; Day 3 first streak milestone; Day 5 "you vs. the average grower"; **Day 7 "First Week" recap reel + milestone card** - the first genuinely shareable artifact, deliberately timed before motivation fades. Notifications are warm and curiosity-driven ("Day 4 - something's stirring under the surface"), never nagging.

This makes the capture reward loop a **first-class build requirement** spanning Pillars 1, 2, and 4 - not a polish pass. The `PhotoService` capture flow, `StreakService`, the twin's modeled-growth curve, and a lightweight `RewardSequenceView` must ship together in the capture-loop milestone.

---

## Feature Set

### Hero Pillars

1. **Auto time-lapse grow reels** - guided ghost-overlay camera -> Vision alignment -> `AVAssetWriter` + `AVVideoCompositionCoreAnimationTool` 9:16 export with day-counter, music, branded end card; one-tap share. Free + unlimited (watermarked).
2. **Living digital twin** - parametric SwiftUI/`Canvas` plant that evolves with real grow stage/age/health; lives on the Home Screen via WidgetKit + a Live Activity / Dynamic Island for the active grow.
3. **AI Plant Doctor** - photo -> structured diagnosis (deficiency / pest / disease / pH / light) + exact fix; on-device Vision pre-pass for instant feel; cloud Claude for the diagnosis.
4. **Gamified streaks + dex** - photo-based daily streak with a forgiving freeze token; milestone/harvest celebrations that auto-generate shareable cards; collectible plant "dex" (collect a species by harvesting it).

### Table Stakes

- **Plant library / encyclopedia** - curated catalog of ~30-60 beginner crops (herbs, leafy greens, easy fruiting/veg) with light hours, pH/EC ranges, days-to-harvest, common issues, care tips. Bundled JSON -> `PlantSpecies`.
- **Multi-grow / multi-system management** - multiple plants; system types (Kratky / DWC / NFT / wick / ebb-flow / aeroponic / other).
- **Full care scheduling & reminders** - water, nutrient dose, pH check, EC check, top-up, light adjust, prune, transplant; per-task cadence; smart daily photo nudge; "Mark done" notification actions.
- **Nutrient & reservoir management** - dose logging, reservoir change tracking, top-up reminders.
- **Environmental logging + charts (Pro)** - pH / EC / PPM / TDS / water-temp / air-temp / humidity readings with trend charts and CSV export.
- **Grow timeline / journal** - every day-card, milestone markers (first true leaf, first flower, harvest), notes, care log.
- **Harvest & yield tracking** - harvest date, notes, dex unlock, "full grow" recap reel.
- **Troubleshooting knowledge base** - species `commonIssues` + Plant Doctor history form a per-plant health journal.
- **Search, iCloud sync, full-res cloud photo backup (Pro), data export, theming/tones, accessibility, onboarding.**

---

## Technical Architecture

- **Stack:** SwiftUI, iOS 26.2 target, Swift 5.0, `@Observable` services injected via `.environment()`. Single Xcode project (like `Anchor`/`Inhale`), not a modular SPM package.
- **Persistence:** SwiftData + CloudKit **private DB** `iCloud.com.sviftstudios.Grow` (clone `Anchor`'s `ModelContainer.shared` pattern - CloudKit-safe `@Model` style: defaults on every stored property, enums as `...Raw` strings, value structs as JSON `Data`, optional relationships with explicit `inverse:`/`deleteRule:`).
- **Media storage:** photos and rendered reels live as **files in the App Group container** `group.com.sviftstudios.Grow` (referenced by filename); only small thumbnails/poster frames sync via `@Attribute(.externalStorage)`. Do **not** put image/video bytes in the synced store.
- **Bundle IDs:** `com.sviftstudios.Grow`, widget `com.sviftstudios.Grow.GrowWidget`.
- **Platform integrations:** WidgetKit, ActivityKit Live Activity + Dynamic Island, App Intents/Siri, `UNUserNotificationCenter` reminders. **No HealthKit**.
- **Monetization:** RevenueCat + StoreKit 2 (entitlement `"Grow Pro"`), mirroring `Convert`'s `SubscriptionService` + `PremiumFeatureGate`.
- **Folder structure:** `Core/`, `Data/`, `Models/`, `Domain/`, `DesignSystem/`, `Services/`, `Views/`, `Utilities/`, `GrowWidget/`.

### SwiftData Model Graph

`Grow` (nickname, speciesID, systemType, startDate, stage, isActive, coverPhotoID; cascades to) `GrowPhoto` (capturedAt, stage, localFileName, thumbnailData, alignment JSON), `CareTask` (kind, cadence JSON, nextDueDate, defaultDoseML), `CareLog` (immutable performed-record), `Reading` (metric enum, value), `Reel` (localFileName, source range, music, style, posterFrame), `Diagnosis` (summary, confidence, issues JSON, modelVersion), `StreakState` (current/longest, lastCareDate, freezeTokens), `Achievement` (dex/milestone/streak). `PlantSpecies` is a **plain `Codable` struct from bundled `PlantCatalog.json`** (versioned, remote-override seam), not a synced `@Model`.

### Services

`GrowStore`, `PlantCatalogService`, `PhotoService`, `ReelRenderingService`, `PlantDoctorService`, `CareService`, `StreakService`, `AchievementService`/`DexService`, `NotificationService`, `StoreService` (RevenueCat) + `PremiumFeatureGate`, `SyncService`, `WidgetSyncService`, `LiveActivityManager`, `DeepLinkRouter` (`grow://`). `CommunityService` (Supabase) added in v1.1.

### Reel Engine Specifics

- Guided **`AVCaptureSession`** camera with a ~25-30% ghost overlay of the previous photo + level + zoom-lock.
- Alignment computed once at capture via `VNTranslationalImageRegistrationRequest` (cached transform per `GrowPhoto`); center-crop fallback on low confidence.
- Two-phase render: `AVAssetWriter` + `AVAssetWriterInputPixelBufferAdaptor` (Metal `CIContext`, `CVPixelBufferPool`, stream frames) -> wrap in `AVMutableComposition` + `AVMutableVideoComposition` with `AVVideoCompositionCoreAnimationTool` for the day-counter overlay + branded end card.
- Footguns: use `AVCoreAnimationBeginTimeAtZero` (never `0`), `isRemovedOnCompletion = false`, no `UIView`-backed layers. Bundle cleared royalty-free music. Export via `AVAssetExportSession`, share via `ShareLink`.

### AI Plant Doctor

- On-device **Vision** pre-pass (is-it-a-plant / in-focus gate) for instant feel + to reject bad photos.
- Thin backend proxy (keys off-device, EXIF stripped, per-user rate-limited) -> **Claude Sonnet 4.6** with strict structured output `{diagnosis, confidence, category, severity, exactFix[], whatToAvoid, recheckInDays}`.
- Escalate to **Opus 4.8** when confidence is below threshold.
- Prompt-cache the stable system prompt + species knowledge.
- Feed context: species, grow-day, last watering, recent photos.
- Persist each result as `Diagnosis`.

---

## Design And Brand

- **Living Green palette** - Sprout green ramp (hero `#3CB85C`), warm soil neutrals (`#FBFAF6` / dark `#121A15`), one warm apricot "Bloom" accent (`#F6A04D`) reserved for harvest/reward. Health states always color + glyph + label. Adaptive light/dark tokens - never hardcode `Color(hex:)` in views.
- **Liquid Glass** confined to the functional layer (tab bar, action capsules, capture HUD, milestone cards), never on the plant/content.
- **Reuse from Anchor:** clone palette/type/spacing/haptics/companion/streak-forgiveness/icon pipeline where useful.
- **First-run within 60 seconds:** reassure -> pick beginner-proof crop -> one question ("where will it live?") -> take Day 1 photo now -> Sprout sprouts, a 2-frame "your reel starts here" teaser plays. Paywall comes after first success, not here.
- **IA/nav:** glass tab bar - `Home (twin)`, `Today`, `Capture`, `Reels`, `Dex`; Plant Doctor + Settings/Paywall reached contextually.

---

## Build Sequencing

1. **Foundation:** models + `ModelContainer.shared` + `GrowStore` + `PlantCatalogService`; validate App Group read path from widget extension early.
2. **Capture loop + reward sequence:** `PhotoService`, guided camera, App Group storage, Vision alignment, `RewardSequenceView`, `StreakService`, `NotificationService`, Day 1-7 danger-zone arc.
3. **Twin surfaces:** `WidgetSyncService` + WidgetKit + `LiveActivityManager` + App Intents.
4. **Reels:** `ReelRenderingService`; build CoreAnimation overlay harness first.
5. **AI:** backend proxy + `PlantDoctorService` + `Diagnosis`.
6. **Gamification depth:** `Achievement`/`Dex` + milestone/harvest celebration reels.
7. **Care/data depth:** full `CareTask`/`CareLog`/`Reading` + charts (Pro).
8. **Monetization:** `StoreService` + `PremiumFeatureGate` + paywall.
9. **Polish + GTM assets.** v1.1: Supabase community + referral reels.

---

## Top Risks And Mitigations

**Product risk:** Daily-photo habit fails in the Day 1-7 danger zone. Mitigation: sub-2s gratification on every capture + modeled twin growth + future-reel preview + Day 1-7 arc + Day-7 recap reel. Treat first-week retention as the primary success metric.

**Technical risks:**

1. CoreAnimation overlay render bugs -> build throwaway 3-frame harness in week 1; keep a no-overlay export fallback.
2. Alignment quality on real beginner photos -> invest in capture-time ghost overlay/zoom-lock; confidence threshold + center-crop fallback; exposure-flicker smoothing as first fast-follow.
3. CloudKit + cross-process media -> files in App Group + thumbnails-only sync; test CloudKit schema on device early.

---

## Verification

- Capture reward loop: capture a single Day-1 photo with a near-identical Day-2 photo and confirm the full reward still lands: alignment score, Day-N card flip, Sprout/twin modeled advance, streak progress, and future-reel preview.
- Walk the Day 1-7 arc with a date-shifted clock and confirm each distinct moment fires and the Day-7 recap reel + milestone card generate.
- Per-pillar manual runs: capture staged photos -> export reel; confirm twin widget + Live Activity; run Plant Doctor; complete care across days and verify streak/freeze/milestone logic.
- AI cost check: log per-request tokens and cache hits on a 20-photo sample.
- Sync/widget: verify App Group read from widget extension on physical device; verify CloudKit private-DB round-trip across two devices.
- Accessibility: Dynamic Type to 200%, VoiceOver pass on capture + Home, Reduce Motion/Transparency fallbacks.
- Unit tests: streak logic, cadence/next-due computation, reading conversions, catalog decode.
