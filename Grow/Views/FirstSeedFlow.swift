import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct FirstSeedFlow: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(GrowStore.self) private var store
    @Environment(PhotoService.self) private var photoService
    @Environment(NotificationService.self) private var notificationService
    @Environment(WidgetSyncService.self) private var widgetSyncService
    @Query(
        filter: #Predicate<Grow> { $0.isActive && $0.archivedDate == nil },
        sort: \Grow.startDate, order: .reverse
    ) private var activeGrows: [Grow]

    let initialStep: OnboardingStep
    var onCompleted: () -> Void

    @State private var didApplyInitialStep = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isSavingCapture = false

    var body: some View {
        ZStack {
            PaperBackground(light: 0.76)

            switch coordinator.step {
            case .promise:
                FirstSeedPromiseView(
                    onBegin: coordinator.begin,
                    onSample: coordinator.showSample
                )
            case .crop:
                FirstSeedCropView(
                    species: launchSpecies,
                    selectedID: coordinator.selectedSpeciesID,
                    onSelect: coordinator.selectSpecies,
                    onContinue: coordinator.advanceFromCrop,
                    onChooseForMe: {
                        coordinator.selectSpecies(OnboardingPolicy.defaultSpeciesID)
                        coordinator.advanceFromCrop()
                    },
                    onBack: coordinator.goBack
                )
            case .setup:
                FirstSeedSetupView(
                    selected: coordinator.selectedSetup,
                    errorMessage: coordinator.errorMessage,
                    onSelect: coordinator.selectSetup,
                    onStart: createGrow,
                    onBack: coordinator.goBack
                )
            case .sample:
                FirstSeedSampleView(
                    onStart: coordinator.leaveSample,
                    onBack: coordinator.leaveSample
                )
            case .capture:
                FirstSeedCaptureBeat(
                    speciesName: speciesName,
                    selectedPhotoItem: $selectedPhotoItem,
                    isSaving: isSavingCapture,
                    errorMessage: coordinator.errorMessage,
                    hasGrow: activeGrow != nil,
                    showSimulatorCapture: !CameraCaptureService.isCameraAvailableForInterface,
                    onCamera: { isShowingCamera = true },
                    onPrototypeCapture: capturePrototype,
                    onRetry: {
                        coordinator.retryCapture()
                        if CameraCaptureService.isCameraAvailable {
                            isShowingCamera = true
                        }
                    },
                    onBack: coordinator.goBack
                )
            case .reward:
                rewardBeat
            }
        }
        .task {
            guard !didApplyInitialStep else { return }
            didApplyInitialStep = true
            coordinator.start(at: initialStep)
            if let activeGrow, (initialStep == .capture || initialStep == .reward) {
                coordinator.didCreateGrow(id: activeGrow.id)
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item, let grow = activeGrow else { return }
            Task { await importPhoto(item, for: grow) }
        }
        .sheet(isPresented: $isShowingCamera) {
            if let grow = activeGrow {
                GuidedPlantCameraView(
                    configuration: .dayOne(speciesName: speciesName),
                    onCapture: { data in
                        isShowingCamera = false
                        recordImageData(data, for: grow)
                    },
                    onCancel: { isShowingCamera = false },
                    onFailure: { message in
                        isShowingCamera = false
                        coordinator.captureFailed(message: captureFailureCopy(message))
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    private var launchSpecies: [PlantSpecies] {
        OnboardingPolicy.launchSpeciesIDs.compactMap { catalog.species(id: $0) }
    }

    private var activeGrow: Grow? {
        if let id = coordinator.createdGrowID {
            return activeGrows.first { $0.id == id }
        }
        return activeGrows.first
    }

    private var speciesName: String {
        guard let grow = activeGrow else {
            return catalog.species(id: coordinator.selectedSpeciesID)?.commonName ?? "Basil"
        }
        return catalog.species(id: grow.speciesID)?.commonName ?? "Plant"
    }

    @ViewBuilder
    private var rewardBeat: some View {
        if let reward = coordinator.reward {
            FirstSeedRewardBeat(
                reward: reward,
                thumbnailData: capturedThumbnailData(reward: reward),
                speciesName: speciesName,
                onComplete: completeCeremony
            )
        } else {
            FirstSeedTransitionView(
                label: "GROWTH MEMORY",
                title: "Your first frame is waiting.",
                message: "Capture or import one photo to begin the story.",
                actionTitle: "Return to capture",
                action: coordinator.retryCapture
            )
        }
    }

    private func createGrow() {
        coordinator.confirmSetup()
        guard let request = coordinator.pendingGrowRequest else { return }

        do {
            let grow = try store.createGrow(
                speciesID: request.speciesID,
                nickname: "",
                system: request.system
            )
            coordinator.errorMessage = nil
            coordinator.didCreateGrow(id: grow.id)
        } catch {
            coordinator.start(at: .setup)
            coordinator.errorMessage = error.localizedDescription
        }
    }

    private func importPhoto(_ item: PhotosPickerItem, for grow: Grow) async {
        isSavingCapture = true
        defer {
            isSavingCapture = false
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoServiceError.unreadableImage
            }
            recordImageData(data, for: grow)
        } catch {
            coordinator.captureFailed(message: captureFailureCopy(error.localizedDescription))
        }
    }

    private func recordImageData(_ data: Data, for grow: Grow) {
        do {
            let reward = try photoService.recordCapture(
                imageData: data,
                for: grow,
                species: catalog.species(id: grow.speciesID)
            )
            finishCapture(reward, grow: grow)
        } catch {
            coordinator.captureFailed(message: captureFailureCopy(error.localizedDescription))
        }
    }

    private func capturePrototype() {
        guard let grow = activeGrow else {
            coordinator.captureFailed(message: "Your grow is still being prepared. Return to setup and try again.")
            return
        }
        let reward = photoService.recordPrototypeCapture(
            for: grow,
            species: catalog.species(id: grow.speciesID)
        )
        finishCapture(reward, grow: grow)
    }

    private func finishCapture(_ reward: CaptureReward, grow: Grow) {
        withAnimation(.smooth(duration: 0.5)) {
            coordinator.didCapture(reward)
        }
        widgetSyncService.sync(
            activeGrow: grow,
            species: catalog.species(id: grow.speciesID),
            streak: reward.streak
        )
        Task { @MainActor in
            await notificationService.scheduleCaptureReminder(
                for: grow,
                species: catalog.species(id: grow.speciesID)
            )
        }
        CaptureHaptics.reward()
    }

    private func capturedThumbnailData(reward: CaptureReward) -> Data? {
        activeGrow?.photos?.first { $0.id == reward.photoID }?.thumbnailData
    }

    private func completeCeremony() {
        guard coordinator.complete() else { return }
        onCompleted()
    }

    private func captureFailureCopy(_ detail: String) -> String {
        "That frame could not be saved. Try again or import a photo. \(detail)"
    }
}

private struct FirstSeedCaptureBeat: View {
    let speciesName: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let isSaving: Bool
    let errorMessage: String?
    let hasGrow: Bool
    let showSimulatorCapture: Bool
    var onCamera: () -> Void
    var onPrototypeCapture: () -> Void
    var onRetry: () -> Void
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GrowSpacing.lg) {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .frame(minHeight: GrowSpacing.touchTargetMin)
                }
                .buttonStyle(.plain)
                .foregroundStyle(GrowPalette.textPrimary)

                VStack(alignment: .leading, spacing: GrowSpacing.sm) {
                    Text("FIELD NOTE · 001").fieldLabel()
                    Text("Make this\nthe before.")
                        .growStyle(GrowType.displayTitle())
                    Text("One steady photo gives every future leaf somewhere to begin.")
                        .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                        .fill(GrowPalette.groundRaised.opacity(0.72))
                    GrowLightGlow(intensity: 0.54, size: 230)
                    SpecimenJar(progress: 0.06, size: 216)
                    CaptureFrameGuide()
                        .padding(GrowSpacing.lg)
                }
                .frame(height: 286)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Day 1 frame guide for \(speciesName)")

                if let errorMessage {
                    VStack(alignment: .leading, spacing: GrowSpacing.sm) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(GrowType.callout())
                            .foregroundStyle(GrowPalette.needsCare)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Try camera again", action: onRetry)
                            .font(GrowType.callout(.semibold))
                            .foregroundStyle(GrowPalette.textPrimary)
                            .frame(minHeight: GrowSpacing.touchTargetMin)
                    }
                }

                VStack(spacing: GrowSpacing.sm) {
                    if showSimulatorCapture {
                        FirstSeedPrimaryButton(
                            title: isSaving ? "Saving frame…" : "Save simulator frame",
                            systemImage: "camera.aperture",
                            action: onPrototypeCapture
                        )
                        .disabled(isSaving || !hasGrow)
                        .accessibilityLabel("Use simulator capture")
                    } else {
                        FirstSeedPrimaryButton(
                            title: isSaving ? "Saving frame…" : "Take first frame",
                            systemImage: "camera.fill",
                            action: onCamera
                        )
                        .disabled(isSaving || !hasGrow)
                        .accessibilityLabel("Take Day 1 frame")
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Import a photo", systemImage: "photo.on.rectangle")
                            .font(GrowType.callout(.semibold))
                            .foregroundStyle(GrowPalette.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: GrowSpacing.touchTargetMin)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || !hasGrow)
                    .accessibilityLabel("Import Day 1 plant photo")

                    if isSaving {
                        ProgressView("Saving growth memory")
                            .tint(GrowPalette.sprout600)
                    }
                }
            }
            .padding(GrowSpacing.lg)
        }
    }
}

