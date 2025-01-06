import SwiftUI
import SwiftData
import Contacts

class DetailViewStore: ObservableObject {
    static let shared = DetailViewStore()
    @Published var selectedContacts: [CNContact]?
    @Published var onMergeComplete: (([CNContact]) -> Void)?
}

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

struct DuplicateDetailView: View {
    @StateObject private var detailStore = DetailViewStore.shared
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        if let contacts = detailStore.selectedContacts {
            VStack {
                HStack {
                    Text("Duplicate Details")
                        .font(.title2)
                        .bold()
                    Spacer()
                }
                .padding()
                
                List(contacts, id: \.identifier) { contact in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(contact.givenName) \(contact.familyName)")
                            .font(.headline)
                        
                        if !contact.phoneNumbers.isEmpty {
                            Text("Phone Numbers:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                                HStack {
                                    Image(systemName: "phone")
                                    Text(phone.value.stringValue)
                                }
                            }
                        }
                        
                        if !contact.emailAddresses.isEmpty {
                            Text("Email Addresses:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            ForEach(contact.emailAddresses, id: \.hashValue) { email in
                                HStack {
                                    Image(systemName: "envelope")
                                    Text(email.value as String)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                HStack {
                    Button("Close") {
                        dismissWindow(id: "duplicateDetails")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Merge Contacts") {
                        mergeContacts(contacts)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .frame(width: 400, height: 500)
            .alert("Merge Result", isPresented: $showAlert) {
                Button("OK") {
                    if !alertMessage.contains("Error") {
                        detailStore.onMergeComplete?(contacts)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dismissWindow(id: "duplicateDetails")
                            detailStore.selectedContacts = nil
                            detailStore.onMergeComplete = nil
                        }
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func mergeContacts(_ contacts: [CNContact]) {
        let store = CNContactStore()
        
        do {
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ]
            
            let fullContacts = try contacts.map { contact in
                try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch)
            }
            
            // Create merged contact
            let mergedContact = CNMutableContact()
            mergedContact.givenName = contacts[0].givenName
            mergedContact.familyName = contacts[0].familyName
            
            var phoneNumbers = Set<String>()
            var emailAddresses = Set<String>()
            
            for contact in contacts {
                phoneNumbers.formUnion(contact.phoneNumbers.map { $0.value.stringValue })
                emailAddresses.formUnion(contact.emailAddresses.map { $0.value as String })
            }
            
            mergedContact.phoneNumbers = phoneNumbers.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
            mergedContact.emailAddresses = emailAddresses.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
            
            let saveRequest = CNSaveRequest()
            saveRequest.add(mergedContact, toContainerWithIdentifier: nil)
            
            for contact in fullContacts {
                let mutableContact = contact.mutableCopy() as! CNMutableContact
                saveRequest.delete(mutableContact)
            }
            
            try store.execute(saveRequest)
            
            alertMessage = "Contacts successfully merged!"
            showAlert = true
        } catch {
            alertMessage = "Error merging contacts: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

struct DuplicatesTableView: View {
    @Binding var duplicateGroups: [String: [CNContact]]
    @State private var selectedItems: Set<String> = []
    @State private var showDeleteAlert = false
    @Environment(\.openWindow) private var openWindow
    @StateObject private var detailStore = DetailViewStore.shared
    
    struct DuplicateEntry: Identifiable {
        let id: String
        let name: String
        let count: Int
        let contacts: [CNContact]
    }
    
    var tableData: [DuplicateEntry] {
        duplicateGroups.values.map { contacts in
            let firstContact = contacts[0]
            let name = "\(firstContact.givenName) \(firstContact.familyName)".trimmingCharacters(in: .whitespaces)
            return DuplicateEntry(
                id: name,
                name: name,
                count: contacts.count,
                contacts: contacts
            )
        }.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        VStack {
            HStack {
                if !selectedItems.isEmpty {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("\(selectedItems.count) selected")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 4)
            
            Table(tableData, selection: $selectedItems) {
                TableColumn("Contact Name") { entry in
                    Text(entry.name)
                        .background(selectedItems.contains(entry.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                }
                TableColumn("Duplicates") { entry in
                    Text("\(entry.count - 1)")
                        .foregroundStyle(entry.count > 1 ? .red : .secondary)
                        .background(selectedItems.contains(entry.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                }
                TableColumn("Status") { entry in
                    Button("Detail") {
                        detailStore.selectedContacts = entry.contacts
                        detailStore.onMergeComplete = { contacts in
                            if let firstContact = contacts.first {
                                // Remove the merged group from duplicateGroups
                                let name = "\(firstContact.givenName) \(firstContact.familyName)".trimmingCharacters(in: .whitespaces)
                                duplicateGroups.removeValue(forKey: name.lowercased())
                            }
                        }
                        openWindow(id: "duplicateDetails")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(minHeight: 400)
        }
        .alert("Delete Contacts", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedContacts()
            }
        } message: {
            Text("Are you sure you want to delete the selected contacts? This action cannot be undone.")
        }
    }
    
    private func deleteSelectedContacts() {
        let store = CNContactStore()
        let selectedContacts = selectedItems.compactMap { id in
            tableData.first(where: { $0.id == id })?.contacts
        }.flatMap { $0 }
        
        Task {
            do {
                let keysToFetch: [CNKeyDescriptor] = [
                    CNContactIdentifierKey as CNKeyDescriptor,
                    CNContactGivenNameKey as CNKeyDescriptor,
                    CNContactFamilyNameKey as CNKeyDescriptor
                ]
                
                let fullContacts = try selectedContacts.map { contact in
                    try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch)
                }
                
                let saveRequest = CNSaveRequest()
                
                for contact in fullContacts {
                    let mutableContact = contact.mutableCopy() as! CNMutableContact
                    saveRequest.delete(mutableContact)
                }
                
                try store.execute(saveRequest)
                
                // Update UI on main thread
                await MainActor.run {
                    // Remove the deleted contacts from duplicateGroups
                    let deletedIds = Set(fullContacts.map { $0.identifier })
                    duplicateGroups = duplicateGroups.mapValues { contacts in
                        contacts.filter { !deletedIds.contains($0.identifier) }
                    }
                    // Remove any groups that now have less than 2 contacts
                    duplicateGroups = duplicateGroups.filter { $0.value.count > 1 }
                    selectedItems.removeAll()
                }
                
            } catch {
                print("Error deleting contacts: \(error.localizedDescription)")
            }
        }
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
                        DuplicatesTableView(
                            duplicateGroups: $duplicateGroups
                        )
                        .padding()
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
            verifyEntitlements()
            checkContactsAccess()
        }
    }
    
    private var hasContactAccess: Bool {
        // Add debug print to see what status we're getting
        let status = CNContactStore.authorizationStatus(for: .contacts)
        print("Current contact access status: \(status.rawValue)")
        return status == .authorized
    }
    
    private var totalDuplicates: Int {
        duplicateGroups.values.reduce(0) { $0 + max($1.count - 1, 0) }
    }
    
    private func findDuplicates() async {
        await MainActor.run {
            isDuplicateSearching = true
        }
        
        await Task.detached(priority: .background) {
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
                
                var groups: [String: Set<CNContact>] = [:]
                
                for contact in contacts {
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces).lowercased()
                    let phones = contact.phoneNumbers.map { $0.value.stringValue.filter { $0.isNumber } }
                    let emails = contact.emailAddresses.map { $0.value as String }
                    
                    // Skip contacts with no identifying information
                    guard !name.isEmpty || !phones.isEmpty || !emails.isEmpty else { continue }
                    
                    var keys: Set<String> = []
                    
                    if !name.isEmpty {
                        keys.insert("n_\(name)")
                    }
                    
                    for phone in phones where !phone.isEmpty {
                        keys.insert("p_\(phone)")
                    }
                    
                    for email in emails where !email.isEmpty {
                        keys.insert("e_\(email)")
                    }
                    
                    // Only group contacts that have at least one matching criteria
                    if !keys.isEmpty {
                        let groupKey = !name.isEmpty ? name : (phones.first ?? emails.first ?? "unknown")
                        groups[groupKey, default: []].insert(contact)
                        
                        for key in keys {
                            if let relatedContacts = groups[key] {
                                groups[groupKey]?.formUnion(relatedContacts)
                                groups.removeValue(forKey: key)
                            }
                        }
                    }
                }
                
                // Filter out groups with no name and single contacts
                let duplicates = groups
                    .filter { !$0.key.isEmpty && $0.value.count > 1 }
                    .mapValues { Array($0) }
                
                await MainActor.run {
                    duplicateGroups = duplicates
                    isDuplicateSearching = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Error scanning contacts: \(error.localizedDescription)"
                    showAlert = true
                    isDuplicateSearching = false
                }
            }
        }.value
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
    
    private func loadContacts() async {
        let store = CNContactStore()
        print("Loading contacts...")
        await fetchContacts(store)
        
        // After contacts are loaded, automatically scan for duplicates
        await findDuplicates()
        
        // Hide loading indicator after everything is done
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func fetchContacts(_ store: CNContactStore) async {
        // Move to background task
        await Task.detached(priority: .background) {
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
                
                // Sort contacts in background before updating UI
                let sortedContacts = contacts.sorted { 
                    ($0.givenName + $0.familyName).lowercased() < 
                    ($1.givenName + $1.familyName).lowercased() 
                }
                
                // Update UI on main thread
                await MainActor.run {
                    allContacts = sortedContacts
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Error loading contacts: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }.value
    }
    
    private func checkContactsAccess() {
        Task {
            print("Checking contacts access for bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
            let status = CNContactStore.authorizationStatus(for: .contacts)
            print("Initial authorization status: \(status.rawValue)")
            
            switch status {
            case .notDetermined:
                print("Status: Not determined - requesting access")
                await requestContactsAccess() // Directly request access instead of waiting for button
            case .restricted, .denied:
                print("Access restricted or denied")
                await MainActor.run {
                    alertMessage = "This app needs access to your contacts. Please grant access in System Settings."
                    showAlert = true
                }
            case .authorized:
                print("Access already authorized - loading contacts")
                await MainActor.run {
                    isLoading = true
                }
                await loadContacts()
            @unknown default:
                print("Unknown authorization status")
                await MainActor.run {
                    alertMessage = "Unknown contacts access status. Please check System Settings."
                    showAlert = true
                }
            }
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
        Task {
            let store = CNContactStore()
            print("Requesting contacts access...")
            
            await MainActor.run {
                isLoading = true
            }
            
            // First check current status
            let currentStatus = CNContactStore.authorizationStatus(for: .contacts)
            print("Current status before request: \(currentStatus.rawValue)")
            
            if currentStatus == .authorized {
                print("Already authorized, loading contacts directly")
                await loadContacts()
                return
            }
            
            do {
                // Test access first with a simple fetch
                try await testContactsAccessAsync(store)
                
                let granted = try await store.requestAccess(for: .contacts)
                print("Access request result: \(granted)")
                
                if granted {
                    print("Access granted, loading contacts...")
                    // Add a longer delay to ensure the permission is properly registered
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                    await loadContacts()
                } else {
                    print("Access denied by user")
                    await MainActor.run {
                        isLoading = false
                        alertMessage = "Access denied. Please grant access in System Settings."
                        showAlert = true
                    }
                }
            } catch {
                print("Error requesting access: \(error.localizedDescription)")
                print("Detailed error: \(error)")
                
                // If we get an error but actually have access, try loading anyway
                if CNContactStore.authorizationStatus(for: .contacts) == .authorized {
                    print("Despite error, we have authorization. Trying to load...")
                    await loadContacts()
                    return
                }
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Error requesting access: \(error.localizedDescription)\nPlease try granting access in System Settings."
                    showAlert = true
                }
            }
        }
    }
    
    // New async test function
    private func testContactsAccessAsync(_ store: CNContactStore) async throws {
        let keys = [CNContactGivenNameKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        
        // Try to fetch a single contact
        var gotContact = false
        try store.enumerateContacts(with: request) { contact, stop in
            print("Successfully accessed contact: \(contact.givenName)")
            gotContact = true
            stop.pointee = true
        }
        
        print("Test access result: \(gotContact ? "succeeded" : "no contacts found")")
    }
    
    private func verifyEntitlements() {
        let securityScopedResource = Bundle.main.object(forInfoDictionaryKey: "com.apple.security.personal-information.addressbook") as? Bool
        print("Contacts entitlement present: \(securityScopedResource == true)")
        
        // Print all entitlements for debugging
        if let path = Bundle.main.path(forResource: "CleanContacts", ofType: "entitlements") {
            print("Entitlements file found at: \(path)")
            if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                print("Entitlements contents: \(String(data: data, encoding: .utf8) ?? "unable to read")")
            }
        } else {
            print("No entitlements file found in bundle")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}
