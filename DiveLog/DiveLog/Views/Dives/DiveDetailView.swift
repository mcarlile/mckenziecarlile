import SwiftUI
import MapKit

struct DiveDetailView: View {
    let dive: Dive
    @EnvironmentObject var diveStore: DiveStore
    @Environment(\.dismiss) var dismiss
    @State private var showBuddyTag = false
    @State private var showShareSheet = false
    @State private var editingNotes = false
    @State private var notesText: String = ""

    private var buddies: [Buddy] { diveStore.buddies(for: dive) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    depthSection
                    metadataGrid
                    if let loc = dive.location { mapSection(loc) }
                    buddySection
                    notesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(red: 0.04, green: 0.06, blue: 0.14))
            .navigationTitle(dive.diveSiteName ?? dive.date.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarItems }
        }
        .onAppear { notesText = dive.notes }
        .sheet(isPresented: $showBuddyTag) { BuddyTagView(dive: dive) }
    }

    // MARK: - Sections

    private var depthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DEPTH PROFILE")
            DepthProfileView(dive: dive)
                .padding(16)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var metadataGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DIVE DATA")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metaCard(icon: "arrow.down.to.line", label: "MAX DEPTH", value: dive.maxDepthFormatted, accent: .cyan)
                metaCard(icon: "chart.bar.fill", label: "AVG DEPTH",  value: String(format: "%.1fm", dive.avgDepth), accent: .cyan)
                metaCard(icon: "timer", label: "DURATION", value: dive.durationFormatted, accent: .teal)
                metaCard(icon: "thermometer.medium", label: "WATER TEMP", value: dive.temperatureFormatted ?? "—", accent: .teal)
                metaCard(icon: "calendar", label: "DATE", value: dive.date.formatted(date: .abbreviated, time: .omitted), accent: .indigo)
                metaCard(icon: "clock", label: "TIME", value: dive.date.formatted(date: .omitted, time: .shortened), accent: .indigo)
            }
        }
    }

    private func mapSection(_ loc: DiveLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("LOCATION")
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))) {
                Marker(dive.diveSiteName ?? "Dive Site",
                       coordinate: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude))
                    .tint(.cyan)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var buddySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("BUDDIES")
                Spacer()
                Button {
                    showBuddyTag = true
                } label: {
                    Label("Tag", systemImage: "person.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
            }

            if buddies.isEmpty {
                Text("No buddies tagged on this dive")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(buddies) { buddy in
                            buddyChip(buddy)
                        }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("NOTES")
            if editingNotes {
                TextEditor(text: $notesText)
                    .font(.body)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    .frame(minHeight: 100)
                HStack {
                    Spacer()
                    Button("Save") {
                        var updated = dive
                        updated.notes = notesText
                        diveStore.upsert(updated)
                        editingNotes = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
            } else {
                Text(notesText.isEmpty ? "Tap to add notes…" : notesText)
                    .font(.body)
                    .foregroundStyle(notesText.isEmpty ? .white.opacity(0.3) : .white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .onTapGesture { editingNotes = true }
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.cyan.opacity(0.6))
            .kerning(2)
    }

    private func metaCard(icon: String, label: String, value: String, accent: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(0.5)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func buddyChip(_ buddy: Buddy) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [.cyan, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .overlay(Text(buddy.initials).font(.caption.bold()).foregroundStyle(.white))
            Text(buddy.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.cyan)
            }
        }
    }
}
