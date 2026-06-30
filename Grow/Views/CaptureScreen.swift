import SwiftData
import SwiftUI

struct CaptureScreen: View {
    @Environment(GrowStore.self) private var store
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(PhotoService.self) private var photoService
    @Query(
        filter: #Predicate<Grow> { $0.isActive && $0.archivedDate == nil },
        sort: \Grow.startDate, order: .reverse
    ) private var grows: [Grow]

    @State private var lastReward: CaptureReward?

    var body: some View {
        ZStack {
            PaperBackground(light: 0.58)
            if let grow = grows.first {
                CaptureWorkspace(
                    grow: grow,
                    species: catalog.species(id: grow.speciesID),
                    lastReward: lastReward,
                    onCapture: { capture(grow) }
                )
                .transition(.opacity)
            } else {
                CaptureEmptyState(speciesCount: catalog.species.count, onPlant: plantFirst)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.45), value: grows.isEmpty)
    }

    private func capture(_ grow: Grow) {
        let reward = photoService.recordPrototypeCapture(for: grow, species: catalog.species(id: grow.speciesID))
        withAnimation(.smooth(duration: 0.5)) {
            lastReward = reward
        }
        CaptureHaptics.reward()
    }

    private func plantFirst() {
        let pick = catalog.beginnerPicks.first ?? catalog.species.first
        guard let pick else { return }
        _ = store.createGrow(speciesID: pick.id, nickname: "", system: .kratky)
    }
}

private struct CaptureWorkspace: View {
    let grow: Grow
    let species: PlantSpecies?
    let lastReward: CaptureReward?
    var onCapture: () -> Void

    private var photos: [GrowPhoto] {
        (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    private var currentProgress: Double {
        lastReward?.modeledProgressAfter
            ?? ModeledGrowthCurve.progress(dayIndex: max(1, photos.last?.dayIndex ?? grow.dayCount), species: species)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GrowSpacing.lg) {
                masthead
                captureStage
                rewardPanel
                FutureReelStrip(frameCount: max(photos.count, lastReward?.frameCount ?? 0), progress: lastReward?.futureReelProgress ?? min(1, Double(photos.count) / 30))
            }
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.top, GrowSpacing.lg)
            .padding(.bottom, GrowSpacing.xxl)
        }
    }

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Field notes").fieldLabel()
                Text(species?.commonName ?? "Today's photo")
                    .growStyle(GrowType.serifHeadline())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: -4) {
                Text("FRAMES").fieldLabel(color: GrowPalette.sprout600)
                Text("\(max(photos.count, lastReward?.frameCount ?? 0))")
                    .growStyle(GrowType.numeral(42), color: GrowPalette.textPrimary)
            }
        }
    }

    private var captureStage: some View {
        VStack(spacing: GrowSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                    .fill(GrowPalette.surface.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                            .stroke(GrowPalette.separator, lineWidth: 1)
                    )

                GrowLightGlow(intensity: 0.42 + currentProgress * 0.38, size: 270)
                    .offset(y: -24)

                SpecimenJar(
                    progress: currentProgress,
                    hasBloom: ModeledGrowthCurve.stage(for: currentProgress).hasBloom,
                    size: 230
                )
                .padding(.top, GrowSpacing.sm)

                CaptureReticle()
                    .padding(GrowSpacing.md)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 310)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Aligned capture preview")

            Button(action: onCapture) {
                HStack(spacing: GrowSpacing.sm) {
                    Image(systemName: "camera.fill")
                    Text("Save today's frame")
                }
                .font(GrowType.headline())
                .foregroundStyle(GrowPalette.bloomInk)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(GrowPalette.bloom, in: Capsule())
                .shadow(color: GrowPalette.bloom.opacity(0.28), radius: 14, y: 7)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save today's frame")
        }
    }

    @ViewBuilder
    private var rewardPanel: some View {
        if let reward = lastReward {
            RewardSequenceView(reward: reward)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            QuietCapturePrompt(dayCount: grow.dayCount)
        }
    }
}

private struct RewardSequenceView: View {
    let reward: CaptureReward

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Growth memory saved").fieldLabel(color: GrowPalette.sprout600)
                    Text(reward.dayTitle).growStyle(GrowType.serifHeadline())
                }
                Spacer()
                AlignmentBadge(alignment: reward.alignment)
            }

            HStack(spacing: GrowSpacing.md) {
                TwinAdvanceCard(
                    progressBefore: reward.modeledProgressBefore,
                    progressAfter: reward.modeledProgressAfter,
                    stage: reward.expectedStage
                )
                StreakCard(update: reward.streak)
            }

            if let milestone = reward.milestoneTitle {
                HStack(spacing: GrowSpacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(GrowPalette.bloom)
                    Text(milestone)
                        .growStyle(GrowType.callout(.semibold), color: GrowPalette.textPrimary)
                    Spacer()
                }
                .padding(GrowSpacing.md)
                .background(GrowPalette.bloom.opacity(0.16), in: RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))
            }
        }
        .padding(GrowSpacing.md)
        .background(GrowPalette.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                .stroke(GrowPalette.separator, lineWidth: 1)
        )
    }
}

