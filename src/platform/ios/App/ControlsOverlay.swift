// ControlsOverlay.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import SwiftUI
import UIKit

struct ControlsOverlay: View {
    @Environment(AppState.self) private var app
    @State private var showingStates = false
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // D-pad
                ZStack {
                    VStack(spacing: 8) {
                        DPadKey(symbol: "chevron.up", onPress: { app.bridge.addKeys(1 << 6) }, onRelease: { app.bridge.clearKeys(1 << 6) })
                            .frame(width: 48, height: 48)
                            .background(app.controlsSkin == "kenney" ? Color.clear : Color.black.opacity(0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .opacity(app.controlsSkin == "kenney" ? 0.01 : 1)
                        HStack(spacing: 8) {
                            DPadKey(symbol: "chevron.left", onPress: { app.bridge.addKeys(1 << 5) }, onRelease: { app.bridge.clearKeys(1 << 5) })
                                .frame(width: 48, height: 48)
                                .background(app.controlsSkin == "kenney" ? Color.clear : Color.black.opacity(0.28))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .opacity(app.controlsSkin == "kenney" ? 0.01 : 1)
                            Spacer().frame(width: 32)
                            DPadKey(symbol: "chevron.right", onPress: { app.bridge.addKeys(1 << 4) }, onRelease: { app.bridge.clearKeys(1 << 4) })
                                .frame(width: 48, height: 48)
                                .background(app.controlsSkin == "kenney" ? Color.clear : Color.black.opacity(0.28))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .opacity(app.controlsSkin == "kenney" ? 0.01 : 1)
                        }
                        DPadKey(symbol: "chevron.down", onPress: { app.bridge.addKeys(1 << 7) }, onRelease: { app.bridge.clearKeys(1 << 7) })
                            .frame(width: 48, height: 48)
                            .background(app.controlsSkin == "kenney" ? Color.clear : Color.black.opacity(0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .opacity(app.controlsSkin == "kenney" ? 0.01 : 1)
                    }

                    // Kenney D-pad overlay
                    if app.controlsSkin == "kenney" {
                        Image("kenney_dpad")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 128, height: 128)
                            .opacity(0.9)
                    }
                }
                .padding(.leading, geo.size.width * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.bottom, geo.size.height * 0.18)

                // L button
                ShoulderButton(label: "L", skin: app.controlsSkin, imageName: "kenney_shoulder_l") { app.bridge.addKeys(1 << 9) } onRelease: { app.bridge.clearKeys(1 << 9) }
                    .padding(.leading, geo.size.width * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.bottom, geo.size.height * 0.08)

                // R button
                ShoulderButton(label: "R", skin: app.controlsSkin, imageName: "kenney_shoulder_r") { app.bridge.addKeys(1 << 8) } onRelease: { app.bridge.clearKeys(1 << 8) }
                    .padding(.trailing, geo.size.width * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.bottom, geo.size.height * 0.08)

                // A/B buttons
                ZStack(alignment: .center) {
                    CircleButton(title: "A") { app.bridge.addKeys(1 << 0) } onRelease: { app.bridge.clearKeys(1 << 0) }
                        .frame(width: 56, height: 56)
                        .offset(x: 24, y: -24)
                    CircleButton(title: "B") { app.bridge.addKeys(1 << 1) } onRelease: { app.bridge.clearKeys(1 << 1) }
                        .frame(width: 48, height: 48)
                        .offset(x: -16, y: 16)
                }
                .padding(.trailing, geo.size.width * 0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.bottom, geo.size.height * 0.22)

                // Start/Select
                HStack(spacing: 16) {
                    CapsuleButton(title: "Select") { app.bridge.addKeys(1 << 2) } onRelease: { app.bridge.clearKeys(1 << 2) }
                    CapsuleButton(title: "Start") { app.bridge.addKeys(1 << 3) } onRelease: { app.bridge.clearKeys(1 << 3) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, geo.size.height * 0.12)

                // States button
                Button { showingStates = true } label: { Label("States", systemImage: "rectangle.on.rectangle.angled") }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, geo.size.width * 0.08)
                    .padding(.bottom, geo.size.height * 0.08)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(isPresented: $showingStates) { SaveStatesView() }
    }
}

private struct CircleButton: View {
    let title: String
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressed = false
    @Environment(AppState.self) private var app
    var body: some View {
        Group {
            if app.controlsSkin == "kenney" {
                Image(title.lowercased() == "a" ? "kenney_ab_a" : "kenney_ab_b")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            } else {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.28))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
                    .contentShape(Circle())
            }
        }
        .scaleEffect(pressed ? 0.92 : 1)
        .animation(.easeOut(duration: 0.12), value: pressed)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { pressed = true; onPress() } }
            .onEnded { _ in pressed = false; onRelease() }
        )
    }
}

private struct CapsuleButton: View {
    let title: String
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressed = false
    @Environment(AppState.self) private var app
    var body: some View {
        Group {
            if app.controlsSkin == "kenney" {
                Image(title.lowercased() == "select" ? "kenney_minus" : "kenney_plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            } else {
                Text(title)
                    .font(.subheadline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { pressed = true; onPress() } }
            .onEnded { _ in pressed = false; onRelease() }
        )
    }
}

private struct DPadKey: View {
    let symbol: String
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressed = false
    @Environment(AppState.self) private var app
    var body: some View {
        Image(systemName: symbol)
            .font(.title2)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(app.controlsSkin == "kenney" ? Color.black.opacity(0.22) : Color.black.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                Group {
                    if app.controlsSkin == "kenney" {
                        RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.22), lineWidth: 1)
                    }
                }
            )
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .scaleEffect(pressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { pressed = true; onPress() } }
                .onEnded { _ in pressed = false; onRelease() }
            )
    }
}

private struct ShoulderButton: View {
    let label: String
    let skin: String
    let imageName: String
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressed = false
    var body: some View {
        Group {
            if skin == "kenney" {
                Image(imageName)
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                CircleButton(title: label, onPress: onPress, onRelease: onRelease)
            }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { pressed = true; onPress() } }
            .onEnded { _ in pressed = false; onRelease() }
        )
    }
}


