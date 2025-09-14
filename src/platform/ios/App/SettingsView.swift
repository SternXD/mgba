// SettingsView.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import SwiftUI
import Network

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @AppStorage("videoSync") private var videoSync: Bool = false
    @AppStorage("audioSync") private var audioSync: Bool = false
    @AppStorage("fpsTarget") private var fpsTarget: Double = 60
    @AppStorage("frameskip") private var frameskip: Int = 0
    @AppStorage("mute") private var mute: Bool = false
    @AppStorage("volume") private var volume: Int = 100
    @AppStorage("fastForwardVolume") private var ffVolume: Int = 100
    @AppStorage("fastForwardMute") private var ffMute: Bool = false
    @AppStorage("audioBuffers") private var audioBuffers: Int = 1024
    @AppStorage("sampleRate") private var sampleRate: Int = 44100
    @AppStorage("autofireThreshold") private var autofireThreshold: Int = 8
    @AppStorage("lockIntegerScaling") private var lockIntegerScaling: Bool = false
    @AppStorage("gbaForceGbp") private var gbaForceGbp: Bool = false
    @AppStorage("skipBios") private var skipBios: Bool = true
    @AppStorage("useBios") private var useBios: Bool = false
    @AppStorage("allowOpposing") private var allowOpposing: Bool = true
    @AppStorage("idleOptimization") private var idleOptimization: String = "remove"
    @AppStorage("autoload") private var autoload: Bool = true
    @AppStorage("autosave") private var autosave: Bool = false
    @AppStorage("lockAspectRatio") private var lockAspectRatio: Bool = true
    @AppStorage("integerScaling") private var integerScaling: Bool = false
    @AppStorage("showOSD") private var showOSD: Bool = true
    @AppStorage("showFrameCounter") private var showFrameCounter: Bool = false
    @AppStorage("showResetInfo") private var showResetInfo: Bool = false
    @AppStorage("interframeBlending") private var interframeBlending: Bool = false
    @AppStorage("resampleVideo") private var resampleVideo: Bool = false
    @AppStorage("pauseOnMinimize") private var pauseOnMinimize: Bool = false
    @AppStorage("muteOnMinimize") private var muteOnMinimize: Bool = false
    @AppStorage("showFps") private var showFps: Bool = true
    @AppStorage("showFilename") private var showFilename: Bool = false
    @AppStorage("dynamicTitle") private var dynamicTitle: Bool = true
    @AppStorage("vbaBugCompat") private var vbaBugCompat: Bool = true
    @AppStorage("ffRatio") private var ffRatio: Double = -1
    @AppStorage("ffHeldRatio") private var ffHeldRatio: Double = -1
    @AppStorage("rewindEnable") private var rewindEnable: Bool = false
    @AppStorage("rewindCapacity") private var rewindCapacity: Int = 10
    @AppStorage("rewindInterval") private var rewindInterval: Int = 250
    @AppStorage("sgbBorders") private var sgbBorders: Bool = true
    @AppStorage("gbPalette") private var gbPalette: String = ""
    @AppStorage("logToFile") private var logToFile: Bool = false
    @AppStorage("logToStdout") private var logToStdout: Bool = false
    @AppStorage("logFile") private var logFile: String = ""
    @AppStorage("logLevel") private var logLevel: Int = 0x7F // mLOG_ALL

    var body: some View {
        Form {
            Section("Video") {
                Toggle("Sync to display", isOn: $videoSync)
                Stepper(value: $fpsTarget, in: 30...120, step: 5) { Text("FPS Target: \(Int(fpsTarget))") }
                Stepper(value: $frameskip, in: 0...5) { Text("Frameskip: \(frameskip)") }
                Toggle("Lock integer scaling", isOn: $lockIntegerScaling)
                Toggle("Integer scaling", isOn: $integerScaling)
                Toggle("Show OSD", isOn: $showOSD)
                Toggle("Show frame counter", isOn: $showFrameCounter)
                Toggle("Show reset info", isOn: $showResetInfo)
                Toggle("Interframe blending", isOn: $interframeBlending)
                Toggle("Resample video", isOn: $resampleVideo)
                Button("Apply") { applyVideo() }
            }
            Section("Audio") {
                Toggle("Audio sync", isOn: $audioSync)
                Stepper(value: $audioBuffers, in: 512...8192, step: 512) { Text("Audio buffers: \(audioBuffers)") }
                Stepper(value: $sampleRate, in: 8000...96000, step: 8000) { Text("Sample rate: \(sampleRate) Hz") }
                Toggle("Mute", isOn: $mute)
                Slider(value: Binding(get: { Double(volume) }, set: { volume = Int($0) }), in: 0...100) { Text("Volume") }
                Toggle("Fast forward mute", isOn: $ffMute)
                Slider(value: Binding(get: { Double(ffVolume) }, set: { ffVolume = Int($0) }), in: 0...100) { Text("Fast forward volume") }
                Button("Apply") { applyAudio() }
            }
            Section("Boot") {
                Toggle("Skip BIOS", isOn: $skipBios)
                Toggle("Use BIOS if available", isOn: $useBios)
                Button("Apply") { app.bridge.setSkipBios(skipBios); app.bridge.setUseBios(useBios) }
            }
            Section("Input") {
                Stepper(value: $autofireThreshold, in: 1...30, step: 1) { Text("Autofire threshold: \(autofireThreshold)") }
                Toggle("Allow opposing directions", isOn: $allowOpposing)
                Button("Apply") { app.bridge.setAllowOpposingDirections(allowOpposing) }
            }
            Section("Behavior") {
                Picker("Idle optimization", selection: $idleOptimization) {
                    Text("Ignore").tag("ignore")
                    Text("Remove").tag("remove")
                    Text("Detect").tag("detect")
                }
                Toggle("Autoload last game", isOn: $autoload)
                Toggle("Autosave state", isOn: $autosave)
                Button("Apply") { app.bridge.setIdleOptimization(idleOptimization); app.bridge.setAutoload(autoload); app.bridge.setAutosave(autosave) }
            }
            Section("Interface") {
                Toggle("Lock aspect ratio", isOn: $lockAspectRatio)
                Toggle("Show FPS", isOn: $showFps)
                Toggle("Show filename", isOn: $showFilename)
                Toggle("Dynamic title", isOn: $dynamicTitle)
                Toggle("Pause on minimize", isOn: $pauseOnMinimize)
                Toggle("Mute on minimize", isOn: $muteOnMinimize)
                Button("Apply") { applyInterface() }
            }
            Section("Emulation") {
                Toggle("Resample video", isOn: $resampleVideo)
                Toggle("VBA bug compatibility", isOn: $vbaBugCompat)
                Button("Apply") { applyEmulation() }
            }
            Section("Appearance") {
                ColorPicker("App tint", selection: Binding(get: { app.tintColor }, set: { app.setTint(color: $0) }))
                    .labelsHidden()
                Picker("Controls skin", selection: Binding(get: { app.controlsSkin }, set: { app.controlsSkin = $0 })) {
                    Text("System").tag("system")
                    Text("Kenney Input Prompts").tag("kenney")
                }
            }
            Section("Fast forward") {
                Stepper(value: $ffRatio, in: -1...10, step: 0.5) {
                    let label = ffRatio <= 0 ? "Unbounded" : String(format: "%.1f×", ffRatio)
                    Text("Ratio: \(label)")
                }
                Stepper(value: $ffHeldRatio, in: -1...10, step: 0.5) {
                    let label = ffHeldRatio <= 0 ? "Unbounded" : String(format: "%.1f×", ffHeldRatio)
                    Text("Held ratio: \(label)")
                }
                Button("Apply") { app.bridge.setFastForwardRatio(ffRatio); app.bridge.setFastForwardHeldRatio(ffHeldRatio) }
            }
            Section("Rewind") {
                Toggle("Enable rewind", isOn: $rewindEnable)
                Stepper(value: $rewindCapacity, in: 5...120, step: 5) { Text("Capacity (s): \(rewindCapacity)") }
                Stepper(value: $rewindInterval, in: 50...1000, step: 50) { Text("Interval (ms): \(rewindInterval)") }
                Button("Apply") { app.bridge.setRewindEnable(rewindEnable); app.bridge.setRewindBufferCapacity(Int32(rewindCapacity)); app.bridge.setRewindBufferInterval(Int32(rewindInterval)) }
            }
            Section("Game Boy") {
                Toggle("SGB borders", isOn: $sgbBorders)
                Toggle("GBA force GBP", isOn: $gbaForceGbp)
                Picker("Palette preset", selection: $gbPalette) {
                    Text("Default").tag("")
                    ForEach(app.bridge.listGBPalettePresets(), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Button("Apply") {
                    app.bridge.setSGBBorders(sgbBorders)
                    app.bridge.setGBAForceGBP(gbaForceGbp)
                    if !gbPalette.isEmpty { app.bridge.setGBPalettePreset(gbPalette) }
                }
            }
            Section("Multiplayer") {
                Button("Host Game") {
                    MultiplayerManager.shared.startHosting()
                }
                Button("Join Game") {
                    // TODO: Show IP address input dialog
                    // For now, hardcode localhost for testing
                    MultiplayerManager.shared.joinHost("localhost")
                }
                Button("Disconnect") {
                    MultiplayerManager.shared.stop()
                }
            }
            Section("Logging") {
                Toggle("Log to file", isOn: $logToFile)
                Toggle("Log to stdout", isOn: $logToStdout)
                TextField("Log file", text: $logFile)
                    .disabled(!logToFile)
                Picker("Log level", selection: $logLevel) {
                    Text("Fatal").tag(0x01)
                    Text("Error").tag(0x02)
                    Text("Warn").tag(0x04)
                    Text("Info").tag(0x08)
                    Text("Debug").tag(0x10)
                    Text("Stub").tag(0x20)
                    Text("Game Error").tag(0x40)
                    Text("All").tag(0x7F)
                }
                Button("Apply") { applyLogging() }
            }
        }
    }

    private func applyVideo() {
        app.bridge.setVideoSync(videoSync)
        app.bridge.setFpsTarget(Float(fpsTarget))
        app.bridge.setFrameskip(Int32(frameskip))
        app.bridge.setLockIntegerScaling(lockIntegerScaling)
        // Integer scaling is applied on the view directly
        NotificationCenter.default.post(name: .init("mGBA.IntegerScaling"), object: integerScaling)
        app.bridge.setShowOSD(showOSD)
        app.bridge.setShowFrameCounter(showFrameCounter)
        app.bridge.setShowResetInfo(showResetInfo)
        app.bridge.setInterframeBlending(interframeBlending)
        app.bridge.setResampleVideo(resampleVideo)
    }

    private func applyAudio() {
        app.bridge.setAudioSync(audioSync)
        app.bridge.setAudioBuffers(Int32(audioBuffers))
        app.bridge.setSampleRate(Int32(sampleRate))
        app.bridge.setMute(mute)
        app.bridge.setVolume(Int32(volume))
        app.bridge.setFastForwardMute(ffMute)
        app.bridge.setFastForwardVolume(Int32(ffVolume))
    }

    private func applyInterface() {
        app.bridge.setLockAspectRatio(lockAspectRatio)
        app.bridge.setShowResetInfo(showResetInfo)
    }

    private func applyEmulation() {
        app.bridge.setResampleVideo(resampleVideo)
        app.bridge.setVBABugCompat(vbaBugCompat)
    }

    private func applyLogging() {
        app.bridge.setLogToFile(logToFile)
        app.bridge.setLogToStdout(logToStdout)
        if !logFile.isEmpty {
            app.bridge.setLogFile(logFile)
        }
        app.bridge.setLogLevel(Int32(logLevel))
    }
}


