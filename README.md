# CDOAuth1Kit

[![CI Status](https://github.com/chrisdhaan/CDOAuth1Kit/actions/workflows/ci.yml/badge.svg)](https://github.com/chrisdhaan/CDOAuth1Kit/actions/workflows/ci.yml)
[![Swift](https://img.shields.io/badge/Swift-5.3%2B-orange?style=flat)](https://swift.org)
[![CocoaPods](https://img.shields.io/cocoapods/v/CDOAuth1Kit.svg?style=flat)](https://cocoapods.org/pods/CDOAuth1Kit)
[![SPM](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat)](https://swift.org/package-manager/)
[![License](https://img.shields.io/cocoapods/l/CDOAuth1Kit.svg?style=flat)](LICENSE)

---

A Swift OAuth 1.0a library for iOS and macOS, with no external dependencies.

## Features

- [x] Full OAuth 1.0a three-legged handshake
- [x] HMAC-SHA1 request signing (via CryptoKit)
- [x] Keychain-backed token persistence
- [x] async/await API
- [x] Zero external dependencies

## Requirements

| Platform | Minimum OS | Swift | Installation    |
|----------|-----------|-------|-----------------|
| iOS      | 13.0+     | 5.3+  | SPM, CocoaPods  |
| macOS    | 10.15+    | 5.3+  | SPM, CocoaPods  |

## Installation

### Swift Package Manager

Add CDOAuth1Kit to your `Package.swift`:

```swift
.package(url: "https://github.com/chrisdhaan/CDOAuth1Kit.git", from: "2.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDOAuth1Kit.git`

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'CDOAuth1Kit', '~> 2.0'
```

Then run `pod install`.

## Usage

See [Documentation/Usage.md](Documentation/Usage.md) for comprehensive usage examples.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
