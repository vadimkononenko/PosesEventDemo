//
//  PosesEventDemoApp.swift
//  PosesEventDemo
//
//  Created by Vadim Kononenko on 02.10.2026.
//

import SwiftUI

@main
struct PosesEventDemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // Load the ML Kit and Vision models in the background before the first screen needs them.
                .task { await PoseEngineFactory.warmUp() }
        }
    }
}
