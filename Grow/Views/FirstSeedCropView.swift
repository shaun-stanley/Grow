import SwiftUI

struct FirstSeedCropView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let species: [PlantSpecies]
    let selectedID: String
    var onSelect: (String) -> Void
    var onContinue: () -> Void
    var onChooseForMe: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.md) {
            ScrollView {
                VStack(alignment: .leading, spacing: GrowSpacing.md) {
                    header

                    VStack(spacing: 0) {
                        ForEach(Array(species.enumerated()), id: \.element.id) { index, plant in
                            cropRow(plant)
                            if index < species.count - 1 { Hairline() }
                        }
                    }
                }
            }

            FirstSeedPrimaryButton(
                title: "Grow \(selectedSpeciesName)",
                systemImage: "arrow.right",
                action: onContinue
            )

            Button("Choose for me", action: onChooseForMe)
                .font(GrowType.callout(.semibold))
                .foregroundStyle(GrowPalette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: GrowSpacing.touchTargetMin)
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

            Text("FIELD NOTE · NO. 001").fieldLabel()
            Text("Choose your\nfirst specimen.")
                .growStyle(GrowType.displayTitle())
                .fixedSize(horizontal: false, vertical: true)
            Text("Three forgiving crops for a first hydroponic win.")
                .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
        }
    }

    private func cropRow(_ plant: PlantSpecies) -> some View {
        let isSelected = plant.id == selectedID
        return Button {
            onSelect(plant.id)
        } label: {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityCropRow(plant, isSelected: isSelected)
            } else {
                standardCropRow(plant, isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plant.commonName), \(benefit(for: plant)), \(plant.harvestText)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private func standardCropRow(_ plant: PlantSpecies, isSelected: Bool) -> some View {
        HStack(spacing: GrowSpacing.md) {
            Text(plant.emoji)
                .font(.system(size: 34))
                .frame(width: 48)
                .accessibilityHidden(true)

            cropDescription(plant)

            Spacer(minLength: GrowSpacing.xs)

            VStack(spacing: 3) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? GrowPalette.sprout600 : GrowPalette.textSecondary)
                if isSelected {
                    Text("Selected").fieldLabel(color: GrowPalette.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: FirstSeedVisualContract.optionMinHeight)
        .padding(.vertical, GrowSpacing.sm)
        .contentShape(Rectangle())
    }

    private func accessibilityCropRow(_ plant: PlantSpecies, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: GrowSpacing.sm) {
            HStack(spacing: GrowSpacing.sm) {
                Text(plant.emoji)
                    .font(.system(size: 30))
                    .frame(width: 48)
                    .accessibilityHidden(true)
                Text(plant.commonName).growStyle(GrowType.headline())
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? GrowPalette.sprout500 : GrowPalette.textSecondary)
            }

            Text(benefit(for: plant))
                .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(plant.harvestText).fieldLabel()
                Spacer()
                if isSelected {
                    Text("Selected").fieldLabel(color: GrowPalette.textSecondary)
                }
            }
        }
        .padding(.vertical, GrowSpacing.md)
        .contentShape(Rectangle())
    }

    private func cropDescription(_ plant: PlantSpecies) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plant.commonName).growStyle(GrowType.headline())
            Text(benefit(for: plant))
                .growStyle(GrowType.callout(), color: GrowPalette.textSecondary)
                .lineLimit(2)
            Text(plant.harvestText).fieldLabel()
        }
    }

    private var selectedSpeciesName: String {
        species.first { $0.id == selectedID }?.commonName ?? "basil"
    }

    private func benefit(for plant: PlantSpecies) -> String {
        switch plant.id {
        case "basil": "Forgiving, fragrant, and fast to reward."
        case "lettuce": "Calm, crisp growth you can see each week."
        case "mint": "Resilient roots and a generous first harvest."
        default: "A beginner-friendly first crop."
        }
    }
}
