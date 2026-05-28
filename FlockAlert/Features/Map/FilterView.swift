import SwiftUI

struct FilterView: View {
    @Binding var filters: CameraFilters
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.flockBG.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Owner Type filter
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("OWNER TYPE")
                            FlowLayout(spacing: 8) {
                                ForEach(OwnerType.allCases, id: \.self) { type in
                                    ToggleChip(
                                        label: type.rawValue,
                                        isOn: filters.ownerTypes.contains(type)
                                    ) {
                                        if filters.ownerTypes.contains(type) {
                                            filters.ownerTypes.remove(type)
                                        } else {
                                            filters.ownerTypes.insert(type)
                                        }
                                    }
                                }
                            }
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Confidence filter
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("MINIMUM CONFIDENCE")
                            HStack(spacing: 8) {
                                ForEach([0.5, 0.7, 0.9], id: \.self) { val in
                                    ToggleChip(
                                        label: "\(Int(val * 100))%+",
                                        isOn: filters.minimumConfidence == val
                                    ) {
                                        filters.minimumConfidence = filters.minimumConfidence == val ? nil : val
                                    }
                                }
                                ToggleChip(label: "Any", isOn: filters.minimumConfidence == nil) {
                                    filters.minimumConfidence = nil
                                }
                            }
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Verified only
                        Toggle(isOn: $filters.verifiedOnly) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Verified Only")
                                    .font(.flockHeadline)
                                    .foregroundStyle(Color.flockText)
                                Text("Show cameras with 3+ community verifications")
                                    .font(.flockCaption)
                                    .foregroundStyle(Color.flockTextSub)
                            }
                        }
                        .tint(Color.flockPrimary)
                        .padding(.vertical, 4)

                        // Reset
                        if filters.isActive {
                            Button("Reset All Filters") {
                                filters = CameraFilters()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.flockAlert)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Filter Cameras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.flockPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.flockTextSub)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct SectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.flockTextSub)
            .tracking(1.5)
    }
}

struct ToggleChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? Color.flockBG : Color.flockTextSub)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? Color.flockPrimary : Color.flockSurface2)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0, totalH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                y += lineH + spacing; x = 0; lineH = 0
            }
            lineH = max(lineH, size.height)
            x += size.width + spacing
        }
        totalH = y + lineH
        return CGSize(width: width, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += lineH + spacing; x = bounds.minX; lineH = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            lineH = max(lineH, size.height)
            x += size.width + spacing
        }
    }
}
