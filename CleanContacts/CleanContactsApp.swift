import SwiftUI
import SwiftData
import Contacts

@main
struct CleanContactsApp: App {
    static func main() {
        NSApplication.shared.run()
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
