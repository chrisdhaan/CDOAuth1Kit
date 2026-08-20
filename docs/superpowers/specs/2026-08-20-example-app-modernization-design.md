# CDOAuth1Kit Example App Modernization — Design

## Context

CDOAuth1Kit v2.0.0 rewrote the core library in Swift, but the `Example/` app was
left behind: it still contains a legacy Objective-C/CocoaPods app
(`Example/CDOAuth1Kit/Classes/*.h/.m`, `Example/CDOAuth1Kit.xcodeproj`) alongside a
partially-started Swift scaffold (`Example/Source/{AppDelegate,SceneDelegate}.swift`,
`Example/Source/Networking/TwitterClient.swift`, `Example/Source/Model/Tweet.swift`)
that has no Xcode project wired to it and targets Twitter's OAuth endpoints, which
have been paywalled since 2023.

Three sibling repos (CDMarkdownKit, CDYelpFusionKit, CDUntappdKit) have each been
modernized already and converged on a consistent Example-app pattern. The goal of
this work is to bring CDOAuth1Kit's Example app in line with that pattern.

This spec was produced via the `superpowers:brainstorming` skill (architectural
path). Two decisions were confirmed with the repo owner before writing this spec:

1. **Demo API provider: Discogs**, not Twitter/X (paywalled) — Discogs has a free
   developer tier and a real OAuth 1.0a flow (not just a static personal token).
2. **File layout: match the current sibling pattern** (flat `Source/` with a
   `<Library>Manager` wrapper + a single table-based `ViewController` + a pushed
   JSON response screen) — not the `Networking/Model/ViewControllers` subfolder
   split sketched in `Documentation/IMPLEMENTATION.md` §8, which predates the
   siblings' convergence on the flatter pattern.

## Verified facts (Discogs OAuth 1.0a)

Confirmed via Discogs API docs/forum (2026):

| Step | Method | URL |
|---|---|---|
| Request token | `GET` | `https://api.discogs.com/oauth/request_token` |
| User authorization | browser | `https://www.discogs.com/oauth/authorize?oauth_token=...` |
| Access token | `POST` | `https://api.discogs.com/oauth/access_token` |
| Authenticated identity check | `GET` | `https://api.discogs.com/oauth/identity` |

- A custom callback URL (not just OOB/PIN) is supported — configured in the
  Discogs app's developer settings, matching the app's existing
  `cdoauth1kit://oauthCallback` scheme handling in `SceneDelegate`.
- All requests must send a descriptive `User-Agent` header or Discogs returns 403.
- `CDOAuth1SessionManager.requestSigner` is already `public private(set)`, and
  `CDOAuth1RequestSigner.signed(_:parameters:)` is already public — the Example
  app can sign and execute the `/oauth/identity` call itself with **no changes
  to `Source/`**.

## Verified facts (existing repo state)

- Root `CDOAuth1Kit.xcodeproj` already exists (added in a prior commit) with
  native targets `CDOAuth1Kit iOS` (target GUID `CD0A00000000000000000010`,
  Products group `CD0A00000000000000000006`) and `CDOAuth1Kit macOS`
  (`CD0A00000000000000000019`), each producing `CDOAuth1Kit.framework`.
- `CDOAuth1Kit.xcworkspace` currently references `Example/CDOAuth1Kit.xcodeproj`
  (the legacy project) — needs updating to the new project path.
- None of the three sibling repos build their Example app in CI — confirmed by
  grepping each `.github/workflows/*.yml` for "example" (no matches). CDOAuth1Kit's
  CI should not gain an Example-app job either.
- This machine has Xcode 26.6 and iOS simulators installed, so the hand-authored
  `.pbxproj` can be verified with a real `xcodebuild build`, not just inspected.

## Design

### 1. Remove the legacy Objective-C app

`git rm -r`:
- `Example/CDOAuth1Kit/` (the `Classes/` Obj-C sources, old Info.plist, xcassets,
  storyboards under this legacy path)
- `Example/CDOAuth1Kit.xcodeproj/`

This matches Known Issue #2 in `CLAUDE.md` ("legacy Xcode project files ...
have not been updated to use the new `Source/` structure").

### 2. New file layout

```
Example/
├── iOS Example.xcodeproj/
├── Secrets.xcconfig.example
├── Resources/
│   ├── Assets.xcassets/AppIcon.appiconset/Contents.json
│   ├── Base.lproj/
│   │   ├── Main.storyboard
│   │   └── LaunchScreen.storyboard
│   └── Info.plist
└── Source/
    ├── AppDelegate.swift
    ├── SceneDelegate.swift
    ├── CDOAuth1KitManager.swift
    ├── ViewController.swift
    ├── CDOAuth1KitJSONResponseViewController.swift
    └── JSONPrettyPrinter.swift
```

