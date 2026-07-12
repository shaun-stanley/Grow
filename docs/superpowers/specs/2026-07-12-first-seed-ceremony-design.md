# First Seed Ceremony Design

Date: 2026-07-12  
Status: Approved product, architecture, and visual direction  
Scope: First-run activation from launch through the first saved growth memory

## Context

Grow currently has a polished living-twin home surface, guided capture workspace, reward sequence, and reel studio, but the first-run journey does not connect them. Tapping the existing empty-state action immediately creates a basil grow without letting the beginner choose a crop or setup, without explaining the daily-photo promise, and without delivering the Day-1 capture reward. Care and Dex are still placeholder surfaces, but fixing them before activation would leave the most important retention funnel incoherent.

The first ship-readiness milestone is therefore a focused activation vertical slice called **The First Seed Ceremony**:

`Promise → Choose → Setup → Capture → Reward → Today`

The target user is a first-time urban hydroponic grower who may be uncertain, impatient, or worried about killing a plant. The ceremony must make that person feel capable and emotionally invested in under 60 seconds.

## Research Summary

Current competitors generally fall into three patterns:

- Greg uses a warm illustrated onboarding but stretches setup across 26 screens before and during plant creation.
- Planta uses a nine-step personalization flow and permission pre-prompts. Personalization is useful, but the flow has been criticized for ambiguous selection controls, missing progress feedback, and cognitive overload.
- Blossom uses a nine-step questionnaire and emotional problem framing before a soft paywall.
- PictureThis presents feature slides and a trial before reaching its strongest interaction: camera-based identification.
- Hardware-first hydroponics apps such as Gardyn, Rise Gardens, and LetPot spend onboarding on accounts, Bluetooth, Wi-Fi, and device pairing. Grow is software-only and must not inherit that baggage.

Grow's opportunity is to replace the category's quiz-and-paywall pattern with a real accomplishment. A person completes onboarding having created a grow, captured a real Day-1 artifact, seen the living twin react, and understood how the future reel accumulates.

### Sources

- Apple HIG, Design principles: https://developer.apple.com/design/human-interface-guidelines/design-principles
- Apple HIG, Onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding
- Apple HIG, Feedback: https://developer.apple.com/design/human-interface-guidelines/feedback
- Apple HIG, Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple Design Awards 2026: https://developer.apple.com/design/awards/
- Greg onboarding: https://theappfuel.com/examples/greg_onboarding
- Planta critique: https://ixd.prattsi.org/2025/09/design-critique-planta-ios-app/
- Blossom analysis: https://screensdesign.com/showcase/blossom-plant-care-guide
- PictureThis onboarding: https://theappfuel.com/examples/picturethis_onboarding
- Gardyn pairing: https://help.mygardyn.com/en/articles/1769729
- LetPot pairing: https://letpot.com/blogs/letpot-news-and-other-information/how-to-use-letpot-app-when-you-got-letpot-indoor-gardening-kits

## Product Principles

### Deliver value before explanation

The ceremony is not a feature carousel. Each screen advances the user's real setup. Copy explains only the decision immediately in front of the person.

### One decision per screen

The user chooses a crop, chooses a setup category, and takes a photo. No experience survey, account creation, location request, notification request, nickname form, light questionnaire, or paywall appears in this flow.

### Defaults without deception

"Choose for me" selects Genovese basil and clearly shows the result. Kratky is the recommended default for a simple jar, while countertop systems and an honest flexible fallback remain available.

### Permission at the moment of value

Camera permission is requested only when the user enters the capture step. The preceding screen and capture copy explain that the photo becomes Frame 1 of the grow story. Denying camera access never traps the user; photo import remains available.

### Delight follows action

The most expressive motion, haptics, sound, apricot accent, and celebration appear only after the photo is saved. The ceremony earns delight instead of using decoration to mask setup work.

### Fast, optional, and recoverable

The primary path targets completion in under 60 seconds. A session-only sample experience lets an uncertain user explore without polluting persistent data. Back navigation preserves selections. Abandoning before grow confirmation writes nothing.