private struct FirstSeedRewardBeat: View {
    let reward: CaptureReward
    let thumbnailData: Data?
    let speciesName: String
    var onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GrowSpacing.lg) {
                VStack(alignment: .leading, spacing: GrowSpacing.sm) {
                    Text("GROWTH MEMORY · DAY 1").fieldLabel(color: GrowPalette.sprout600)
                    Text("Growth memory\nsaved.")
                        .growStyle(GrowType.displayTitle())
                    Text("This is the before. The story gets more rewarding from here.")
                        .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
                }

                capturedFrame

                CaptureRewardSequenceView(reward: reward)
            }
            .padding(GrowSpacing.lg)
            .padding(.bottom, 88)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FirstSeedPrimaryButton(
                title: "Meet your \(speciesName.lowercased())",
                systemImage: "sparkles",
                color: GrowPalette.bloom,
                ink: GrowPalette.bloomInk,
                action: onComplete
            )
            .accessibilityHint("Finishes setup and opens Today")
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.vertical, GrowSpacing.sm)
            .background(.bar)
        }
    }

    @ViewBuilder
    private var capturedFrame: some View {
        if let thumbnailData, let image = UIImage(data: thumbnailData) {
            HStack(spacing: GrowSpacing.md) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 116, height: 206)
                    .clipShape(RoundedRectangle(cornerRadius: GrowRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: GrowSpacing.sm) {
                    Text("THE BEFORE").fieldLabel(color: GrowPalette.sprout600)
                    Text("Frame 01")
                        .growStyle(GrowType.displayHeadline())
                    Text("The first true reference point for every leaf that follows.")
                        .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                    Spacer(minLength: 0)
                    Label("Saved", systemImage: "checkmark.seal.fill")
                        .font(GrowType.callout(.semibold))
                        .foregroundStyle(GrowPalette.sprout600)
                }
                .padding(.vertical, GrowSpacing.sm)
            }
            .padding(GrowSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GrowPalette.groundRaised, in: RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                    .stroke(GrowPalette.separator.opacity(0.72), lineWidth: 1)
            }
                .accessibilityLabel("Saved Day 1 photo of \(speciesName)")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: GrowRadius.lg, style: .continuous)
                    .fill(GrowPalette.groundRaised)
                SpecimenJar(progress: reward.modeledProgressAfter, size: 170)
                Text("FRAME 01 · SAVED")
                    .fieldLabel(color: GrowPalette.sprout600)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(GrowSpacing.md)
            }
            .frame(height: 210)
            .accessibilityLabel("Saved Day 1 growth memory for \(speciesName)")
        }
    }
}