Flat `Source/`, no `Networking/`/`Model/`/`ViewControllers/` subfolders. The
existing `Example/Source/Networking/TwitterClient.swift` and
`Example/Source/Model/Tweet.swift` are deleted (superseded by
`CDOAuth1KitManager.swift`, which owns both the OAuth handshake and the one
authenticated demo call — there is no separate domain model, since the identity
response is displayed as raw pretty-printed JSON, not decoded into a typed
struct).

`Example/Secrets.xcconfig` (the real, filled-in file) is gitignored, created
locally by copying `Secrets.xcconfig.example`, matching CDYelpFusionKit and
CDUntappdKit exactly (`Example/Secrets.xcconfig` already needs a `.gitignore`
entry).

### 3. `CDOAuth1KitManager.swift`

`@MainActor final class`, singleton (`.shared`), mirrors
`CDYelpFusionKitManager`/`CDUntappdKitManager` in shape:

- `configure()`: reads `DISCOGS_CONSUMER_KEY` / `DISCOGS_CONSUMER_SECRET` from
  `Bundle.main.infoDictionary`; `fatalError`s with setup instructions
  ("copy Secrets.xcconfig.example to Secrets.xcconfig...") if missing or empty —
  matches `CDUntappdKitManager.configure()`'s guard pattern exactly. Constructs
  `CDOAuth1SessionManager(baseURL: "https://api.discogs.com/oauth/", ...)`.
- `var isAuthorized: Bool` — proxies `sessionManager.isAuthorized`.
- `func beginAuthorization() async throws -> URL` — calls
  `sessionManager.fetchRequestToken(path: "request_token", method: "GET", callbackURL: cdoauth1kitCallbackURL)`,
  returns `https://www.discogs.com/oauth/authorize?oauth_token=<token>`.
- `func completeAuthorization(callbackURL url: URL) async throws` — parses
  `url.query` into a `CDOAuth1Credential`, calls
  `sessionManager.fetchAccessToken(path: "access_token", method: "POST", requestToken:)`.
- `func deauthorize() throws` — proxies `sessionManager.deauthorize()`.
- `func fetchIdentity() async throws -> Data` — builds
  `GET https://api.discogs.com/oauth/identity` with a `User-Agent` header set,
  signs it via `sessionManager.requestSigner.signed(_:)`, executes via
  `URLSession.shared.data(for:)`, returns the raw response `Data`.

### 4. `SceneDelegate.swift`

Keep the existing `scene(_:openURLContexts:)` →
`CDOAuth1Helper.isAuthorizationCallbackURL(url, scheme: "cdoauth1kit", host: "oauthCallback")`
→ `NotificationCenter.default.post(name: ..., object: url)` logic as-is — this is
unique to CDOAuth1Kit (the siblings have no interactive redirect flow to
intercept). Replace the manual `UIWindow`/bare-`UIViewController` construction in
`willConnectTo` with storyboard-driven setup (drop the window-building code
entirely, matching CDUntappdKit's near-empty `willConnectTo`, relying on
`UIApplicationSceneManifest.UISceneStoryboardFile = "Main"` in `Info.plist`).

### 5. `ViewController.swift`

Table-based (`UITableViewDataSource`/`UITableViewDelegate`), one section, three
rows, matching the Yelp/Untappd endpoint-list idiom:

1. "Authorize with Discogs" — always tappable. Calls
   `CDOAuth1KitManager.shared.beginAuthorization()`, opens the returned URL via
   `UIApplication.shared.open(_:)`.
2. "Fetch My Identity" — grayed out / disabled when `!manager.isAuthorized`.
   Calls `fetchIdentity()`, pretty-prints the `Data` via `JSONPrettyPrinter`,
   pushes `CDOAuth1KitJSONResponseViewController`.
3. "Deauthorize" — grayed out / disabled when `!manager.isAuthorized`. Calls
   `deauthorize()`, reloads the table.

