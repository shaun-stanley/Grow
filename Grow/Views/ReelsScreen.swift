import SwiftData
import SwiftUI
import UIKit

struct ReelsScreen: View {
    @Environment(PlantCatalogService.self) private var catalog
    @Environment(ReelRenderingService.self) private var reelRenderingService
    @Query(
        filter: #Predicate<Grow> { $0.isActive && $0.archivedDate == nil },
        sort: \Grow.startDate,
        order: .reverse
    ) private var grows: [Grow]

    var body: some View {
        ZStack {
            PaperBackground(light: 0.48)
            if let grow = grows.first {
                ReelStudio(grow: grow, species: catalog.species(id: grow.speciesID))
                    .environment(reelRenderingService)
            } else {
                FirstReelEmptyState()
            }
        }
    }
}

private struct ReelStudio: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(ReelRenderingService.self) private var reelRenderingService
    let grow: Grow
    let species: PlantSpecies?

    private var photos: [GrowPhoto] {
        (grow.photos ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    private var reels: [Reel] {
        (grow.reels ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    private var latestShareURL: URL? {
        if let result = reelRenderingService.lastResult,
           let url = ReelStudioPolicy.shareURL(
               localFileName: result.localFileName,
               containerURL: AppGroup.containerURL
           ) {
            return url
        }

        guard let latestReel = reels.first else { return nil }
        return ReelStudioPolicy.shareURL(
            localFileName: latestReel.localFileName,
            containerURL: AppGroup.containerURL
        )
    }

    private var status: ReelStudioStatus {
        ReelStudioPolicy.status(
            frameCount: photos.count,
            isRendering: reelRenderingService.isRendering,
            renderedFrameCount: reelRenderingService.lastResult?.frameCount,
            renderedDurationSeconds: reelRenderingService.lastResult?.durationSeconds,
            errorMessage: reelRenderingService.lastErrorMessage
        )
    }

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: contentSpacing
            ) {
                masthead
                    .growEntrance(0)

                ReelPosterPreview(
                    grow: grow,
                    species: species,
                    latestPhoto: photos.last,
                    frameCount: photos.count
                )
                .frame(maxWidth: previewMaxWidth)
                .frame(maxWidth: .infinity)
                .growEntrance(1)

                ReelReadinessStrip(
                    latestDay: photos.last?.dayIndex ?? grow.dayCount,
                    frameCount: photos.count,
                    isCompact: isAccessibilityLayout
                )
                .growEntrance(2)

                ReelActionCluster(
                    frameCount: photos.count,
                    status: status,
                    shareURL: latestShareURL,
                    displayName: displayName,
                    isRendering: reelRenderingService.isRendering,
                    render: {
                        Task {
                            await reelRenderingService.renderPreview(for: grow, species: species)
                        }
                    }
                )
                .growEntrance(3)

                if !reels.isEmpty {
                    ReelExportsList(reels: reels)
                        .growEntrance(4)
                }
            }
            .padding(.horizontal, GrowSpacing.lg)
            .padding(.top, GrowSpacing.lg)
            .padding(.bottom, ReelStudioVisualContract.bottomScrollPadding)
        }
        .scrollIndicators(.hidden)
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.xs) {
            Text("Reel studio")
                .fieldLabel()
            HStack(alignment: .firstTextBaseline, spacing: GrowSpacing.sm) {
                Text(displayName)
                    .growStyle(GrowType.displayHeadline())
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: GrowSpacing.sm)
                Text("\(photos.count)")
                    .growStyle(
                        GrowType.numeral(34, weight: .semibold),
                        color: GrowPalette.sprout600
                    )
                    .monospacedDigit()
                Text(photos.count == 1 ? "frame" : "frames")
                    .fieldLabel()
            }
            Hairline()
        }
    }

    private var displayName: String {
        grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname
    }

    private var isAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var previewMaxWidth: CGFloat {
        isAccessibilityLayout
            ? ReelStudioVisualContract.accessibilityPreviewMaxWidth
            : ReelStudioVisualContract.previewMaxWidth
    }

    private var contentSpacing: CGFloat {
        isAccessibilityLayout
            ? ReelStudioVisualContract.accessibilityContentSpacing
            : ReelStudioVisualContract.studioContentSpacing
    }
}

