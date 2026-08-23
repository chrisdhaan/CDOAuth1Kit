# CDOAuth1Kit

[![CI Status](https://github.com/chrisdhaan/CDOAuth1Kit/actions/workflows/ci.yml/badge.svg)](https://github.com/chrisdhaan/CDOAuth1Kit/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-5.3%2B-orange?style=flat)](https://swift.org)
[![SPM](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat)](LICENSE)

---

A Swift OAuth 1.0a library for iOS, macOS, and visionOS, with no external dependencies.

## Features

- [x] Full OAuth 1.0a three-legged handshake
- [x] HMAC-SHA1 request signing (via CryptoKit)
- [x] Keychain-backed token persistence
- [x] async/await API
- [x] Zero external dependencies

## Requirements

| Platform | Minimum OS | Swift | Installation |
|----------|-----------|-------|--------------|
| iOS      | 13.0+     | 5.3+  | SPM          |
| macOS    | 10.15+    | 5.3+  | SPM          |
| visionOS | 1.0+      | 5.3+  | SPM          |

## Installation

### Swift Package Manager

Add CDOAuth1Kit to your `Package.swift`:

```swift
.package(url: "https://github.com/chrisdhaan/CDOAuth1Kit.git", from: "2.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDOAuth1Kit.git`

## Usage

See [Documentation/Usage.md](Documentation/Usage.md) for comprehensive usage examples, or browse the full [API documentation](https://chrisdhaan.github.io/CDOAuth1Kit/documentation/cdoauth1kit/).

## Example App

The `Example/` app demonstrates the full OAuth 1.0a handshake against the [Discogs API](https://www.discogs.com/developers). It reads its Discogs `consumerKey`/`consumerSecret` from `Example/Secrets.xcconfig` (gitignored). Before building it:

```bash
cp "Example/Secrets.xcconfig.example" "Example/Secrets.xcconfig"
```

Then edit `Secrets.xcconfig` with your own credentials from the [Discogs Developer settings](https://www.discogs.com/settings/developers). Open `CDOAuth1Kit.xcworkspace` and run the `iOS Example` scheme.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
