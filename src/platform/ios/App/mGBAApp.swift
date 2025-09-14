// mGBAApp.swift
// mGBA
//
// Created by SternXD on 9/12/25.
//

import SwiftUI
import UIKit
import SwiftData

@main
struct mGBAApp: App {
    @State private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(for: ROMEntry.self)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }
}



