@main
struct CleanContactsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar) // Optional: for a more modern look
        
        Window("Duplicate Details", id: "duplicateDetails") {
            DuplicateDetailView()
        }
    }
} 