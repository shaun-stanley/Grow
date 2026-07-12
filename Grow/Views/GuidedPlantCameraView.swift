import Foundation
import SwiftUI

struct GuidedPlantCameraConfiguration: Equatable {
    let title: String
    let guidance: String
    let speciesName: String
    let frameCount: Int
    let ghostThumbnailData: Data?
    let currentProgress: Double

    static func dayOne(speciesName: String) -> GuidedPlantCameraConfiguration {
        GuidedPlantCameraConfiguration(
            title: "Frame one",
            guidance: "Center the jar inside the guide",
            speciesName: speciesName,
            frameCount: 1,
            ghostThumbnailData: nil,
            currentProgress: 0.03
        )
    }

    static func daily(
        speciesName: String,
        frameCount: Int,
        ghostThumbnailData: Data?,
        progress: Double
    ) -> GuidedPlantCameraConfiguration {
        GuidedPlantCameraConfiguration(
            title: "Frame \(frameCount)",
            guidance: ghostThumbnailData == nil
                ? "Center the jar inside the guide"
                : "Match yesterday’s frame",
            speciesName: speciesName,
            frameCount: frameCount,
            ghostThumbnailData: ghostThumbnailData,
            currentProgress: progress
        )
    }
}

struct GuidedPlantCameraView: View {
    let configuration: GuidedPlantCameraConfiguration
    var onCapture: (Data) -> Void
    var onCancel: () -> Void
    var onFailure: (String) -> Void = { _ in }

    var body: some View {
        GuidedPlantCameraContent(
            configuration: configuration,
            onCapture: onCapture,
            onCancel: onCancel,
            onFailure: onFailure
        )
    }
}
