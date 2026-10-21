import SwiftUI
import SwiftData

@main
struct PetTimelineApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Pet.self, TimelineEvent.self, EventPhoto.self])
    }
}
