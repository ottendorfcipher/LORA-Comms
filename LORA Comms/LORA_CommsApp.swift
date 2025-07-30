//
//  LORA_CommsApp.swift
//  LORA Comms
//
//  Created by Nicholas Weiner on 7/28/25.
//

import SwiftUI

@main
struct LORA_CommsApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}