## Experience Design

### Beat 1: Promise

The opening screen uses the existing Living Field Journal language: warm paper, system typography, a living glass specimen jar, a small future Day-30 marker, and one strong action.

- Kicker: `Grow · a living journal`
- Title: `Grow something from almost nothing.`
- Supporting copy: `A photo a day becomes the story of your first harvest.`
- Primary action: `Plant your first seed`
- Footnote: `No account · About one minute`
- Secondary action: `Explore with a sample grow`

There is no separate splash screen, logo animation, sign-in prompt, or feature carousel.

### Beat 2: Choose

The user sees three beginner crops as compact living specimens:

1. Genovese basil — fast, aromatic, 28–35 days.
2. Butterhead lettuce — calm, crisp, 35–45 days.
3. Mint — hardy, fragrant, 30–40 days.

Each choice uses a distinct botanical image or specimen rendering, crop name, short benefit, harvest range, and a familiar single-selection indicator. The default selection is basil. `Choose for me` explicitly selects basil and continues only after the user sees that selection.

### Beat 3: Setup

The flow asks one question: `Where will your basil grow?`

- `A simple jar` maps to Kratky and is recommended.
- `Countertop garden` maps to DWC for launch behavior.
- `Something else` maps to Other and keeps advice flexible.

The screen does not ask about container size, room, light exposure, nutrients, experience, or naming. Those details can appear later as contextual improvements when they influence a real task.

Tapping `Start my grow` is the persistence boundary. The app creates the `Grow` and seeds care tasks through `GrowStore`.

### Beat 4: Capture

The guided camera opens as a purposeful continuation of onboarding, not as an unrelated modal.

- Title: `Frame one`
- Subtitle: selected crop name.
- A jar-shaped guide makes the expected composition obvious.
- Short coaching copy changes from centering guidance to a steady success state.
- The shutter is the dominant control.
- Photo import remains visible.
- Camera switching and latest-thumbnail access remain secondary.

For Day 1 there is no previous-frame ghost. The guide establishes the reusable composition that future ghost overlays will reinforce.

### Beat 5: Reward

After the file is successfully saved, the existing capture reward becomes the emotional conclusion:

1. A success haptic confirms the save.
2. `Growth memory saved` appears with a clear visual seal.
3. The captured photo becomes a physical-feeling dated Day-1 memory card.
4. Sprout and the living twin visibly emerge.
5. Alignment, streak, and first-reel progress appear as labeled metrics.
6. A tiny future-reel preview makes the accumulating payoff tangible.
7. The primary action `Meet your basil` lands on Today.

The screen must still feel rewarding when the plant is only a seed, pod, or empty-looking jar. Real-world visible growth is not required for emotional progress.

### Destination: Today

The completed ceremony lands on the active grow's living-twin surface. The first frame and Day-1 progress must be visible or reachable without hunting. The next action is tomorrow's frame, not account creation or a paywall.

## Visual Direction

The approved visual storyboard is the high-fidelity **First Seed Ceremony** direction shown on 2026-07-11.

### Living Field Journal

- Warm paper and soil neutrals provide the content layer.
- Sprout green carries active selection, progress, and living growth.
- Bloom apricot is reserved for the earned reward and completion action.
- System typography maintains native legibility and Dynamic Type behavior.
- Botanical specimen imagery is the hero; generic card stacks are not.
- Data is presented like field annotations rather than dashboard widgets.

### Liquid Glass

Liquid Glass is limited to functional camera chrome and compact floating controls. Crop, setup, and memory surfaces remain clear and tactile. No nested glass cards or decorative material layers appear.

### Motion and sound

- Screen transitions use short directional motion that preserves context.
- Selection changes use restrained matched movement or scale, never bouncing every element.
- The specimen can show subtle organic motion while Reduce Motion receives a static equivalent.
- The reward sequence may use a card flip, Sprout emergence, haptic, and short sound only after persistence succeeds.
- No essential information is conveyed by animation, sound, or color alone.

## Architecture

### `OnboardingCoordinator`

