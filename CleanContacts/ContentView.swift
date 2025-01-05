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
                        VStack {
                            Image(systemName: "person.crop.circle.badge.exclamationmark")
                                .font(.system(size: 50))
                                .padding()
                            Text("Contact Access Required")
                                .font(.headline)
                            Text("This app needs access to your contacts")
                                .foregroundStyle(.secondary)
                            Button("Open Settings") {
                                openSettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
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
        .onAppear {
            loadContacts()
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Contacts") {
            NSWorkspace.shared.open(settingsUrl)
        }
    }
    
    private func loadContacts() {
        let store = CNContactStore()
        
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, error in
                if !granted {
                    alertMessage = "Please grant access to contacts in System Settings to use this feature."
                    showAlert = true
                } else {
                    Task { await fetchContacts(store) }
                }
            }
        case .authorized:
            Task { await fetchContacts(store) }
        case .denied, .restricted:
            alertMessage = "Contact access denied. Please grant access in System Settings."
            showAlert = true
        @unknown default:
            alertMessage = "Unknown authorization status"
            showAlert = true
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
    
    // Keep your existing duplicate scanning methods...
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}
