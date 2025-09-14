// EmulatorGLView.swift
// mGBA
//
// Created by SternXD on 9/12/25.
//

import SwiftUI

struct EmulatorGLView: UIViewRepresentable {
    typealias UIViewType = GLRenderView

    let bridge: MGBCoreBridge

    func makeUIView(context: Context) -> GLRenderView {
        let view = GLRenderView(frame: .zero)
        view.attach(bridge)
        bridge.videoFrame = { [weak view] (pixels: UnsafeRawPointer, width: Int32, height: Int32, stride: Int32) in
            guard let v = view else { return }
            DispatchQueue.main.async {
                v.updateFrame(withPixels: pixels, width: width, height: height, stride: Int(stride))
            }
        }
        view.startDisplay()
        return view
    }

    func updateUIView(_ uiView: GLRenderView, context: Context) {
        // No-op
    }

    static func dismantleUIView(_ uiView: GLRenderView, coordinator: ()) {
        uiView.stopDisplay()
    }
}
