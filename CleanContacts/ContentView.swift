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
    @Environment(\.openWindow) private var openWindow
    
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
                    
                    Button("Merge These Contacts") {
                        MergePlanView.contact = mergeContacts(contacts)
                        MergePlanView.originalContacts = contacts
                        MergePlanView.onMergeComplete = {
                            detailStore.onMergeComplete?(contacts)
                        }
                        dismissWindow(id: "duplicateDetails")
                        openWindow(id: "mergePlan")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .frame(width: 400, height: 500)
        }
    }
    
    private func mergeContacts(_ contacts: [CNContact]) -> CNContact {
        // Simplified merge logic: take the first contact and append unique phone numbers and emails
        guard let firstContact = contacts.first else { return CNContact() }
        
        let mergedContact = CNMutableContact()
        mergedContact.givenName = firstContact.givenName
        mergedContact.familyName = firstContact.familyName
        
        var phoneNumbers = Set<String>()
        var emailAddresses = Set<String>()
        
        for contact in contacts {
            phoneNumbers.formUnion(contact.phoneNumbers.map { $0.value.stringValue })
            emailAddresses.formUnion(contact.emailAddresses.map { $0.value as String })
        }
        
        mergedContact.phoneNumbers = phoneNumbers.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
        mergedContact.emailAddresses = emailAddresses.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
        
        return mergedContact
    }
}

struct MergePlanView: View {
    static var contact: CNContact?
    static var originalContacts: [CNContact]?
    static var onMergeComplete: (() -> Void)? // Add callback for merge completion
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        if let contact = MergePlanView.contact {
            VStack(alignment: .leading, spacing: 12) {
                Text("Merge Plan")
                    .font(.title2)
                    .bold()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(contact.givenName) \(contact.familyName)")
                        .font(.headline)
                    
                    if !contact.phoneNumbers.isEmpty {
                        Text("Phone Numbers:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                            HStack(spacing: 4) {
                                Image(systemName: "phone")
                                    .imageScale(.small)
                                Text(phone.value.stringValue)
                            }
                        }
                    }
                    
                    if !contact.emailAddresses.isEmpty {
                        Text("Email Addresses:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(contact.emailAddresses, id: \.hashValue) { email in
                            HStack(spacing: 4) {
                                Image(systemName: "envelope")
                                    .imageScale(.small)
                                Text(email.value as String)
                            }
                        }
                    }
                }
                
                HStack {
                    Button("Close") {
                        dismissWindow(id: "mergePlan")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Merge Contact") {
                        mergeContacts()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)
            .fixedSize()
            .alert("Merge Result", isPresented: $showAlert) {
                Button("OK") {
                    dismissWindow(id: "mergePlan")
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func mergeContacts() {
        guard let mergedContact = MergePlanView.contact as? CNMutableContact,
              let originalContacts = MergePlanView.originalContacts else {
            return
        }
        
        let store = CNContactStore()
        
        do {
            // Fetch full contacts with all required keys
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ]
            
            // Get full contacts with all required keys
            let fullContacts = try originalContacts.map { contact in
                try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keysToFetch)
            }
            
            // Create save request
            let saveRequest = CNSaveRequest()
            
            // Add the merged contact first
            saveRequest.add(mergedContact, toContainerWithIdentifier: nil)
            
            // Delete the original contacts
            for contact in fullContacts {
                let mutableContact = contact.mutableCopy() as! CNMutableContact
                saveRequest.delete(mutableContact)
            }
            
            // Execute the save request
            try store.execute(saveRequest)
            
            // Call the completion handler to update the table
            MergePlanView.onMergeComplete?()
            
            alertMessage = "Contacts successfully merged!"
            showAlert = true
        } catch {
            alertMessage = "Error merging contacts: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

struct DuplicatesTableView: View {
    let duplicateGroups: [String: [CNContact]]
    @State private var mergedGroups: Set<String> = []
    @Environment(\.openWindow) private var openWindow
    @StateObject private var detailStore = DetailViewStore.shared
    
    struct DuplicateEntry: Identifiable {
        let id: UUID
        let name: String
        let count: Int
        let contacts: [CNContact]
    }
    
    var tableData: [DuplicateEntry] {
        duplicateGroups.values.map { contacts in
            let firstContact = contacts[0]
            let name = "\(firstContact.givenName) \(firstContact.familyName)".trimmingCharacters(in: .whitespaces)
            return DuplicateEntry(
                id: UUID(),
                name: name,
                count: contacts.count,
                contacts: contacts
            )
        }.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        Table(tableData) {
            TableColumn("Contact Name", value: \.name)
            TableColumn("Duplicates") { (entry: DuplicateEntry) in
                Text("\(entry.count - 1)")
                    .foregroundStyle(entry.count > 1 ? .red : .secondary)
            }
            TableColumn("Status") { (entry: DuplicateEntry) in
                HStack {
                    if mergedGroups.contains(entry.name) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Button("Detail") {
                        detailStore.selectedContacts = entry.contacts
                        detailStore.onMergeComplete = { contacts in
                            if let firstContact = contacts.first {
                                let name = "\(firstContact.givenName) \(firstContact.familyName)".trimmingCharacters(in: .whitespaces)
                                mergedGroups.insert(name)
                            }
                        }
                        openWindow(id: "duplicateDetails")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minHeight: 400)
    }
    
    private func mergeContacts(_ contacts: [CNContact]) -> CNContact {
        // Simplified merge logic: take the first contact and append unique phone numbers and emails
        guard let firstContact = contacts.first else { return CNContact() }
        
        let mergedContact = CNMutableContact()
        mergedContact.givenName = firstContact.givenName
        mergedContact.familyName = firstContact.familyName
        
        var phoneNumbers = Set<String>()
        var emailAddresses = Set<String>()
        
        for contact in contacts {
            phoneNumbers.formUnion(contact.phoneNumbers.map { $0.value.stringValue })
            emailAddresses.formUnion(contact.emailAddresses.map { $0.value as String })
        }
        
        mergedContact.phoneNumbers = phoneNumbers.map { CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0)) }
        mergedContact.emailAddresses = emailAddresses.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
        
        return mergedContact
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
                            duplicateGroups: duplicateGroups
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
        await MainActor.run {
            isDuplicateSearching = true
        }
        
        // Move to background task
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
                
                // Process duplicates in background
                var groups: [String: [CNContact]] = [:]
                
                for contact in contacts {
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces).lowercased()
                    let phones = contact.phoneNumbers.map { $0.value.stringValue.filter { $0.isNumber } }
                    let emails = contact.emailAddresses.map { $0.value as String }
                    
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
                    
                    for key in keys {
                        groups[key, default: []].append(contact)
                    }
                }
                
                let duplicates = groups.filter { $0.value.count > 1 }
                
                // Update UI on main thread
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
                print("Status: Not determined - showing request button")
                // Don't do anything, let user tap the request button
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
                // Already in a Task, so we can just await
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
                isLoading = true // Show loading while requesting
            }
            
            do {
                let granted = try await store.requestAccess(for: .contacts)
                
                if granted {
                    print("Access granted, loading contacts...")
                    await loadContacts()
                } else {
                    print("Access denied by user")
                    await MainActor.run {
                        isLoading = false
                        alertMessage = "Access denied. Please try again or grant access in System Settings."
                        showAlert = true
                    }
                }
            } catch {
                print("Error requesting access: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Error: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}