Observes the OAuth-callback `NotificationCenter` notification (added once,
e.g. in `viewDidLoad`); on receipt, extracts the URL, calls
`completeAuthorization(callbackURL:)` in a `Task`, then reloads the table to
reflect the new authorized state (and surfaces failures via a
`UIAlertController`, matching Yelp's `presentError(_:)` pattern).

### 6. `CDOAuth1KitJSONResponseViewController.swift`

Near-identical port of `CDYelpJSONResponseViewController`
/`CDUntappdJSONResponseViewController`: takes a title + pretty-printed JSON
string, displays it in a read-only monospaced `UITextView`, pushed onto the nav
stack.

### 7. `JSONPrettyPrinter.swift`

Simpler than the sibling version: since `fetchIdentity()` already returns raw
`Data` from the network (there is no typed `Decodable` response model to
re-encode via `Mirror` reflection), this is just:

```swift
enum JSONPrettyPrinter {
    static func string(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: pretty, encoding: .utf8) else {
            return String(data: data, encoding: .utf8) ?? "<undecodable response>"
        }
        return text
    }
}
```

### 8. `Info.plist`

Same shape as the sibling `Resources/Info.plist` files (scene manifest pointing
at `Main` storyboard, `UILaunchStoryboardName`), plus:
- `CFBundleURLTypes` registering the `cdoauth1kit` scheme (required so Safari can
  hand the OAuth redirect back to the app).
- `DISCOGS_CONSUMER_KEY` / `DISCOGS_CONSUMER_SECRET` keys sourced from
  `$(DISCOGS_CONSUMER_KEY)` / `$(DISCOGS_CONSUMER_SECRET)` build settings
  (populated by `Secrets.xcconfig`), matching how `YelpAPIKey` is wired in
  CDYelpFusionKit's `Info.plist`.

### 9. `iOS Example.xcodeproj`

Hand-authored (no Xcode GUI available in this environment), modeled on
CDYelpFusionKit's/CDUntappdKit's `iOS Example.xcodeproj`:
- Single iOS app target named `iOS Example`.
- Cross-project reference to the root `CDOAuth1Kit.xcodeproj`, linking and
  embedding the `CDOAuth1Kit iOS` framework target (`PBXContainerItemProxy` with
  `remoteGlobalIDString = CD0A00000000000000000010`, `ProductGroup =
  CD0A00000000000000000006`) — same mechanism as the siblings' cross-project
  framework references, just pointed at CDOAuth1Kit's existing target GUIDs.
- `Secrets.xcconfig` wired as the target's `baseConfigurationReference` (both
  Debug and Release), matching CDYelpFusionKit's pbxproj wiring exactly.
- Scheme named `iOS Example` (shared scheme under `xcshareddata/xcschemes/`).

### 10. Root workspace

Update `CDOAuth1Kit.xcworkspace/contents.xcworkspacedata`'s second `FileRef`
from `group:Example/CDOAuth1Kit.xcodeproj` to
`group:Example/iOS Example.xcodeproj`.

### 11. CI

No changes. Confirmed none of the three sibling repos build their Example app
in CI; CDOAuth1Kit's `.github/workflows/ci.yml` should not gain one either.

### 12. Verification

Since this machine has Xcode 26.6 and iOS simulators available, verification is
a real build, not just visual inspection:
```
xcodebuild -project "Example/iOS Example.xcodeproj" -scheme "iOS Example" \
  -destination "OS=<sim-version>,name=<sim-device>" -configuration Debug clean build
```
This must succeed (with `Secrets.xcconfig` populated with placeholder values —
the build doesn't need real Discogs credentials, only the handshake at runtime
does) before the work is considered done. Interactive testing of the actual
OAuth handshake against Discogs (running in Simulator, tapping through
Authorize → browser → redirect → Identity) should also be attempted, but
requires real Discogs developer credentials the repo owner will need to supply
or test themselves.

### 13. Documentation updates

- `CLAUDE.md`: update the "Repository Layout" section's `Example/` tree to match
  the new structure (§2 above), and update/remove Known Issues #1 and #2 (Example
  app incomplete / legacy Xcode project not updated) since both are resolved by
  this work.
- `README.md`: add an "Example App" section modeled on CDUntappdKit's — explains
  copying `Secrets.xcconfig.example` → `Secrets.xcconfig` and filling in Discogs
  credentials from the [Discogs Developer settings](https://www.discogs.com/settings/developers).
- `Documentation/IMPLEMENTATION.md` §8: leave as a historical record, but add a
  one-line note at the top of the section pointing to the actual implementation
  (this spec / the real `Example/` directory) since the section's Twitter-based,
  subfolder-split plan is now superseded.

## Out of scope

- No changes to `Source/` (the core library) — `requestSigner` and `signed(_:)`
  are already public and sufficient for the Example app's needs.
- No CI job for the Example app (matches sibling precedent).
- No visionOS/tvOS/watchOS Example targets (library itself doesn't target them
  per `Package.swift`).
- No macOS Example app (none of the three sibling repos have one either; all are
  iOS-only example apps despite the libraries themselves supporting macOS).
