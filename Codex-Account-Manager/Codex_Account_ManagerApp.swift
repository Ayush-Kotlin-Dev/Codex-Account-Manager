//
//  Codex_Account_ManagerApp.swift
//  Codex-Account-Manager
//
//  Main app entry point for Codex Account Manager
//

import SwiftUI

@main
struct Codex_Account_ManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 540, height: 600)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default New command
            }
        }
    }
}
