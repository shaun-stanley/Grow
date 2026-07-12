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
    @State private var creationError: String?

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
        .alert("Couldn’t start your grow", isPresented: creationErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(creationError ?? "Please try again.")
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item, let grow = grows.first else { return }
            Task { await importPhoto(item, for: grow) }
        }
        .sheet(isPresented: $isShowingCamera) {
            if let grow = grows.first {
                GuidedPlantCameraView(
                    configuration: .daily(
                        speciesName: catalog.species(id: grow.speciesID)?.commonName ?? "Plant",
                        frameCount: (grow.photos ?? []).count + 1,
                        ghostThumbnailData: (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }.last?.thumbnailData,
                        progress: ModeledGrowthCurve.progress(
                            dayIndex: max(1, grow.dayCount),
                            species: catalog.species(id: grow.speciesID)
                        )
                    ),
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

    private var creationErrorBinding: Binding<Bool> {
        Binding(
            get: { creationError != nil },
            set: { if !$0 { creationError = nil } }
        )
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
        do {
            let grow = try store.createGrow(speciesID: pick.id, nickname: "", system: .kratky)
            creationError = nil
            widgetSyncService.sync(activeGrow: grow, species: pick, streak: streakService.snapshot())
        } catch {
            creationError = error.localizedDescription
        }
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

                    if lastReward != nil {
                        Color.clear
                            .frame(height: CaptureRewardVisualContract.rewardScrollLeadIn)
                            .id(CaptureScrollTarget.reward)
                    }

                    rewardPanel
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
                    try? await Task.sleep(nanoseconds: 620_000_000)
                    withAnimation(.smooth(duration: 0.62)) {
                        proxy.scrollTo(CaptureScrollTarget.reward, anchor: .top)
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
            CaptureRewardSequenceView(reward: reward)
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

struct CaptureFrameGuide: View {
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

struct CaptureRewardSequenceContent: View {
    let reward: CaptureReward
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealStage = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            receiptHeader
                .rewardStep(revealStage >= 1, reduceMotion: reduceMotion)

            ReceiptDivider()
                .padding(.vertical, CaptureRewardVisualContract.sectionSpacing)

            GrowthMemoryCard(reward: reward, isActive: revealStage >= 2, reduceMotion: reduceMotion)
                .rewardStep(revealStage >= 2, reduceMotion: reduceMotion)

            ReceiptDivider()
                .padding(.vertical, CaptureRewardVisualContract.sectionSpacing)

            metricGrid

            if let firstWeekNote = reward.firstWeekNote {
                ReceiptDivider()
                    .padding(.vertical, CaptureRewardVisualContract.sectionSpacing)
                FirstWeekArcNote(dayIndex: reward.dayIndex, note: firstWeekNote)
                    .rewardStep(revealStage >= 5, reduceMotion: reduceMotion)
            }

            ReceiptDivider()
                .padding(.vertical, CaptureRewardVisualContract.sectionSpacing)
            MicroRewardCard(moment: RewardMicroMoment(reward: reward))
                .rewardStep(revealStage >= 6, reduceMotion: reduceMotion)

            if let milestone = reward.milestoneTitle {
                ReceiptDivider()
                    .padding(.vertical, CaptureRewardVisualContract.sectionSpacing)
                MilestoneReceiptRow(title: milestone)
                    .rewardStep(revealStage >= 6, reduceMotion: reduceMotion)
            }
        }
        .padding(CaptureRewardVisualContract.receiptPadding)
        .background(GrowPalette.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.82), lineWidth: 1)
        )
        .sensoryFeedback(.impact, trigger: reward.id)
        .task(id: reward.id) {
            await playSequence()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Growth memory saved for \(reward.dayTitle)")
    }

    private var receiptHeader: some View {
        HStack(alignment: .top, spacing: GrowSpacing.md) {
            ReceiptHeaderMetric(
                label: "Memory saved",
                value: reward.dayTitle,
                detail: "Frame \(reward.frameCount) saved",
                tint: GrowPalette.sprout600
            )

            ReceiptHeaderMetric(
                label: reward.alignment.sourceLabel,
                value: "\(reward.alignment.percent)%",
                suffix: reward.alignment.adjective,
                detail: reward.alignment.guidanceCopy,
                tint: GrowPalette.sprout600,
                isTrailing: true
            )
        }
        .frame(minHeight: CaptureRewardVisualContract.receiptHeaderMinHeight, alignment: .top)
    }

    private var metricGrid: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: GrowSpacing.sm) {
                twinCard
                streakCard
            }

            VStack(spacing: GrowSpacing.sm) {
                twinCard
                streakCard
            }
        }
    }

    private var twinCard: some View {
        TwinAdvanceCard(
            progressBefore: reward.modeledProgressBefore,
            progressAfter: reward.modeledProgressAfter,
            stage: reward.expectedStage,
            isActive: revealStage >= 3
        )
        .rewardStep(revealStage >= 3, reduceMotion: reduceMotion)
    }

    private var streakCard: some View {
        StreakCard(update: reward.streak, isActive: revealStage >= 4)
            .rewardStep(revealStage >= 4, reduceMotion: reduceMotion)
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(GrowPalette.groundRaised.opacity(isActive ? 0.7 : 0.48))
                    .frame(width: 74, height: 74)
                SpecimenJar(
                    progress: reward.modeledProgressAfter,
                    hasBloom: reward.expectedStage.hasBloom,
                    size: 66
                )
                .scaleEffect(isActive && !reduceMotion ? 1.06 : 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline saved")
                    .fieldLabel(color: GrowPalette.sprout600)
                    .lineLimit(1)
                Text(reward.dayTitle)
                    .growStyle(GrowType.displayHeadline())
                Text(reward.capturedAt.formatted(date: .abbreviated, time: .omitted))
                    .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
            }

            Spacer(minLength: GrowSpacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(reward.frameCount)")
                    .growStyle(GrowType.numeral(34), color: GrowPalette.textPrimary)
                Text(reward.frameCount == 1 ? "frame" : "frames").fieldLabel()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct FirstWeekArcNote: View {
    let dayIndex: Int
    let note: String

    var body: some View {
        ReceiptInfoRow(
            icon: dayIndex >= 7 ? "film.stack.fill" : "camera.metering.center.weighted",
            title: dayIndex <= 7 ? "First-week frame" : "Frame note",
            body: note,
            tint: GrowPalette.sprout600
        )
    }
}

private struct RewardMicroMoment {
    let title: String
    let body: String
    let icon: String
    let tint: Color

    init(reward: CaptureReward) {
        let moment = CaptureRewardPolicy.microMoment(for: reward)
        title = moment.title
        body = moment.body
        icon = moment.icon
        tint = moment.tintRole.color
    }
}

private struct MicroRewardCard: View {
    let moment: RewardMicroMoment

    var body: some View {
        ReceiptInfoRow(
            icon: moment.icon,
            title: moment.title,
            body: moment.body,
            tint: moment.tint
        )
    }
}

private struct AlignmentBadge: View {
    let alignment: CaptureAlignment

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(alignment.percent)%")
                    .growStyle(GrowType.numeral(32), color: GrowPalette.sprout600)
                Text(alignment.adjective)
                    .fieldLabel()
            }

            Text(alignment.sourceLabel)
                .fieldLabel(color: GrowPalette.textSecondary)
            Text(alignment.guidanceCopy)
                .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: 148, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alignment \(alignment.percent) percent, \(alignment.adjective). \(alignment.guidanceCopy).")
    }
}

private struct ReceiptHeaderMetric: View {
    let label: String
    let value: String
    var suffix: String?
    let detail: String
    let tint: Color
    var isTrailing = false

    private var horizontalAlignment: HorizontalAlignment {
        isTrailing ? .trailing : .leading
    }

    private var frameAlignment: Alignment {
        isTrailing ? .topTrailing : .topLeading
    }

    private var textAlignment: TextAlignment {
        isTrailing ? .trailing : .leading
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 5) {
            Text(label)
                .fieldLabel(color: tint)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .growStyle(GrowType.receiptValue(), color: isTrailing ? GrowPalette.sprout600 : GrowPalette.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                if let suffix {
                    Text(suffix)
                        .fieldLabel()
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: isTrailing ? .trailing : .leading)

            Text(detail)
                .growStyle(GrowType.caption(.semibold), color: GrowPalette.textSecondary)
                .multilineTextAlignment(textAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity, minHeight: CaptureRewardVisualContract.receiptHeaderMinHeight, alignment: frameAlignment)
        .accessibilityElement(children: .combine)
    }
}

private struct TwinAdvanceCard: View {
    let progressBefore: Double
    let progressAfter: Double
    let stage: GrowStage
    var isActive = false

    var body: some View {
        RewardMetricCell(
            title: "Twin",
            icon: stage.systemImage,
            tint: GrowPalette.sprout600,
            value: "+\(Int(max(0, progressAfter - progressBefore) * 100))%",
            valueSuffix: "expected",
            progress: progressAfter,
            caption: "Modeled growth"
        )
    }
}

private struct StreakCard: View {
    let update: StreakUpdate
    var isActive = false

    var body: some View {
        RewardMetricCell(
            title: "Streak",
            icon: update.spentFreezeToken ? "snowflake" : "flame.fill",
            tint: update.spentFreezeToken ? GrowPalette.info : GrowPalette.bloom,
            value: "\(update.current)",
            valueSuffix: "days",
            progress: update.milestoneProgress,
            caption: update.milestoneCopy
        )
    }
}

private struct RewardMetricCell: View {
    let title: String
    let icon: String
    let tint: Color
    let value: String
    let valueSuffix: String
    let progress: Double
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            HStack(alignment: .center, spacing: GrowSpacing.xs) {
                Text(title)
                    .fieldLabel()
                Spacer(minLength: GrowSpacing.xs)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: CaptureRewardVisualContract.metricCellIconSize, height: CaptureRewardVisualContract.metricCellIconSize)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .growStyle(GrowType.receiptValue(32), color: GrowPalette.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: CaptureRewardVisualContract.metricValueLineHeight, alignment: .bottomLeading)
                Text(valueSuffix)
                    .growStyle(GrowType.caption(.semibold), color: GrowPalette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ProgressView(value: progress)
                .tint(tint)

            Text(caption)
                .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: CaptureRewardVisualContract.metricCellMinHeight, alignment: .leading)
        .padding(CaptureRewardVisualContract.metricCellPadding)
        .background(GrowPalette.groundRaised.opacity(0.44), in: RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.68), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct ReceiptInfoRow: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    init(icon: String, title: String, body: String, tint: Color) {
        self.icon = icon
        self.title = title
        self.message = body
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .top, spacing: GrowSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: CaptureRewardVisualContract.metricCellIconSize, height: CaptureRewardVisualContract.metricCellIconSize)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fieldLabel(color: tint)
                Text(message)
                    .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct MilestoneReceiptRow: View {
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: GrowSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GrowPalette.bloom)
                .frame(width: CaptureRewardVisualContract.metricCellIconSize, height: CaptureRewardVisualContract.metricCellIconSize)
            Text(title)
                .growStyle(GrowType.callout(.semibold), color: GrowPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReceiptDivider: View {
    var body: some View {
        Hairline(color: GrowPalette.separator.opacity(0.72))
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

struct GuidedPlantCameraContent: View {
    let configuration: GuidedPlantCameraConfiguration
    var onCapture: (Data) -> Void
    var onCancel: () -> Void
    var onFailure: (String) -> Void = { _ in }

    @State private var camera = CameraCaptureService()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
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

            if let ghostThumbnailData = configuration.ghostThumbnailData,
               let image = UIImage(data: ghostThumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(camera.status.isReady ? 0.3 : 0.2)
                    .saturation(0.45)
                    .blendMode(.screen)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

            CameraGuideOverlay(
                title: configuration.title,
                guidance: configuration.guidance,
                progress: configuration.currentProgress,
                speciesName: configuration.speciesName,
                hasGhostGuide: configuration.ghostThumbnailData != nil
            )
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

                CameraConfidenceHUD(camera: camera)
                    .padding(.horizontal, GrowSpacing.lg)
                    .padding(.bottom, GrowSpacing.sm)

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
            SpecimenJar(progress: configuration.currentProgress, size: 160)
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

                    VStack(spacing: GrowSpacing.sm) {
                        Button("Open Camera Settings") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(GrowPalette.sprout500)
                        .frame(minHeight: GrowSpacing.touchTargetMin)

                        Button("Import a photo instead", action: close)
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                            .frame(minHeight: GrowSpacing.touchTargetMin)
                    }
                    .padding(.top, GrowSpacing.sm)
                }
            }
            .padding(.horizontal, GrowSpacing.xl)
        }
    }

    private func capture() {
        camera.capturePhoto { result in
            switch result {
            case .success(let data):
                onCapture(data)
            case .failure(let error):
                onFailure(error.localizedDescription)
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
    let title: String
    let guidance: String
    let progress: Double
    let speciesName: String
    let hasGhostGuide: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fieldLabel(color: .white.opacity(0.72))
                    Text(speciesName)
                        .font(GrowType.headline())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer()
            }
            .padding(.leading, FirstSeedVisualContract.cameraHeaderLeadingClearance)
            .padding(.trailing, FirstSeedVisualContract.cameraHeaderTrailingClearance)

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.56), style: StrokeStyle(lineWidth: 1.5, dash: [10, 9]))

                VStack(spacing: GrowSpacing.xs) {
                    Image(systemName: "scope")
                        .font(.system(size: 22, weight: .semibold))
                    Text(guidance)
                        .font(GrowType.caption(.semibold))
                    if hasGhostGuide {
                        Text("Ghost guide on")
                            .font(GrowType.caption())
                            .foregroundStyle(.white.opacity(0.68))
                    }
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

private struct CameraConfidenceHUD: View {
    let camera: CameraCaptureService

    var body: some View {
        HStack(spacing: GrowSpacing.sm) {
            if camera.supportsZoom {
                CameraZoomControl(camera: camera)
            }

            if camera.supportsFocusExposureLock {
                Button {
                    camera.toggleFocusExposureLock()
                } label: {
                    Image(systemName: camera.isFocusExposureLocked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(.black.opacity(0.34), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(camera.isFocusExposureLocked ? "Unlock focus and exposure" : "Lock focus and exposure")
            }

            if !camera.supportsZoom && !camera.supportsFocusExposureLock {
                CameraSteadyCue()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CameraZoomControl: View {
    let camera: CameraCaptureService

    var body: some View {
        HStack(spacing: GrowSpacing.xs) {
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Slider(
                value: Binding(
                    get: { camera.zoomFactor },
                    set: { camera.setZoomFactor($0) }
                ),
                in: camera.minZoomFactor...camera.maxZoomFactor
            )
            .tint(GrowPalette.bloom)

            Text("\(camera.zoomFactor, specifier: "%.1f")x")
                .font(GrowType.caption(.semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(maxWidth: 260)
        .background(.black.opacity(0.34), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Zoom \(camera.zoomFactor, specifier: "%.1f") times"))
    }
}

private struct CameraSteadyCue: View {
    var body: some View {
        HStack(spacing: GrowSpacing.xs) {
            Image(systemName: "camera.metering.center.weighted")
                .font(.system(size: 15, weight: .semibold))
            Text("Hold steady")
                .font(GrowType.caption(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.vertical, 10)
        .padding(.horizontal, 13)
        .background(.black.opacity(0.28), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hold steady")
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
                    .growStyle(GrowType.displayTitle())
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

enum CaptureHaptics {
    static func reward() {
        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
        #endif
    }
}
