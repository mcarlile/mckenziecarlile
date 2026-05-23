import SwiftUI

struct GlobeContainerView: View {
    @EnvironmentObject var diveStore: DiveStore
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var selectedDive: Dive?
    @State private var showDiveDetail = false

    private var allDives: [Dive] {
        let hkDives = healthKitService.dives
        let stored = diveStore.dives
        // Merge: prefer HealthKit source of truth, supplement with stored
        var merged = hkDives
        for d in stored where !hkDives.contains(where: { $0.workoutID == d.workoutID }) {
            merged.append(d)
        }
        return merged
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GlobeView(dives: allDives, selectedDive: $selectedDive)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                globeHeader
                Spacer()
                if let dive = selectedDive {
                    diveCallout(dive)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(item: $selectedDive) { dive in
            DiveDetailView(dive: dive)
        }
        .animation(.spring(response: 0.4), value: selectedDive?.id)
    }

    private var globeHeader: some View {
        VStack(spacing: 4) {
            Text("DIVELOG")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.7))
                .kerning(4)
            Text("\(allDives.count) dives logged")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.top, 60)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func diveCallout(_ dive: Dive) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dive.diveSiteName ?? dive.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(dive.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            statChip(label: "MAX", value: dive.maxDepthFormatted)
            statChip(label: "TIME", value: dive.durationFormatted)
            if let temp = dive.temperatureFormatted {
                statChip(label: "TEMP", value: temp)
            }
            Image(systemName: "chevron.right")
                .foregroundStyle(.cyan)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .onTapGesture { showDiveDetail = true }
    }

    private func statChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.7))
                .kerning(1)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