private struct AlignmentBadge: View {
    let alignment: CaptureAlignment

    var body: some View {
        VStack(alignment: .trailing, spacing: -2) {
            Text("\(alignment.percent)%")
                .growStyle(GrowType.numeral(34), color: GrowPalette.sprout600)
            Text(alignment.adjective).fieldLabel()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment \(alignment.percent) percent, \(alignment.adjective)")
    }
}

private struct TwinAdvanceCard: View {
    let progressBefore: Double
    let progressAfter: Double
    let stage: GrowStage

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            HStack {
                Text("Twin").fieldLabel()
                Spacer()
                Image(systemName: stage.systemImage)
                    .foregroundStyle(GrowPalette.sprout600)
            }
            ProgressView(value: progressAfter)
                .tint(GrowPalette.sprout500)
            Text("+\(Int(max(0, progressAfter - progressBefore) * 100))% expected growth")
                .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GrowSpacing.md)
        .background(GrowPalette.sprout50.opacity(0.7), in: RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))
    }
}

private struct StreakCard: View {
    let update: StreakUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            HStack {
                Text("Streak").fieldLabel()
                Spacer()
                Image(systemName: update.spentFreezeToken ? "snowflake" : "flame.fill")
                    .foregroundStyle(update.spentFreezeToken ? GrowPalette.info : GrowPalette.bloom)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(update.current)")
                    .growStyle(GrowType.numeral(36), color: GrowPalette.textPrimary)
                Text("days").growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
            }
            ProgressView(value: update.milestoneProgress)
                .tint(GrowPalette.bloom)
            Text(update.milestoneCopy)
                .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GrowSpacing.md)
        .background(GrowPalette.bloom.opacity(0.14), in: RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))
    }
}

private struct FutureReelStrip: View {
    let frameCount: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.sm) {
            HStack {
                Text("Future reel").fieldLabel()
                Spacer()
                Text("\(min(frameCount, 30))/30").fieldLabel(color: GrowPalette.sprout600)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(GrowPalette.separator.opacity(0.6))
                    Capsule()
                        .fill(LinearGradient(colors: [GrowPalette.sprout500, GrowPalette.bloom], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 8)

            HStack(spacing: GrowSpacing.xs) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(index < min(6, frameCount) ? GrowPalette.sprout300.opacity(0.55) : GrowPalette.surface.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(GrowPalette.separator, lineWidth: 1)
                        )
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                }
            }
        }
        .padding(GrowSpacing.md)
        .background(GrowPalette.surface.opacity(0.66), in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
    }
}

private struct QuietCapturePrompt: View {
    let dayCount: Int

    var body: some View {
        HStack(alignment: .center, spacing: GrowSpacing.md) {
            ZStack {
                Circle().fill(GrowPalette.sprout50)
                Image(systemName: "leaf.arrow.triangle.circlepath")
                    .foregroundStyle(GrowPalette.sprout600)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("Day \(dayCount)").fieldLabel(color: GrowPalette.sprout600)
                Text("A new memory is ready for the reel.")
                    .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(GrowSpacing.md)
        .background(GrowPalette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
    }
}

private struct CaptureReticle: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [8, 8]))
                .foregroundStyle(GrowPalette.sprout600.opacity(0.55))

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "scope")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout600.opacity(0.72))
                    Spacer()
                }
                Spacer()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CaptureEmptyState: View {
    let speciesCount: Int
    var onPlant: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.lg) {
            Text("Field notes").fieldLabel()
            Spacer(minLength: GrowSpacing.xl)
            SpecimenJar(progress: 0.06, size: 260)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: GrowSpacing.sm) {
                Text("Start with one living subject.")
                    .growStyle(GrowType.serifTitle())
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(speciesCount) beginner-proof crops are ready for their first frame.")
                    .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onPlant) {
                    HStack(spacing: GrowSpacing.sm) {
                        Image(systemName: "leaf.fill")
                        Text("Plant first crop")
                    }
                    .font(GrowType.headline())
                    .foregroundStyle(GrowPalette.bloomInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(GrowPalette.bloom, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, GrowSpacing.xs)
            }
            Spacer(minLength: GrowSpacing.lg)
        }
        .padding(GrowSpacing.lg)
    }
}

private enum CaptureHaptics {
    static func reward() {
        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
        #endif
    }
}
