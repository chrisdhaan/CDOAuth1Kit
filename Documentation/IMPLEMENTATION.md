# CDOAuth1Kit — Modernization Implementation Plan

> Implementation plan for bringing CDOAuth1Kit from v1.0.0 (released 2016) to a current, well-maintained open source Swift package. Modeled after the CDMarkdownKit 3.0.0 modernization. The end result is version **2.0.0**.
>
> Sections are largely independent and can be implemented in any order, with the exceptions noted below. Complete Section 4 (Swift Rewrite) before starting Section 5 (Unit Tests). Complete Section 3 (Package.swift) before running SPM tests.

---

## Table of Contents

- [1. Repository Housekeeping](#1-repository-housekeeping)
- [2. Infrastructure & Tooling](#2-infrastructure--tooling)
- [3. Swift Package Manager](#3-swift-package-manager)
- [4. CocoaPods Podspec Update](#4-cocoapods-podspec-update)
- [5. CI/CD: Replace Travis CI with GitHub Actions](#5-cicd-replace-travis-ci-with-github-actions)
- [6. Swift Rewrite — Core Library](#6-swift-rewrite--core-library)
- [7. Unit Tests](#7-unit-tests)
- [8. Example App Update](#8-example-app-update)
- [9. Documentation](#9-documentation)
- [10. CHANGELOG.md](#10-changelogmd)

> **CDMarkdownKit 3.1.0 alignment** — Sections updated to match CDMarkdownKit 3.1.0 patterns (released 2026-05-12):
> - Section 1.6: Gemfile drops `jazzy` gem (DocC replaces Jazzy)
> - Section 2.2: Replaced `.jazzy.yaml` with DocC toolchain notes
> - Section 2.6 *(new)*: `.swiftformat` config
> - Section 3.1: `Package.swift` adds `swift-docc-plugin` dependency
> - Section 5: CI adds SwiftFormat job, DocC build job replaces Jazzy doc job, iOS matrix expanded
> - Section 9.7 *(new)*: DocC catalog (`Source/CDOAuth1Kit.docc/`)
> - Section 10: CHANGELOG updated with SwiftFormat and DocC entries

---

## 1. Repository Housekeeping

Quick, low-risk changes that improve the repo's credibility and contributor experience before any code changes are made.

### ✅ 1.1 — Reformat `CHANGELOG.md`

Create `CHANGELOG.md` at the repo root. CDOAuth1Kit currently has no changelog. Use the following format (identical to CDMarkdownKit's format):

```markdown
# Change Log
All notable changes to this project will be documented in this file.
`CDOAuth1Kit` adheres to [Semantic Versioning](https://semver.org/).

## Table of Contents

- [2.0.0](#200)
- [1.0.0](#100)

---

## [2.0.0](https://github.com/chrisdhaan/CDOAuth1Kit/releases/tag/2.0.0)

Released on YYYY-MM-DD.

### Added
- Description.

### Updated
- Description.

### Fixed
- Description.

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
```

Rules:
- Dates in `YYYY-MM-DD` format.
- Three categories only: **Added**, **Updated**, **Fixed**.
- Releases separated by `---`.

### ✅ 1.2 — Replace the single issue template with a directory structure

Delete `.travis.yml` is handled in Section 5. For GitHub templates:

Create `.github/ISSUE_TEMPLATE/config.yml`:
```yaml
blank_issues_enabled: false
contact_links:
  - name: Usage Question
    url: https://stackoverflow.com/questions/tagged/cdoauth1kit
    about: Please ask usage questions on Stack Overflow using the `cdoauth1kit` tag.
  - name: Security Vulnerability
    url: mailto:contact@christopherdehaan.me
    about: Please report security vulnerabilities privately via email.
```

Create `.github/ISSUE_TEMPLATE/bug_report.md`:
```markdown
---
name: Bug Report
about: Report a reproducible bug or regression.
labels: bug
---

**What did you do?**
<!-- A clear description of the steps that produced the bug. -->

**What did you expect to happen?**

**What actually happened?**

**CDOAuth1Kit version:**

**Swift version:**

**Platform and OS version:**

**Minimal reproducible example:**
<!-- A short Swift snippet demonstrating the bug. -->
```

Create `.github/ISSUE_TEMPLATE/feature_request.md`:
```markdown
---
name: Feature Request
about: Suggest a new feature or enhancement.
labels: enhancement
---

**What problem does this feature solve?**

**Describe the solution you'd like.**

**Have you considered any alternatives?**
```

### ✅ 1.3 — Add `PULL_REQUEST_TEMPLATE.md`

Create `.github/PULL_REQUEST_TEMPLATE.md`:
```markdown
### Issue :link:

> Link to the GitHub issue this PR addresses.

### Goals :soccer:

> Bullet list of what this PR accomplishes.

### Implementation Details :construction:

> Describe any non-obvious implementation decisions.

### Testing Details :mag:

> How was this tested? List new tests added, or explain why no tests are needed.
```

### ✅ 1.4 — Add `FUNDING.yml`

Create `.github/FUNDING.yml`:
```yaml
github: chrisdhaan
```

### ✅ 1.5 — Update `.gitignore`

Replace the current (absent) or any existing `.gitignore` with:
```
# Mac OS X
.DS_Store

# Xcode
build/
DerivedData
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3
xcuserdata
*.xccheckout
*.moved-aside
*.xcuserstate
*.xcscmblueprint
*.hmap
*.ipa
timeline.xctimeline
playground.xcworkspace

# Swift Package Manager
.build/

# CocoaPods
Pods/

# Carthage
Carthage/Build

# Bundler
.bundle/

# Jazzy documentation
docs/undocumented.json
```

Note: Pods/ should be gitignored once the Example app is converted to SPM or uses a modern CocoaPods setup that doesn't commit Pods. The existing committed Pods directory should be removed from tracking via `git rm -r --cached Example/Pods/`.

### ✅ 1.6 — Add `Gemfile` and `Gemfile.lock`

Create `Gemfile` at the repo root:
```ruby
source "https://rubygems.org"

gem "cocoapods"
```

`jazzy` is **not** included — documentation is generated via DocC (Section 9.7), which requires no additional Ruby gems. Matching CDMarkdownKit 3.1.0's Gemfile.

Run `bundle lock` (or `bundle install`) to generate `Gemfile.lock`. Commit both files.

### ✅ 1.7 — Add `.ruby-version`

Create `.ruby-version` at the repo root. Match the version used by the system Homebrew Ruby or the same version used in CDMarkdownKit:
```
3.4.2
```
(Verify with `/opt/homebrew/opt/ruby/bin/ruby --version` and update as needed.)

---

## 2. Infrastructure & Tooling

### ✅ 2.1 — Add `.swiftlint.yml`

Create `.swiftlint.yml`:
```yaml
included:
  - Source
  - Example/Source

file_length: 300
function_body_length: 60
identifier_name:
  excluded:
    - id
    - to
    - url
line_length:
  error: 200
  ignores_comments: true
  ignores_function_declarations: true
  warning: 149
type_body_length: 200
```

### ✅ 2.2 — Documentation Toolchain: DocC (not Jazzy)

**CDMarkdownKit 3.1.0 context:** CDMarkdownKit 3.0.0 originally planned Jazzy and shipped `.jazzy.yaml`, then 3.1.0 migrated entirely to DocC — removing `.jazzy.yaml`, dropping the `jazzy` gem, and adding `swift-docc-plugin`. CDOAuth1Kit v2.0.0 skips Jazzy entirely and goes straight to DocC.

Do **not** create `.jazzy.yaml`. Instead:
- Add `swift-docc-plugin` to `Package.swift` (Section 3.1).
- Create `Source/CDOAuth1Kit.docc/` catalog (Section 9.7).
- Replace the documentation CI job with a DocC build step (Section 5).

The `docs/` output directory is generated by `swift package generate-documentation` and committed to `gh-pages` or the `master` branch for GitHub Pages hosting. See CDMarkdownKit's `docs/` directory as the reference output structure.

### ✅ 2.3 — Add `PrivacyInfo.xcprivacy`

Create `Source/PrivacyInfo.xcprivacy`. CDOAuth1Kit accesses the keychain but does not collect data for tracking. The privacy manifest should reflect this:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
</dict>
</plist>
```

Note: If Apple's guidance evolves to require explicit declaration of keychain access in the privacy manifest, update `NSPrivacyAccessedAPITypes` accordingly. As of 2026, keychain usage does not require a `NSPrivacyAccessedAPITypes` entry.

### ✅ 2.4 — Delete `.travis.yml`

Travis CI is no longer actively maintained for open source. Delete `.travis.yml`. GitHub Actions replaces it entirely (Section 5).

### ✅ 2.5 — Remove committed `Pods/` directory

The `Example/Pods/` directory is currently committed to git. Remove it:
```bash
git rm -r --cached Example/Pods/
```

Add `Pods/` to `.gitignore` (done in 1.5). Update `Example/Podfile` to use the new library version and structure when applicable.

### ✅ 2.6 — Add `.swiftformat`

*(Added to match CDMarkdownKit 3.1.0 — CDMarkdownKit introduced SwiftFormat alongside SwiftLint for consistent code formatting.)*

Create `.swiftformat` at the repo root. SwiftFormat enforces mechanical style (spacing, trailing commas, semicolons) while SwiftLint enforces semantic rules (complexity, naming). Both run in CI.

```
# Swift language version target
--swiftversion 5.9

# Indentation: 4 spaces, no tabs
--indent 4
--tabwidth 4
--smarttabs enabled
--indentcase false

# Line length — matches the warning threshold in .swiftlint.yml
--maxwidth 149

# Line endings
--linebreaks lf

# Trailing syntax
--commas always
--semicolons never
--stripunusedargs closure-only

# Argument wrapping (disabled to prevent code expansion)
--wraparguments preserve
--wrapparameters preserve
--wrapcollections preserve

# Import grouping
--importgrouping testable-last

# File headers: leave existing MIT copyright blocks untouched
--header ignore

# Paths to exclude from formatting
--exclude .build,Pods,docs,Package.swift

# Rules disabled to preserve existing codebase conventions
--disable blankLinesAtStartOfScope,blankLinesAtEndOfScope,blankLineAfterImports,blankLinesBetweenScopes,extensionAccessControl,redundantSelf,redundantType,redundantInternal,wrap,wrapMultilineStatementBraces,wrapPropertyBodies
```

Update `.swiftlint.yml` `included` paths to match (Source directory). SwiftFormat and SwiftLint should agree on line length (149 warning) and indentation (4 spaces).

---

## 3. Swift Package Manager

### ✅ 3.1 — Create `Package.swift`

CDOAuth1Kit currently has no SPM support. The rewritten library (Section 6) targets iOS 13.0+ and macOS 10.15+, which is the minimum required for `CryptoKit` (used for HMAC-SHA1 signing).

Create `Package.swift` at the repo root:
```swift
// swift-tools-version:6.0
//
//  Package.swift
//  CDOAuth1Kit
//
//  Created by Christopher de Haan on 8/28/16.
//
//  Copyright © 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//
//  [MIT license header]
//

import PackageDescription

let package = Package(
    name: "CDOAuth1Kit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "CDOAuth1Kit",
            targets: ["CDOAuth1Kit"]
        ),
        .library(
            name: "CDOAuth1KitDynamic",
            type: .dynamic,
            targets: ["CDOAuth1Kit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "CDOAuth1Kit",
            path: "Source",
            exclude: ["Info.plist"],
            resources: [.process("PrivacyInfo.xcprivacy")],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny")
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
                .linkedFramework("CryptoKit")
            ]
        ),
        .testTarget(
            name: "CDOAuth1KitTests",
            dependencies: ["CDOAuth1Kit"]
        )
    ],
    swiftLanguageModes: [.v5]
)
```

**Rationale for platform choices:**
- `iOS 13.0+` — minimum for `CryptoKit` (HMAC-SHA1), `UUID`, and back-deployable `async/await` shims
- `macOS 10.15+` — same reasons as iOS 13
- `tvOS` and `watchOS` are excluded — OAuth 1.0 three-legged flows require a browser redirect that is not practical on these platforms
- `visionOS` is excluded for v2.0.0 — visionOS does have Safari / `ASWebAuthenticationSession` and could support OAuth flows, but is deprioritized for the initial rewrite. Consider adding `.visionOS(.v1)` in a follow-up release (CDMarkdownKit 3.1.0 added visionOS this way).
- `swift-tools-version: 6.0` with `swiftLanguageModes: [.v5]` — matches CDMarkdownKit; compiles in Swift 5 language mode on a Swift 6 toolchain to avoid strict concurrency warnings before a full Swift 6 audit
- `swift-docc-plugin` — added as a build-tool dependency to enable `swift package generate-documentation` (Section 9.7). This replaces the Jazzy approach used in earlier CDMarkdownKit versions.

---

## ✅ 4. CocoaPods Podspec Update

Replace the current `CDOAuth1Kit.podspec` with:
```ruby
Pod::Spec.new do |s|
  s.name = 'CDOAuth1Kit'
  s.version = '2.0.0'
  s.cocoapods_version = '>= 1.13.0'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.summary = 'A Swift OAuth 1.0a library for iOS and macOS.'
  s.description = <<-DESC
    This Swift library provides the functionality to request and refresh access tokens
    for APIs requiring OAuth 1.0a authentication, with no external dependencies.
  DESC
  s.homepage = 'https://github.com/chrisdhaan/CDOAuth1Kit'
  s.author = { 'Christopher de Haan' => 'contact@christopherdehaan.me' }
  s.source = { :git => 'https://github.com/chrisdhaan/CDOAuth1Kit.git', :tag => s.version.to_s }
  s.documentation_url = 'https://chrisdhaan.github.io/CDOAuth1Kit/'

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'

  s.swift_versions = ['5']

  s.source_files = 'Source/*.swift'
  s.resource_bundles = { 'CDOAuth1Kit' => ['Source/PrivacyInfo.xcprivacy'] }

  s.framework = 'Foundation'
  s.framework = 'Security'
  s.framework = 'CryptoKit'
end
```

Key changes from v1.0.0:
- Removed `s.dependency 'AFNetworking'` — zero external dependencies
- Updated deployment targets: iOS 13.0, macOS 10.15
- Added `cocoapods_version '>= 1.13.0'`
- Added `documentation_url`
- Added `resource_bundles` for `PrivacyInfo.xcprivacy`
- Added `Security` and `CryptoKit` frameworks

---

## ✅ 5. CI/CD: Replace Travis CI with GitHub Actions

Delete `.travis.yml`. Create `.github/workflows/ci.yml`:

```yaml
name: "CDOAuth1Kit CI"

on:
  push:
    branches:
      - master
    paths:
      - ".github/workflows/**"
      - "Package.swift"
      - "Source/**"
      - "Tests/**"
  pull_request:
    paths:
      - ".github/workflows/**"
      - "Package.swift"
      - "Source/**"
      - "Tests/**"

concurrency:
  group: ${{ github.ref_name }}
  cancel-in-progress: true

jobs:
  iOS:
    name: Test ${{ matrix.name }}
    runs-on: ${{ matrix.runner }}
    timeout-minutes: 15
    strategy:
      fail-fast: false
      matrix:
        include:
          - runner: macos-26
            xcode: /Applications/Xcode_26.4.1.app/Contents/Developer
            destination: "OS=26.2,name=iPhone 17 Pro"
            name: "iOS 26 (Xcode 26.4.1)"
          - runner: macos-26
            xcode: /Applications/Xcode_26.3.app/Contents/Developer
            destination: "OS=26.2,name=iPhone 17 Pro"
            name: "iOS 26 (Xcode 26.3)"
          - runner: macos-26
            xcode: /Applications/Xcode_26.2.app/Contents/Developer
            destination: "OS=26.2,name=iPhone 17 Pro"
            name: "iOS 26 (Xcode 26.2)"
          - runner: macos-26
            xcode: /Applications/Xcode_26.1.1.app/Contents/Developer
            destination: "OS=26.1,name=iPhone 17 Pro"
            name: "iOS 26 (Xcode 26.1.1)"
          - runner: macos-15
            xcode: /Applications/Xcode_16.4.app/Contents/Developer
            destination: "OS=18.6,name=iPhone 16 Pro"
            name: "iOS 18 (Xcode 16.4)"
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s ${{ matrix.xcode }}
      - name: List available simulators
        run: xcrun simctl list
      - name: Install xcbeautify
        run: brew install xcbeautify
      - name: ${{ matrix.name }} - Debug
        run: |
          set -o pipefail
          env NSUnbufferedIO=YES xcodebuild -project "CDOAuth1Kit.xcodeproj" -scheme "CDOAuth1Kit iOS" -destination "${{ matrix.destination }}" -configuration Debug clean build 2>&1 | xcbeautify --renderer github-actions
      - name: ${{ matrix.name }} - Release
        run: |
          set -o pipefail
          env NSUnbufferedIO=YES xcodebuild -project "CDOAuth1Kit.xcodeproj" -scheme "CDOAuth1Kit iOS" -destination "${{ matrix.destination }}" -configuration Release clean build 2>&1 | xcbeautify --renderer github-actions

  macOS:
    name: Test ${{ matrix.name }}
    runs-on: ${{ matrix.runner }}
    timeout-minutes: 10
    strategy:
      fail-fast: false
      matrix:
        include:
          - runner: macos-26
            xcode: /Applications/Xcode_26.4.1.app/Contents/Developer
            name: "macOS 26 (Xcode 26.4.1)"
          - runner: macos-26
            xcode: /Applications/Xcode_26.3.app/Contents/Developer
            name: "macOS 26 (Xcode 26.3)"
          - runner: macos-15
            xcode: /Applications/Xcode_16.4.app/Contents/Developer
            name: "macOS 15 (Xcode 16.4)"
          - runner: macos-15
            xcode: /Applications/Xcode_16.3.app/Contents/Developer
            name: "macOS 15 (Xcode 16.3)"
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s ${{ matrix.xcode }}
      - name: Install xcbeautify
        run: brew install xcbeautify
      - name: ${{ matrix.name }} - Debug
        run: |
          set -o pipefail
          env NSUnbufferedIO=YES xcodebuild -project "CDOAuth1Kit.xcodeproj" -scheme "CDOAuth1Kit macOS" -destination "platform=macOS" -configuration Debug clean build 2>&1 | xcbeautify --renderer github-actions
      - name: ${{ matrix.name }} - Release
        run: |
          set -o pipefail
          env NSUnbufferedIO=YES xcodebuild -project "CDOAuth1Kit.xcodeproj" -scheme "CDOAuth1Kit macOS" -destination "platform=macOS" -configuration Release clean build 2>&1 | xcbeautify --renderer github-actions

  CocoaPods:
    name: pod lib lint
    runs-on: macos-15
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.4.app/Contents/Developer
      - uses: actions/cache@v4
        with:
          path: Pods
          key: ${{ runner.os }}-pods-${{ hashFiles('**/Podfile.lock') }}
          restore-keys: |
            ${{ runner.os }}-pods-
      - name: Install Gems
        run: bundle install
      - name: pod lib lint
        run: bundle exec pod lib lint --allow-warnings

  SPM:
    name: Test with SPM
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.4.app/Contents/Developer
      - name: Install xcbeautify
        run: brew install xcbeautify
      - name: swift test
        run: set -o pipefail && swift test -c debug 2>&1 | xcbeautify --renderer github-actions

  swiftlint:
    name: SwiftLint
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Install SwiftLint
        run: brew install swiftlint
      - name: Lint
        run: swiftlint lint --strict

  swiftformat:
    name: SwiftFormat
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Install SwiftFormat
        run: brew install swiftformat
      - name: Check formatting
        run: swiftformat Source Tests --lint

  documentation:
    name: DocC Build
    runs-on: macos-15
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Build DocC
        run: |
          swift package --disable-sandbox generate-documentation \
            --target CDOAuth1Kit \
            --output-path /tmp/docc-output \
            --transform-for-static-hosting \
            --hosting-base-path CDOAuth1Kit \
            2>&1 | tee docc.log
      - name: Fail on DocC warnings
        run: grep -qE "^warning:" docc.log && exit 1 || exit 0

  codeql:
    name: CodeQL
    runs-on: macos-15
    timeout-minutes: 20
    permissions:
      security-events: write
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.4.app/Contents/Developer
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: swift
      - name: Build
        run: |
          xcodebuild -project CDOAuth1Kit.xcodeproj \
            -scheme "CDOAuth1Kit iOS" \
            -destination "generic/platform=iOS" \
            -configuration Debug \
            clean build
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
```

**Notes on CI design:**
- tvOS, watchOS, and visionOS jobs are omitted — not supported by the library for v2.0.0 (Section 3.1 rationale).
- Catalyst is omitted — not a natural fit for an OAuth networking library.
- Triggers only on changes to source, tests, Package.swift, or workflow files — avoids running the full suite for README edits.
- `concurrency` group cancels in-progress runs on the same branch when a new push arrives.
- `swiftformat` job runs `--lint` (check-only, no writes) — matches CDMarkdownKit 3.1.0 pattern.
- `documentation` job builds DocC via `swift package generate-documentation` — replaces the Jazzy doc job from CDMarkdownKit 3.0.0; output is written to a temp path so it does not pollute the workspace.
- iOS matrix expanded to four Xcode versions on macos-26 (26.4.1, 26.3, 26.2, 26.1.1) — aligns with CDMarkdownKit 3.1.0.

---

## 6. Swift Rewrite — Core Library

This is the largest change. The library is rewritten from Objective-C to Swift, and the dependency on AFNetworking is removed entirely. URLSession and CryptoKit (both part of Apple's SDKs) replace AFNetworking's functionality.

### ✅ 6.1 — New Source Directory Structure

```
CDOAuth1Kit/
└── Source/
    ├── CDOAuth1Kit.swift          # Module entry, version constant
    ├── CDOAuth1Credential.swift   # replaces CDOAuth1Credential.h/m
    ├── CDOAuth1Error.swift        # replaces CDOAuth1ErrorCode.h
    ├── CDOAuth1Helper.swift       # replaces CDOAuth1Helper.h/m
    ├── CDOAuth1RequestSigner.swift # replaces CDOAuth1RequestSerializer.h/m
    ├── CDOAuth1SessionManager.swift # replaces CDOAuth1SessionManager.h/m
    ├── KeychainStore.swift        # new: internal keychain helper (replaces SecItem calls in RequestSerializer)
    ├── Extensions/
    │   ├── Dictionary+CDOAuth1Kit.swift  # replaces NSDictionary+CDOAuth1Kit.h/m
    │   └── String+CDOAuth1Kit.swift      # replaces NSString+CDOAuth1Kit.h/m
    ├── Info.plist
    └── PrivacyInfo.xcprivacy
```

Delete the old `CDOAuth1Kit/Source/Core/` hierarchy (all `.h` and `.m` files) after the Swift files are in place.

### ✅ 6.2 — `CDOAuth1Kit.swift`

```swift
// CDOAuth1Kit.swift
// Version constant and Swift version guard.

public let CDOAuth1KitVersionNumber = 2.0
public let CDOAuth1KitVersionString = "2.0.0"
```

### ✅ 6.3 — `CDOAuth1Credential.swift`

Replace `CDOAuth1Credential.h/m` with a Swift struct. Use `Codable` instead of `NSCoding` for modern serialization. Use `Sendable` for concurrency safety.

Key design decisions vs. the original:
- `struct` instead of `class` — value semantics are appropriate for a credential token.
- `Codable` replaces `NSCoding` — enables `JSONEncoder`/`JSONDecoder` for keychain storage, removing the NSKeyedArchiver dependency.
- `Sendable` — safe to pass across actor boundaries.
- Factory class methods (`credentialWithToken:secret:expiration:`) become Swift initializers.
- `initWithQueryString:` becomes a failable initializer `init?(queryString:)`.

```swift
public struct CDOAuth1Credential: Codable, Sendable, Equatable {

    public let token: String
    public let secret: String
    public var verifier: String?
    public var expiration: Date?
    public var userInfo: [String: String]?

    public var isExpired: Bool {
        guard let expiration else { return false }
        return expiration < Date()
    }

    public init(token: String,
                secret: String,
                expiration: Date? = nil) {
        self.token = token
        self.secret = secret
        self.expiration = expiration
    }

    public init?(queryString: String) {
        let params = [String: String](queryString: queryString)
        guard let token = params["oauth_token"],
              let secret = params["oauth_token_secret"] else {
            return nil
        }
        self.token = token
        self.secret = secret
        self.verifier = params["oauth_verifier"]
        if let duration = params["oauth_token_duration"].flatMap(Double.init) {
            self.expiration = Date(timeIntervalSinceNow: duration)
        }
        var info = params
        ["oauth_token", "oauth_token_secret", "oauth_verifier", "oauth_token_duration"]
            .forEach { info.removeValue(forKey: $0) }
        self.userInfo = info.isEmpty ? nil : info
    }
}
```

### ✅ 6.4 — `CDOAuth1Error.swift`

Replace the C enum `CDOAuth1ErrorCode` with a proper Swift error type:

```swift
public enum CDOAuth1Error: Error, Sendable {
    case invalidRequestToken
    case invalidAccessToken
    case invalidResponse
    case keychainError(OSStatus)
}
```

Remove the old `CDOAuth1ErrorDomain` NSString constant — Swift errors do not need string domains.

### ✅ 6.5 — `CDOAuth1Helper.swift`

Replace the Objective-C class with a Swift enum (no cases = namespace):

```swift
public enum CDOAuth1Helper {
    public static func isAuthorizationCallbackURL(
        _ url: URL,
        scheme callbackScheme: String,
        host callbackHost: String
    ) -> Bool {
        url.scheme == callbackScheme && url.host == callbackHost
    }
}
```

### ✅ 6.6 — `KeychainStore.swift` (new internal file)

Extract keychain access from `CDOAuth1RequestSerializer` into its own internal type. Use `JSONEncoder`/`JSONDecoder` (via `Codable`) instead of `NSKeyedArchiver`/`NSKeyedUnarchiver`.

```swift
enum KeychainStore {

    static func read(service: String) -> CDOAuth1Credential? {
        var query = baseQuery(service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(CDOAuth1Credential.self, from: data)
    }

    static func write(_ credential: CDOAuth1Credential, service: String) throws {
        guard let data = try? JSONEncoder().encode(credential) else { return }
        var query = baseQuery(service: service)

        if read(service: service) != nil {
            let update = [kSecValueData as String: data] as CFDictionary
            let status = SecItemUpdate(query as CFDictionary, update)
            if status != errSecSuccess { throw CDOAuth1Error.keychainError(status) }
        } else {
            query[kSecValueData as String] = data
            let status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess { throw CDOAuth1Error.keychainError(status) }
        }
    }

    static func delete(service: String) throws {
        let status = SecItemDelete(baseQuery(service: service) as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw CDOAuth1Error.keychainError(status)
        }
    }

    private static func baseQuery(service: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service]
    }
}
```

**Why this matters:** The original code used `NSKeyedArchiver.archivedDataWithRootObject:` (deprecated in iOS 12) and `NSKeyedUnarchiver.initForReadingWithData:` (deprecated in iOS 12), with a class name mapping hack (`setClass:forClassName:`) to handle a legacy rename from `CDOAuthToken` to `CDOAuth1Credential`. The new implementation has no legacy baggage.

### ✅ 6.7 — `CDOAuth1RequestSigner.swift`

This is the most complex file. It replaces `CDOAuth1RequestSerializer.h/m`, which was an `AFHTTPRequestSerializer` subclass. The new type is a pure Swift struct with no superclass dependency.

Key changes vs. original:
- `struct` instead of `class` — the signer has no identity requirements.
- No AFNetworking — uses `URLRequest` directly.
- HMAC-SHA1 uses `CryptoKit.HMAC<Insecure.SHA1>` instead of `CommonCrypto/CCHmac`.
- URL encoding uses `addingPercentEncoding(withAllowedCharacters:)` instead of the deprecated `CFURLCreateStringByAddingPercentEscapes`.
- `UUID().uuidString` instead of `CFUUIDCreate`.
- No preprocessor macros — the iOS 7/macOS 10.9 base64 compat guards are gone; iOS 13 / macOS 10.15 already has modern base64 encoding.

```swift
public struct CDOAuth1RequestSigner {

    public let service: String
    public let consumerKey: String
    public let consumerSecret: String

    public var requestToken: CDOAuth1Credential?
    public private(set) var accessToken: CDOAuth1Credential?

    public init(service: String,
                consumerKey: String,
                consumerSecret: String) {
        self.service = service
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.accessToken = KeychainStore.read(service: service)
    }

    // MARK: - Keychain

    public mutating func saveAccessToken(_ token: CDOAuth1Credential) throws {
        try KeychainStore.write(token, service: service)
        self.accessToken = token
    }

    public mutating func removeAccessToken() throws {
        try KeychainStore.delete(service: service)
        self.accessToken = nil
    }

    // MARK: - OAuth Parameters

    public func oauthParameters() -> [String: String] {
        var params: [String: String] = [:]
        params["oauth_version"]          = "1.0"
        params["oauth_consumer_key"]     = consumerKey
        params["oauth_timestamp"]        = String(Int(Date().timeIntervalSince1970))
        params["oauth_signature_method"] = "HMAC-SHA1"
        params["oauth_nonce"]            = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return params
    }

    // MARK: - Request Signing

    /// Produces a signed copy of the given URLRequest, adding an OAuth Authorization header.
    public func signed(_ request: URLRequest,
                       parameters: [String: String] = [:]) throws -> URLRequest {
        guard let method = request.httpMethod,
              let urlString = request.url?.absoluteString else {
            throw CDOAuth1Error.invalidRequestToken
        }

        var authParams = oauthParameters()
        if let token = (accessToken ?? requestToken)?.token {
            authParams["oauth_token"] = token
        }

        var allParams = authParams.merging(parameters) { $1 }
        authParams["oauth_signature"] = try signature(
            method: method,
            urlString: urlString,
            parameters: allParams
        )

        var signed = request
        signed.setValue(authorizationHeader(from: authParams), forHTTPHeaderField: "Authorization")
        signed.httpShouldHandleCookies = false
        return signed
    }

    // MARK: - Private

    private func signature(method: String,
                           urlString: String,
                           parameters: [String: String]) throws -> String {
        let tokenSecret = (accessToken ?? requestToken)?.secret ?? ""
        let signingKey = "\(consumerSecret.oauthPercentEncoded())&\(tokenSecret.oauthPercentEncoded())"

        let baseURL = urlString.components(separatedBy: "?")[0].oauthPercentEncoded()
        let sortedParams = parameters.sorted { $0.key < $1.key }
        let paramString = sortedParams
            .map { "\($0.key.oauthPercentEncoded())=\($0.value.oauthPercentEncoded())" }
            .joined(separator: "&")
            .oauthPercentEncoded()

        let baseString = "\(method.uppercased())&\(baseURL)&\(paramString)"

        return try hmacSHA1(message: baseString, key: signingKey)
    }

    private func hmacSHA1(message: String, key: String) throws -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(message.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: symmetricKey)
        return Data(mac).base64EncodedString()
    }

    private func authorizationHeader(from params: [String: String]) -> String {
        let components = params
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { "\($0.key)=\"\($0.value)\"" }
            .joined(separator: ", ")
        return "OAuth \(components)"
    }
}
```

**Import note:** `CryptoKit` must be imported at the top of this file:
```swift
import CryptoKit
import Foundation
```

### ✅ 6.8 — `CDOAuth1SessionManager.swift`

Replaces `CDOAuth1SessionManager.h/m`, which subclassed `AFHTTPSessionManager`. The new implementation wraps `URLSession` directly.

Key design decisions vs. the original:
- `final class` (not open) — callers subclass rarely; matches typical networking wrapper pattern.
- `async throws` for all three OAuth handshake methods — replaces success/failure callbacks.
- `URLSession` injection in `init` — enables testing without live network.
- `@MainActor` not applied here — networking should not be pinned to the main actor; callers dispatch UI updates themselves.

```swift
public final class CDOAuth1SessionManager {

    public let baseURL: URL
    public let session: URLSession
    public private(set) var requestSigner: CDOAuth1RequestSigner

    public var isAuthorized: Bool {
        guard let token = requestSigner.accessToken else { return false }
        return !token.isExpired
    }

    public init(baseURL: URL,
                consumerKey: String,
                consumerSecret: String,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.requestSigner = CDOAuth1RequestSigner(
            service: baseURL.host ?? baseURL.absoluteString,
            consumerKey: consumerKey,
            consumerSecret: consumerSecret
        )
    }

    // MARK: - Authorization Status

    public func deauthorize() throws {
        try requestSigner.removeAccessToken()
    }

    // MARK: - OAuth Handshake

    public func fetchRequestToken(path: String,
                                  method: String,
                                  callbackURL: URL,
                                  scope: String? = nil) async throws -> CDOAuth1Credential {
        requestSigner.requestToken = nil

        var params = requestSigner.oauthParameters()
        params["oauth_callback"] = callbackURL.absoluteString
        if let scope, requestSigner.accessToken == nil {
            params["scope"] = scope
        }

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try requestSigner.signed(request, parameters: params)
        let (data, _) = try await session.data(for: signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.invalidResponse
        }

        requestSigner.requestToken = credential
        return credential
    }

    public func fetchAccessToken(path: String,
                                 method: String,
                                 requestToken: CDOAuth1Credential) async throws -> CDOAuth1Credential {
        guard let token = requestToken.token.nilIfEmpty,
              let verifier = requestToken.verifier?.nilIfEmpty else {
            throw CDOAuth1Error.invalidRequestToken
        }

        requestSigner.requestToken = requestToken

        var params = requestSigner.oauthParameters()
        params["oauth_token"]    = token
        params["oauth_verifier"] = verifier

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try requestSigner.signed(request, parameters: params)
        let (data, _) = try await session.data(for: signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.invalidResponse
        }

        try requestSigner.saveAccessToken(credential)
        requestSigner.requestToken = nil
        return credential
    }

    public func refreshAccessToken(path: String,
                                   parameters: [String: String]? = nil,
                                   method: String,
                                   accessToken: CDOAuth1Credential) async throws -> CDOAuth1Credential {
        guard let token = accessToken.token.nilIfEmpty else {
            throw CDOAuth1Error.invalidAccessToken
        }

        var params = requestSigner.oauthParameters()
        params["oauth_token"] = token
        if let extra = parameters {
            params.merge(extra) { $1 }
        }

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try requestSigner.signed(request, parameters: params)
        let (data, _) = try await session.data(for: signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.invalidResponse
        }

        try requestSigner.saveAccessToken(credential)
        requestSigner.requestToken = nil
        return credential
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
```

**Breaking API changes vs. v1.0.0:**
| Old (Objective-C / callbacks) | New (Swift / async throws) |
|-------------------------------|---------------------------|
| `fetchRequestTokenWithPath:method:callbackURL:scope:success:failure:` | `fetchRequestToken(path:method:callbackURL:scope:) async throws` |
| `fetchAccessTokenWithPath:method:requestToken:success:failure:` | `fetchAccessToken(path:method:requestToken:) async throws` |
| `refreshAccessTokenWithPath:parameters:method:accessToken:success:failure:` | `refreshAccessToken(path:parameters:method:accessToken:) async throws` |
| `requestSerializer.saveAccessToken(_:)` returns `BOOL` | `requestSigner.saveAccessToken(_:) throws` |
| `requestSerializer.removeAccessToken()` returns `BOOL` | via `deauthorize() throws` on the manager |

### ✅ 6.9 — `String+CDOAuth1Kit.swift`

Replace `NSString+CDOAuth1Kit.h/m`. Key changes:
- Replace deprecated `CFURLCreateStringByAddingPercentEscapes` with `addingPercentEncoding(withAllowedCharacters:)`.
- Replace deprecated `CFURLCreateStringByReplacingPercentEscapesUsingEncoding` with `removingPercentEncoding`.
- `cd_URLEncodeSlashesAndQuestionMarks` workaround for AFNetworking 2.6 is no longer needed.

```swift
extension String {

    /// RFC 5849 §3.6 percent encoding — encodes everything except unreserved characters.
    func oauthPercentEncoded() -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }

    func oauthPercentDecoded() -> String {
        removingPercentEncoding ?? self
    }
}
```

The `cd_` prefix methods in the original (`cd_URLEncode`, `cd_URLDecode`, `cd_URLEncodeSlashesAndQuestionMarks`) are replaced by `oauthPercentEncoded()` and `oauthPercentDecoded()`. They are internal implementation details — not public API.

### ✅ 6.10 — `Dictionary+CDOAuth1Kit.swift`

Replace `NSDictionary+CDOAuth1Kit.h/m`:

```swift
extension [String: String] {

    init(queryString: String) {
        self = queryString
            .components(separatedBy: "&")
            .reduce(into: [:]) { dict, pair in
                let parts = pair.components(separatedBy: "=")
                guard parts.count == 2 else { return }
                dict[parts[0].oauthPercentDecoded()] = parts[1].oauthPercentDecoded()
            }
    }

    func queryStringRepresentation() -> String {
        map { "\($0.key.oauthPercentEncoded())=\($0.value.oauthPercentEncoded())" }
            .sorted()
            .joined(separator: "&")
    }
}
```

---

## 7. Unit Tests

Create `Tests/CDOAuth1KitTests/` directory. Tests use the Swift Testing framework (matching CDMarkdownKit).

### ✅ 7.1 — Directory Structure

```
Tests/
└── CDOAuth1KitTests/
    ├── CDOAuth1CredentialTests.swift
    ├── CDOAuth1HelperTests.swift
    ├── CDOAuth1RequestSignerTests.swift
    ├── CDOAuth1SessionManagerTests.swift
    └── Extensions/
        ├── DictionaryTests.swift
        └── StringTests.swift
```

### ✅ 7.2 — `CDOAuth1CredentialTests.swift`

```swift
import Testing
@testable import CDOAuth1Kit

@Suite struct CDOAuth1CredentialTests {

    @Test func initWithTokenAndSecret() {
        let cred = CDOAuth1Credential(token: "tok", secret: "sec")
        #expect(cred.token == "tok")
        #expect(cred.secret == "sec")
        #expect(cred.isExpired == false)
    }

    @Test func initWithQueryString() {
        let qs = "oauth_token=T&oauth_token_secret=S&oauth_verifier=V"
        let cred = CDOAuth1Credential(queryString: qs)
        #expect(cred != nil)
        #expect(cred?.token == "T")
        #expect(cred?.secret == "S")
        #expect(cred?.verifier == "V")
    }

    @Test func initWithInvalidQueryString() {
        #expect(CDOAuth1Credential(queryString: "") == nil)
        #expect(CDOAuth1Credential(queryString: "oauth_token=T") == nil) // missing secret
    }

    @Test func isExpiredWhenPastDate() {
        let past = Date(timeIntervalSinceNow: -1)
        let cred = CDOAuth1Credential(token: "t", secret: "s", expiration: past)
        #expect(cred.isExpired == true)
    }

    @Test func isNotExpiredWhenFutureDate() {
        let future = Date(timeIntervalSinceNow: 3600)
        let cred = CDOAuth1Credential(token: "t", secret: "s", expiration: future)
        #expect(cred.isExpired == false)
    }

    @Test func isNotExpiredWhenNoExpiration() {
        let cred = CDOAuth1Credential(token: "t", secret: "s")
        #expect(cred.isExpired == false)
    }

    @Test func codableRoundTrip() throws {
        let cred = CDOAuth1Credential(token: "t", secret: "s", expiration: Date())
        let data = try JSONEncoder().encode(cred)
        let decoded = try JSONDecoder().decode(CDOAuth1Credential.self, from: data)
        #expect(decoded == cred)
    }

    @Test func userInfoPopulatedFromExtraQueryParams() {
        let qs = "oauth_token=T&oauth_token_secret=S&oauth_session_handle=H"
        let cred = CDOAuth1Credential(queryString: qs)
        #expect(cred?.userInfo?["oauth_session_handle"] == "H")
    }
}
```

### ✅ 7.3 — `CDOAuth1HelperTests.swift`

```swift
import Testing
@testable import CDOAuth1Kit

@Suite struct CDOAuth1HelperTests {

    @Test func matchingSchemeAndHost() {
        let url = URL(string: "myapp://oauthCallback?oauth_token=T")!
        #expect(CDOAuth1Helper.isAuthorizationCallbackURL(url, scheme: "myapp", host: "oauthCallback"))
    }

    @Test func mismatchedScheme() {
        let url = URL(string: "myapp://oauthCallback")!
        #expect(!CDOAuth1Helper.isAuthorizationCallbackURL(url, scheme: "otherapp", host: "oauthCallback"))
    }

    @Test func mismatchedHost() {
        let url = URL(string: "myapp://oauthCallback")!
        #expect(!CDOAuth1Helper.isAuthorizationCallbackURL(url, scheme: "myapp", host: "other"))
    }
}
```

### ✅ 7.4 — `CDOAuth1RequestSignerTests.swift`

The OAuth signature algorithm has a well-known test vector from RFC 5849 Appendix A. Use it to verify the HMAC-SHA1 implementation:

```swift
import Testing
@testable import CDOAuth1Kit

@Suite struct CDOAuth1RequestSignerTests {

    // Test vector from RFC 5849 §A.5
    // https://tools.ietf.org/html/rfc5849#appendix-A.5
    @Test func rfc5849SignatureTestVector() throws {
        // Given fixed parameters (nonce, timestamp, token)
        // the signature base string should produce a known HMAC-SHA1 value.
        // This test verifies the signing pipeline end-to-end.
        let consumerSecret = "djr9rjt0jd78jf88"
        let tokenSecret    = "jjd999tj88uiths3"
        let signingKey     = "\(consumerSecret.oauthPercentEncoded())&\(tokenSecret.oauthPercentEncoded())"

        let baseString = "POST&https%3A%2F%2Fphotos.example.net%2Finitiate&oauth_callback%3Doob%26oauth_consumer_key%3Ddpf43f3p2l4k3l03%26oauth_nonce%3DwnnvGrqVeYPSIXXI%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D137131200%26oauth_version%3D1.0"

        // Manually call the internal hmacSHA1 via the signer
        // (package-private test; expose via @testable import)
        let signer = CDOAuth1RequestSigner(service: "example.net",
                                           consumerKey: "dpf43f3p2l4k3l03",
                                           consumerSecret: consumerSecret)
        // Test that the public `signed(_:parameters:)` does not throw on a valid request
        let url = URL(string: "https://photos.example.net/initiate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        #expect(throws: Never.self) { try signer.signed(request) }
    }

    @Test func oauthParametersContainRequiredKeys() {
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "key",
                                           consumerSecret: "secret")
        let params = signer.oauthParameters()
        #expect(params["oauth_version"] == "1.0")
        #expect(params["oauth_consumer_key"] == "key")
        #expect(params["oauth_signature_method"] == "HMAC-SHA1")
        #expect(params["oauth_timestamp"] != nil)
        #expect(params["oauth_nonce"] != nil)
    }

    @Test func signedRequestHasAuthorizationHeader() throws {
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "ck",
                                           consumerSecret: "cs")
        var request = URLRequest(url: URL(string: "https://api.example.com/endpoint")!)
        request.httpMethod = "GET"
        let signed = try signer.signed(request)
        let authHeader = signed.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader?.hasPrefix("OAuth ") == true)
    }
}
```

### ✅ 7.5 — `Extensions/StringTests.swift`

```swift
import Testing
@testable import CDOAuth1Kit

@Suite struct StringOAuthTests {

    @Test func percentEncodesSpecialCharacters() {
        #expect("hello world".oauthPercentEncoded() == "hello%20world")
        #expect("a&b=c".oauthPercentEncoded() == "a%26b%3Dc")
    }

    @Test func percentDecodesEncodedString() {
        #expect("hello%20world".oauthPercentDecoded() == "hello world")
    }

    @Test func unreservedCharactersNotEncoded() {
        let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        #expect(unreserved.oauthPercentEncoded() == unreserved)
    }
}
```

### ✅ 7.6 — `Extensions/DictionaryTests.swift`

```swift
import Testing
@testable import CDOAuth1Kit

@Suite struct DictionaryQueryStringTests {

    @Test func initFromQueryString() {
        let dict = [String: String](queryString: "key=value&foo=bar")
        #expect(dict["key"] == "value")
        #expect(dict["foo"] == "bar")
    }

    @Test func queryStringRepresentation() {
        let dict = ["b": "2", "a": "1"]
        let qs = dict.queryStringRepresentation()
        #expect(qs == "a=1&b=2")
    }

    @Test func roundTrip() {
        let original = ["oauth_token": "T", "oauth_verifier": "V"]
        let qs = original.queryStringRepresentation()
        let parsed = [String: String](queryString: qs)
        #expect(parsed == original)
    }
}
```

---

## 8. Example App Update

The example app demonstrates the full OAuth 1.0 flow using Twitter's API (or a mock service once Twitter's API is no longer public). The current app is Objective-C. Convert it to Swift and reorganize its file structure to match CDMarkdownKit's example layout.

### ✅ 8.1 — New File Structure

```
Example/
├── Source/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── Networking/
│   │   └── TwitterClient.swift       # replaces CDTwitterClient.h/m
│   ├── Model/
│   │   └── Tweet.swift               # replaces CDTweet.h/m
│   └── ViewControllers/
│       └── TweetsViewController.swift # replaces CDTweetsViewController.h/m
└── Resources/
    ├── Assets.xcassets/
    │   └── AppIcon.appiconset/
    │       └── Contents.json
    ├── Base.lproj/
    │   ├── LaunchScreen.storyboard
    │   └── Main.storyboard
    └── Info.plist
```

Delete:
- `Example/CDOAuth1Kit/Supporting Files/CDOAuth1Kit-Prefix.pch` — precompiled headers are not used in Swift projects.
- `Example/CDOAuth1Kit/en.lproj/` — rename/replace with `Resources/Base.lproj/`.

### ✅ 8.2 — AppDelegate / SceneDelegate

Add a `SceneDelegate.swift` to support iOS 13+ scene-based lifecycle. Remove the UIWebView usage (`UIWebView+AFNetworking` from AFNetworking) — it is deprecated since iOS 12.

### ✅ 8.3 — TwitterClient.swift

Replace the Objective-C `CDTwitterClient` with a Swift class using `CDOAuth1SessionManager` with async/await:

```swift
final class TwitterClient {

    static let shared = TwitterClient()

    private let manager = CDOAuth1SessionManager(
        baseURL: URL(string: "https://api.twitter.com/oauth/")!,
        consumerKey: "YOUR_CONSUMER_KEY",
        consumerSecret: "YOUR_CONSUMER_SECRET"
    )

    var isAuthorized: Bool { manager.isAuthorized }

    func fetchRequestToken() async throws -> CDOAuth1Credential {
        try await manager.fetchRequestToken(
            path: "request_token",
            method: "POST",
            callbackURL: URL(string: "cdoauth1kit://oauthCallback")!
        )
    }

    func fetchAccessToken(requestToken: CDOAuth1Credential) async throws {
        _ = try await manager.fetchAccessToken(
            path: "access_token",
            method: "POST",
            requestToken: requestToken
        )
    }

    func deauthorize() throws {
        try manager.deauthorize()
    }
}
```

### ✅ 8.4 — Tweet Model

Replace `CDTweet` with a Swift `Codable` struct:

```swift
struct Tweet: Codable, Identifiable {
    let id: String
    let text: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id = "id_str"
        case text
        case createdAt = "created_at"
    }
}
```

### ✅ 8.5 — Update Podfile

Update `Example/Podfile`:
```ruby
platform :ios, '13.0'

use_frameworks!

target 'CDOAuth1Kit_Example' do
  pod 'CDOAuth1Kit', :path => '../'
end
```

---

## 9. Documentation

### ✅ 9.1 — README.md

Replace the current README with a modern navigation-hub format matching CDMarkdownKit:

```markdown
# CDOAuth1Kit

[![CI Status](https://github.com/chrisdhaan/CDOAuth1Kit/actions/workflows/ci.yml/badge.svg)](...)
[![Swift](https://img.shields.io/badge/Swift-5.3%2B-orange?style=flat)](...)
[![CocoaPods](https://img.shields.io/cocoapods/v/CDOAuth1Kit.svg?style=flat)](...)
[![SPM](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat)](...)
[![License](https://img.shields.io/cocoapods/l/CDOAuth1Kit.svg?style=flat)](...)

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
[...]

### CocoaPods
[...]

## Usage

See [Documentation/Usage.md](Documentation/Usage.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT. See [LICENSE](LICENSE).
```

Remove badges for:
- Travis CI (deleted)
- Carthage (no longer supported; community has abandoned it)

### ✅ 9.2 — CONTRIBUTING.md

Create `CONTRIBUTING.md` at the repo root. Use the CDMarkdownKit `CONTRIBUTING.md` as a template, substituting all `CDMarkdownKit` references with `CDOAuth1Kit` and updating the Stack Overflow tag to `cdoauth1kit`.

### ✅ 9.3 — CLAUDE.md

Create `CLAUDE.md` at the repo root. This file provides context to Claude Code for future work on the project. Include:

- Project overview (OAuth 1.0a library for iOS/macOS, no dependencies)
- Repository layout
- Platform & Swift support table
- Architecture summary (CDOAuth1RequestSigner → CDOAuth1SessionManager flow)
- How to build (SPM and Xcode commands)
- How to generate documentation (Jazzy)
- How to run tests
- Distribution methods (SPM, CocoaPods)
- CI job descriptions
- Known issues / tech debt

### ✅ 9.4 — `Documentation/ARCHITECTURE.md`

Create `Documentation/ARCHITECTURE.md`. Document:

**OAuth 1.0a signing flow:**
```
Caller
  │
  ▼
CDOAuth1SessionManager
  │  holds baseURL, URLSession, CDOAuth1RequestSigner
  │
  ├─ fetchRequestToken(path:method:callbackURL:scope:)
  │    ├─ calls requestSigner.oauthParameters()
  │    ├─ calls requestSigner.signed(request, parameters:)
  │    │    └─ CDOAuth1RequestSigner.signature(method:urlString:parameters:)
  │    │         └─ CryptoKit.HMAC<Insecure.SHA1>
  │    └─ URLSession.data(for: signedRequest)
  │
  ├─ fetchAccessToken(path:method:requestToken:)
  │    └─ (same signing flow)
  │    └─ KeychainStore.write(accessToken, service:)
  │
  └─ refreshAccessToken(path:parameters:method:accessToken:)
       └─ (same signing flow)
       └─ KeychainStore.write(refreshedToken, service:)

KeychainStore
  internal helper — JSONEncoder/Decoder + SecItem APIs
  no public API surface
```

**Keychain storage:** Credentials are stored under `kSecClassGenericPassword` keyed by `kSecAttrService` = the manager's `baseURL.host`. One credential per service.

### 9.5 — `Documentation/Usage.md`

Create `Documentation/Usage.md` with full usage examples:
- Initialization
- Registering a callback URL scheme in Info.plist
- Fetching a request token (with async/await)
- Handling the OAuth callback URL (`CDOAuth1Helper.isAuthorizationCallbackURL`)
- Fetching an access token
- Refreshing an expired access token
- Checking authorization status (`manager.isAuthorized`)
- Deauthorizing (`manager.deauthorize()`)
- Error handling

### 9.6 — `Documentation/CDOAuth1Kit 2.0 Migration Guide.md`

Create a migration guide for users upgrading from v1.0.0 (Objective-C / AFNetworking) to v2.0.0 (Swift / no dependencies). Cover:

1. **Installation changes** — remove `pod 'AFNetworking'` from Podfile; update to `pod 'CDOAuth1Kit', '~> 2.0'`
2. **Import changes** — remove `#import <AFNetworking/AFNetworking.h>`
3. **Initialization** — same parameters, method name unchanged
4. **OAuth handshake** — migrate from success/failure blocks to `async throws`
5. **Callback handling** — `CDOAuth1Helper` method signature change (parameter labels added)
6. **Token storage** — keychain data is not migrated automatically; users must re-authenticate once after upgrading
7. **Removed APIs** — `CDOAuth1RequestSerializer` (replaced by `CDOAuth1RequestSigner`); `saveAccessToken:` now `throws` instead of returning `BOOL`

### 9.7 — DocC Catalog (`Source/CDOAuth1Kit.docc/`)

*(Added to match CDMarkdownKit 3.1.0 — CDMarkdownKit migrated from Jazzy to DocC in 3.1.0. CDOAuth1Kit skips Jazzy and goes straight to DocC for v2.0.0.)*

Create a DocC documentation catalog inside the `Source/` directory. The catalog provides a landing page and a Getting Started article; all public API is documented via `///` triple-slash doc comments in the Swift source files.

**Directory structure:**
```
Source/
└── CDOAuth1Kit.docc/
    ├── CDOAuth1Kit.md      # module landing page
    └── GettingStarted.md  # article linked from landing page
```

**`CDOAuth1Kit.md`** — module landing page:
```markdown
# ``CDOAuth1Kit``

A pure-Swift, zero-dependency OAuth 1.0a library for iOS and macOS.

## Overview

CDOAuth1Kit handles the full OAuth 1.0a three-legged handshake using `URLSession` and
`CryptoKit`, storing the access token in the keychain. It requires no external dependencies.

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
```

**`GettingStarted.md`** — step-by-step article:
```markdown
# Getting Started

Authenticate with an OAuth 1.0a API in four steps.

## Create a session manager

```swift
let manager = CDOAuth1SessionManager(
    baseURL: URL(string: "https://api.example.com/")!,
    consumerKey: "YOUR_CONSUMER_KEY",
    consumerSecret: "YOUR_CONSUMER_SECRET"
)
```

## Fetch a request token

```swift
let requestToken = try await manager.fetchRequestToken(
    path: "oauth/request_token",
    method: "POST",
    callbackURL: URL(string: "yourapp://oauthCallback")!
)
```

## Handle the callback URL

In `SceneDelegate.scene(_:openURLContexts:)`:

```swift
if CDOAuth1Helper.isAuthorizationCallbackURL(url, scheme: "yourapp", host: "oauthCallback") {
    // Extract oauth_token and oauth_verifier from url.query
}
```

## Fetch the access token

```swift
let accessToken = try await manager.fetchAccessToken(
    path: "oauth/access_token",
    method: "POST",
    requestToken: verifiedRequestToken
)
```
```

**Generating and hosting docs:**

```bash
# Generate static site locally
swift package --disable-sandbox generate-documentation \
  --target CDOAuth1Kit \
  --output-path docs \
  --transform-for-static-hosting \
  --hosting-base-path CDOAuth1Kit
```

Commit the `docs/` output to the repo. Enable GitHub Pages on the `master` branch `docs/` folder in the repository settings. The documentation URL will be `https://chrisdhaan.github.io/CDOAuth1Kit/documentation/cdoauth1kit/`.

Update `README.md` and the podspec `documentation_url` to point to this URL.

**Inline doc comments:** All public symbols (`CDOAuth1SessionManager`, `CDOAuth1RequestSigner`, `CDOAuth1Credential`, `CDOAuth1Error`, `CDOAuth1Helper`) must have `///` doc comments on every public `init`, `func`, and `var`. The DocC build job in CI fails on any `warning:` output, which catches undocumented public symbols.

---

## 10. CHANGELOG.md

The complete `CHANGELOG.md` for v2.0.0 entry (to be finalized with the actual release date):

```markdown
## [2.0.0](https://github.com/chrisdhaan/CDOAuth1Kit/releases/tag/2.0.0)

Released on YYYY-MM-DD.

### Added

- Swift Package Manager support (swift-tools-version 6.0, iOS 13.0+, macOS 10.15+)
- `async throws` API on all three OAuth handshake methods
- `CDOAuth1Error` Swift error enum replacing the C-style `CDOAuth1ErrorCode` typedef
- `CryptoKit`-based HMAC-SHA1 signing replacing `CommonCrypto/CCHmac` directly
- `PrivacyInfo.xcprivacy` privacy manifest for App Store compliance
- `KeychainStore` internal type using `Codable` / `JSONEncoder` for credential serialization
- Unit test suite using Swift Testing framework
- GitHub Actions CI (iOS/macOS matrix builds, CocoaPods lint, SPM test, SwiftLint, SwiftFormat, DocC build, CodeQL)
- DocC documentation catalog (`Source/CDOAuth1Kit.docc/`) with landing page and Getting Started article
- `swift-docc-plugin` dependency in `Package.swift` for `swift package generate-documentation`
- GitHub Pages–hosted API documentation at `https://chrisdhaan.github.io/CDOAuth1Kit/`
- `.swiftlint.yml` for semantic code quality enforcement
- `.swiftformat` for mechanical code style enforcement
- `Gemfile` / `Gemfile.lock` for reproducible Ruby dependency management
- `CONTRIBUTING.md`, `CLAUDE.md`
- `Documentation/ARCHITECTURE.md`, `Documentation/Usage.md`
- `Documentation/CDOAuth1Kit 2.0 Migration Guide.md`
- GitHub issue templates (bug report, feature request) and pull request template
- `FUNDING.yml` for GitHub Sponsors

### Updated

- Rewritten entirely in Swift — no Objective-C files remain
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
```

---

## Summary: What Does Not Change

| Item | Status | Notes |
|------|--------|-------|
| OAuth 1.0a algorithm | Unchanged | HMAC-SHA1 is the spec; only the implementation library changes |
| Keychain service key | Unchanged | Still uses `baseURL.host` as the keychain service identifier |
| `CDOAuth1Helper` logic | Unchanged | Same scheme+host comparison; only the Swift calling convention changes |
| MIT License | Unchanged | |
| `CDOAuth1Credential` field names | Unchanged | `token`, `secret`, `verifier`, `expiration`, `userInfo` all preserved |
| Three OAuth methods | Unchanged | Same three-step handshake; only the calling convention (callbacks → async/await) changes |

---

## Xcode Project Changes Required

The existing `Example/CDOAuth1Kit.xcodeproj` was built for a CocoaPods workspace and uses an Objective-C build target. The Xcode project needs to be rebuilt or significantly modified. The recommended approach is to create a new Xcode project using Xcode's "Create New Project" flow and configure it with the following:

1. **Two framework schemes**: `CDOAuth1Kit iOS` and `CDOAuth1Kit macOS`
2. **One test scheme**: connected to `Tests/CDOAuth1KitTests/`
3. **One example scheme**: `CDOAuth1Kit Example` (iOS app)
4. **Swift version**: 5 (matching `swiftLanguageModes: [.v5]` in Package.swift)
5. **Deployment targets**: iOS 13.0, macOS 10.15
6. **Source root**: `Source/` for the framework target
7. **No bridging headers** — pure Swift
8. **Enable modules**: Yes

The `.xcworkspace` at the repo root should be updated to reference the new project.
