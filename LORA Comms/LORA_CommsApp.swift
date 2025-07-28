//
//  LORA_CommsApp.swift
//  LORA Comms
//
//  Created by Nicholas Weiner on 7/28/25.
//

import SwiftUI

@main
struct LORA_CommsApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
