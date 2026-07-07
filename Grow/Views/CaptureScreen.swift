import AVFoundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CaptureScreen: View {
    @Environment(GrowStore.self) private var store
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(StreakService.self) private var streakService
    @Environment(PhotoService.self) private var photoService
    @Environment(NotificationService.self) private var notificationService
    @Environment(WidgetSyncService.self) private var widgetSyncService
    @Query(
        filter: #Predicate<Grow> { $0.isActive && $0.archivedDate == nil },
        sort: \Grow.startDate, order: .reverse
    ) private var grows: [Grow]

    @State private var lastReward: CaptureReward?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isCapturing = false
    @State private var captureError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(light: 0.58)
                if let grow = grows.first {
                    CaptureWorkspace(
                        grow: grow,
                        species: catalog.species(id: grow.speciesID),
                        lastReward: lastReward,
                        selectedPhotoItem: $selectedPhotoItem,
                        isCapturing: isCapturing,
                        captureError: captureError,
                        onCamera: { isShowingCamera = true },
                        onPrototypeCapture: { capturePrototype(grow) }
                    )
                    .transition(.opacity)
                } else {
                    CaptureEmptyState(speciesCount: catalog.species.count, onPlant: plantFirst)
                        .transition(.opacity)
                }
            }
            .navigationTitle("Capture")
            .navigationSubtitle(navigationSubtitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .animation(.smooth(duration: 0.45), value: grows.isEmpty)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item, let grow = grows.first else { return }
            Task { await importPhoto(item, for: grow) }
        }
        .sheet(isPresented: $isShowingCamera) {
            if let grow = grows.first {
                PlantCameraView(
                    speciesName: catalog.species(id: grow.speciesID)?.commonName ?? "Plant",
                    frameCount: (grow.photos ?? []).count + 1,
                    latestThumbnailData: (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }.last?.thumbnailData,
                    currentProgress: ModeledGrowthCurve.progress(dayIndex: max(1, grow.dayCount), species: catalog.species(id: grow.speciesID)),
                    onCapture: { data in
                        isShowingCamera = false
                        recordImageData(data, for: grow)
                    },
                    onCancel: { isShowingCamera = false }
                )
                .ignoresSafeArea()
            }
        }
    }

    private var navigationSubtitle: LocalizedStringKey {
        guard let grow = grows.first else { return "No active grow" }
        let displayName = grow.nickname.isEmpty
            ? (catalog.species(id: grow.speciesID)?.commonName ?? "Active grow")
            : grow.nickname
        return LocalizedStringKey(displayName)
    }

    private func capturePrototype(_ grow: Grow) {
        let reward = photoService.recordPrototypeCapture(for: grow, species: catalog.species(id: grow.speciesID))
        withAnimation(.smooth(duration: 0.5)) {
            captureError = nil
            lastReward = reward
        }
        scheduleTomorrowReminder(for: grow)
        syncWidgetSnapshot(for: grow, streak: reward.streak)
        CaptureHaptics.reward()
    }

    private func importPhoto(_ item: PhotosPickerItem, for grow: Grow) async {
        isCapturing = true
        defer {
            isCapturing = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoServiceError.unreadableImage
            }
            recordImageData(data, for: grow)
        } catch {
            captureError = error.localizedDescription
        }
    }

    private func recordImageData(_ data: Data, for grow: Grow) {
        do {
            let reward = try photoService.recordCapture(imageData: data, for: grow, species: catalog.species(id: grow.speciesID))
            withAnimation(.smooth(duration: 0.5)) {
                captureError = nil
                lastReward = reward
            }
            scheduleTomorrowReminder(for: grow)
            syncWidgetSnapshot(for: grow, streak: reward.streak)
            CaptureHaptics.reward()
        } catch {
            captureError = error.localizedDescription
        }
    }

    private func scheduleTomorrowReminder(for grow: Grow) {
        let species = catalog.species(id: grow.speciesID)
        Task { @MainActor in
            await notificationService.scheduleCaptureReminder(for: grow, species: species)
        }
    }

    private func syncWidgetSnapshot(for grow: Grow, streak: StreakUpdate) {
        widgetSyncService.sync(
            activeGrow: grow,
            species: catalog.species(id: grow.speciesID),
            streak: streak
        )
    }

    private func plantFirst() {
        let pick = catalog.beginnerPicks.first ?? catalog.species.first
        guard let pick else { return }
        let grow = store.createGrow(speciesID: pick.id, nickname: "", system: .kratky)
        widgetSyncService.sync(activeGrow: grow, species: pick, streak: streakService.snapshot())
    }
}

