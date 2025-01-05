# CleanContacts

CleanContacts is a macOS application that helps you manage and clean up duplicate contacts in your address book. It provides an easy-to-use interface for identifying and merging duplicate contacts based on names, phone numbers, and email addresses.

## Features

- **Automatic Duplicate Detection**: Intelligently identifies potential duplicate contacts based on:
  - Matching names
  - Matching phone numbers
  - Matching email addresses

- **Smart Grouping**: Groups related contacts together even if they have slight variations in their information

- **Detailed Comparison**: View detailed information for each potential duplicate, including:
  - Full names
  - Phone numbers
  - Email addresses

- **Easy Merging**: Merge duplicate contacts with a single click while preserving all unique information

## System Requirements

- macOS 14.0 or later
- Access to Contacts.app (permission required)

## Privacy

CleanContacts requires access to your contacts to function. The app:
- Only reads contact information locally
- Does not store or transmit any contact data
- Requires explicit permission to access your contacts

## Usage

1. Launch the app
2. Grant contacts access when prompted
3. Wait for the app to scan your contacts
4. Review the identified duplicate groups
5. Select a group to view detailed comparison
6. Click "Merge" to combine duplicate contacts

## Development

Built using:
- SwiftUI
- Contacts framework
- SwiftData
- Swift 5.0

## License

Free to use and modify.

## Author

Samir Patel