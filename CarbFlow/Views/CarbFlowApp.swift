//
//  CarbFlowApp.swift
//  CarbFlow
//
//  Created by Luke Latham on 18/10/2025.
//

import SwiftUI
import SwiftData
import CoreData

@main
struct CarbFlowApp: App {
    init() {
        FeatureFlags.configure()
        #if DEBUG
        print("[FeatureFlags] cf_food_local_store = \(FeatureFlags.foodLocalStoreEnabled)")
        print("[FeatureFlags] cf_scan_enabled = \(FeatureFlags.scanEnabled)")
        #endif
        NonFatalReporter.configure()
        scheduleFoodSeedInstall()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

private extension CarbFlowApp {
    func scheduleFoodSeedInstall() {
        guard CFFlags.isEnabled(.cf_fooddb) else {
            #if DEBUG
            print("[SeedInstaller] cf_fooddb disabled; skipping seed install.")
            #endif
            return
        }

        let seedVersion: Int64 = 1
        Task {
            let context = await MainActor.run { () -> NSManagedObjectContext in
                cf_logEvent("seed_install_start", ["version": seedVersion])
                return CFPersistence.shared.newBackgroundContext()
            }
            CFSeedInstaller.installIfNeeded(
                seedResourceName: "foods_seed_v1",
                seedVersion: seedVersion,
                context: context
            )
        }
    }
}
