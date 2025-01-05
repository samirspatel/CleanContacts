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

struct DuplicatesTableView: View {
    let duplicateGroups: [String: [CNContact]]
    
    // Define a struct for our table data that conforms to Identifiable
    struct DuplicateEntry: Identifiable {
        let id: String // name will be our id
        let name: String
        let count: Int
    }
    
    var tableData: [DuplicateEntry] {
        duplicateGroups.values.map { contacts in
            let firstContact = contacts[0]
            let name = "\(firstContact.givenName) \(firstContact.familyName)".trimmingCharacters(in: .whitespaces)
            return DuplicateEntry(id: name, name: name, count: contacts.count)
        }.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        Table(tableData) {
            TableColumn("Contact Name", value: \.name)
            TableColumn("Duplicates") { entry in
                Text("\(entry.count - 1)")
                    .foregroundStyle(entry.count > 1 ? .red : .secondary)
            }
        }
        .frame(minHeight: 400)
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
    @State private var isLoading = false
    @State private var duplicateGroups: [String: [CNContact]] = [:] // Key is name+phone/email, Value is array of duplicate contacts
    @State private var isDuplicateSearching = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                Group {
                    if isLoading || isDuplicateSearching {
                        VStack {
                            ProgressView()
                                .controlSize(.large)
                            Text(isDuplicateSearching ? "Scanning for Duplicates..." : "Loading Contacts...")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !hasContactAccess {
                        // Show permission request view
                        VStack(spacing: 20) {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 50))
                                .padding()
                            Text("Contact Access Required")
                                .font(.headline)
                            Text("This app needs access to your contacts")
                                .foregroundStyle(.secondary)
                            
                            Button("Request Access") {
                                requestContactsAccess()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack {
                            if duplicateGroups.isEmpty {
                                Button("Find Duplicates") {
                                    Task {
                                        await findDuplicates()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .padding()
                            } else {
                                DuplicatesTableView(duplicateGroups: duplicateGroups)
                                    .padding()
                            }
                        }
                    }
                }
                .navigationTitle("Duplicate Contacts (\(totalDuplicates))")
            }
            .tabItem {
                Label("Duplicates", systemImage: "person.2")
            }
            .tag(0)
        }
        .onAppear {
            checkContactsAccess()
        }
    }
    
    private var hasContactAccess: Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    private var totalDuplicates: Int {
        duplicateGroups.values.reduce(0) { $0 + max($1.count - 1, 0) }
    }
    
    private func findDuplicates() async {
        isDuplicateSearching = true
        defer { isDuplicateSearching = false }
        
        let store = CNContactStore()
        
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
            
            // Group contacts by potential duplicates
            var groups: [String: [CNContact]] = [:]
            
            for contact in contacts {
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces).lowercased()
                let phones = contact.phoneNumbers.map { $0.value.stringValue.filter { $0.isNumber } }
                let emails = contact.emailAddresses.map { $0.value as String }
                
                // Create keys for matching
                var keys: Set<String> = []
                
                // Add name-based key if name is not empty
                if !name.isEmpty {
                    keys.insert("n_\(name)")
                }
                
                // Add phone-based keys
                for phone in phones {
                    if !phone.isEmpty {
                        keys.insert("p_\(phone)")
                    }
                }
                
                // Add email-based keys
                for email in emails {
                    if !email.isEmpty {
                        keys.insert("e_\(email)")
                    }
                }
                
                // Add contact to all matching groups
                for key in keys {
                    groups[key, default: []].append(contact)
                }
            }
            
            // Filter out groups with no duplicates
            let duplicates = groups.filter { $0.value.count > 1 }
            
            await MainActor.run {
                duplicateGroups = duplicates
            }
        } catch {
            await MainActor.run {
                alertMessage = "Error scanning contacts: \(error.localizedDescription)"
                showAlert = true
            }
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
        
        print("Loading contacts...")
        Task {
            await fetchContacts(store)
            // Hide loading indicator after contacts are loaded
            await MainActor.run {
                isLoading = false
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
            print("Status: Not determined - showing request button")
            // Don't do anything, let user tap the request button
        case .restricted, .denied:
            print("Access restricted or denied")
            alertMessage = "This app needs access to your contacts. Please grant access in System Settings."
            showAlert = true
        case .authorized:
            print("Access already authorized - loading contacts")
            isLoading = true
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
        print("Requesting contacts access...")
        isLoading = true // Show loading while requesting
        
        store.requestAccess(for: .contacts) { granted, error in
            if let error = error {
                print("Error requesting access: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isLoading = false
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            
            if granted {
                print("Access granted, loading contacts...")
                loadContacts()
            } else {
                print("Access denied by user")
                DispatchQueue.main.async {
                    isLoading = false
                    self.alertMessage = "Access denied. Please try again or grant access in System Settings."
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
