import SwiftUI
import SwiftData
import Contacts

@main
struct CleanContactsApp: App {
    static func main() {
        // Entry point for the app
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        
        Window("Duplicate Details", id: "duplicateDetails") {
            DuplicateDetailView()
        }
    }
}