private struct CaptureWorkspace: View {
    let grow: Grow
    let species: PlantSpecies?
    let lastReward: CaptureReward?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isCapturing: Bool
    let captureError: String?
    var onCamera: () -> Void
    var onPrototypeCapture: () -> Void

    private var photos: [GrowPhoto] {
        (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    private var latestPhoto: GrowPhoto? {
        photos.last
    }

    private var currentProgress: Double {
        lastReward?.modeledProgressAfter
            ?? ModeledGrowthCurve.progress(dayIndex: max(1, photos.last?.dayIndex ?? grow.dayCount), species: species)
    }

    private var capturedFrameCount: Int {
        max(photos.count, lastReward?.frameCount ?? 0)
    }

    private var reelProgress: Double {
        lastReward?.futureReelProgress ?? min(1, Double(photos.count) / 30)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: GrowSpacing.md) {
                    captureStage
                    rewardPanel
                        .id(CaptureScrollTarget.reward)
                    FutureReelStrip(
                        photos: photos,
                        frameCount: capturedFrameCount,
                        progress: reelProgress,
                        isRewardActive: lastReward != nil
                    )
                    .id(CaptureScrollTarget.futureReel)
                    .padding(.top, 144)
                }
                .padding(.horizontal, GrowSpacing.lg)
                .padding(.top, GrowSpacing.lg)
                .padding(.bottom, 168)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 116)
            }
            .contentMargins(.bottom, 116, for: .scrollContent)
            .scrollIndicators(.hidden)
            .onChange(of: lastReward?.id) { _, rewardID in
                guard rewardID != nil else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    withAnimation(.smooth(duration: 0.62)) {
                        proxy.scrollTo(CaptureScrollTarget.reward, anchor: .center)
                    }
                }
            }
        }
        .task(id: grow.id) {
            await runLaunchRewardIfRequested()
        }
    }

    @MainActor
    private func runLaunchRewardIfRequested() async {
        #if DEBUG
        guard CommandLine.arguments.contains("-simulateCaptureReward") else { return }
        try? await Task.sleep(nanoseconds: 700_000_000)
        onPrototypeCapture()
        #endif
    }

    private var captureStage: some View {
        VStack(spacing: GrowSpacing.sm) {
            CaptureCompositionCard(
                currentProgress: currentProgress,
                stage: ModeledGrowthCurve.stage(for: currentProgress),
                latestThumbnailData: latestPhoto?.thumbnailData,
                frameCount: capturedFrameCount
            )

            CaptureActionDeck(
                selectedPhotoItem: $selectedPhotoItem,
                isCapturing: isCapturing,
                showSimulatorCapture: !CameraCaptureService.isCameraAvailable,
                onCamera: onCamera,
                onPrototypeCapture: onPrototypeCapture
            )

            if let captureError {
                Text(captureError)
                    .growStyle(GrowType.caption(.semibold), color: GrowPalette.needsCare)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Capture error: \(captureError)")
            }
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

private struct CaptureCompositionCard: View {
    let currentProgress: Double
    let stage: GrowStage
    let latestThumbnailData: Data?
    let frameCount: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                .fill(GrowPalette.surface.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                        .stroke(GrowPalette.separator.opacity(0.78), lineWidth: 1)
                )

            if let latestThumbnailData, let image = UIImage(data: latestThumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.12)
                    .saturation(0.42)
                    .blur(radius: 0.3)
                    .clipShape(RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
                    .accessibilityHidden(true)
            }

            GrowLightGlow(intensity: 0.38 + currentProgress * 0.34, size: 238)
                .offset(y: -28)

            SpecimenJar(
                progress: currentProgress,
                hasBloom: stage.hasBloom,
                size: 204
            )
            .offset(y: 8)

            CaptureFrameGuide()
                .padding(18)

            VStack {
                HStack(alignment: .top) {
                    CaptureHintPill(
                        icon: frameCount > 0 ? "scope" : "camera.metering.center.weighted",
                        text: frameCount > 0 ? "Match last angle" : "Frame the whole plant"
                    )
                    Spacer()
                    CaptureHintPill(icon: stage.systemImage, text: stage.displayName)
                }
                Spacer()
                HStack {
                    CaptureHintPill(icon: "leaf.fill", text: "\(Int(currentProgress * 100))% expected")
                    Spacer()
                }
            }
            .padding(GrowSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 292)
        .clipShape(RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capture composition preview")
    }
}

private struct CaptureHintPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(GrowType.caption(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .foregroundStyle(GrowPalette.sprout800)
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(GrowPalette.sprout50.opacity(0.86), in: Capsule())
        .overlay(
            Capsule()
                .stroke(GrowPalette.sprout300.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct CaptureActionDeck: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isCapturing: Bool
    let showSimulatorCapture: Bool
    var onCamera: () -> Void
    var onPrototypeCapture: () -> Void

    var body: some View {
        VStack(spacing: GrowSpacing.sm) {
            Button(action: onCamera) {
                Label(isCapturing ? "Saving..." : "Take frame", systemImage: "camera.fill")
                    .font(GrowType.headline())
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(GrowPalette.bloom)
            .disabled(isCapturing)
            .accessibilityLabel("Take today's frame")

            HStack(spacing: GrowSpacing.sm) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Import photo", systemImage: "photo.on.rectangle")
                        .font(GrowType.callout(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(GrowPalette.sprout600)
                .disabled(isCapturing)
                .accessibilityLabel("Import plant photo")

                if showSimulatorCapture {
                    Button(action: onPrototypeCapture) {
                        Label("Simulator", systemImage: "camera.aperture")
                            .font(GrowType.callout(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .tint(GrowPalette.sprout600)
                    .accessibilityLabel("Use simulator capture")
                }
            }
        }
    }
}

private struct CaptureFrameGuide: View {
    var body: some View {
        Canvas { context, size in
            let length: CGFloat = 28
            let radius: CGFloat = 18
            let rect = CGRect(origin: .zero, size: size)
            let corners: [(CGPoint, CGFloat, CGFloat)] = [
                (CGPoint(x: rect.minX, y: rect.minY), 0, 0),
                (CGPoint(x: rect.maxX, y: rect.minY), -length, 0),
                (CGPoint(x: rect.minX, y: rect.maxY), 0, -length),
                (CGPoint(x: rect.maxX, y: rect.maxY), -length, -length)
            ]

            var path = Path()
            for corner in corners {
                let origin = corner.0
                let xDirection: CGFloat = origin.x == rect.minX ? 1 : -1
                let yDirection: CGFloat = origin.y == rect.minY ? 1 : -1
                path.move(to: CGPoint(x: origin.x + xDirection * radius, y: origin.y))
                path.addLine(to: CGPoint(x: origin.x + xDirection * length, y: origin.y))
                path.move(to: CGPoint(x: origin.x, y: origin.y + yDirection * radius))
                path.addLine(to: CGPoint(x: origin.x, y: origin.y + yDirection * length))
            }

            context.stroke(
                path,
                with: .color(GrowPalette.sprout600.opacity(0.45)),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
            )
        }
        .allowsHitTesting(false)
    }
}

private enum CaptureScrollTarget: Hashable {
    case reward
    case futureReel
}

private struct RewardSequenceView: View {
    let reward: CaptureReward
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStage = 0

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
            .rewardStep(revealStage >= 1, reduceMotion: reduceMotion)

            GrowthMemoryCard(reward: reward, isActive: revealStage >= 2, reduceMotion: reduceMotion)
                .rewardStep(revealStage >= 2, reduceMotion: reduceMotion)

            HStack(spacing: GrowSpacing.md) {
                TwinAdvanceCard(
                    progressBefore: reward.modeledProgressBefore,
                    progressAfter: reward.modeledProgressAfter,
                    stage: reward.expectedStage,
                    isActive: revealStage >= 3
                )
                .rewardStep(revealStage >= 3, reduceMotion: reduceMotion)

                StreakCard(update: reward.streak, isActive: revealStage >= 4)
                    .rewardStep(revealStage >= 4, reduceMotion: reduceMotion)
            }

            if let firstWeekNote = reward.firstWeekNote {
                FirstWeekArcNote(dayIndex: reward.dayIndex, note: firstWeekNote)
                    .rewardStep(revealStage >= 5, reduceMotion: reduceMotion)
            }

            MicroRewardCard(moment: RewardMicroMoment(reward: reward))
                .rewardStep(revealStage >= 6, reduceMotion: reduceMotion)

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
                .rewardStep(revealStage >= 6, reduceMotion: reduceMotion)
            }
        }
        .sensoryFeedback(.impact, trigger: reward.id)
        .task(id: reward.id) {
            await playSequence()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Growth memory saved for \(reward.dayTitle)")
    }

    private func playSequence() async {
        if reduceMotion {
            revealStage = 6
            return
        }

        revealStage = 0
        for stage in 1...6 {
            try? await Task.sleep(nanoseconds: UInt64(stage == 1 ? 90_000_000 : 180_000_000))
            withAnimation(.smooth(duration: 0.34)) {
                revealStage = stage
            }
        }
    }
}

private struct GrowthMemoryCard: View {
    let reward: CaptureReward
    let isActive: Bool
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: GrowSpacing.md) {
            ZStack {
                Circle()
                    .fill(GrowPalette.sunGlow.opacity(isActive ? 0.32 : 0.16))
                    .frame(width: 84, height: 84)
                SpecimenJar(
                    progress: reward.modeledProgressAfter,
                    hasBloom: reward.expectedStage.hasBloom,
                    size: 76
                )
                .scaleEffect(isActive && !reduceMotion ? 1.06 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Saved to the timeline").fieldLabel(color: GrowPalette.sprout600)
                Text(reward.dayTitle)
                    .growStyle(GrowType.serifHeadline())
                Text(reward.capturedAt.formatted(date: .abbreviated, time: .omitted))
                    .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
            }

            Spacer(minLength: GrowSpacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(reward.frameCount)")
                    .growStyle(GrowType.numeral(36), color: GrowPalette.textPrimary)
                Text("frames").fieldLabel()
            }
        }
        .padding(GrowSpacing.md)
        .background(GrowPalette.surface.opacity(0.84), in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.78), lineWidth: 1)
        )
        .rotation3DEffect(
            .degrees(isActive || reduceMotion ? 0 : -8),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.7
        )
        .shadow(color: GrowPalette.sprout600.opacity(isActive ? 0.12 : 0), radius: 18, y: 8)
        .accessibilityElement(children: .combine)
    }
}

private struct FirstWeekArcNote: View {
    let dayIndex: Int
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: GrowSpacing.sm) {
            Image(systemName: dayIndex >= 7 ? "film.stack.fill" : "camera.metering.center.weighted")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(GrowPalette.sprout600)
                .frame(width: 28, height: 28)
                .background(GrowPalette.sprout50, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(dayIndex <= 7 ? "First-week frame" : "Frame note")
                    .fieldLabel(color: GrowPalette.sprout600)
                Text(note)
                    .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, GrowSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}

private struct RewardMicroMoment {
    let title: String
    let body: String
    let icon: String
    let tint: Color

    init(reward: CaptureReward) {
        switch reward.dayIndex {
        case 1:
            title = "Reel seed planted"
            body = "The before-frame is now anchored. Every future leaf has somewhere to return to."
            icon = "record.circle"
            tint = GrowPalette.bloom
        case 2:
            title = "Germination is mostly invisible"
            body = "Today is about roots, moisture, and patience. The twin moves so the habit has a pulse."
            icon = "water.waves"
            tint = GrowPalette.info
        case 3:
            title = "First streak marker"
            body = "Three steady frames is the first real signal that this grow has a rhythm."
            icon = "flame.fill"
            tint = GrowPalette.bloom
        case 5:
            title = "Ahead of the average beginner"
            body = "Most first grows lose consistency here. Five frames means your recap already has structure."
            icon = "chart.line.uptrend.xyaxis"
            tint = GrowPalette.sprout600
        case 7:
            title = "First-week recap ready"
            body = "Seven frames is enough to make the quiet first week feel like a story."
            icon = "film.stack.fill"
            tint = GrowPalette.bloom
        default:
            if reward.alignment.score >= 0.96 {
                title = "Frame locked"
                body = "That alignment will make the future time-lapse feel calmer and more cinematic."
                icon = "scope"
                tint = GrowPalette.sprout600
            } else {
                title = "Memory banked"
                body = "Even imperfect frames count. The reel gets stronger because the day was captured."
                icon = "checkmark.seal.fill"
                tint = GrowPalette.healthy
            }
        }
    }
}

private struct MicroRewardCard: View {
    let moment: RewardMicroMoment

    var body: some View {
        HStack(alignment: .top, spacing: GrowSpacing.sm) {
            Image(systemName: moment.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(moment.tint)
                .frame(width: 30, height: 30)
                .background(moment.tint.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(moment.title).fieldLabel(color: moment.tint)
                Text(moment.body)
                    .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(GrowSpacing.md)
        .background(moment.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous)
                .stroke(moment.tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
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
    var isActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            HStack {
                Text("Twin").fieldLabel()
                Spacer()
                Image(systemName: stage.systemImage)
                    .foregroundStyle(GrowPalette.sprout600)
                    .symbolEffect(.bounce, value: isActive)
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
    var isActive = false

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            HStack {
                Text("Streak").fieldLabel()
                Spacer()
                Image(systemName: update.spentFreezeToken ? "snowflake" : "flame.fill")
                    .foregroundStyle(update.spentFreezeToken ? GrowPalette.info : GrowPalette.bloom)
                    .symbolEffect(.pulse, value: isActive)
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
    let photos: [GrowPhoto]
    let frameCount: Int
    let progress: Double
    let isRewardActive: Bool

    private var previewFrames: [GrowPhoto] {
        Array(photos.suffix(8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Future reel").fieldLabel()
                    Text(reelStatusText)
                        .growStyle(GrowType.callout(.semibold), color: GrowPalette.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                }
                Spacer()
                Text("\(min(frameCount, 30))/30")
                    .growStyle(GrowType.callout(.semibold), color: GrowPalette.sprout600)
                    .monospacedDigit()
            }

            ProgressView(value: progress)
                .tint(GrowPalette.sprout500)

            ScrollView(.horizontal) {
                HStack(spacing: GrowSpacing.sm) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        ReelThumb(photo: previewFrames[safe: index], isFilled: index < previewFrames.count)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(GrowSpacing.md)
        .background(GrowPalette.surface.opacity(0.66), in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.7), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Future reel preview, \(min(frameCount, 30)) of 30 frames")
    }

    private var slotCount: Int {
        max(4, min(8, max(frameCount, previewFrames.count)))
    }

    private var reelStatusText: String {
        switch frameCount {
        case 0:
            "Frame 1 starts the reel."
        case 1..<7:
            "The first week is taking shape."
        case 7..<30:
            "\(30 - frameCount) frames until the first full reel."
        default:
            "Your first full reel is ready."
        }
    }
}

private struct ReelThumb: View {
    let photo: GrowPhoto?
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isFilled ? GrowPalette.sprout300.opacity(0.26) : GrowPalette.surface.opacity(0.72))

            if let photo,
               let data = photo.thumbnailData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .saturation(0.78)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if isFilled {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GrowPalette.sprout600)
            }
        }
        .frame(width: 68, height: 106)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(GrowPalette.separator, lineWidth: 1)
        )
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
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(label).fieldLabel(color: GrowPalette.sprout600)
                Text(message)
                    .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(GrowSpacing.sm)
        .background(GrowPalette.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
    }

    private var label: String {
        dayCount <= 7 ? "Day \(dayCount) · first week" : "Day \(dayCount)"
    }

    private var message: String {
        switch dayCount {
        case 1...2:
            "Nothing dramatic has to happen today. A steady before-frame is already valuable."
        case 3...7:
            "Tiny daily frames are how the first-week reveal gets built."
        default:
            "A new memory is ready for the reel."
        }
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

private struct PlantCameraView: View {
    let speciesName: String
    let frameCount: Int
    let latestThumbnailData: Data?
    let currentProgress: Double
    var onCapture: (Data) -> Void
    var onCancel: () -> Void

    @State private var camera = CameraCaptureService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.status.isReady || camera.status == .capturing {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .transition(.opacity)
            } else {
                cameraStatusView
                    .transition(.opacity)
            }

            if let latestThumbnailData, let image = UIImage(data: latestThumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.22)
                    .saturation(0.45)
                    .blendMode(.screen)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

            CameraGuideOverlay(progress: currentProgress, frameCount: frameCount, speciesName: speciesName)
                .padding(.horizontal, GrowSpacing.lg)
                .padding(.top, GrowSpacing.lg)
                .padding(.bottom, GrowSpacing.xl)

            VStack {
                HStack {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.34), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close camera")

                    Spacer()

                    CameraStatusPill(status: camera.status)
                }
                .padding(.horizontal, GrowSpacing.lg)
                .padding(.top, GrowSpacing.lg)

                Spacer()

                Button(action: capture) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.86), lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(camera.status == .capturing ? GrowPalette.bloom.opacity(0.72) : .white)
                            .frame(width: 62, height: 62)
                    }
                    .shadow(color: .black.opacity(0.32), radius: 14, y: 6)
                    .scaleEffect(camera.status == .capturing && !reduceMotion ? 0.92 : 1)
                }
                .buttonStyle(.plain)
                .disabled(!camera.canCapture)
                .accessibilityLabel("Capture frame")
                .padding(.bottom, 34)
            }
        }
        .task {
            camera.prepare()
        }
        .onDisappear {
            camera.stop()
        }
        .animation(.smooth(duration: 0.28), value: camera.status)
    }

    private var cameraStatusView: some View {
        VStack(spacing: GrowSpacing.md) {
            SpecimenJar(progress: currentProgress, size: 160)
                .opacity(0.9)

            VStack(spacing: GrowSpacing.xs) {
                Text(camera.status.message)
                    .font(GrowType.headline())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if camera.status == .denied {
                    Text("Import still works for today's reel.")
                        .growStyle(GrowType.callout(), color: .white.opacity(0.74))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, GrowSpacing.xl)
        }
    }

    private func capture() {
        camera.capturePhoto { result in
            if case .success(let data) = result {
                onCapture(data)
            }
        }
    }

    private func close() {
        onCancel()
        dismiss()
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewHostView {
        let view = PreviewHostView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewHostView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewHostView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private struct CameraGuideOverlay: View {
    let progress: Double
    let frameCount: Int
    let speciesName: String

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Frame \(frameCount)").fieldLabel(color: .white.opacity(0.72))
                    Text(speciesName)
                        .font(GrowType.headline())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer()
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.56), style: StrokeStyle(lineWidth: 1.5, dash: [10, 9]))

                VStack(spacing: GrowSpacing.xs) {
                    Image(systemName: "scope")
                        .font(.system(size: 22, weight: .semibold))
                    Text("Same angle")
                        .font(GrowType.caption(.semibold))
                }
                .foregroundStyle(.white.opacity(0.82))
                .padding(.vertical, GrowSpacing.sm)
                .padding(.horizontal, GrowSpacing.md)
                .background(.black.opacity(0.24), in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)

            Spacer()

            HStack(spacing: GrowSpacing.sm) {
                Image(systemName: ModeledGrowthCurve.stage(for: progress).systemImage)
                    .foregroundStyle(GrowPalette.bloom)
                ProgressView(value: progress)
                    .tint(GrowPalette.bloom)
                Text("\(Int(progress * 100))%")
                    .font(GrowType.caption(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(.vertical, GrowSpacing.sm)
            .padding(.horizontal, GrowSpacing.md)
            .background(.black.opacity(0.28), in: Capsule())
            .padding(.bottom, 124)
        }
        .allowsHitTesting(false)
    }
}

private struct CameraStatusPill: View {
    let status: CameraCaptureStatus

    var body: some View {
        HStack(spacing: GrowSpacing.xs) {
            Circle()
                .fill(status.isReady ? GrowPalette.healthy : GrowPalette.bloom)
                .frame(width: 8, height: 8)
            Text(label)
                .font(GrowType.caption(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.black.opacity(0.34), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera status: \(label)")
    }

    private var label: String {
        switch status {
        case .ready:
            "Ready"
        case .capturing:
            "Saving"
        case .denied:
            "No access"
        case .unavailable:
            "No camera"
        case .failed:
            "Check camera"
        case .idle, .requestingAccess, .configuring:
            "Opening"
        }
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

private extension View {
    func rewardStep(_ isVisible: Bool, reduceMotion: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 12)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
            .animation(.smooth(duration: reduceMotion ? 0.01 : 0.34), value: isVisible)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
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
