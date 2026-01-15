//
//  AppAttestDecoderTestAppApp.swift
//  AppAttestDecoderTestApp
//
//  Created by Michael Danylchuk on 1/11/26.
//

import SwiftUI

@main
struct AppAttestDecoderTestAppApp: App {
    init() {
        // Debug: Log app initialization
        print("[App] AppAttestDecoderTestAppApp initializing...")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    print("[App] ContentView appeared")
                }
        }
    }
}