private struct ReelReadinessStrip: View {
    let latestDay: Int
    let frameCount: Int
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: isCompact ? GrowSpacing.sm : GrowSpacing.md) {
            ReadinessMetric(label: isCompact ? "Day" : "Latest day", value: "\(latestDay)")
            Divider()
                .frame(height: 28)
            ReadinessMetric(
                label: isCompact ? "Ready" : "Progress",
                value: "\(ReelStudioPolicy.progressPercent(frameCount: frameCount))%"
            )
            if !isCompact {
                Spacer(minLength: 0)
                Text("\(CaptureRewardPolicy.frameCountLabel(frameCount)) / 30")
                    .fieldLabel()
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Latest day \(latestDay), \(frameCount) of 30 frames, \(ReelStudioPolicy.progressPercent(frameCount: frameCount)) percent"
        )
    }
}

private struct ReadinessMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .fieldLabel()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(value)
                .growStyle(GrowType.numeral(24, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(minWidth: 68, alignment: .leading)
    }
}

private struct ReelActionCluster: View {
    let frameCount: Int
    let status: ReelStudioStatus
    let shareURL: URL?
    let displayName: String
    let isRendering: Bool
    let render: () -> Void

    var body: some View {
        VStack(spacing: GrowSpacing.sm) {
            HStack(spacing: GrowSpacing.sm) {
                Button(action: render) {
                    HStack(spacing: GrowSpacing.xs) {
                        if isRendering {
                            ProgressView()
                                .controlSize(.small)
                                .tint(GrowPalette.bloomInk)
                        } else {
                            Image(systemName: "sparkles.rectangle.stack.fill")
                        }
                        Text(isRendering ? "Rendering" : "Render preview")
                    }
                    .font(GrowType.headline())
                    .foregroundStyle(GrowPalette.bloomInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: ReelStudioVisualContract.primaryActionHeight)
                    .background(GrowPalette.bloom, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(frameCount == 0 || isRendering)
                .opacity(frameCount == 0 ? 0.52 : 1)

                if let shareURL {
                    ShareLink(
                        item: shareURL,
                        subject: Text("\(displayName) grow reel"),
                        message: Text("My Grow time-lapse is ready.")
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(GrowPalette.sprout800)
                            .frame(
                                width: ReelStudioVisualContract.shareButtonSize,
                                height: ReelStudioVisualContract.shareButtonSize
                            )
                            .background(GrowPalette.sprout100, in: Circle())
                    }
                    .accessibilityLabel("Share latest reel")
                }
            }

            ReelStatusRow(status: status)
        }
    }
}

private struct ReelStatusRow: View {
    let status: ReelStudioStatus

    var body: some View {
        HStack(spacing: GrowSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, GrowSpacing.sm)
        .frame(minHeight: GrowSpacing.touchTargetMin)
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch status {
        case .noFrames:
            "camera.fill"
        case .ready:
            "play.rectangle.fill"
        case .rendering:
            "hourglass"
        case .rendered:
            "checkmark.seal.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    private var text: String {
        switch status {
        case .noFrames:
            "Frame 1 is waiting"
        case .ready(let progressPercent):
            "\(progressPercent)% of the first 30-frame reel"
        case .rendering:
            "Rendering your latest reel"
        case .rendered(let frameCount, let durationText):
            "\(frameCount) frames rendered in \(durationText)"
        case .failed(let message):
            message
        }
    }

    private var tint: Color {
        switch status {
        case .noFrames:
            GrowPalette.info
        case .ready:
            GrowPalette.sprout600
        case .rendering:
            GrowPalette.bloom
        case .rendered:
            GrowPalette.healthy
        case .failed:
            GrowPalette.needsCare
        }
    }
}

private struct ReelPosterPreview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let grow: Grow
    let species: PlantSpecies?
    let latestPhoto: GrowPhoto?
    let frameCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            posterImage
                .frame(maxWidth: .infinity)
                .aspectRatio(
                    ReelStudioVisualContract.previewAspectRatio,
                    contentMode: .fit
                )
                .clipped()

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: GrowSpacing.xs) {
                if !isAccessibilityLayout {
                    Text("Future reel")
                        .fieldLabel(color: .white.opacity(0.74))
                        .lineLimit(1)
                }
                Text("Day \(latestPhoto?.dayIndex ?? grow.dayCount)")
                    .font(.system(size: posterDayFontSize, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                HStack(spacing: GrowSpacing.xs) {
                    Image(systemName: frameCount > 0 ? "checkmark.seal.fill" : "camera.fill")
                    Text(statusText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(.system(size: posterStatusFontSize, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.86))

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.28))
                        Capsule()
                            .fill(GrowPalette.bloom)
                            .frame(
                                width: proxy.size.width * max(
                                    0.04,
                                    ReelStudioPolicy.progress(frameCount: frameCount)
                                )
                            )
                    }
                }
                .frame(height: 9)
                .padding(.top, 4)
            }
            .padding(GrowSpacing.md)
        }
        .background(GrowPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(GrowPalette.separator.opacity(0.68), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Reel preview for \(displayName), Day \(latestPhoto?.dayIndex ?? grow.dayCount), \(CaptureRewardPolicy.frameCountLabel(frameCount))"
        )
    }

