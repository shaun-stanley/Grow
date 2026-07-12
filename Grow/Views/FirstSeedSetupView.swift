import SwiftUI

struct FirstSeedSetupView: View {
    let selected: OnboardingSetupChoice
    let errorMessage: String?
    var onSelect: (OnboardingSetupChoice) -> Void
    var onStart: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: GrowSpacing.md) {
                    header

                    VStack(spacing: 0) {
                        ForEach(Array(OnboardingSetupChoice.allCases.enumerated()), id: \.element.id) { index, choice in
                            setupRow(choice)
                            if index < OnboardingSetupChoice.allCases.count - 1 { Hairline() }
                        }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(GrowType.callout())
                            .foregroundStyle(GrowPalette.needsCare)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            FirstSeedPrimaryButton(
                title: "Start my grow",
                systemImage: "leaf.fill",
                action: onStart
            )
        }
        .padding(GrowSpacing.lg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.sm) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
                    .frame(minHeight: GrowSpacing.touchTargetMin)
            }
            .buttonStyle(.plain)
            .foregroundStyle(GrowPalette.textPrimary)

            Text("YOUR GROWING VESSEL").fieldLabel()
            Text("What are you\ngrowing in?")
                .growStyle(GrowType.displayTitle())
                .fixedSize(horizontal: false, vertical: true)
            Text("A best guess is enough. You can change this later.")
                .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
        }
    }

    private func setupRow(_ choice: OnboardingSetupChoice) -> some View {
        let isSelected = choice == selected
        return Button {
            onSelect(choice)
        } label: {
            HStack(spacing: GrowSpacing.md) {
                Image(systemName: icon(for: choice))
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(GrowPalette.sprout600)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title(for: choice)).growStyle(GrowType.headline())
                    Text(detail(for: choice))
                        .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: GrowSpacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? GrowPalette.sprout600 : GrowPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: FirstSeedVisualContract.optionMinHeight)
            .padding(.vertical, GrowSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title(for: choice)), \(detail(for: choice))")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func title(for choice: OnboardingSetupChoice) -> String {
        switch choice {
        case .simpleJar: "A simple jar"
        case .countertopGarden: "A countertop garden"
        case .somethingElse: "Something else"
        }
    }

    private func detail(for choice: OnboardingSetupChoice) -> String {
        switch choice {
        case .simpleJar: "No pump · Kratky-style"
        case .countertopGarden: "Built-in light or circulating water"
        case .somethingElse: "I’m still figuring it out"
        }
    }

    private func icon(for choice: OnboardingSetupChoice) -> String {
        switch choice {
        case .simpleJar: "waterbottle"
        case .countertopGarden: "light.beacon.max"
        case .somethingElse: "questionmark.circle"
        }
    }
}
