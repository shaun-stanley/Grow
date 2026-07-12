import SwiftUI

struct FirstSeedPromiseView: View {
    var onBegin: () -> Void
    var onSample: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            spaciousLayout
            ScrollView { compactLayout }
        }
    }

    private var spaciousLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            promiseHeader
            Spacer(minLength: GrowSpacing.sm)
            specimen
            Spacer(minLength: GrowSpacing.sm)
            actions
        }
        .padding(GrowSpacing.lg)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.lg) {
            promiseHeader
            specimen
            actions
        }
        .padding(GrowSpacing.lg)
    }

    private var promiseHeader: some View {
        VStack(alignment: .leading, spacing: GrowSpacing.sm) {
            Text("GROW · A LIVING JOURNAL").fieldLabel()
            Text("Grow something\nfrom almost nothing.")
                .growStyle(GrowType.displayTitle())
                .fixedSize(horizontal: false, vertical: true)
            Text("Your first harvest begins with one small frame.")
                .growStyle(GrowType.body(), color: GrowPalette.textSecondary)
        }
    }

    private var specimen: some View {
        ZStack(alignment: .topTrailing) {
            SpecimenJar(progress: 0.06, size: 270)
                .accessibilityLabel("A newly planted seed in a hydroponic jar")

            VStack(alignment: .trailing, spacing: 2) {
                Text("FUTURE REEL").fieldLabel()
                Text("Day 30")
                    .growStyle(GrowType.title())
            }
            .padding(.top, GrowSpacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    private var actions: some View {
        VStack(spacing: GrowSpacing.sm) {
            FirstSeedPrimaryButton(
                title: "Plant your first seed",
                systemImage: "arrow.right",
                action: onBegin
            )

            Button("Explore with a sample grow", action: onSample)
                .font(GrowType.callout(.semibold))
                .foregroundStyle(GrowPalette.textPrimary)
                .frame(minHeight: FirstSeedVisualContract.secondaryActionMinHeight)

            Text("No account · about one minute")
                .growStyle(GrowType.caption(), color: GrowPalette.textSecondary)
                .frame(maxWidth: .infinity)
        }
    }
}
