# Change Log
All notable changes to this project will be documented in this file.
`CDOAuth1Kit` adheres to [Semantic Versioning](https://semver.org/).

## Table of Contents

- [Unreleased](#unreleased)
- [2.1.0](#210)
- [2.0.0](#200)
- [1.0.0](#100)

---

## [Unreleased]

### Added

- `CDOAuth1RetryConfiguration` and `CDOAuth1SessionManager.retryConfiguration` — opt-in automatic retry with exponential backoff for `request(path:method:parameters:)`, restricted to idempotent HTTP methods (`GET`/`HEAD`/`OPTIONS`). Retries on a configurable set of HTTP status codes (default `429`, `500`, `502`, `503`, `504`), honoring a `Retry-After` response header when present.
- `CDOAuth1RequestAdapter` and `CDOAuth1SessionManager.requestAdapters` — adapters applied, in order, to each signed outgoing `request(path:method:parameters:)` call (e.g. to inject a tracing header), without subclassing `CDOAuth1SessionManager`
- `CDOAuth1EventMonitor` and `CDOAuth1SessionManager.eventMonitors` — pluggable lifecycle observers (`requestWillStart`, `requestDidSucceed`, `requestDidFail`, `requestWillRetry`) for logging or metrics on `request(path:method:parameters:)` calls, each with a no-op default so a conformer only implements the events it needs
- `CDOAuth1KitTesting` SPM product — publishes `CDOAuth1MockURLProtocol`, a `URLProtocol` stub for mocking `CDOAuth1Kit` network calls, so downstream consumers can test against it without reimplementing a `URLProtocol` stub themselves

---

## [2.1.0](https://github.com/chrisdhaan/CDOAuth1Kit/releases/tag/2.1.0)

Released on 2026-08-23.

### Added

- `CDOAuth1Error.httpError(statusCode:headers:)`, `.networkError(URLError)`, `.decodingFailed`, and `.authorizationCancelled` cases
- `LocalizedError` conformance on `CDOAuth1Error`
- `CDOAuth1SessionManager`'s three OAuth handshake methods now validate the HTTP status code of every response, throwing `.httpError(statusCode:headers:)` for non-2xx responses (header names normalized to `Title-Case` for predictable lookup) and `.networkError` when the underlying `URLSession` request fails (e.g. offline)
- `CDOAuth1SessionManager.request(path:method:parameters:)` — makes a signed, authenticated API request with the current access token in a single call, returning `(Data, HTTPURLResponse)`. Parameters are appended as URL query items for `GET`/`HEAD`/`DELETE` and as an `application/x-www-form-urlencoded` body otherwise, and are included in the OAuth signature either way.
- `CDOAuth1SessionManager.refreshAccessTokenPath`/`.refreshAccessTokenMethod` — when both are set, `request(path:method:parameters:)` automatically refreshes an expired access token before signing the outgoing request, instead of requiring callers to check `isExpired`/call `refreshAccessToken()` themselves
- `CDOAuth1AuthSession` — an `async`/`await` wrapper around `ASWebAuthenticationSession` for completing the browser-redirect step of an OAuth 1.0a handshake, without writing custom `ASWebAuthenticationPresentationContextProviding` or callback-URL-interception boilerplate
- `CDOAuth1SigningMethod` — selects the RFC 5849 §3.4 signature method (`.hmacSHA1`, `.rsaSHA1(privateKey:)`, or `.plaintext`) used by `CDOAuth1RequestSigner`/`CDOAuth1SessionManager`, defaulting to `.hmacSHA1`
- `Combine` publisher equivalents of `CDOAuth1SessionManager`'s `async` APIs — `fetchRequestTokenPublisher(path:method:callbackURL:scope:)`, `fetchAccessTokenPublisher(path:method:requestToken:)`, `refreshAccessTokenPublisher(path:parameters:method:accessToken:)`, and `requestPublisher(path:method:parameters:)` — for codebases that haven't fully migrated to async/await
- visionOS 1.0+ platform support — `Package.swift`, the native `CDOAuth1Kit.xcodeproj` (new `CDOAuth1Kit visionOS` target/scheme), and CI

### Changed

- Example app's Discogs authorization flow migrated from manual `UIApplication.shared.open` + `SceneDelegate` callback-URL interception to `CDOAuth1AuthSession`, removing the `Notification.Name.cdoauth1kitAuthorizationCallback` round trip

### Deprecated

- `CDOAuth1Error.invalidResponse` — use `.decodingFailed` instead. `CDOAuth1SessionManager`'s handshake methods now throw `.decodingFailed` when a response body can't be parsed into a credential.

---

## [2.0.0](https://github.com/chrisdhaan/CDOAuth1Kit/releases/tag/2.0.0)

Released on 2026-08-21.

### Added

- Swift Package Manager support (swift-tools-version 6.0, iOS 13.0+, macOS 10.15+)
- `async throws` API on all three OAuth handshake methods
- `CDOAuth1Error` Swift error enum replacing the C-style `CDOAuth1ErrorCode` typedef
- `CryptoKit`-based HMAC-SHA1 signing replacing `CommonCrypto/CCHmac` directly
- `PrivacyInfo.xcprivacy` privacy manifest for App Store compliance
- `KeychainStore` internal type using `Codable` / `JSONEncoder` for credential serialization
- Unit test suite using Swift Testing framework
- GitHub Actions CI (iOS/macOS matrix builds, SPM test, SwiftLint, SwiftFormat, DocC build, CodeQL)
- DocC documentation catalog (`Source/CDOAuth1Kit.docc/`) with landing page and Getting Started article
- `swift-docc-plugin` dependency in `Package.swift` for `swift package generate-documentation`
- GitHub Pages–hosted API documentation at `https://chrisdhaan.github.io/CDOAuth1Kit/`
- `.swiftlint.yml` for semantic code quality enforcement
- `.swiftformat` for mechanical code style enforcement
- `CONTRIBUTING.md`, `CLAUDE.md`
- `Documentation/ARCHITECTURE.md`, `Documentation/Usage.md`
- `Documentation/CDOAuth1Kit 2.0 Migration Guide.md`
- GitHub issue templates (bug report, feature request) and pull request template
- `FUNDING.yml` for GitHub Sponsors
- Root `CDOAuth1Kit.xcodeproj` / `CDOAuth1Kit.xcworkspace` — native multi-platform Xcode project (iOS, macOS targets/schemes) alongside the SPM package
- `scripts/generate-docs.sh` for local DocC generation

### Removed

- CocoaPods support — `CDOAuth1Kit.podspec`, `Gemfile`/`Gemfile.lock`, and the CI CocoaPods lint job are gone. 1.0.0 remains the last version distributed via CocoaPods; see the 2.0 Migration Guide for switching to Swift Package Manager. Carthage and Git Submodules were never supported by this library.

### Updated

- Rewritten entirely in Swift — no Objective-C files remain
- Example app rewritten from scratch in Swift, targeting **Discogs** OAuth 1.0a instead of Twitter — scene-based lifecycle, `Secrets.xcconfig`-based credential configuration, cross-references the root `CDOAuth1Kit.xcodeproj` via `Example/iOS Example.xcodeproj`
- Removed dependency on AFNetworking — uses `URLSession` from Foundation directly
- Deployment targets: iOS 13.0+ (was iOS 8.0+), macOS 10.15+ (new platform)
- `CDOAuth1RequestSerializer` renamed to `CDOAuth1RequestSigner` (value type, no superclass)
- `CDOAuth1SessionManager` now wraps `URLSession` directly instead of subclassing `AFHTTPSessionManager`
- `CDOAuth1Credential` converted to Swift `struct` with `Codable` and `Sendable` conformances
- Keychain storage now uses `JSONEncoder`/`JSONDecoder` instead of `NSKeyedArchiver`/`NSKeyedUnarchiver`
- README restructured as navigation hub with modern badges
- CHANGELOG reformatted to Semantic Versioning standard
- Travis CI replaced with GitHub Actions
- Documentation hosting migrated from Jazzy to DocC; `.jazzy.yaml` not created

### Fixed

- Deprecated `CFURLCreateStringByAddingPercentEscapes` replaced with `addingPercentEncoding(withAllowedCharacters:)`
- Deprecated `CFURLCreateStringByReplacingPercentEscapesUsingEncoding` replaced with `removingPercentEncoding`
- Deprecated `NSKeyedArchiver.archivedDataWithRootObject:` (deprecated iOS 12) replaced with `JSONEncoder`
- Deprecated `NSKeyedUnarchiver.initForReadingWithData:` (deprecated iOS 12) replaced with `JSONDecoder`
- Legacy class name mapping hack (`setClass:forClassName: "CDOAuthToken"`) eliminated
- iOS 7 / macOS 10.9 base64 preprocessor guards removed — baseline is now iOS 13 / macOS 10.15
- `CFUUIDCreate` replaced with `UUID()` for nonce generation
- `CDOAuth1Credential.initWithQueryString:` crash when query string has fewer than 2 components per `=`-split (defensive guard added)
- Authorization header omitted `oauth_callback` and `oauth_verifier`, breaking the three-legged handshake
- Authorization header values not percent-encoded per RFC 5849 §3.5.1
- Redundant `oauthParameters()` calls in `CDOAuth1SessionManager`
- RFC 5849 test vector in `CDOAuth1RequestSignerTests` did not actually assert on the computed HMAC output
- `KeychainStore.write` silently swallowed `JSONEncoder` errors instead of propagating them

---

## [1.0.0](https://github.com/chrisdhaan/CDOAuth1Kit/releases/tag/1.0.0)

Released on 2016-08-28.

### Added
- OAuth 1.0a credential management (`CDOAuth1Credential`)
- OAuth request signing via HMAC-SHA1 (`CDOAuth1RequestSerializer`)
- Full OAuth 1.0 three-legged handshake (`CDOAuth1SessionManager`)
- Keychain-backed access token persistence
- Request token / access token / token refresh flows
- `CDOAuth1Helper` for callback URL detection
- iOS 8.0+ support via CocoaPods

---
