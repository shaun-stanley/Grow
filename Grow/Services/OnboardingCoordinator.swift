import Foundation
import Observation

@MainActor
@Observable
final class OnboardingCoordinator {
    private(set) var step: OnboardingStep = .promise
    private(set) var selectedSpeciesID = OnboardingPolicy.defaultSpeciesID
    private(set) var selectedSetup: OnboardingSetupChoice = .simpleJar
    private(set) var pendingGrowRequest: OnboardingGrowRequest?
    private(set) var createdGrowID: UUID?
    private(set) var reward: CaptureReward?
    var errorMessage: String?

    func begin() {
        step = .crop
    }

    func selectSpecies(_ id: String) {
        selectedSpeciesID = id
    }

    func advanceFromCrop() {
        step = .setup
    }

    func selectSetup(_ setup: OnboardingSetupChoice) {
        selectedSetup = setup
    }

    func confirmSetup() {
        pendingGrowRequest = OnboardingGrowRequest(
            speciesID: selectedSpeciesID,
            system: OnboardingPolicy.system(for: selectedSetup)
        )
        step = .capture
    }

    func didCreateGrow(id: UUID) {
        createdGrowID = id
        pendingGrowRequest = nil
    }

    func didCapture(_ reward: CaptureReward) {
        self.reward = reward
        step = .reward
    }

    func showSample() {
        step = .sample
        pendingGrowRequest = nil
    }

    func leaveSample() {
        step = .promise
    }

    func retryCapture() {
        errorMessage = nil
        step = .capture
    }

    func goBack() {
        switch step {
        case .crop:
            step = .promise
        case .setup:
            step = .crop
        case .capture where createdGrowID == nil:
            step = .setup
        case .sample:
            step = .promise
        case .promise, .capture, .reward:
            break
        }
    }
}
