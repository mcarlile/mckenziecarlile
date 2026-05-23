import SwiftUI

struct BuddyListView: View {
    @EnvironmentObject var diveStore: DiveStore
    @State private var showAddBuddy = false
    @State private var selectedBuddy: Buddy?
    @State private var newName = ""
    @State private var newEmail = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.14).ignoresSafeArea()

                if diveStore.buddies.isEmpty {
                    emptyView
                } else {
                    buddyList
                }
            }
            .navigationTitle("Buddies")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBuddy = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(.cyan)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddBuddy) { addBuddySheet }
        .sheet(item: $selectedBuddy) { BuddyDetailView(buddy: $0) }
    }

    private var buddyList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(diveStore.buddies) { buddy in
                    BuddyRow(buddy: buddy)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedBuddy = buddy }
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var addBuddySheet: some View {
        NavigationStack {
            Form {
                Section("BUDDY INFO") {
                    TextField("Name", text: $newName)
                        .foregroundStyle(.white)
                    TextField("Email (optional)", text: $newEmail)
                        .foregroundStyle(.white)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.04, green: 0.06, blue: 0.14))
            .navigationTitle("Add Buddy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddBuddy = false }
                        .foregroundStyle(.cyan)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let buddy = Buddy(name: newName, email: newEmail.isEmpty ? nil : newEmail)
                        diveStore.upsert(buddy)
                        newName = ""
                        newEmail = ""
                        showAddBuddy = false
                    }
                    .foregroundStyle(.cyan)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 56))
                .foregroundStyle(.cyan.opacity(0.3))
            Text("No buddies yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            Text("Add dive buddies to tag them on dives\nand share your logs with them.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
            Button {
                showAddBuddy = true
            } label: {
                Label("Add Buddy", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
        .padding()
    }
}

struct BuddyRow: View {
    let buddy: Buddy
    @EnvironmentObject var diveStore: DiveStore

    var body: some View {
        HStack(spacing: 14) {
            avatarView
            VStack(alignment: .leading, spacing: 3) {
                Text(buddy.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let email = buddy.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(buddy.taggedDiveIDs.count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                Text("dives")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Divider().background(Color.white.opacity(0.08))
        }
    }

    private var avatarView: some View {
        Circle()
            .fill(LinearGradient(
                colors: [.cyan.opacity(0.7), .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .frame(width: 44, height: 44)
            .overlay(
                Text(buddy.initials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}
