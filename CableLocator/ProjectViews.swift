import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var showingNewProject = false

    var body: some View {
        NavigationStack {
            List {
                if store.projects.isEmpty {
                    ContentUnavailableView("No sites yet", systemImage: "building.2",
                        description: Text("Create a site before the wall lining goes on."))
                } else {
                    ForEach(store.projects) { project in
                        NavigationLink(value: project.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name).font(.headline)
                                Text(project.address.isEmpty ? "\(project.marks.count) cable marks" : project.address)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Cable Locator")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New site", systemImage: "plus") { showingNewProject = true }
                }
            }
            .navigationDestination(for: UUID.self) { id in ProjectDetailView(projectID: id) }
            .sheet(isPresented: $showingNewProject) { NewProjectView() }
            .alert("Storage error", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } })) {
                    Button("OK", role: .cancel) { store.errorMessage = nil }
                } message: { Text(store.errorMessage ?? "") }
        }
    }
}

private struct NewProjectView: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Site") {
                    TextField("Site name", text: $name)
                    TextField("Address or lot number", text: $address)
                }
                Section {
                    Text("Projects and photos are saved on this iPhone. Back up the phone before deleting the app.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { _ = store.addProject(name: name, address: address); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject private var store: ProjectStore
    let projectID: UUID
    @State private var showingCapture = false

    var body: some View {
        Group {
            if let project = store.project(projectID) {
                List {
                    Section {
                        Button {
                            showingCapture = true
                        } label: {
                            Label("Mark a cable end", systemImage: "scope")
                                .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } footer: {
                        Text("Scan before gyprock. Photograph each cable and measure it from fixed references.")
                    }
                    if project.marks.isEmpty {
                        ContentUnavailableView("No cable marks", systemImage: "cable.connector",
                            description: Text("Add the first marker while the framing is visible."))
                    } else {
                        Section("Cable ends") {
                            ForEach(project.marks.reversed()) { mark in
                                NavigationLink {
                                    MarkDetailView(projectID: projectID, markID: mark.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        if let image = store.image(for: mark) {
                                            Image(uiImage: image).resizable().scaledToFill()
                                                .frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(mark.label).font(.headline)
                                            Text(mark.room).font(.subheadline).foregroundStyle(.secondary)
                                            Text(mark.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle(project.name)
                .fullScreenCover(isPresented: $showingCapture) {
                    CaptureView(projectID: projectID)
                }
            } else {
                ContentUnavailableView("Site unavailable", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

struct MarkDetailView: View {
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    let markID: UUID
    @State private var showingLocate = false
    @State private var showingDelete = false

    private var mark: CableMark? { store.project(projectID)?.marks.first { $0.id == markID } }

    var body: some View {
        Group {
            if let mark {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let image = store.image(for: mark) {
                            Image(uiImage: image).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("Site photo showing the cable position")
                        }
                        Button { showingLocate = true } label: {
                            Label("Find in AR", systemImage: "arkit")
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Room", value: mark.room)
                            if let mm = mark.fromLeftReferenceMM {
                                LabeledContent("Across", value: "\(mm) mm from reference")
                            }
                            if let mm = mark.fromFloorMM {
                                LabeledContent("Height", value: "\(mm) mm above floor datum")
                            }
                            if !mark.referenceDescription.isEmpty {
                                LabeledContent("Reference", value: mark.referenceDescription)
                            }
                            if !mark.notes.isEmpty { Text(mark.notes).padding(.top, 6) }
                        }
                        .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        Text("Confirm the location with the photo and physical measurements before cutting. AR position can drift, especially after the wall changes.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .navigationTitle(mark.label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Delete", systemImage: "trash", role: .destructive) { showingDelete = true }
                    }
                }
                .confirmationDialog("Delete this cable mark?", isPresented: $showingDelete) {
                    Button("Delete mark", role: .destructive) {
                        store.deleteMark(markID, from: projectID)
                        dismiss()
                    }
                }
                .fullScreenCover(isPresented: $showingLocate) {
                    LocateView(projectID: projectID, markID: markID)
                }
            }
        }
    }
}
