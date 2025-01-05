import SwiftUI
import SwiftData

@main
struct CleanContactsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        Window("Duplicate Details", id: "duplicateDetails") {
            DuplicateDetailView()
        }
    }
}
