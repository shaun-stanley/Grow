# Capture Loop v0.2 Design

Date: 2026-07-07
Status: Approved design draft for user review
Owner: Codex

## Goal

Capture Loop v0.2 tightens Grow's highest-risk habit loop: the beginner takes a daily plant photo during Days 1-7, feels rewarded even when the plant has not visibly changed, and trusts the camera guidance enough to keep the framing steady for future reels.

This spec intentionally stays inside the capture-loop milestone. It does not add a WidgetKit extension, Live Activity, AI Plant Doctor, care scheduling, monetization, or social/community features.

## Current Findings

- The app is on `main`, with the capture loop and reel harness already merged.
- `CaptureScreen` has the reward sequence, future-reel strip, camera/import/simulator capture paths, and a debug `-simulateCaptureReward` hook.
- `PhotoService` writes App Group photo files, thumbnails, alignment JSON, captions, modeled stage changes, streak updates, and simulator prototype frames.
- `CameraCaptureService` owns a real `AVCaptureSession`, but camera trust controls are still basic: no surfaced zoom state, focus/exposure lock affordance, level/steadiness coaching, or device capability copy.
- `CaptureAlignment` currently stores score, offsets, and rotation only. The UI cannot distinguish a real Vision translation result from a fallback estimate.
- There is no test target in the project yet.
- The prior visual QA found the capture reward direction promising, but the next pass needs accessibility-grade contrast, Dynamic Type resilience, deterministic Day 1-7 states, and real-device confidence cues.

## Source Checks

- Apple Human Interface Guidelines source anchor: https://developer.apple.com/design/human-interface-guidelines
- Apple Liquid Glass source anchor: https://developer.apple.com/documentation/technologyoverviews/liquid-glass
- Sosumi Apple docs surfaced current AVFoundation primitives for `AVCaptureDevice.lockForConfiguration()`, `focusMode`, `exposureMode`, `videoZoomFactor`, `minAvailableVideoZoomFactor`, and `maxAvailableVideoZoomFactor`.
- Sosumi Apple docs surfaced current Vision image-registration primitives around `VNImageTranslationAlignmentObservation`, `VNTranslationalImageRegistrationRequest`, and trackable translational registration.
- Sosumi Apple docs surfaced accessible appearance/material/motion guidance and confirmed the design constraint: glass can support functional chrome, but legibility and accessibility must win.
- Web search around current Apple design direction reinforced that modern Apple-quality work is judged on interaction, accessibility, visual specificity, and restraint rather than generic gradient-heavy UI.

## Product Direction

The approved direction is **Capture Confidence + First-Week Ritual**.

The tone is a hybrid: Grow keeps the calm Living Field Journal base, then adds playful sparks only for milestones, unusually good alignment, and first-week moments. The app should never feel like a generic habit tracker, a motivational poster, or a purple-gradient AI app. The memorable thing should be the feeling of preserving a living specimen one frame at a time.

Primary success lenses:

- First-week retention: Day 1-7 rewards feel emotionally strong even when the plant barely changes.
- Camera confidence: the user feels guided, not judged, while matching the previous frame.

Secondary success lens:

- Engineering foundation: the policy logic and QA states become testable enough that future polish does not regress the Day 1-7 loop.

## UX Design

The daily capture experience should feel like a short ritual:

1. Frame the plant against the ghost of the previous photo.
2. Stabilize the device and lock the same angle.
3. Capture today's frame.
4. Receive a sub-2s reward sequence that proves the memory, streak, twin, and future reel all advanced.

Day 1-7 arc:

- Day 1: "Your reel starts here." The first frame matters because it becomes the before-state.
- Day 2: Invisible growth reassurance. The reward explains that germination is mostly roots and patience.
- Day 3: First streak marker. The app treats three frames as the first sign of rhythm.
- Day 5: Confidence beat. The copy reinforces that consistency here is unusual and valuable.
- Day 7: First-week recap unlock. This becomes the first shareable artifact, not just another streak badge.

Camera guidance:

- Stronger previous-frame ghost when a prior photo exists.
- Clear "same angle" coaching before capture.
- Level or steadiness cue that is glanceable and not fussy.
- Zoom affordance that encourages consistent framing without turning the screen into a pro camera panel.
- Focus/exposure lock affordance when supported; graceful coaching when unavailable.
- Alignment badge copy that distinguishes real Vision alignment from fallback estimates.

Reward UI:

- Keep Liquid Glass in capture HUD/chrome and milestone cards only.
- Keep content and plant surfaces clear, tactile, and readable.
- Improve Twin and Streak card contrast in light/dark modes.
- Support Dynamic Type without text overlap, clipped score labels, or cramped side-by-side cards.
- Use glyph plus label plus color for status; do not rely on color alone.
- Respect Reduce Motion by skipping staged animations while preserving the reward content.

## Architecture

The implementation should keep the existing SwiftUI and `@Observable` service pattern.

### CaptureRewardPolicy

Add a small domain helper for pure reward policy:

