# CleanContacts

CleanContacts is a macOS application that helps you manage and clean up duplicate contacts in your address book. It provides an easy-to-use interface for identifying and merging duplicate contacts based on names, phone numbers, and email addresses.

## Installation

### From Source
1. Clone the repository
```bash
git clone https://github.com/samirspatel/CleanContacts.git
```
2. Open CleanContacts.xcodeproj in Xcode
3. Build and run the project (⌘R)

### Requirements for Development
- Xcode 15.0 or later
- macOS Sonoma 14.0 or later
- Apple Developer account (for signing)

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

### Project Structure
- `ContentView.swift`: Main UI and contact management logic
- `Contact.swift`: Contact model definition
- `CleanContactsApp.swift`: App entry point and window management

### Development Setup
1. Ensure you have the latest Xcode installed
2. Install the macOS SDK
3. Configure signing capabilities in Xcode:
  - Enable Contact access in Capabilities
  - Set up your development team

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

MIT License

Copyright (c) 2024 Samir Patel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Author

Samir Patel