An `@Observable` state machine owns transient onboarding state:

- Current step: promise, crop, setup, capture, reward, or sample.
- Selected species ID.
- Selected setup category and mapped `GrowSystem`.
- Whether grow creation has crossed the persistence boundary.
- Capture/reward state needed to resume safely after interruptions.

The coordinator exposes explicit forward, backward, sample, cancel, retry, and completion transitions. SwiftUI views do not mutate step state ad hoc.

### `OnboardingPolicy`

A pure domain helper owns:

- The integer `AppStorage` key `grow.onboarding.completedVersion`; the current ceremony version is `1`, and `0` means incomplete.
- The three launch crop IDs and default crop.
- Setup-category-to-`GrowSystem` mapping.
- Step-transition eligibility.
- User-facing policy copy that must remain consistent across accessibility labels and tests.

Policy tests do not require SwiftUI, SwiftData, camera hardware, or simulator state.

### `FirstSeedFlow`

Presentation is split into focused SwiftUI files rather than added to `RootView.swift` or `CaptureScreen.swift`:

- `FirstSeedFlow.swift` owns routing and shared ceremony chrome.
- `FirstSeedPromiseView.swift` owns Beat 1.
- `FirstSeedCropView.swift` owns Beat 2.
- `FirstSeedSetupView.swift` owns Beat 3.
- `FirstSeedCaptureView.swift` adapts the shared guided camera for Beat 4.
- `FirstSeedRewardView.swift` adapts the shared reward sequence for Beat 5.

Names may be consolidated where a file would otherwise contain only trivial markup, but no ceremony file should become another multi-responsibility monolith.

### Shared capture extraction

`CaptureScreen.swift` is currently approximately 1,444 lines and owns workspace, camera, reward, and many receipt components. This milestone extracts only the boundaries required for reuse:

- Guided camera presentation and overlays move to a focused capture-camera file.
- Reward sequence and its supporting memory/reel components move to a focused reward file.
- `CaptureScreen` remains the tab-level feature and orchestrates the shared components.
- Onboarding passes an explicit Day-1 configuration rather than duplicating camera or reward logic.

This is a targeted risk reduction, not a broad rewrite of capture internals.

### Persistence and data flow

Before `Start my grow`, all state is transient. On confirmation:

1. `GrowStore.createGrow(speciesID:nickname:system:)` creates the aggregate and care tasks.
2. The coordinator holds the created grow identity for the remainder of the flow.
3. The shared camera provides image data.
4. `PhotoService` writes the full image to the App Group container, stores only file references and a small thumbnail in SwiftData, computes Day-1 alignment metadata, advances streak state, and returns `CaptureReward`.
5. The reward view presents only after the save succeeds.
6. Completing the reward writes the versioned onboarding-completion value and routes to Today.

No full photo or video bytes enter the synced SwiftData store.

### Sample mode

`Explore with a sample grow` is session-only. It renders a read-only sample using catalog values and existing specimen/reel presentation without creating `Grow`, `GrowPhoto`, `Reel`, streak, or achievement records. Leaving sample mode returns to the ceremony. Relaunching shows the ceremony again until a real grow completes onboarding.

## Error Handling and Recovery

### Camera permission denied

The capture step explains that camera access creates Frame 1, then offers:

- `Choose a photo` using the system photo picker.
- `Open Settings` when appropriate.
- `Not now`, which returns to the ceremony without marking onboarding complete.

### Photo import or encoding failure

The user remains on capture with the selected grow intact. The error uses human copy, preserves the chosen crop/setup, and offers retry or another photo. A reward never appears for an unsaved file.

### App interruption

Before grow creation, transient selections may restart without data cleanup. After grow creation, relaunch detects an active grow with no photos and routes to a resumable `Take your Day-1 photo` state rather than showing the entire ceremony again. An active grow with a photo routes to Today and records onboarding completion if needed.

### Save failure

`GrowStore` and `PhotoService` must surface failures to the coordinator. The ceremony cannot silently continue after a failed SwiftData save or App Group write.

### Sample exit