- Day 1-7 milestone titles.
- First-week notes.
- Micro-reward title/body/icon/tint identity.
- Future-reel progress math.
- Reward caption copy.

This lets tests cover emotional/product rules without SwiftData or SwiftUI.

### CaptureAlignment

Extend the Codable alignment payload with method/source metadata while keeping backward compatibility for existing saved JSON:

- `source`: Vision translation, fallback estimate, or prototype/simulator.
- `confidence`: a coarse value or normalized score category.
- Existing score and offsets stay intact.
- UI exposes source-specific copy, such as "Vision matched this frame" or "Estimated match".

### PhotoService

`PhotoService` remains the single media write path:

- Normalize and encode real photos.
- Write originals into App Group media storage.
- Store thumbnails in SwiftData external storage.
- Compute alignment.
- Persist alignment JSON.
- Update streak and modeled twin stage.
- Return `CaptureReward`.

Move policy copy out of `PhotoService` where practical so the service focuses on capture persistence and reward assembly.

### CameraCaptureService

Keep ownership of `AVCaptureSession`, but expose a small camera-state surface:

- Availability of focus/exposure lock.
- Availability and bounds of zoom.
- Current zoom factor.
- Lock state and coaching state.
- Methods for setting zoom and toggling supported lock behavior through `lockForConfiguration()`.

The view should not configure capture hardware directly.

### CaptureScreen

`CaptureScreen` remains the main ritual surface:

- Use policy values for reward text.
- Render improved camera/reward UI with existing design tokens.
- Add deterministic debug launch states for first-week screenshots.
- Keep import and simulator capture as reliable fallback paths.

## Data Flow

1. User captures or imports image data.
2. `PhotoService` normalizes image data and loads previous photo if available.
3. Vision translational image registration runs when possible.
4. Alignment source and confidence are encoded into `GrowPhoto.alignmentData`.
5. The photo file and thumbnail are saved.
6. Streak and modeled twin stage update.
7. `CaptureRewardPolicy` supplies copy and milestone metadata.
8. `CaptureScreen` renders reward sequence and future-reel progress.
9. `WidgetSyncService` continues receiving snapshots after successful captures, but widget extension validation stays out of scope.

## Error Handling

- If camera permission is denied, keep the current Settings/import fallback path and make the copy calm.
- If a device lacks a back camera, simulator capture and import remain available.
- If zoom/focus/exposure features are unsupported, hide active controls and show passive coaching.
- If Vision alignment fails or prior media is missing, still save the photo and reward the user, but label the score as an estimate.
- If App Group media write fails, surface a capture error and do not pretend the frame was saved.
- If tests cannot be attached through a clean Xcode test target, the implementation plan must explicitly call that out and choose the least brittle fallback.

## Testing And QA

Target tests:

- Day 1, 2, 3, 5, and 7 reward policy.
- Modeled growth progress and stage boundaries.
- Streak same-day, next-day, missed-day-with-freeze, and missed-day-without-freeze behavior.
- Alignment Codable compatibility for old payloads and new source metadata.
- Fallback alignment copy so estimates are not presented as Vision matches.

Manual verification:

- Run the required Xcode build command from `AGENTS.md`.
- Use XcodeBuildMCP to build, launch, control the simulator, and take screenshots when tools are exposed.
- Verify Day 2 reward state: reassurance lands even with nearly identical frames.
- Verify Day 7 reward state: first-week recap/milestone feels distinct and shareable.
- Verify Dynamic Type and dark/light contrast for reward cards.
- Verify camera fallback behavior in simulator/no-camera conditions.

## Living Todo Seed

- [ ] Create implementation plan with change log and living todo.
- [ ] Verify latest Apple docs through Sosumi for AVFoundation camera configuration and Vision alignment before code changes.
- [ ] Add or validate a `GrowTests` target.
- [ ] Extract pure reward policy.
- [ ] Extend alignment metadata with source/confidence.
- [ ] Add deterministic Day 1-7 launch states.
- [ ] Improve capture HUD and camera confidence UI.
- [ ] Improve reward-card contrast, Dynamic Type behavior, and Reduce Motion fallbacks.
- [ ] Add focused tests.
- [ ] Build and visually verify with XcodeBuildMCP screenshots.
- [ ] Record every implementation update in the living plan file.

## Out Of Scope

- WidgetKit extension and signed App Group cross-process validation.
- Live Activity and Dynamic Island surfaces.
- Full reel editor or music selection.
- AI Plant Doctor.
- Care scheduling and nutrient logging.
- Paywall, subscriptions, or RevenueCat.
- Social/community features.

## Approval State

The user approved:

- Scope: Capture Loop v0.2 first.
- Success lens: first-week emotional payoff and camera confidence.
- Tone: hybrid field-journal base with playful sparks at milestones and great alignment moments.
- Architecture: focused domain helpers, honest alignment metadata, improved camera-state surface, deterministic first-week QA states.
- QA direction: tests plus XcodeBuildMCP visual verification.
