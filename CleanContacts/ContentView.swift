import SwiftUI
import SwiftData
import Contacts

struct ContactRowView: View {
    let contact: CNContact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(contact.givenName) \(contact.familyName)")
                .font(.headline)
            
            ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                HStack {
                    Image(systemName: "phone")
                        .font(.caption)
                    Text(phone.value.stringValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            ForEach(contact.emailAddresses, id: \.hashValue) { email in
                HStack {
                    Image(systemName: "envelope")
                        .font(.caption)
                    Text(email.value as String)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var contacts: [Contact]
    @State private var isScanning = false
    @State private var duplicates: [(Contact, Contact)] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var allContacts: [CNContact] = []
    @State private var selectedTab = 0
    @State private var showSettings = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                Group {
                    if allContacts.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 50))
                                .padding()
                            Text("Contact Access Required")
                                .font(.headline)
                            Text("This app needs access to your contacts")
                                .foregroundStyle(.secondary)
                            
                            // Add direct request button
                            Button("Request Access") {
                                requestContactsAccess()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            // Add test button for debugging
                            Button("Test Access") {
                                testContactsAccess()
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(allContacts, id: \.identifier) { contact in
                                ContactRowView(contact: contact)
                            }
                        }
                    }
                }
                .navigationTitle("All Contacts (\(allContacts.count))")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: loadContacts) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .tabItem {
                Label("Contacts", systemImage: "person.2")
            }
            .tag(0)
            
            // Rest of your existing TabView content...
        }
        .alert("Contacts Access", isPresented: $showAlert) {
            Button("Open Settings") {
                openSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            checkContactsAccess()
        }
    }
    
    private func openSettings() {
        // Try to open System Settings directly to Privacy & Security
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback to opening System Settings
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Settings.app"))
        }
    }
    
    private func loadContacts() {
        let store = CNContactStore()
        
        print("Requesting contacts access...")
        store.requestAccess(for: .contacts) { granted, error in
            if let error = error {
                print("Error requesting access: \(error.localizedDescription)")
                return
            }
            
            if granted {
                print("Access granted, fetching contacts...")
                Task {
                    await fetchContacts(store)
                }
            } else {
                print("Access denied by user")
                DispatchQueue.main.async {
                    self.alertMessage = """
                        Please follow these steps to grant access:
                        1. Open System Settings
                        2. Click on Privacy & Security
                        3. Scroll down to Contacts
                        4. Find CleanContacts in the list
                        5. Toggle the switch to allow access
                        """
                    self.showAlert = true
                }
            }
        }
    }
    
    private func fetchContacts(_ store: CNContactStore) async {
        do {
            let keysToFetch = [
                CNContactGivenNameKey,
                CNContactFamilyNameKey,
                CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey
            ] as [CNKeyDescriptor]
            
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            var contacts: [CNContact] = []
            
            try store.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
            
            await MainActor.run {
                allContacts = contacts.sorted { 
                    ($0.givenName + $0.familyName).lowercased() < 
                    ($1.givenName + $1.familyName).lowercased() 
                }
            }
        } catch {
            await MainActor.run {
                alertMessage = "Error loading contacts: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func checkContactsAccess() {
        print("Checking contacts access for bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        let status = CNContactStore.authorizationStatus(for: .contacts)
        print("Initial authorization status: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("Requesting contacts access...")
            loadContacts() // This will trigger the permission request
        case .restricted, .denied:
            print("Access restricted or denied")
            alertMessage = "This app needs access to your contacts. Please grant access in System Settings."
            showAlert = true
        case .authorized:
            print("Access already authorized")
            loadContacts()
        @unknown default:
            print("Unknown authorization status")
            alertMessage = "Unknown contacts access status. Please check System Settings."
            showAlert = true
        }
    }
    
    private func testContactsAccess() {
        let store = CNContactStore()
        
        // First try to fetch a single contact to trigger the permission prompt
        let keys = [CNContactGivenNameKey] as [CNKeyDescriptor]
        let fetchRequest = CNContactFetchRequest(keysToFetch: keys)
        
        do {
            try store.enumerateContacts(with: fetchRequest) { contact, stop in
                print("Successfully accessed contact: \(contact.givenName)")
                stop.pointee = true  // Stop after first contact
            }
        } catch {
            print("Error accessing contacts: \(error)")
            if let error = error as? CNError {
                print("CNError code: \(error.code.rawValue)")
            }
        }
    }
    
    private func requestContactsAccess() {
        let store = CNContactStore()
        print("Directly requesting contacts access...")
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        
        // First check if we can even request access
        let status = CNContactStore.authorizationStatus(for: .contacts)
        print("Current status: \(status.rawValue)")
        
        // Force the permission prompt
        store.requestAccess(for: .contacts) { granted, error in
            print("Request access callback - granted: \(granted)")
            if let error = error {
                print("Error requesting access: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            
            if granted {
                print("Access granted!")
                Task {
                    await fetchContacts(store)
                }
            } else {
                print("Access denied")
                DispatchQueue.main.async {
                    self.alertMessage = "Access denied. Please try again."
                    self.showAlert = true
                }
            }
        }
    }
    
    // Keep your existing duplicate scanning methods...
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}
