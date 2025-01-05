import Foundation
import SwiftData

@Model
final class Contact {
    var firstName: String
    var lastName: String
    var phoneNumbers: [String]
    var emailAddresses: [String]
    var createdDate: Date
    
    init(firstName: String = "", 
         lastName: String = "", 
         phoneNumbers: [String] = [], 
         emailAddresses: [String] = []) {
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.createdDate = Date()
    }
} 