# CDOAuth1Kit — Claude Code Context

## Project Overview

CDOAuth1Kit is a pure-Swift, zero-dependency OAuth 1.0a authentication library for iOS, macOS, and visionOS. It handles the complete three-legged OAuth handshake, request signing with HMAC-SHA1 (via Apple's CryptoKit), and secure keychain-backed token persistence. The library uses modern async/await APIs and targets iOS 13.0+, macOS 10.15+, and visionOS 1.0+.

**Key characteristics:**
- No external dependencies (URLSession, Foundation, Security, CryptoKit only)
- Full OAuth 1.0a RFC 5849 compliance (HMAC-SHA1 signatures, percent encoding, nonce/timestamp)
- Async/await support for all network operations
- Keychain integration via JSONEncoder/JSONDecoder
- Comprehensive test suite using Swift Testing framework
- DocC documentation catalog

## Repository Layout

```
CDOAuth1Kit/
├── CDOAuth1Kit.xcodeproj/             # Root native Xcode project (iOS + macOS targets/schemes)
├── CDOAuth1Kit.xcworkspace/           # Ties CDOAuth1Kit.xcodeproj + Example/iOS Example.xcodeproj together
├── Source/                           # Core library (Swift)
│   ├── CDOAuth1Kit.swift             # Module version constants
│   ├── CDOAuth1Credential.swift      # OAuth token storage model
│   ├── CDOAuth1Error.swift           # Error enum
│   ├── CDOAuth1Helper.swift          # URL callback detection
│   ├── CDOAuth1RequestSigner.swift   # HMAC-SHA1 request signing
│   ├── CDOAuth1SessionManager.swift  # Main public API
│   ├── KeychainStore.swift           # Internal keychain helper
│   ├── CDOAuth1Kit.docc/             # DocC documentation catalog
│   ├── Extensions/
│   │   ├── String+CDOAuth1Kit.swift  # RFC 5849 percent encoding
│   │   └── Dictionary+CDOAuth1Kit.swift  # Query string handling
│   ├── Info.plist                    # Native Xcode target Info.plist (SPM excludes this file)
│   └── PrivacyInfo.xcprivacy         # App Store privacy manifest
├── Tests/CDOAuth1KitTests/           # Test suite (Swift Testing)
│   ├── CDOAuth1CredentialTests.swift
│   ├── CDOAuth1HelperTests.swift
│   ├── CDOAuth1RequestSignerTests.swift  # includes RFC 5849 test vector
│   ├── CDOAuth1SessionManagerTests.swift
│   └── Extensions/
│       ├── StringTests.swift
│       └── DictionaryTests.swift
├── Example/                          # Example iOS app (Discogs OAuth 1.0a demo)
│   ├── iOS Example.xcodeproj/        # Cross-references root CDOAuth1Kit.xcodeproj for the framework
│   ├── Secrets.xcconfig.example      # Copy to Secrets.xcconfig (gitignored) with your Discogs API credentials
│   ├── Source/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift       # Intercepts the cdoauth1kit:// OAuth callback URL
│   │   ├── CDOAuth1KitManager.swift  # Wraps CDOAuth1SessionManager for the Discogs handshake
│   │   ├── ViewController.swift      # Authorize / Fetch Identity / Deauthorize demo screen
│   │   ├── CDOAuth1KitJSONResponseViewController.swift
│   │   └── JSONPrettyPrinter.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Base.lproj/
│       └── Info.plist
├── Documentation/
│   ├── ARCHITECTURE.md                # Architecture overview
│   └── Usage.md                       # Usage examples
├── scripts/
│   └── generate-docs.sh               # DocC build + GitHub Pages redirect/.nojekyll/404 fixups
├── Package.swift                      # SPM manifest (swift-tools-version 6.0)
├── .swiftlint.yml                     # SwiftLint config (line length 149/200)
├── .swiftformat                       # SwiftFormat config
├── .github/workflows/ci.yml           # GitHub Actions CI
├── README.md
├── CONTRIBUTING.md
├── CLAUDE.md                          # This file
├── CHANGELOG.md                       # Release notes
└── LICENSE                            # MIT license
```

**Two parallel project representations, by design:** `Package.swift` (SPM, used for `swift build`/`swift test` and consumption via SPM) and `CDOAuth1Kit.xcodeproj` (a native multi-platform Xcode project with one scheme per platform — `CDOAuth1Kit iOS`, `CDOAuth1Kit macOS`, more added as platforms are added — used by CI's `codeql` job and for local multi-platform build verification in Xcode). The two must be kept in sync manually: adding a source file to `Source/` requires adding it to both `Package.swift`'s implicit file scan (automatic) *and* `CDOAuth1Kit.xcodeproj/project.pbxproj`'s `PBXFileReference`/`PBXBuildFile`/`PBXSourcesBuildPhase` entries for both targets (manual — Xcode does this automatically when adding a file through the Xcode UI, but not when a file is added via a text editor or agent). The native project's schemes have no Testables wired — actual test execution goes through `swift test` (the `SPM` CI job), not through this project. `Example/iOS Example.xcodeproj` hard-references the root project's target/product GUIDs (`CD0A00000000000000000010` = `CDOAuth1Kit iOS` target, `CD0A00000000000000000011` = its product/framework file reference, `CD0A00000000000000000019` = `CDOAuth1Kit macOS` target, `CD0A00000000000000000020` = its product/framework file reference) via `PBXContainerItemProxy` cross-project references, so regenerating the root project must preserve these exact GUIDs — a `proxyType = 2` product proxy or `proxyType = 1` target proxy pointed at the wrong kind of GUID will make Xcode fail to read the project, or crash with `-[PBXNativeTarget sourceTree]: unrecognized selector`.

## Platform & Swift Support

| Platform | Minimum OS | Swift | SPM |
|----------|-----------|-------|-----|
| iOS      | 13.0+     | 5.3+  | ✅  |
| macOS    | 10.15+    | 5.3+  | ✅  |
| visionOS | 1.0+      | 5.3+  | ✅  |

## Architecture Summary

The library follows a layered architecture:

```
User Code
  │
  ▼
CDOAuth1SessionManager (public API)
  │
  ├─ CDOAuth1RequestSigner (request signing)
  │  └─ CryptoKit.HMAC<Insecure.SHA1>
  │
  ├─ CDOAuth1Credential (token model, Codable)
  │
  ├─ KeychainStore (internal, JSONEncoder/Decoder)
  │
  └─ URLSession (network I/O)
       │
       ▼
    OAuth Provider (Twitter, etc.)

Helper APIs:
  - CDOAuth1Helper: URL callback detection
  - String+CDOAuth1Kit: RFC 5849 percent encoding
  - Dictionary+CDOAuth1Kit: Query string parsing
```

## Building

### Swift Package Manager

```bash
swift build
swift build -c release
```

### Xcode (SPM)

File → Add Packages → Enter `https://github.com/chrisdhaan/CDOAuth1Kit.git`

## Running Tests

```bash
# All tests
swift test

# Specific suite
swift test --filter CDOAuth1CredentialTests

# Verbose output
swift test -v
```

Test coverage includes:
- **CDOAuth1Credential**: initialization, query string parsing, expiration, Codable round-trip
- **CDOAuth1Helper**: OAuth callback URL detection with scheme/host matching
- **CDOAuth1RequestSigner**: RFC 5849 test vector, OAuth parameters, Authorization headers
- **String extensions**: Percent encoding/decoding, unreserved character handling
- **Dictionary extensions**: Query string parsing, alphabetical sorting, round-trip serialization

## Generating Documentation

CDOAuth1Kit uses **DocC** (not Jazzy) for documentation.

### Local build

```bash
bash scripts/generate-docs.sh
```

This runs the same `swift package generate-documentation` invocation CI uses, then restores the root `index.html` redirect DocC overwrites, and adds `.nojekyll` and `404.html` for GitHub Pages hosting.

The docs are hosted at: `https://chrisdhaan.github.io/CDOAuth1Kit/documentation/cdoauth1kit/`

### Doc requirements

All public symbols must have `///` comments:
- `CDOAuth1SessionManager`
- `CDOAuth1RequestSigner`
- `CDOAuth1Credential`
- `CDOAuth1Error`
- `CDOAuth1Helper`

The CI job fails on any public symbol without documentation.

## Distribution

### Swift Package Manager

Published to: `https://github.com/chrisdhaan/CDOAuth1Kit`

## CI/CD Pipeline (GitHub Actions)

Located in `.github/workflows/ci.yml`. Runs on:
- Source file changes
- Test changes
- Package.swift changes
- Workflow changes

### Jobs

1. **iOS Tests** (5 Xcode versions: 26.4.1, 26.3, 26.2, 26.1.1)
   - Runs on `macos-26` runners
   - Builds and tests for iOS 13+

2. **macOS Tests** (4 versions: 14, 13, 12, 11)
   - Runs on `macos-15` runners
   - Builds and tests for macOS 10.15+

3. **visionOS** (5 Xcode versions)
   - Runs on `macos-26`/`macos-15` runners
   - Builds for visionOS 1.0+ (generic simulator destination; no dedicated test target)

4. **SPM** — Runs `swift build` and `swift test`

5. **SwiftLint** — Code style validation (line length warnings at 149, errors at 200)

6. **SwiftFormat** — Code formatting check

7. **DocC** — Builds documentation; fails on undocumented public symbols

8. **CodeQL** — Security analysis

## Code Style

- **SwiftLint**: Line length warning 149, error 200
- **SwiftFormat**: 4-space indentation, Swift 5.x formatting rules
- Run before committing:
  ```bash
  swiftformat .
  swiftlint
  ```

## Key Design Decisions

1. **No external dependencies** — Uses only Foundation, Security, CryptoKit (all Apple frameworks)
2. **Async/await** — Modern concurrency model; no completion handlers
3. **CryptoKit HMAC-SHA1** — Replaces CommonCrypto (deprecated)
4. **Keychain with Codable** — Secure storage via JSONEncoder/JSONDecoder
5. **DocC not Jazzy** — Modern Apple documentation tooling
6. **Swift Testing** — Modern test framework (@Suite, @Test, #expect)
7. **RFC 5849 compliance** — Full OAuth 1.0a spec implementation (percent encoding, nonce, timestamp)

## Known Issues / Tech Debt

1. **Migration path** — Upgrading from v1.0.0 to v2.0.0 requires re-authentication (keychain format changed from NSKeyedArchiver to JSONEncoder)

## Common Tasks

### Add a new public type

1. Create file in `Source/` directory
2. Add `///` doc comments on all public members
3. Import CDOAuth1Kit in tests
4. Add tests to `Tests/CDOAuth1KitTests/`
5. Run `swift test` and `swiftlint`
6. DocC build will fail if you miss doc comments

### Add a test

1. Create file in `Tests/CDOAuth1KitTests/` or subdirectory
2. Use `@Suite` and `@Test` macros (Swift Testing)
3. Use `#expect()` for assertions
4. Run `swift test --filter YourTestName`

### Update documentation

1. Edit files in `Documentation/` or doc comments in source
2. Run local DocC build to preview
3. Commit docs/ folder if building static site

### Release a new version

1. Update version in `Source/CDOAuth1Kit.swift`
2. Update `CHANGELOG.md` with actual release date
3. Tag commit: `git tag 2.0.0`
4. Push: `git push origin master --tags`
5. GitHub Releases: Create release from tag with CHANGELOG entry

## Testing checklist before release

- [ ] `swift test` passes with all 21 tests
- [ ] `swiftlint` passes with zero violations
- [ ] `swiftformat .` produces no changes
- [ ] `swift build -c release` succeeds
- [ ] DocC build succeeds with zero warnings
- [ ] Example app builds and runs
- [ ] README badges and links are correct
- [ ] CHANGELOG.md has actual release date

## Further Reading

- [RFC 5849 — OAuth 1.0 Protocol](https://tools.ietf.org/html/rfc5849)
- [Documentation/ARCHITECTURE.md](Documentation/ARCHITECTURE.md) — Detailed architecture
- [Documentation/Usage.md](Documentation/Usage.md) — Code examples
- [CONTRIBUTING.md](CONTRIBUTING.md) — Contribution guidelines
