// RootView.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Environment(AppState.self) private var app
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.9),
                    Color.gray.opacity(0.3),
                    Color.black.opacity(0.9)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .tag(0)

                PlayView()
                    .tabItem {
                        Label("Play", systemImage: "gamecontroller")
                    }
                    .tag(1)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(2)
            }
            .tint(app.tintColor)
            .background(Color.clear)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedTab)
    }
}


