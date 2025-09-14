// AppState.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
final class AppState {
    var bridge: MGBCoreBridge = MGBCoreBridge()
    var loadedPath: String? = nil
    var isRunning: Bool = false
    var hasController: Bool = false

    private let tintDefaultsKey = "appTintHex"
    var tintHex: String? {
        didSet { UserDefaults.standard.setValue(tintHex, forKey: tintDefaultsKey) }
    }
    init() {
        tintHex = UserDefaults.standard.string(forKey: tintDefaultsKey)
        controlsSkin = UserDefaults.standard.string(forKey: controlsSkinKey) ?? "system"
    }
    var tintColor: Color {
        if let hex = tintHex, let c = AppState.color(fromHex: hex) { return c }
        return .mint
    }
    func setTint(color: Color) {
        if let hex = AppState.hexString(from: color) { tintHex = hex }
    }

    // MARK: - Color helpers
    private static func color(fromHex hex: String) -> Color? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let val = UInt64(s, radix: 16) else { return nil }
        let a, r, g, b: Double
        if s.count == 8 {
            a = Double((val >> 24) & 0xFF) / 255.0
            r = Double((val >> 16) & 0xFF) / 255.0
            g = Double((val >> 8) & 0xFF) / 255.0
            b = Double(val & 0xFF) / 255.0
        } else {
            a = 1.0
            r = Double((val >> 16) & 0xFF) / 255.0
            g = Double((val >> 8) & 0xFF) / 255.0
            b = Double(val & 0xFF) / 255.0
        }
        return Color(red: r, green: g, blue: b, opacity: a)
    }
    private static func hexString(from color: Color) -> String? {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let ri = Int(round(r * 255)), gi = Int(round(g * 255)), bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    // MARK: - Controls skin
    private let controlsSkinKey = "controlsSkin"
    var controlsSkin: String = "system" { // "system" or "kenney"
        didSet { UserDefaults.standard.setValue(controlsSkin, forKey: controlsSkinKey) }
    }

    func loadROM(at path: String) {
        bridge.start(withROMPath: path)
        loadedPath = path
        isRunning = true
    }

    func stop() {
        bridge.flushSaves()
        bridge.stop()
        isRunning = false
    }
}


