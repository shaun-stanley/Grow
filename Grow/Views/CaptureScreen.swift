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

                if let thumbnailData = latestPhoto?.thumbnailData, let image = UIImage(data: thumbnailData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .opacity(0.18)
                        .saturation(0.55)
                        .clipShape(RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
                        .padding(GrowSpacing.lg)
                        .accessibilityHidden(true)
                }

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

            HStack(spacing: GrowSpacing.sm) {
                Button(action: onCamera) {
                    HStack(spacing: GrowSpacing.sm) {
                        Image(systemName: "camera.fill")
                        Text(isCapturing ? "Saving..." : "Take frame")
                    }
                    .font(GrowType.headline())
                    .foregroundStyle(GrowPalette.bloomInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(GrowPalette.bloom, in: Capsule())
                    .shadow(color: GrowPalette.bloom.opacity(0.28), radius: 14, y: 7)
                }
                .buttonStyle(.plain)
                .disabled(isCapturing)
                .accessibilityLabel("Take today's frame")

                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout800)
                        .frame(width: 54, height: 52)
                        .background(GrowPalette.sprout100, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isCapturing)
                .accessibilityLabel("Import plant photo")
            }

            if !CameraCaptureService.isCameraAvailable {
                Button(action: onPrototypeCapture) {
                    HStack(spacing: GrowSpacing.xs) {
                        Image(systemName: "camera.aperture")
                            .foregroundStyle(GrowPalette.sprout600)
                        Text("Use simulator capture")
                            .growStyle(GrowType.callout(.semibold), color: GrowPalette.sprout600)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(GrowPalette.sprout50.opacity(0.82), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Use simulator capture")
            }

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

            if let firstWeekNote = reward.firstWeekNote {
                FirstWeekArcNote(dayIndex: reward.dayIndex, note: firstWeekNote)
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
                Text(label).fieldLabel(color: GrowPalette.sprout600)
                Text(message)
                    .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(GrowSpacing.md)
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

private enum CaptureHaptics {
    static func reward() {
        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
        #endif
    }
}
