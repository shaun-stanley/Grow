# Grow App Icon Design

**Date:** 2026-07-13
**Status:** Concept approved; awaiting written-spec review
**Selected concept:** Geometric seed at the water boundary
**Approved generated source:** `DesignSources/AppIcon/GrowAppIconConcept-01.png`

## Objective

Replace Grow's empty app-icon slot with a memorable, first-party-feeling iOS icon that communicates hydroponic growth through one simple event: a seed meeting water and becoming a shoot.

## Approved Mark

The icon uses four large geometric elements:

1. A rich living-green field.
2. A mineral-blue lower semicircle representing water.
3. A small warm-apricot seed placed exactly at the water boundary.
4. A warm-white two-leaf shoot rising from the seed.

The seed is the visual hinge. It joins water and growth without depicting a jar, garden, camera, reel, or interface. The mark stays legible at notification size and remains recognizable when iOS applies dark, clear, or tinted rendering.

## Production Treatment

- Preserve the approved silhouette, proportions, spatial relationships, and four-color hierarchy.
- Use the generated concept as the actual production-art source, not as a prompt for a code-drawn replacement.
- Deliver one unmasked, opaque, square 1024×1024 PNG in the existing `AppIcon.appiconset`.
- Do not bake rounded corners, device framing, text, branding words, borders, drop shadows, bevels, or additional highlights into the artwork.
- Normalize the selected source to 1024×1024 in sRGB without aesthetic filtering or generative reinterpretation.
- Keep all essential content inside Apple's app-icon safe placement area.
- Let iOS generate dark, clear, and tinted appearances from the core artwork for the initial ship; the geometry must not change between appearances.
- Retain the 1254×1254 selected generation source in `DesignSources/AppIcon/` for future Icon Composer layer reconstruction.

## Asset Integration

- Production file: `Grow/Assets.xcassets/AppIcon.appiconset/GrowAppIcon.png`.
- `Contents.json` associates `GrowAppIcon.png` with the universal iOS 1024×1024 slot.
- No alternate icon or app-setting UI is added in this milestone.
- The source asset and production derivative are both committed; the app target bundles only the asset-catalog derivative.

## Verification

- Validate PNG dimensions, format, color profile, opacity, and absence of an embedded corner mask.
- Build through XcodeBuildMCP and the repository-required `xcodebuild` command.
- Install on iPhone 17 Pro and visually inspect the icon on the Home Screen, Spotlight, Settings, a notification, and the share sheet at standard/default text size.
- Inspect default, dark, clear light, clear dark, tinted light, and tinted dark Home Screen appearances.
- Compare at 1024, 180, 120, 60, 40, and 29 pixels; the seed, water boundary, and shoot must remain distinct.
- Verify the icon does not visually merge with common green backgrounds or disappear in monochrome/tinted treatments.

## Acceptance Criteria

- The installed app no longer shows an empty or generic generated placeholder.
- The production icon is the user-selected generated concept, faithfully normalized rather than redrawn in Swift, SVG, or procedural code.
- The icon reads as seed + water + growth at Home Screen and notification sizes.
- There is no pre-rounded corner mask, text, watermark, or visible generative artifact.
- All required builds pass and the icon is visually approved in the simulator across current iOS appearance modes.

## Apple Guidance

Apple permits flattened app icons, applies the platform mask itself, recommends a simple centered concept with clearly defined edges, and automatically creates appearance variants when custom variants are absent. The design follows [App icons — Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons).

## Out of Scope

- The Ojai UGC photo system, which has its own approved spec and implementation plan.
- Alternate icons.
- Replacing the living digital twin or widget artwork.
- A custom Icon Composer multilayer file in this milestone; the approved source is retained so layered reconstruction can be evaluated after the flattened icon ships and is tested.