struct FirstSeedPrimaryButton: View {
    let title: String
    var systemImage: String?
    var color: Color = GrowPalette.sprout500
    var ink: Color = .white
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: GrowSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(GrowType.headline())
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: FirstSeedVisualContract.primaryActionHeight)
            .background(color, in: Capsule())
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

private struct FirstSeedTransitionView: View {
    let label: String
    let title: String
    let message: String
    let actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.lg) {
            Spacer()
            Text(label).fieldLabel()
            Text(title).growStyle(GrowType.displayTitle())
            Text(message).growStyle(GrowType.body(), color: GrowPalette.textSecondary)
            Spacer()
            FirstSeedPrimaryButton(title: actionTitle, action: action)
        }
        .padding(GrowSpacing.lg)
    }
}

private struct FirstSeedSampleView: View {
    var onStart: () -> Void
    var onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GrowSpacing.lg) {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                        .frame(minHeight: GrowSpacing.touchTargetMin)
                }
                .buttonStyle(.plain)
                .foregroundStyle(GrowPalette.textPrimary)

                Text("SAMPLE FIELD NOTE").fieldLabel()
                Text("Seven days with basil.")
                    .growStyle(GrowType.displayTitle())

                HStack {
                    Spacer()
                    SpecimenJar(progress: 0.28, size: 230)
                        .accessibilityLabel("Sample basil on Day 7")
                    Spacer()
                }

                HStack(spacing: 0) {
                    ForEach(1...7, id: \.self) { day in
                        VStack(spacing: GrowSpacing.xs) {
                            Circle()
                                .fill(day == 7 ? GrowPalette.sprout500 : GrowPalette.sprout100)
                                .frame(width: 12, height: 12)
                            Text("D\(day)")
                                .font(GrowType.caption())
                                .foregroundStyle(GrowPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sample timeline, seven daily frames")

                Hairline()
                Text("Seven small frames become the beginning of a reel.")
                    .growStyle(GrowType.body(), color: GrowPalette.textSecondary)

                FirstSeedPrimaryButton(
                    title: "Start my own grow",
                    systemImage: "leaf.fill",
                    action: onStart
                )
            }
            .padding(GrowSpacing.lg)
        }
    }
}