Leaving sample mode writes nothing and returns to the promise screen. No destructive cleanup is necessary.

## Accessibility

- Support Dynamic Type through accessibility sizes without clipping, overlap, or hiding the primary action.
- Use VoiceOver grouping so each crop and setup option reads as one labeled selection control with name, benefit, timing, and selected state.
- Provide explicit VoiceOver guidance for the Day-1 camera guide and a labeled shutter action.
- Never encode health, selection, readiness, or success using color alone; pair color with glyph, label, and state.
- Maintain 44-point default hit targets and sufficient spacing between adjacent controls.
- Honor Reduce Motion with fades/static state changes and Reduce Transparency with opaque functional chrome.
- Pair reward sounds with haptics and visible text; mute never removes feedback.
- Preserve a photo-import path for people who cannot comfortably use the live camera.
- Test Increased Contrast and Differentiate Without Color behavior.

## Testing and Verification

### Unit tests

- `OnboardingPolicy` default crop and ordered launch choices.
- Setup choice mapping to Kratky, DWC, and Other.
- Valid and invalid step transitions.
- Persistence boundary behavior.
- Completion and resume routing for no grow, active grow without photos, and active grow with a Day-1 photo.
- Sample mode never produces persistence intents.

### Service tests

- Grow creation seeds the expected care tasks for the selected species.
- A successful Day-1 capture writes a nonempty App Group file and persists the expected `GrowPhoto` metadata.
- A failed media write produces no reward and leaves a recoverable state.

### Simulator flows

Use XcodeBuildMCP on iPhone 17 Pro with iOS 26.2:

1. Clean install → complete basil/Kratky/camera path.
2. Clean install → choose lettuce/countertop/import path.
3. Clean install → deny camera → import photo recovery.
4. Clean install → sample mode → exit → real grow.
5. Interrupt after grow creation but before capture → relaunch and resume Day-1 capture.
6. Complete capture → verify Today, Capture, and Reels all show consistent Day-1 data.

Every milestone UI change requires screenshots and semantic snapshots. Visual QA covers standard text, Accessibility Large text, Reduce Motion, Increased Contrast, and at least one compact-height iPhone.

### Required build

```bash
xcodebuild -project Grow.xcodeproj -scheme Grow -configuration Debug -sdk iphonesimulator -derivedDataPath /tmp/GrowDerivedData CODE_SIGNING_ALLOWED=NO build
```

### Manual emotional QA

Use a seed or visually unchanged jar photo. The sequence must still feel rewarding through alignment feedback, the tangible memory card, Sprout/twin emergence, streak progress, and the visible promise of the future reel.

## Non-Goals

- Account creation, sign-in, CloudKit account UI, or profile setup.
- Paywall, purchase, rating, review, or notification permission prompts.
- Plant Doctor diagnosis.
- Full Care or Dex implementation.
- Widget or Live Activity implementation.
- Hardware discovery or pairing.
- A general rewrite of capture, reels, SwiftData, or the design system.
- More than three launch crop choices.

## Acceptance Criteria

- A new user can reach a saved Day-1 growth memory in under 60 seconds without an account or purchase prompt.
- The journey follows Promise → Choose → Setup → Capture → Reward → Today.
- The three approved beginner crops and three setup choices are clear, accessible single-selection controls.
- No `Grow` is persisted before explicit confirmation.
- The Day-1 image is stored as a file in the App Group container, not as full bytes in SwiftData.
- Camera denial and photo-import failure have clear, nontrapping recovery paths.
- The reward appears only after persistence succeeds and remains emotionally effective with no visible real-world growth.
- Sample mode writes no persistent user data.
- Relaunch after partial completion resumes at the correct state.
- Camera and reward UI are shared with the Capture tab rather than duplicated.
- Standard and accessibility simulator screenshots match the approved Living Field Journal storyboard and show no clipping, low-contrast controls, generic card stacking, or decorative Liquid Glass misuse.
- Focused tests, all existing tests, the required Xcode build, `git diff --check`, and simulator visual QA pass before implementation is committed and pushed.
