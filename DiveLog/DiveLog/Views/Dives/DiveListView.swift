import SwiftUI

struct DiveListView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var diveStore: DiveStore
    @State private var searchText = ""
    @State private var selectedDive: Dive?

    private var allDives: [Dive] {
        let hk = healthKitService.dives
        let stored = diveStore.dives
        var merged = hk
        for d in stored where !hk.contains(where: { $0.workoutID == d.workoutID }) {
            merged.append(d)
        }
        return merged.sorted { $0.date > $1.date }
    }

    private var filtered: [Dive] {
        guard !searchText.isEmpty else { return allDives }
        return allDives.filter {
            ($0.diveSiteName ?? "").localizedCaseInsensitiveContains(searchText) ||
            $0.date.formatted().localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedByYear: [(String, [Dive])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        let groups = Dictionary(grouping: filtered) { formatter.string(from: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.14).ignoresSafeArea()

                if healthKitService.isLoading {
                    loadingView
                } else if allDives.isEmpty {
                    emptyView
                } else {
                    diveList
                }
            }
            .navigationTitle("Dive Log")
            .searchable(text: $searchText, prompt: "Search dives")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if healthKitService.isLoading {
                        ProgressView().tint(.cyan)
                    } else {
                        Button {
                            Task { try? await healthKitService.fetchDives() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedDive) { DiveDetailView(dive: $0) }
    }

    private var diveList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedByYear, id: \.0) { year, dives in
                    Section {
                        ForEach(dives) { dive in
                            DiveRow(dive: dive)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedDive = dive }
                                .padding(.horizontal, 16)
                        }
                    } header: {
                        Text(year)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.cyan.opacity(0.7))
                            .kerning(2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.04, green: 0.06, blue: 0.14).opacity(0.95))
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.cyan)
                .scaleEffect(1.5)
            Text("Syncing dives from Health…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "water.waves")
                .font(.system(size: 56))
                .foregroundStyle(.cyan.opacity(0.3))
            Text("No dives yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Complete a dive with your Apple Watch\nand it will appear here automatically.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct DiveRow: View {
    let dive: Dive
    @EnvironmentObject var diveStore: DiveStore

    private var buddies: [Buddy] { diveStore.buddies(for: dive) }

    var body: some View {
        HStack(spacing: 16) {
            depthIndicator
            VStack(alignment: .leading, spacing: 4) {
                Text(dive.diveSiteName ?? dive.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(dive.date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                if !buddies.isEmpty {
                    buddyStack
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(dive.maxDepthFormatted)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                Text(dive.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.08))
        }
    }

    private var depthIndicator: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [.cyan.opacity(0.2), .indigo.opacity(0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 44)
            Image(systemName: "water.waves")
                .font(.system(size: 18))
                .foregroundStyle(.cyan)
        }
    }

    private var buddyStack: some View {
        HStack(spacing: -6) {
            ForEach(buddies.prefix(3)) { buddy in
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 18, height: 18)
                    .overlay(Text(buddy.initials).font(.system(size: 7, weight: .bold)).foregroundStyle(.white))
                    .overlay(Circle().stroke(Color(red: 0.04, green: 0.06, blue: 0.14), lineWidth: 1.5))
            }
            if buddies.count > 3 {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 18, height: 18)
                    .overlay(Text("+\(buddies.count - 3)").font(.system(size: 7, weight: .bold)).foregroundStyle(.white.opacity(0.7)))
                    .overlay(Circle().stroke(Color(red: 0.04, green: 0.06, blue: 0.14), lineWidth: 1.5))
            }
        }
    }
}
