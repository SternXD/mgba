// PlayView.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import SwiftUI

struct PlayView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack(alignment: .bottom) {
            EmulatorGLView(bridge: app.bridge)
                .ignoresSafeArea()
                .background(Color.black)

            if !app.hasController {
                ControlsOverlay()
            }
        }
        .onAppear {
            ControllerManager.shared.start(app: app)
            MultiplayerManager.shared.start(app: app)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("mGBA.IntegerScaling"))) { note in
            if let enabled = note.object as? Bool {
                // Find the GL view and apply scaling. In this wrapper we can't grab it directly,
                // but a simple approach is to toggle via UIWindow hierarchy on main thread.
                DispatchQueue.main.async {
                    if let window = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first,
                       let gl = findGL(in: window) {
                        gl.setIntegerScalingEnabled(enabled)
                    }
                }
            }
        }
    }
}

private func findGL(in root: UIView) -> GLRenderView? {
    if let v = root as? GLRenderView { return v }
    for sub in root.subviews { if let v = findGL(in: sub) { return v } }
    return nil
}