    @ViewBuilder
    private var posterImage: some View {
        if let data = latestPhoto?.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                GrowPalette.groundRaised
                SpecimenJar(
                    progress: grow.currentStage.growthProgress,
                    hasBloom: grow.currentStage.hasBloom,
                    size: 240
                )
            }
        }
    }

    private var displayName: String {
        grow.nickname.isEmpty ? (species?.commonName ?? "My plant") : grow.nickname
    }

    private var isAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var posterDayFontSize: CGFloat {
        isAccessibilityLayout
            ? ReelStudioVisualContract.accessibilityPosterDayFontSize
            : ReelStudioVisualContract.posterDayFontSize
    }

    private var posterStatusFontSize: CGFloat {
        isAccessibilityLayout
            ? ReelStudioVisualContract.accessibilityPosterStatusFontSize
            : UIFont.preferredFont(forTextStyle: .subheadline).pointSize
    }

    private var statusText: String {
        if frameCount > 0 {
            return isAccessibilityLayout
                ? CaptureRewardPolicy.frameCountLabel(frameCount)
                : CaptureRewardPolicy.capturedFrameCountLabel(frameCount)
        }
        return isAccessibilityLayout ? "Frame 1" : "Frame 1 is waiting"
    }
}

private struct ReelExportsList: View {
    let reels: [Reel]

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.sm) {
            HStack {
                Text("Exports")
                    .fieldLabel()
                Spacer()
                Text("\(reels.count)")
                    .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                    .monospacedDigit()
            }

            VStack(spacing: 0) {
                ForEach(reels) { reel in
                    ReelExportRow(reel: reel)
                    if reel.id != reels.last?.id {
                        Hairline()
                            .padding(
                                .leading,
                                ReelStudioVisualContract.exportThumbnailWidth + GrowSpacing.lg
                            )
                    }
                }
            }
            .background(
                GrowPalette.surface.opacity(0.74),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(GrowPalette.separator.opacity(0.74), lineWidth: 1)
            )
        }
    }
}

private struct ReelExportRow: View {
    let reel: Reel

    private var shareURL: URL? {
        ReelStudioPolicy.shareURL(
            localFileName: reel.localFileName,
            containerURL: AppGroup.containerURL
        )
    }

    var body: some View {
        HStack(spacing: GrowSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(GrowPalette.sprout50)
                if let data = reel.posterFrameData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout600)
                }
            }
            .frame(
                width: ReelStudioVisualContract.exportThumbnailWidth,
                height: ReelStudioVisualContract.exportThumbnailHeight
            )
            .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(reel.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .growStyle(GrowType.callout(.semibold))
                    .lineLimit(1)
                Text(
                    "\(reel.photoCount) frames - \(ReelStudioPolicy.durationText(reel.durationSeconds))"
                )
                .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
            }

            Spacer(minLength: GrowSpacing.sm)

            if let shareURL {
                ShareLink(item: shareURL) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(GrowPalette.sprout600)
                        .frame(
                            width: GrowSpacing.touchTargetMin,
                            height: GrowSpacing.touchTargetMin
                        )
                }
                .accessibilityLabel("Share reel")
            }
        }
        .padding(.horizontal, ReelStudioVisualContract.exportRowHorizontalPadding)
        .padding(.vertical, ReelStudioVisualContract.exportRowVerticalPadding)
    }
}

private struct FirstReelEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.md) {
            Text("Reel studio")
                .fieldLabel()
                .growEntrance(0)
            Text("Plant first, then motion follows.")
                .growStyle(GrowType.displayTitle())
                .fixedSize(horizontal: false, vertical: true)
                .growEntrance(1)
            Hairline()
                .growEntrance(2)
            SpecimenJar(progress: 0.08, size: 260)
                .frame(maxWidth: .infinity)
                .growEntrance(3)
            ReelStatusRow(status: .noFrames)
                .growEntrance(4)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GrowSpacing.lg)
        .padding(.top, GrowSpacing.xl)
    }
}
