import SwiftUI

struct BuddyTagView: View {
    let dive: Dive
    @EnvironmentObject var diveStore: DiveStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.14).ignoresSafeArea()

                if diveStore.buddies.isEmpty {
                    emptyState
                } else {
                    buddyGrid
                }
            }
            .navigationTitle("Tag Buddies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.cyan)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var buddyGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(diveStore.buddies) { buddy in
                    let isTagged = dive.buddyIDs.contains(buddy.id)
                    BuddyTagCell(buddy: buddy, isTagged: isTagged) {
                        if isTagged {
                            diveStore.untagBuddy(buddy.id, from: dive.id)
                        } else {
                            diveStore.tagBuddy(buddy.id, on: dive.id)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2")
                .font(.system(size: 40))
                .foregroundStyle(.cyan.opacity(0.3))
            Text("No buddies yet")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            Text("Add friends in the Buddies tab first.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

struct BuddyTagCell: View {
    let buddy: Buddy
    let isTagged: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(LinearGradient(
                            colors: isTagged ? [.cyan, .indigo] : [.white.opacity(0.1), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Text(buddy.initials)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    if isTagged {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 18, height: 18)
                            .overlay(Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white))
                    }
                }
                Text(buddy.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isTagged
                    ? Color.cyan.opacity(0.12)
                    : Color.white.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isTagged ? Color.cyan.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25), value: isTagged)
    }
}
