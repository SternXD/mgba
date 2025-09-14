// ContentView.swift
// mGBA
//
// Created by SternXD on 9/12/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var bridge = MGBCoreBridge()
    @State private var showingPicker = false
    @State private var pickedURL: URL?

    var body: some View {
        ZStack {
            EmulatorGLView(bridge: bridge)
                .ignoresSafeArea()
                .background(Color.black)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button("Open ROM") { showingPicker = true }
                        .buttonStyle(.borderedProminent)
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { url in
                pickedURL = url
                if let url = url {
                    bridge.start(withROMPath: url.path)
                }
            }
        }
        .onAppear {
            if let last = UserDefaults.standard.string(forKey: "LastROMPath"),
               FileManager.default.fileExists(atPath: last) {
                bridge.start(withROMPath: last)
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                bridge.flushSaves()
                bridge.stop()
            }
        }
    }
}

private struct DocumentPicker: UIViewControllerRepresentable {
    let handler: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(handler: handler) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let c = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.data], asCopy: true)
        c.allowsMultipleSelection = false
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let handler: (URL?) -> Void
        init(handler: @escaping (URL?) -> Void) { self.handler = handler }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            handler(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            handler(nil)
        }
    }
}

