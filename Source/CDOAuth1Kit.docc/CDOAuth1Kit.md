# ``CDOAuth1Kit``

A pure-Swift, zero-dependency OAuth 1.0a library for iOS and macOS.

## Overview

CDOAuth1Kit handles the full OAuth 1.0a three-legged handshake using `URLSession` and `CryptoKit`, storing the access token in the keychain. It requires no external dependencies.

CDOAuth1Kit provides:

- Full OAuth 1.0a compliance per RFC 5849
- HMAC-SHA1 request signing via Apple's CryptoKit
- Keychain-backed secure token storage
- Modern async/await API
- Support for iOS 13.0+ and macOS 10.15+
- Zero external dependencies

## Topics

### Getting Started

- <doc:GettingStarted>

### Session Management

- ``CDOAuth1SessionManager``

### Request Signing

- ``CDOAuth1RequestSigner``

### Credentials

- ``CDOAuth1Credential``

### Errors

- ``CDOAuth1Error``

### Utilities

- ``CDOAuth1Helper``
