import SwiftUI

struct BuddyDetailView: View {
    let buddy: Buddy
    @EnvironmentObject var diveStore: DiveStore
    @Environment(\.dismiss) var dismiss
    @State private var showSharePicker = false
    @State private var selectedDivesToShare: Set<UUID> = []
    @State private var showDeleteConfirm = false

    private var sharedDives: [Dive] { diveStore.dives(for: buddy) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.14).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        buddyHeader
                        diveHistory
                        shareSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(buddy.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Remove Buddy", systemImage: "person.badge.minus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .alert("Remove \(buddy.name)?", isPresented: $showDeleteConfirm) {
            Button("Remove", role: .destructive) {
                diveStore.delete(buddy)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will untag them from all your dives. Their own dive records won't be affected.")
        }
    }

    private var buddyHeader: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [.cyan.opacity(0.7), .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 80, height: 80)
                .overlay(Text(buddy.initials).font(.title.bold()).foregroundStyle(.white))
                .padding(.top, 8)

            if let email = buddy.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 24) {
                statBadge(value: "\(sharedDives.count)", label: "DIVES TOGETHER")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var diveHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DIVES TOGETHER")
            if sharedDives.isEmpty {
                Text("No dives tagged yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.vertical, 8)
            } else {
                ForEach(sharedDives) { dive in
                    sharedDiveRow(dive)
                }
            }
        }
    }

    private func sharedDiveRow(_ dive: Dive) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(dive.diveSiteName ?? dive.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(dive.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(dive.maxDepthFormatted)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                Text(dive.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            // Preview depth profile (compact)
            DepthProfileView(dive: dive, compact: true)
                .frame(width: 80)
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SHARE DIVES")
            Text("Send dive logs to \(buddy.name) so they can import them into their own DiveLog.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))

            Button {
                showSharePicker = true
            } label: {
                Label("Choose Dives to Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
        .sheet(isPresented: $showSharePicker) {
            DiveSharePicker(buddy: buddy)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.cyan.opacity(0.6))
            .kerning(2)
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .kerning(1)
        }
    }
}

struct DiveSharePicker: View {
    let buddy: Buddy
    @EnvironmentObject var diveStore: DiveStore
    @Environment(\.dismiss) var dismiss
    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(diveStore.dives, id: \.id, selection: $selected) { dive in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dive.diveSiteName ?? dive.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.headline)
                        Text("\(dive.maxDepthFormatted) · \(dive.durationFormatted)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selected.contains(dive.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.cyan)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selected.contains(dive.id) { selected.remove(dive.id) }
                    else { selected.insert(dive.id) }
                }
            }
            .navigationTitle("Share with \(buddy.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share (\(selected.count))") {
                        shareDives()
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func shareDives() {
        let packages = diveStore.dives
            .filter { selected.contains($0.id) }
            .map { diveStore.sharePackage(for: $0) }

        // Encode as JSON for sharing (AirDrop, Messages, etc.)
        guard let data = try? JSONEncoder().encode(packages) else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dives_for_\(buddy.name).divelog")
        try? data.write(to: url)

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // Present from root view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let vc = windowScene.windows.first?.rootViewController {
            vc.present(activityVC, animated: true)
        }
    }
}
