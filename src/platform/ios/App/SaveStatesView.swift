// SaveStatesView.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import SwiftUI

struct SaveStatesView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(0..<10, id: \.self) { slot in
                HStack {
                    VStack(alignment: .leading) {
                        Text("Slot \(slot)").font(.headline)
                        Text("Tap to load, swipe for options").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Save") { _ = app.bridge.saveState(Int32(slot)) }
                        .buttonStyle(.borderedProminent)
                }
                .contentShape(Rectangle())
                .onTapGesture { _ = app.bridge.loadState(Int32(slot)); dismiss() }
            }
            .navigationTitle("Save States")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}



