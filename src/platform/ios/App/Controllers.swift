// Controllers.swift
// mGBA
//
// Created by SternXD on 9/13/25.
//

import SwiftUI
import Foundation
import GameController
import Network

@MainActor
final class ControllerManager {
    static let shared = ControllerManager()
    private init() { }

    private var app: AppState?

    func start(app: AppState) {
        self.app = app
        NotificationCenter.default.addObserver(self, selector: #selector(handleConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        GCController.startWirelessControllerDiscovery {}
        GCController.controllers().forEach { setup($0) }
    }

    @objc private func handleConnect(_ note: Notification) {
        guard let c = note.object as? GCController else { return }
        setup(c)
        app?.hasController = true
    }

    @objc private func handleDisconnect(_ note: Notification) {
        if GCController.controllers().isEmpty { app?.hasController = false }
    }

    private func setup(_ controller: GCController) {
        guard let app else { return }
        if let gp = controller.extendedGamepad {
            gp.valueChangedHandler = { [weak app] _, element in
                guard let app else { return }
                var add: UInt32 = 0
                var clear: UInt32 = 0

                func toggle(_ pressed: Bool, bit: Int) {
                    if pressed { add |= 1 << bit } else { clear |= 1 << bit }
                }

                // Map: A,B,X->SELECT,Y->START; shoulders L/R; dpad; start/select
                toggle(gp.buttonA.isPressed, bit: 0) // A
                toggle(gp.buttonB.isPressed, bit: 1) // B
                toggle(gp.buttonOptions?.isPressed ?? false, bit: 2) // SELECT
                toggle(gp.buttonMenu.isPressed, bit: 3) // START
                toggle(gp.dpad.right.isPressed || gp.leftThumbstick.xAxis.value > 0.5, bit: 4) // D-PAD RIGHT
                toggle(gp.dpad.left.isPressed || gp.leftThumbstick.xAxis.value < -0.5, bit: 5) // D-PAD LEFT
                toggle(gp.dpad.up.isPressed || gp.leftThumbstick.yAxis.value > 0.5, bit: 6) // D-PAD UP
                toggle(gp.dpad.down.isPressed || gp.leftThumbstick.yAxis.value < -0.5, bit: 7) // D-PAD DOWN
                toggle(gp.rightShoulder.isPressed || gp.rightTrigger.isPressed, bit: 8) // R
                toggle(gp.leftShoulder.isPressed || gp.leftTrigger.isPressed, bit: 9) // L

                if clear != 0 { app.bridge.clearKeys(clear) }
                if add != 0 { app.bridge.addKeys(add) }
            }
        }
    }
}

@MainActor
final class MultiplayerManager {
    static let shared = MultiplayerManager()
    private init() { }

    private var app: AppState?
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var isHosting = false

    func start(app: AppState) {
        self.app = app
        print("Multiplayer: Manager started - networking layer ready")
    }

    func startHosting() {
        guard !isHosting else { return }

        print("Multiplayer: Starting host...")

        do {
            listener = try NWListener(using: .tcp, on: 8888)
            listener?.service = NWListener.Service(name: "mGBA-Multiplayer", type: "_mgba._tcp")
            listener?.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    switch state {
                    case .ready:
                        print("Multiplayer: Listening on port 8888")
                        self?.isHosting = true
                    case .failed(let error):
                        print("Multiplayer: Listener failed: \(error)")
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.handleNewConnection(connection)
                }
            }

            listener?.start(queue: .main)
        } catch {
            print("Multiplayer: Failed to start listener: \(error)")
        }
    }

    func joinHost(_ host: String) {
        print("Multiplayer: Joining host at \(host)...")

        let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port("8888")!, using: .tcp)
        connections.append(connection)
        setupConnection(connection)
        connection.start(queue: .main)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connections.append(connection)
        setupConnection(connection)
        connection.start(queue: .main)
    }

    private func setupConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("Multiplayer: Connection ready")
                    self?.startReceiving(on: connection)
                case .failed(let error):
                    print("Multiplayer: Connection failed: \(error)")
                    if let index = self?.connections.firstIndex(where: { $0 === connection }) {
                        self?.connections.remove(at: index)
                    }
                default:
                    break
                }
            }
        }
    }

    private func startReceiving(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data {
                // TODO: Process received multiplayer data and feed to lockstep
                print("Multiplayer: Received \(data.count) bytes")
            }

            if error == nil && !isComplete {
                self?.startReceiving(on: connection)
            }
        }
    }

    func sendData(_ data: Data) {
        for connection in connections where connection.state == .ready {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("Multiplayer: Send failed: \(error)")
                }
            })
        }
    }

    func stop() {
        print("Multiplayer: Stopping...")

        listener?.cancel()
        listener = nil
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        isHosting = false
    }
}
