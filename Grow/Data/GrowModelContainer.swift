import Foundation
import SwiftData

/// Shared SwiftData container for the whole app (and, later, the widget + App Intents).
///
/// CloudKit private-DB sync is enabled on device; on the simulator it's disabled (the
/// simulator has no signed-in iCloud + CloudKit container), matching Anchor's approach.
/// Always falls back to an on-disk local store, and finally an in-memory store, so the
/// app never hard-crashes on container init.
enum GrowModelContainer {

    static let schema = Schema([
        Grow.self,
        GrowPhoto.self,
        CareTask.self,
        CareLog.self,
        Reading.self,
        Reel.self,
        Diagnosis.self,
        StreakState.self,
        Achievement.self,
    ])

    static let shared: ModelContainer = {
        // 1. Try CloudKit-synced (device only).
        #if !targetEnvironment(simulator)
        do {
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.sviftstudios.Grow")
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            print("⚠️ Grow: CloudKit container init failed (\(error)). Falling back to local.")
            #endif
        }
        #endif

        // 2. Local on-disk store.
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            print("⚠️ Grow: local container init failed (\(error)). Falling back to in-memory.")
            #endif
        }

        // 3. Last resort: in-memory (keeps the app usable for the session).
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Grow: could not create any ModelContainer: \(error)")
        }
    }()
}
