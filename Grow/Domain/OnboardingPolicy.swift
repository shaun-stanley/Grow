import Foundation

enum OnboardingStep: Int, CaseIterable, Equatable {
    case promise
    case crop
    case setup
    case capture
    case reward
    case sample
}

enum OnboardingSetupChoice: String, CaseIterable, Identifiable, Equatable {
    case simpleJar
    case countertopGarden
    case somethingElse

    var id: String { rawValue }
}

enum OnboardingLaunchRoute: Equatable {
    case ceremony
    case resumeCapture
    case app
}

struct OnboardingGrowRequest: Equatable {
    let speciesID: String
    let system: GrowSystem
}

enum OnboardingPolicy {
    static let completedVersionKey = "grow.onboarding.completedVersion"
    static let currentVersion = 1
    static let launchSpeciesIDs = ["basil", "lettuce", "mint"]
    static let defaultSpeciesID = "basil"

    static func system(for choice: OnboardingSetupChoice) -> GrowSystem {
        switch choice {
        case .simpleJar: .kratky
        case .countertopGarden: .dwc
        case .somethingElse: .other
        }
    }

    static func launchRoute(
        completedVersion: Int,
        hasActiveGrow: Bool,
        activePhotoCount: Int
    ) -> OnboardingLaunchRoute {
        if completedVersion >= currentVersion { return .app }
        if hasActiveGrow { return activePhotoCount > 0 ? .app : .resumeCapture }
        return .ceremony
    }
}
