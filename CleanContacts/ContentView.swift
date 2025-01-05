//
//  ContentView.swift
//  CleanContacts
//
//  Created by Samir Patel on 1/4/25.
//

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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // All Contacts Tab
            NavigationStack {
                List {
                    ForEach(allContacts, id: \.identifier) { contact in
                        ContactRowView(contact: contact)
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
            
            // Duplicates Tab
            NavigationStack {
                List {
                    if duplicates.isEmpty {
                        Text("No duplicates found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(duplicates.enumerated()), id: \.offset) { _, pair in
                            DuplicateContactView(contact1: pair.0, contact2: pair.1)
                        }
                    }
                }
                .navigationTitle("Duplicates")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: scanForDuplicates) {
                            Label("Scan", systemImage: "magnifyingglass")
                        }
                        .disabled(isScanning)
                    }
                }
                .overlay {
                    if isScanning {
                        ProgressView("Scanning contacts...")
                    }
                }
            }
            .tabItem {
                Label("Duplicates", systemImage: "person.2.slash")
            }
            .tag(1)
        }
        .alert("Contact Access", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadContacts()
        }
    }
    
    private func loadContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                Task {
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
            } else {
                alertMessage = "Please grant access to contacts in System Settings to use this feature."
                showAlert = true
            }
        }
    }
    
    private func scanForDuplicates() {
        isScanning = true
        let store = CNContactStore()
        
        store.requestAccess(for: .contacts) { granted, error in
            if granted {
                Task {
                    await findDuplicates(in: store)
                }
            } else {
                alertMessage = "Please grant access to contacts in System Settings to use this feature."
                showAlert = true
                isScanning = false
            }
        }
    }
    
    private func findDuplicates(in store: CNContactStore) async {
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
            
            // Find duplicates based on name or contact info
            var newDuplicates: [(Contact, Contact)] = []
            
            for i in 0..<contacts.count {
                for j in (i + 1)..<contacts.count {
                    let contact1 = contacts[i]
                    let contact2 = contacts[j]
                    
                    if isDuplicate(contact1, contact2) {
                        let modelContact1 = Contact(
                            firstName: contact1.givenName,
                            lastName: contact1.familyName,
                            phoneNumbers: contact1.phoneNumbers.map { $0.value.stringValue },
                            emailAddresses: contact1.emailAddresses.map { $0.value as String }
                        )
                        
                        let modelContact2 = Contact(
                            firstName: contact2.givenName,
                            lastName: contact2.familyName,
                            phoneNumbers: contact2.phoneNumbers.map { $0.value.stringValue },
                            emailAddresses: contact2.emailAddresses.map { $0.value as String }
                        )
                        
                        newDuplicates.append((modelContact1, modelContact2))
                    }
                }
            }
            
            await MainActor.run {
                duplicates = newDuplicates
                isScanning = false
            }
            
        } catch {
            await MainActor.run {
                alertMessage = "Error scanning contacts: \(error.localizedDescription)"
                showAlert = true
                isScanning = false
            }
        }
    }
    
    private func isDuplicate(_ contact1: CNContact, _ contact2: CNContact) -> Bool {
        // Check if names are similar
        let name1 = "\(contact1.givenName) \(contact1.familyName)".lowercased()
        let name2 = "\(contact2.givenName) \(contact2.familyName)".lowercased()
        
        if name1 == name2 && !name1.isEmpty {
            return true
        }
        
        // Check for matching phone numbers
        let phones1 = Set(contact1.phoneNumbers.map { $0.value.stringValue })
        let phones2 = Set(contact2.phoneNumbers.map { $0.value.stringValue })
        if !phones1.isDisjoint(with: phones2) && !phones1.isEmpty {
            return true
        }
        
        // Check for matching email addresses
        let emails1 = Set(contact1.emailAddresses.map { $0.value as String })
        let emails2 = Set(contact2.emailAddresses.map { $0.value as String })
        if !emails1.isDisjoint(with: emails2) && !emails1.isEmpty {
            return true
        }
        
        return false
    }
}

struct DuplicateContactView: View {
    let contact1: Contact
    let contact2: Contact
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Possible Duplicate")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("\(contact1.firstName) \(contact1.lastName)")
                ForEach(contact1.phoneNumbers, id: \.self) { phone in
                    Text(phone)
                        .font(.caption)
                }
                ForEach(contact1.emailAddresses, id: \.self) { email in
                    Text(email)
                        .font(.caption)
                }
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading) {
                Text("\(contact2.firstName) \(contact2.lastName)")
                ForEach(contact2.phoneNumbers, id: \.self) { phone in
                    Text(phone)
                        .font(.caption)
                }
                ForEach(contact2.emailAddresses, id: \.self) { email in
                    Text(email)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Contact.self, inMemory: true)
}
