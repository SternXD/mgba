// LibraryView.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \ROMEntry.lastPlayed, order: .reverse) private var recents: [ROMEntry]
    @State private var showingFilePicker = false
    @State private var showingFolderPicker = false
    @State private var confirmDelete: ROMEntry? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(recents) { entry in
                        ROMCell(entry: entry)
                            .contextMenu {
                                Button(entry.favorite ? "Unfavorite" : "Favorite") {
                                    entry.favorite.toggle()
                                }
                                Button(role: .destructive) {
                                    confirmDelete = entry
                                } label: { Label("Delete from Library", systemImage: "trash") }
                                Button(role: .destructive) {
                                    deleteEntry(entry, removeFile: true)
                                } label: { Label("Delete + Remove File", systemImage: "trash.fill") }
                            }
                            .onTapGesture {
                                app.loadROM(at: entry.url)
                                entry.lastPlayed = .now
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Welcome to mGBA!")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button(action: { showingFilePicker = true }) { Label("File", systemImage: "plus") }
                        Button(action: { showingFolderPicker = true }) { Label("Folder", systemImage: "folder.badge.plus") }
                    }
                }
            }
        }
        .alert("Delete entry?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("Delete", role: .destructive) { if let e = confirmDelete { deleteEntry(e, removeFile: false) }; confirmDelete = nil }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("This removes the game from your library. The file remains on disk.")
        }
        .sheet(isPresented: $showingFilePicker) { FileImportSheet(onPicked: handleImportedFiles(_:)) }
        .sheet(isPresented: $showingFolderPicker) { FolderImportSheet(onPicked: handleImportedFolder(_:)) }
    }

    private func handleImportedFiles(_ urls: [URL]) {
        let destDir = gamesDirectory()
        for url in urls {
            if isSupportedROM(url), let dest = copyOrMoveURL(url, toDirectory: destDir) { insertEntry(for: dest) }
        }
        try? context.save()
    }

    private func handleImportedFolder(_ url: URL?) {
        guard let folder = url else { return }
        guard folder.startAccessingSecurityScopedResource() else { return }
        defer { folder.stopAccessingSecurityScopedResource() }
        let fm = FileManager.default
        let destDir = gamesDirectory()
        if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if isSupportedROM(fileURL), let dest = copyOrMoveURL(fileURL, toDirectory: destDir) { insertEntry(for: dest) }
            }
        }
        try? context.save()
    }

    private func deleteEntry(_ entry: ROMEntry, removeFile: Bool) {
        if removeFile { try? FileManager.default.removeItem(atPath: entry.url) }
        context.delete(entry)
        try? context.save()
    }

    // MARK: - File helpers
    private func gamesDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Games", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func copyOrMoveURL(_ src: URL, toDirectory dir: URL) -> URL? {
        let ext = src.pathExtension
        var base = src.deletingPathExtension().lastPathComponent
        if base.isEmpty { base = "Game" }
        var dest = dir.appendingPathComponent("\(base).\(ext)")
        var i = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = dir.appendingPathComponent("\(base) \(i).\(ext)")
            i += 1
        }
        do {
            // Try move first (for Inbox -> app)
            if (try? FileManager.default.moveItem(at: src, to: dest)) != nil {
                return dest
            }
            // Fallback to copy
            if src.isFileURL {
                try FileManager.default.copyItem(at: src, to: dest)
            } else {
                let data = try Data(contentsOf: src)
                try data.write(to: dest)
            }
            return dest
        } catch {
            return nil
        }
    }
    private func isSupportedROM(_ url: URL) -> Bool {
        let ex = url.pathExtension.lowercased()
        return ["gba", "gb", "gbc"].contains(ex)
    }
    private func insertEntry(for url: URL) {
        let title = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        let system = (ext == "gba") ? "GBA" : (ext == "gbc" ? "GBC" : "GB")
        let entry = ROMEntry(url: url.path, title: title, system: system)
        context.insert(entry)
    }
}

private struct ROMCell: View {
    let entry: ROMEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 120)
            }
            Text(entry.title)
                .font(.headline)
                .lineLimit(1)
            HStack {
                Text(entry.system).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if entry.favorite { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(.thinMaterial))
    }
}

private struct FileImportSheet: UIViewControllerRepresentable {
    let onPicked: ([URL]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let c = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data], asCopy: true)
        c.allowsMultipleSelection = true
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: ([URL]) -> Void
        init(onPicked: @escaping ([URL]) -> Void) { self.onPicked = onPicked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { onPicked(urls) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPicked([]) }
    }
}

private struct FolderImportSheet: UIViewControllerRepresentable {
    let onPicked: (URL?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let c = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        c.allowsMultipleSelection = false
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL?) -> Void
        init(onPicked: @escaping (URL?) -> Void) { self.onPicked = onPicked }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { onPicked(urls.first) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onPicked(nil) }
    }
}


