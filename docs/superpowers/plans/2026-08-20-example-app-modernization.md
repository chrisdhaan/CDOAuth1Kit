# CDOAuth1Kit Example App Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace CDOAuth1Kit's legacy Objective-C/CocoaPods Example app with a modern Swift Example app (demonstrating the OAuth 1.0a handshake against the Discogs API) that matches the file layout, conventions, and Xcode project structure used by the sibling repos (CDMarkdownKit, CDYelpFusionKit, CDUntappdKit).

**Architecture:** A flat `Example/Source/` directory with a `CDOAuth1KitManager` singleton wrapping `CDOAuth1SessionManager` for the OAuth handshake against Discogs, a single table-based `ViewController` (Authorize / Fetch Identity / Deauthorize), and a pushed JSON response screen — all wired into a hand-authored `Example/iOS Example.xcodeproj` that cross-project-references the existing root `CDOAuth1Kit.xcodeproj` for the framework dependency, matching exactly how the three sibling repos wire their Example apps.

**Tech Stack:** Swift 5 (iOS 13.0+), UIKit + Storyboards, Xcode native project (no SPM/CocoaPods for the Example app), `Secrets.xcconfig` for API credentials.

**Spec:** `docs/superpowers/specs/2026-08-20-example-app-modernization-design.md`

## Global Constraints

- Demo API is **Discogs** (OAuth 1.0a), not Twitter/X. Endpoints: `GET https://api.discogs.com/oauth/request_token`, browser authorize at `https://www.discogs.com/oauth/authorize?oauth_token=...`, `POST https://api.discogs.com/oauth/access_token`, authenticated check at `GET https://api.discogs.com/oauth/identity`. All requests need a `User-Agent` header.
- Callback URL scheme stays `cdoauth1kit://oauthCallback` (already used by the existing `CDOAuth1Helper.isAuthorizationCallbackURL` call).
- File layout is **flat** `Example/Source/` (no `Networking/`/`Model/`/`ViewControllers/` subfolders) — matches the current sibling pattern, not `Documentation/IMPLEMENTATION.md` §8's older sketch.
- No changes to `Source/` (the core library) — `CDOAuth1SessionManager.requestSigner` and `CDOAuth1RequestSigner.signed(_:parameters:)` are already public and sufficient.
- No CI job for the Example app — none of the three sibling repos build their Example app in CI either.
- Root `CDOAuth1Kit.xcodeproj` already exists with targets `CDOAuth1Kit iOS` (target GUID `CD0A00000000000000000010`, product/framework file reference GUID `CD0A00000000000000000011`) and `CDOAuth1Kit macOS` (target GUID `CD0A00000000000000000019`, product/framework file reference GUID `CD0A00000000000000000020`) — these exact GUIDs are load-bearing for the new Example project's cross-project reference; do not regenerate them.
- `PRODUCT_BUNDLE_IDENTIFIER` for the Example app is `com.christopherdehaan.iOS-Example` — matches the (deliberately identical) convention used by all three sibling repos' Example apps.
- All file content below has already been prototyped and verified: it compiles and links cleanly (`xcodebuild ... build` → `BUILD SUCCEEDED`, zero warnings) and passes `swiftlint lint --strict` with zero violations. Copy it verbatim.

---

## Task 1: Scaffold the new Example app and verify it builds

**Files:**
- Create: `Example/Source/CDOAuth1KitManager.swift`
- Create: `Example/Source/ViewController.swift`
- Create: `Example/Source/CDOAuth1KitJSONResponseViewController.swift`
- Create: `Example/Source/JSONPrettyPrinter.swift`
- Modify (overwrite): `Example/Source/AppDelegate.swift`
- Modify (overwrite): `Example/Source/SceneDelegate.swift`
- Delete: `Example/Source/Networking/TwitterClient.swift`, `Example/Source/Networking/` (directory)
- Delete: `Example/Source/Model/Tweet.swift`, `Example/Source/Model/` (directory)
- Modify (overwrite): `Example/Resources/Info.plist`
- Modify (overwrite): `Example/Resources/Base.lproj/Main.storyboard`
- Delete: `Example/Resources/Base.lproj/Launch Screen.storyboard`
- Create: `Example/Resources/Base.lproj/LaunchScreen.storyboard`
- Modify (overwrite): `Example/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Delete: `Example/Resources/Assets.xcassets/LaunchImage.launchimage/` (directory)
- Create: `Example/Secrets.xcconfig.example`
- Create: `Example/iOS Example.xcodeproj/project.pbxproj`
- Create: `Example/iOS Example.xcodeproj/xcshareddata/xcschemes/iOS Example.xcscheme`
- Test: manual `xcodebuild` verification (no XCTest target — matches sibling repos, which don't wire Testables into their Example schemes either)

**Interfaces:**
- Consumes: `CDOAuth1SessionManager` (`baseURL:consumerKey:consumerSecret:session:` init, `isAuthorized`, `requestSigner`, `deauthorize()`, `fetchRequestToken(path:method:callbackURL:scope:)`, `fetchAccessToken(path:method:requestToken:)`), `CDOAuth1Credential(queryString:)`, `CDOAuth1Helper.isAuthorizationCallbackURL(_:scheme:host:)`, `CDOAuth1Error`, `CDOAuth1RequestSigner.signed(_:parameters:)` — all already public in `Source/`.
- Produces: `CDOAuth1KitManager.shared` (singleton, `@MainActor`) with `isAuthorized: Bool`, `beginAuthorization() async throws -> URL`, `completeAuthorization(callbackURL: URL) async throws`, `deauthorize() throws`, `fetchIdentity() async throws -> Data`. `Notification.Name.cdoauth1kitAuthorizationCallback` (defined in `SceneDelegate.swift`). `JSONPrettyPrinter.string(from: Data) -> String`. `CDOAuth1KitJSONResponseViewController(title: String, jsonText: String)`.

- [ ] **Step 1: Remove the superseded Networking/ and Model/ subdirectories**

```bash
git rm -r "Example/Source/Networking" "Example/Source/Model"
```

- [ ] **Step 2: Overwrite `Example/Source/AppDelegate.swift`**

```swift
//
//  AppDelegate.swift
//  iOS Example
//
//  Created by Christopher de Haan on 5/30/26.
//
//  Copyright © 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        CDOAuth1KitManager.shared.configure()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
```

- [ ] **Step 3: Overwrite `Example/Source/SceneDelegate.swift`**

```swift
//
//  SceneDelegate.swift
//  iOS Example
//
//  Created by Christopher de Haan on 5/30/26.
//
//  Copyright © 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit
import CDOAuth1Kit

/// Posted when `scene(_:openURLContexts:)` receives the OAuth 1.0a callback URL.
/// `ViewController` observes this to complete the access-token exchange.
extension Notification.Name {
    static let cdoauth1kitAuthorizationCallback = Notification.Name("CDOAuth1KitAuthorizationCallbackURL")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard scene is UIWindowScene else { return }

        // Window is configured by the storyboard's UISceneStoryboardFile entry point.
        for urlContext in connectionOptions.urlContexts {
            self.scene(scene, openURLContexts: [urlContext])
        }
    }

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        for urlContext in URLContexts {
            let url = urlContext.url
            if CDOAuth1Helper.isAuthorizationCallbackURL(
                url,
                scheme: "cdoauth1kit",
                host: "oauthCallback"
            ) {
                NotificationCenter.default.post(name: .cdoauth1kitAuthorizationCallback, object: url)
            }
        }
    }
}
```

- [ ] **Step 4: Create `Example/Source/CDOAuth1KitManager.swift`**

```swift
//
//  CDOAuth1KitManager.swift
//  iOS Example
//
//  Created by Christopher de Haan on 8/20/26.
//
//  Copyright © 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import CDOAuth1Kit
import Foundation

@MainActor
final class CDOAuth1KitManager: NSObject {

    static let shared = CDOAuth1KitManager()

    private static let callbackURL = URL(string: "cdoauth1kit://oauthCallback")!
    private static let userAgent = "CDOAuth1KitExample/1.0 +https://github.com/chrisdhaan/CDOAuth1Kit"

    var sessionManager: CDOAuth1SessionManager!

    var isAuthorized: Bool { sessionManager.isAuthorized }

    func configure() {
        // consumerKey/consumerSecret are sourced from Secrets.xcconfig via Info.plist.
        // Copy Secrets.xcconfig.example to Secrets.xcconfig and fill in your own
        // Discogs API credentials before building this app.
        guard let consumerKey = Bundle.main.infoDictionary?["DISCOGS_CONSUMER_KEY"] as? String,
              let consumerSecret = Bundle.main.infoDictionary?["DISCOGS_CONSUMER_SECRET"] as? String,
              !consumerKey.isEmpty, !consumerSecret.isEmpty else {
            fatalError("Missing DISCOGS_CONSUMER_KEY / DISCOGS_CONSUMER_SECRET. Copy Secrets.xcconfig.example to " +
                "Secrets.xcconfig and fill in your own Discogs API credentials.")
        }

        self.sessionManager = CDOAuth1SessionManager(
            baseURL: URL(string: "https://api.discogs.com/oauth/")!,
            consumerKey: consumerKey,
            consumerSecret: consumerSecret
        )
    }

    /// Fetches a request token and returns the Discogs authorize-page URL to open in the browser.
    func beginAuthorization() async throws -> URL {
        let requestToken = try await sessionManager.fetchRequestToken(
            path: "request_token",
            method: "GET",
            callbackURL: Self.callbackURL
        )

        var components = URLComponents(string: "https://www.discogs.com/oauth/authorize")!
        components.queryItems = [URLQueryItem(name: "oauth_token", value: requestToken.token)]
        guard let authorizeURL = components.url else {
            throw CDOAuth1Error.invalidResponse
        }
        return authorizeURL
    }

    /// Exchanges the callback URL's query string for an access token.
    func completeAuthorization(callbackURL url: URL) async throws {
        guard let query = url.query,
              let requestToken = CDOAuth1Credential(queryString: query) else {
            throw CDOAuth1Error.invalidResponse
        }

        _ = try await sessionManager.fetchAccessToken(
            path: "access_token",
            method: "POST",
            requestToken: requestToken
        )
    }

    func deauthorize() throws {
        try sessionManager.deauthorize()
    }

    /// Makes an authenticated `GET /oauth/identity` request to prove the access token works.
    func fetchIdentity() async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.discogs.com/oauth/identity")!)
        request.httpMethod = "GET"
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")

        let signedRequest = try sessionManager.requestSigner.signed(request)
        let (data, _) = try await URLSession.shared.data(for: signedRequest)
        return data
    }
}
```

- [ ] **Step 5: Create `Example/Source/JSONPrettyPrinter.swift`**

```swift
//
//  JSONPrettyPrinter.swift
//  iOS Example
//
//  Created by Christopher de Haan on 8/20/26.
//
//  Copyright © 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

/// Pretty-prints a raw JSON HTTP response body for on-screen display.
enum JSONPrettyPrinter {

    static func string(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: prettyData, encoding: .utf8) else {
            return String(data: data, encoding: .utf8) ?? "<undecodable response>"
        }
        return text
    }
}
```

- [ ] **Step 6: Create `Example/Source/CDOAuth1KitJSONResponseViewController.swift`**

```swift
//
//  CDOAuth1KitJSONResponseViewController.swift
//  iOS Example
//
//  Created by Christopher de Haan on 8/20/26.
//
//  Copyright © 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

/// Displays a pretty-printed JSON response, pushed onto the navigation stack so the user
/// can tap back to return to the endpoint list.
final class CDOAuth1KitJSONResponseViewController: UIViewController {

    private let jsonText: String

    init(title: String, jsonText: String) {
        self.jsonText = jsonText
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.text = jsonText
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.alwaysBounceVertical = true
        self.view = textView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}
```

- [ ] **Step 7: Create `Example/Source/ViewController.swift`**

```swift
//
//  ViewController.swift
//  iOS Example
//
//  Created by Christopher de Haan on 8/20/26.
//
//  Copyright © 2016-2026 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet private var tableView: UITableView!

    private enum Row: Int, CaseIterable {
        case authorize
        case fetchIdentity
        case deauthorize

        var title: String {
            switch self {
            case .authorize: return "Authorize with Discogs"
            case .fetchIdentity: return "Fetch My Identity"
            case .deauthorize: return "Deauthorize"
            }
        }

        /// Only the Authorize row is usable before the user has an access token.
        var requiresAuthorization: Bool {
            self != .authorize
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthorizationCallback(_:)),
            name: .cdoauth1kitAuthorizationCallback,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}

// MARK: - UITableViewDataSource Methods

extension ViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CDOAuth1KitEndpointCell", for: indexPath)
        guard let row = Row(rawValue: indexPath.row) else { return cell }

        cell.textLabel?.text = row.title
        let enabled = !row.requiresAuthorization || CDOAuth1KitManager.shared.isAuthorized
        cell.textLabel?.textColor = enabled ? .label : .tertiaryLabel
        cell.selectionStyle = enabled ? .default : .none

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Discogs OAuth 1.0a Demo"
    }
}

// MARK: - UITableViewDelegate Methods

extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        if row.requiresAuthorization && !CDOAuth1KitManager.shared.isAuthorized {
            presentAlert(title: "Not Authorized", message: "Tap \"Authorize with Discogs\" first.")
            return
        }

        switch row {
        case .authorize:
            authorize()
        case .fetchIdentity:
            fetchIdentity()
        case .deauthorize:
            deauthorize()
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0.1
    }
}

// MARK: - Actions

private extension ViewController {

    func authorize() {
        Task {
            do {
                let authorizeURL = try await CDOAuth1KitManager.shared.beginAuthorization()
                await UIApplication.shared.open(authorizeURL)
            } catch {
                presentAlert(title: "Request Failed", message: "\(error)")
            }
        }
    }

    func fetchIdentity() {
        Task {
            do {
                let data = try await CDOAuth1KitManager.shared.fetchIdentity()
                let jsonText = JSONPrettyPrinter.string(from: data)
                let jsonResponseViewController = CDOAuth1KitJSONResponseViewController(
                    title: "My Identity",
                    jsonText: jsonText
                )
                navigationController?.pushViewController(jsonResponseViewController, animated: true)
            } catch {
                presentAlert(title: "Request Failed", message: "\(error)")
            }
        }
    }

    func deauthorize() {
        do {
            try CDOAuth1KitManager.shared.deauthorize()
            tableView.reloadData()
        } catch {
            presentAlert(title: "Deauthorize Failed", message: "\(error)")
        }
    }

    @objc func handleAuthorizationCallback(_ notification: Notification) {
        guard let url = notification.object as? URL else { return }
        Task {
            do {
                try await CDOAuth1KitManager.shared.completeAuthorization(callbackURL: url)
                tableView.reloadData()
                presentAlert(title: "Authorized", message: "You're now authorized with Discogs.")
            } catch {
                presentAlert(title: "Authorization Failed", message: "\(error)")
            }
        }
    }

    func presentAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
```

- [ ] **Step 8: Remove the stale LaunchImage asset and space-named launch storyboard**

```bash
git rm -r "Example/Resources/Assets.xcassets/LaunchImage.launchimage"
git rm "Example/Resources/Base.lproj/Launch Screen.storyboard"
```

- [ ] **Step 9: Overwrite `Example/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`**

```json
{
  "images" : [
    {
      "idiom" : "iphone",
      "size" : "20x20",
      "scale" : "2x"
    },
    {
      "idiom" : "iphone",
      "size" : "20x20",
      "scale" : "3x"
    },
    {
      "idiom" : "iphone",
      "size" : "29x29",
      "scale" : "2x"
    },
    {
      "idiom" : "iphone",
      "size" : "29x29",
      "scale" : "3x"
    },
    {
      "idiom" : "iphone",
      "size" : "40x40",
      "scale" : "2x"
    },
    {
      "idiom" : "iphone",
      "size" : "40x40",
      "scale" : "3x"
    },
    {
      "idiom" : "iphone",
      "size" : "60x60",
      "scale" : "2x"
    },
    {
      "idiom" : "iphone",
      "size" : "60x60",
      "scale" : "3x"
    },
    {
      "idiom" : "ios-marketing",
      "size" : "1024x1024",
      "scale" : "1x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
```

- [ ] **Step 10: Create `Example/Resources/Base.lproj/LaunchScreen.storyboard`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="20037" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" colorMatched="YES" initialViewController="01J-lp-oVM">
    <device id="retina6_1" orientation="portrait" appearance="light"/>
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="20020"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <!--View Controller-->
        <scene sceneID="EHf-IW-A2E">
            <objects>
                <viewController id="01J-lp-oVM" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="Llm-lL-Icb"/>
                        <viewControllerLayoutGuide type="bottom" id="xb3-aO-Qok"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="Ze5-6b-2t3">
                        <rect key="frame" x="0.0" y="0.0" width="414" height="896"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <label opaque="NO" clipsSubviews="YES" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" text="CDOAuth1Kit" textAlignment="center" lineBreakMode="middleTruncation" baselineAdjustment="alignBaselines" minimumFontSize="18" translatesAutoresizingMaskIntoConstraints="NO" id="uT7-g3-lFm">
                                <rect key="frame" x="0.0" y="426.5" width="414" height="43"/>
                                <constraints>
                                    <constraint firstAttribute="height" constant="43" id="LaE-vT-1UZ"/>
                                </constraints>
                                <fontDescription key="fontDescription" type="boldSystem" pointSize="36"/>
                                <color key="textColor" systemColor="darkTextColor"/>
                                <nil key="highlightedColor"/>
                            </label>
                            <label opaque="NO" clipsSubviews="YES" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" text="iOS Example" textAlignment="center" lineBreakMode="middleTruncation" baselineAdjustment="alignBaselines" minimumFontSize="18" translatesAutoresizingMaskIntoConstraints="NO" id="PVG-pz-erk">
                                <rect key="frame" x="0.0" y="477.5" width="414" height="34"/>
                                <constraints>
                                    <constraint firstAttribute="height" constant="34" id="KLO-Su-xYQ"/>
                                </constraints>
                                <fontDescription key="fontDescription" type="boldSystem" pointSize="28"/>
                                <color key="textColor" systemColor="darkTextColor"/>
                                <nil key="highlightedColor"/>
                            </label>
                            <label opaque="NO" clipsSubviews="YES" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" text="Copyright © 2016-2026 Christopher de Haan. All rights reserved." textAlignment="center" lineBreakMode="tailTruncation" baselineAdjustment="alignBaselines" minimumFontSize="9" translatesAutoresizingMaskIntoConstraints="NO" id="Wfq-wn-afO">
                                <rect key="frame" x="5" y="821" width="404" height="21"/>
                                <constraints>
                                    <constraint firstAttribute="height" constant="21" id="kw4-hn-3g1"/>
                                </constraints>
                                <fontDescription key="fontDescription" type="system" pointSize="17"/>
                                <color key="textColor" systemColor="darkTextColor"/>
                                <nil key="highlightedColor"/>
                            </label>
                        </subviews>
                        <color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>
                            <constraint firstItem="PVG-pz-erk" firstAttribute="top" secondItem="uT7-g3-lFm" secondAttribute="bottom" constant="8" id="7TE-s0-aEd"/>
                            <constraint firstItem="PVG-pz-erk" firstAttribute="leading" secondItem="Ze5-6b-2t3" secondAttribute="leading" id="9Xr-AG-Sa9"/>
                            <constraint firstAttribute="trailing" secondItem="uT7-g3-lFm" secondAttribute="trailing" id="FLb-U5-dR9"/>
                            <constraint firstAttribute="trailing" secondItem="PVG-pz-erk" secondAttribute="trailing" id="WhV-8a-5En"/>
                            <constraint firstItem="xb3-aO-Qok" firstAttribute="top" secondItem="Wfq-wn-afO" secondAttribute="bottom" constant="20" id="dT4-en-rn3"/>
                            <constraint firstItem="uT7-g3-lFm" firstAttribute="centerY" secondItem="Ze5-6b-2t3" secondAttribute="centerY" id="dZ1-fA-5jd"/>
                            <constraint firstItem="Wfq-wn-afO" firstAttribute="leading" secondItem="Ze5-6b-2t3" secondAttribute="leading" constant="5" id="eau-s5-dzE"/>
                            <constraint firstItem="uT7-g3-lFm" firstAttribute="leading" secondItem="Ze5-6b-2t3" secondAttribute="leading" id="k6N-sm-AXA"/>
                            <constraint firstAttribute="trailing" secondItem="Wfq-wn-afO" secondAttribute="trailing" constant="5" id="lfw-Xi-VAs"/>
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="iYj-Kq-Ea1" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="50.724637681159422" y="374.33035714285711"/>
        </scene>
    </scenes>
    <resources>
        <systemColor name="darkTextColor">
            <color white="0.0" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>
        </systemColor>
    </resources>
</document>
```

- [ ] **Step 11: Overwrite `Example/Resources/Base.lproj/Main.storyboard`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="12121" systemVersion="16G29" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" useTraitCollections="YES" colorMatched="YES" initialViewController="N4v-ig-001">
    <device id="retina4_7" orientation="portrait">
        <adaptation id="fullscreen"/>
    </device>
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="12089"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <!--Navigation Controller-->
        <scene sceneID="N4v-sc-001">
            <objects>
                <navigationController storyboardIdentifier="RootNavigationController" id="N4v-ig-001" sceneMemberID="viewController">
                    <navigationBar key="navigationBar" contentMode="scaleToFill" id="N4v-ba-001">
                        <rect key="frame" x="0.0" y="0.0" width="375" height="44"/>
                        <autoresizingMask key="autoresizingMask"/>
                    </navigationBar>
                    <connections>
                        <segue destination="vXZ-lx-hvc" kind="relationship" relationship="rootViewController" id="N4v-sg-001"/>
                    </connections>
                </navigationController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="N4v-fr-001" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="-580" y="139"/>
        </scene>
        <!--View Controller-->
        <scene sceneID="ufC-wZ-h7g">
            <objects>
                <viewController id="vXZ-lx-hvc" customClass="ViewController" customModule="iOS_Example" customModuleProvider="target" sceneMemberID="viewController">
                    <layoutGuides>
                        <viewControllerLayoutGuide type="top" id="jyV-Pf-zRb"/>
                        <viewControllerLayoutGuide type="bottom" id="2fi-mo-0CV"/>
                    </layoutGuides>
                    <view key="view" contentMode="scaleToFill" id="kh9-bI-dsS">
                        <rect key="frame" x="0.0" y="0.0" width="375" height="667"/>
                        <autoresizingMask key="autoresizingMask" flexibleMaxX="YES" flexibleMaxY="YES"/>
                        <subviews>
                            <tableView clipsSubviews="YES" contentMode="scaleToFill" alwaysBounceVertical="YES" dataMode="prototypes" style="plain" separatorStyle="default" rowHeight="44" sectionHeaderHeight="28" sectionFooterHeight="28" translatesAutoresizingMaskIntoConstraints="NO" id="xGL-Zs-1GK">
                                <rect key="frame" x="0.0" y="20" width="375" height="647"/>
                                <color key="backgroundColor" white="1" alpha="1" colorSpace="calibratedWhite"/>
                                <prototypes>
                                    <tableViewCell clipsSubviews="YES" contentMode="scaleToFill" selectionStyle="default" indentationWidth="10" reuseIdentifier="CDOAuth1KitEndpointCell" id="dR4-m3-j9Y">
                                        <rect key="frame" x="0.0" y="28" width="375" height="44"/>
                                        <autoresizingMask key="autoresizingMask"/>
                                        <tableViewCellContentView key="contentView" opaque="NO" clipsSubviews="YES" multipleTouchEnabled="YES" contentMode="center" tableViewCell="dR4-m3-j9Y" id="h9W-qY-MYb">
                                            <rect key="frame" x="0.0" y="0.0" width="375" height="44"/>
                                            <autoresizingMask key="autoresizingMask"/>
                                        </tableViewCellContentView>
                                    </tableViewCell>
                                </prototypes>
                                <connections>
                                    <outlet property="dataSource" destination="vXZ-lx-hvc" id="ekS-jZ-3ql"/>
                                    <outlet property="delegate" destination="vXZ-lx-hvc" id="w7U-VN-tts"/>
                                </connections>
                            </tableView>
                        </subviews>
                        <color key="backgroundColor" red="1" green="1" blue="1" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>
                        <constraints>
                            <constraint firstItem="2fi-mo-0CV" firstAttribute="top" secondItem="xGL-Zs-1GK" secondAttribute="bottom" id="FVO-BN-gLo"/>
                            <constraint firstAttribute="trailing" secondItem="xGL-Zs-1GK" secondAttribute="trailing" id="RHh-ck-40M"/>
                            <constraint firstItem="xGL-Zs-1GK" firstAttribute="top" secondItem="kh9-bI-dsS" secondAttribute="top" constant="20" id="ZaV-fi-3nI"/>
                            <constraint firstItem="xGL-Zs-1GK" firstAttribute="leading" secondItem="kh9-bI-dsS" secondAttribute="leading" id="hJQ-FT-MOe"/>
                        </constraints>
                    </view>
                    <connections>
                        <outlet property="tableView" destination="xGL-Zs-1GK" id="vHe-IO-f29"/>
                    </connections>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="x5A-6p-PRh" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="140" y="138.98050974512745"/>
        </scene>
    </scenes>
</document>
```

- [ ] **Step 12: Overwrite `Example/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>CDOAuth1Kit</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>cdoauth1kit</string>
			</array>
		</dict>
	</array>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>DISCOGS_CONSUMER_KEY</key>
	<string>$(DISCOGS_CONSUMER_KEY)</string>
	<key>DISCOGS_CONSUMER_SECRET</key>
	<string>$(DISCOGS_CONSUMER_SECRET)</string>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<false/>
		<key>UISceneConfigurations</key>
		<dict>
			<key>UIWindowSceneSessionRoleApplication</key>
			<array>
				<dict>
					<key>UISceneConfigurationName</key>
					<string>Default Configuration</string>
					<key>UISceneDelegateClassName</key>
					<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
					<key>UISceneStoryboardFile</key>
					<string>Main</string>
				</dict>
			</array>
		</dict>
	</dict>
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>armv7</string>
	</array>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 13: Create `Example/Secrets.xcconfig.example`**

```
//
//  Secrets.xcconfig.example
//  iOS Example
//
//  Copy this file to Secrets.xcconfig (gitignored) and fill in your own
//  Discogs API credentials from https://www.discogs.com/settings/developers
//  before building the iOS Example app.
//

DISCOGS_CONSUMER_KEY = your_consumer_key_here
DISCOGS_CONSUMER_SECRET = your_consumer_secret_here
```

- [ ] **Step 14: Create `Example/iOS Example.xcodeproj/project.pbxproj`**

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 46;
	objects = {

/* Begin PBXBuildFile section */
		CD0AE1000000000000000015 /* AppDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000002 /* AppDelegate.swift */; };
		CD0AE1000000000000000016 /* SceneDelegate.swift in Sources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000003 /* SceneDelegate.swift */; };
		CD0AE1000000000000000017 /* CDOAuth1KitManager.swift in Sources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000004 /* CDOAuth1KitManager.swift */; };
		CD0AE1000000000000000018 /* ViewController.swift in Sources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000005 /* ViewController.swift */; };
		CD0AE1000000000000000019 /* JSONPrettyPrinter.swift in Sources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000006 /* JSONPrettyPrinter.swift */; };
		CD0AE1000000000000000020 /* CDOAuth1KitJSONResponseViewController.swift in Sources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000007 /* CDOAuth1KitJSONResponseViewController.swift */; };
		CD0AE1000000000000000021 /* Assets.xcassets in Resources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000008 /* Assets.xcassets */; };
		CD0AE1000000000000000022 /* LaunchScreen.storyboard in Resources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000043 /* LaunchScreen.storyboard */; };
		CD0AE1000000000000000023 /* Main.storyboard in Resources */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000044 /* Main.storyboard */; };
		CD0AE1000000000000000024 /* CDOAuth1Kit.framework in Embed Frameworks */ = {isa = PBXBuildFile; fileRef = CD0AE1000000000000000039 /* CDOAuth1Kit.framework */; settings = {ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		CD0AE1000000000000000025 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = CD0AE1000000000000000014 /* CDOAuth1Kit.xcodeproj */;
			proxyType = 2;
			remoteGlobalIDString = CD0A00000000000000000020;
			remoteInfo = "CDOAuth1Kit macOS";
		};
		CD0AE1000000000000000026 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = CD0AE1000000000000000014 /* CDOAuth1Kit.xcodeproj */;
			proxyType = 2;
			remoteGlobalIDString = CD0A00000000000000000011;
			remoteInfo = "CDOAuth1Kit iOS";
		};
		CD0AE1000000000000000027 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = CD0AE1000000000000000014 /* CDOAuth1Kit.xcodeproj */;
			proxyType = 1;
			remoteGlobalIDString = CD0A00000000000000000010;
			remoteInfo = "CDOAuth1Kit iOS";
		};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
		CD0AE1000000000000000028 /* Embed Frameworks */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 10;
			files = (
				CD0AE1000000000000000024 /* CDOAuth1Kit.framework in Embed Frameworks */,
			);
			name = "Embed Frameworks";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
		CD0AE1000000000000000001 /* iOS Example.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "iOS Example.app"; sourceTree = BUILT_PRODUCTS_DIR; };
		CD0AE1000000000000000002 /* AppDelegate.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = AppDelegate.swift; sourceTree = "<group>"; };
		CD0AE1000000000000000003 /* SceneDelegate.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = SceneDelegate.swift; sourceTree = "<group>"; };
		CD0AE1000000000000000004 /* CDOAuth1KitManager.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = CDOAuth1KitManager.swift; sourceTree = "<group>"; };
		CD0AE1000000000000000005 /* ViewController.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = ViewController.swift; sourceTree = "<group>"; };
		CD0AE1000000000000000006 /* JSONPrettyPrinter.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = JSONPrettyPrinter.swift; sourceTree = "<group>"; };
		CD0AE1000000000000000007 /* CDOAuth1KitJSONResponseViewController.swift */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = CDOAuth1KitJSONResponseViewController.swift; sourceTree = "<group>"; };
		CD0AE1000000000000000008 /* Assets.xcassets */ = {isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = Resources/Assets.xcassets; sourceTree = SOURCE_ROOT; };
		CD0AE1000000000000000009 /* Info.plist */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.plist.xml; name = Info.plist; path = Resources/Info.plist; sourceTree = SOURCE_ROOT; };
		CD0AE1000000000000000010 /* Secrets.xcconfig */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.xcconfig; path = Secrets.xcconfig; sourceTree = SOURCE_ROOT; };
		CD0AE1000000000000000011 /* Secrets.xcconfig.example */ = {isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = text.xcconfig; path = Secrets.xcconfig.example; sourceTree = SOURCE_ROOT; };
		CD0AE1000000000000000012 /* Base */ = {isa = PBXFileReference; lastKnownFileType = file.storyboard; name = Base; path = Resources/Base.lproj/LaunchScreen.storyboard; sourceTree = SOURCE_ROOT; };
		CD0AE1000000000000000013 /* Base */ = {isa = PBXFileReference; lastKnownFileType = file.storyboard; name = Base; path = Resources/Base.lproj/Main.storyboard; sourceTree = SOURCE_ROOT; };
		CD0AE1000000000000000014 /* CDOAuth1Kit.xcodeproj */ = {isa = PBXFileReference; lastKnownFileType = "wrapper.pb-project"; name = CDOAuth1Kit.xcodeproj; path = ../CDOAuth1Kit.xcodeproj; sourceTree = "<group>"; };
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		CD0AE1000000000000000029 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		CD0AE1000000000000000030 = {
			isa = PBXGroup;
			children = (
				CD0AE1000000000000000032 /* Source */,
				CD0AE1000000000000000031 /* Products */,
				CD0AE1000000000000000014 /* CDOAuth1Kit.xcodeproj */,
			);
			sourceTree = "<group>";
		};
		CD0AE1000000000000000031 /* Products */ = {
			isa = PBXGroup;
			children = (
				CD0AE1000000000000000001 /* iOS Example.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		CD0AE1000000000000000032 /* Source */ = {
			isa = PBXGroup;
			children = (
				CD0AE1000000000000000002 /* AppDelegate.swift */,
				CD0AE1000000000000000003 /* SceneDelegate.swift */,
				CD0AE1000000000000000004 /* CDOAuth1KitManager.swift */,
				CD0AE1000000000000000005 /* ViewController.swift */,
				CD0AE1000000000000000007 /* CDOAuth1KitJSONResponseViewController.swift */,
				CD0AE1000000000000000006 /* JSONPrettyPrinter.swift */,
				CD0AE1000000000000000034 /* Resources */,
				CD0AE1000000000000000033 /* Supporting Files */,
			);
			path = Source;
			sourceTree = "<group>";
		};
		CD0AE1000000000000000033 /* Supporting Files */ = {
			isa = PBXGroup;
			children = (
				CD0AE1000000000000000009 /* Info.plist */,
				CD0AE1000000000000000010 /* Secrets.xcconfig */,
				CD0AE1000000000000000011 /* Secrets.xcconfig.example */,
			);
			name = "Supporting Files";
			sourceTree = "<group>";
		};
		CD0AE1000000000000000034 /* Resources */ = {
			isa = PBXGroup;
			children = (
				CD0AE1000000000000000008 /* Assets.xcassets */,
				CD0AE1000000000000000043 /* LaunchScreen.storyboard */,
				CD0AE1000000000000000044 /* Main.storyboard */,
			);
			name = Resources;
			sourceTree = "<group>";
		};
		CD0AE1000000000000000035 /* Products */ = {
			isa = PBXGroup;
			children = (
				CD0AE1000000000000000039 /* CDOAuth1Kit.framework */,
				CD0AE1000000000000000038 /* CDOAuth1Kit.framework */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		CD0AE1000000000000000036 /* iOS Example */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = CD0AE1000000000000000050 /* Build configuration list for PBXNativeTarget "iOS Example" */;
			buildPhases = (
				CD0AE1000000000000000041 /* Sources */,
				CD0AE1000000000000000029 /* Frameworks */,
				CD0AE1000000000000000040 /* Resources */,
				CD0AE1000000000000000028 /* Embed Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				CD0AE1000000000000000042 /* PBXTargetDependency */,
			);
			name = "iOS Example";
			productName = "iOS Example";
			productReference = CD0AE1000000000000000001 /* iOS Example.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		CD0AE1000000000000000037 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				ORGANIZATIONNAME = "Christopher de Haan";
				TargetAttributes = {
					CD0AE1000000000000000036 = {
						CreatedOnToolsVersion = 26.6;
						ProvisioningStyle = Automatic;
					};
				};
			};
			buildConfigurationList = CD0AE1000000000000000049 /* Build configuration list for PBXProject "iOS Example" */;
			compatibilityVersion = "Xcode 3.2";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = CD0AE1000000000000000030;
			productRefGroup = CD0AE1000000000000000031 /* Products */;
			projectDirPath = "";
			projectReferences = (
				{
					ProductGroup = CD0AE1000000000000000035 /* Products */;
					ProjectRef = CD0AE1000000000000000014 /* CDOAuth1Kit.xcodeproj */;
				},
			);
			projectRoot = "";
			targets = (
				CD0AE1000000000000000036 /* iOS Example */,
			);
		};
/* End PBXProject section */

/* Begin PBXReferenceProxy section */
		CD0AE1000000000000000038 /* CDOAuth1Kit.framework */ = {
			isa = PBXReferenceProxy;
			fileType = wrapper.framework;
			path = CDOAuth1Kit.framework;
			remoteRef = CD0AE1000000000000000025 /* PBXContainerItemProxy */;
			sourceTree = BUILT_PRODUCTS_DIR;
		};
		CD0AE1000000000000000039 /* CDOAuth1Kit.framework */ = {
			isa = PBXReferenceProxy;
			fileType = wrapper.framework;
			path = CDOAuth1Kit.framework;
			remoteRef = CD0AE1000000000000000026 /* PBXContainerItemProxy */;
			sourceTree = BUILT_PRODUCTS_DIR;
		};
/* End PBXReferenceProxy section */

/* Begin PBXResourcesBuildPhase section */
		CD0AE1000000000000000040 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				CD0AE1000000000000000022 /* LaunchScreen.storyboard in Resources */,
				CD0AE1000000000000000021 /* Assets.xcassets in Resources */,
				CD0AE1000000000000000023 /* Main.storyboard in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		CD0AE1000000000000000041 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				CD0AE1000000000000000018 /* ViewController.swift in Sources */,
				CD0AE1000000000000000015 /* AppDelegate.swift in Sources */,
				CD0AE1000000000000000016 /* SceneDelegate.swift in Sources */,
				CD0AE1000000000000000017 /* CDOAuth1KitManager.swift in Sources */,
				CD0AE1000000000000000020 /* CDOAuth1KitJSONResponseViewController.swift in Sources */,
				CD0AE1000000000000000019 /* JSONPrettyPrinter.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		CD0AE1000000000000000042 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			name = "CDOAuth1Kit iOS";
			targetProxy = CD0AE1000000000000000027 /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin PBXVariantGroup section */
		CD0AE1000000000000000043 /* LaunchScreen.storyboard */ = {
			isa = PBXVariantGroup;
			children = (
				CD0AE1000000000000000012 /* Base */,
			);
			name = LaunchScreen.storyboard;
			sourceTree = "<group>";
		};
		CD0AE1000000000000000044 /* Main.storyboard */ = {
			isa = PBXVariantGroup;
			children = (
				CD0AE1000000000000000013 /* Base */,
			);
			name = Main.storyboard;
			sourceTree = "<group>";
		};
/* End PBXVariantGroup section */

/* Begin XCBuildConfiguration section */
		CD0AE1000000000000000045 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				CODE_SIGN_IDENTITY = "iPhone Developer";
				"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu99;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_SYMBOLS_PRIVATE_EXTERN = NO;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
				MACOSX_DEPLOYMENT_TARGET = 10.15;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_SWIFT3_OBJC_INFERENCE = Off;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		CD0AE1000000000000000046 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				CODE_SIGN_IDENTITY = "iPhone Developer";
				"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "iPhone Developer";
				COPY_PHASE_STRIP = YES;
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu99;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 13.0;
				MACOSX_DEPLOYMENT_TARGET = 10.15;
				SDKROOT = iphoneos;
				SWIFT_OPTIMIZATION_LEVEL = "-Owholemodule";
				SWIFT_SWIFT3_OBJC_INFERENCE = Off;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		CD0AE1000000000000000047 /* Debug */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = CD0AE1000000000000000010 /* Secrets.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				DEVELOPMENT_TEAM = "";
				INFOPLIST_FILE = Resources/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				PRODUCT_BUNDLE_IDENTIFIER = "com.christopherdehaan.iOS-Example";
				PRODUCT_NAME = "$(TARGET_NAME)";
			};
			name = Debug;
		};
		CD0AE1000000000000000048 /* Release */ = {
			isa = XCBuildConfiguration;
			baseConfigurationReference = CD0AE1000000000000000010 /* Secrets.xcconfig */;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				DEVELOPMENT_TEAM = "";
				INFOPLIST_FILE = Resources/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				PRODUCT_BUNDLE_IDENTIFIER = "com.christopherdehaan.iOS-Example";
				PRODUCT_NAME = "$(TARGET_NAME)";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		CD0AE1000000000000000049 /* Build configuration list for PBXProject "iOS Example" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				CD0AE1000000000000000045 /* Debug */,
				CD0AE1000000000000000046 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		CD0AE1000000000000000050 /* Build configuration list for PBXNativeTarget "iOS Example" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				CD0AE1000000000000000047 /* Debug */,
				CD0AE1000000000000000048 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = CD0AE1000000000000000037 /* Project object */;
}
```

**IMPORTANT — do not "fix" the GUID pattern above.** `CD0AE1...0011`/`...0020` (used in the `PBXContainerItemProxy` blocks with `proxyType = 2`) are the root project's **product file reference** GUIDs, deliberately different from `...0010`/`...0019` (the **target** GUIDs, used only in the `proxyType = 1` target-dependency proxy). Swapping these causes Xcode to crash with `-[PBXNativeTarget sourceTree]: unrecognized selector sent to instance` when reading the project — this was hit and fixed during plan validation.

- [ ] **Step 15: Create `Example/iOS Example.xcodeproj/xcshareddata/xcschemes/iOS Example.xcscheme`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2660"
   version = "1.3">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "CD0AE1000000000000000036"
               BuildableName = "iOS Example.app"
               BlueprintName = "iOS Example"
               ReferencedContainer = "container:iOS Example.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <MacroExpansion>
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "CD0AE1000000000000000036"
            BuildableName = "iOS Example.app"
            BlueprintName = "iOS Example"
            ReferencedContainer = "container:iOS Example.xcodeproj">
         </BuildableReference>
      </MacroExpansion>
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "CD0AE1000000000000000036"
            BuildableName = "iOS Example.app"
            BlueprintName = "iOS Example"
            ReferencedContainer = "container:iOS Example.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "CD0AE1000000000000000036"
            BuildableName = "iOS Example.app"
            BlueprintName = "iOS Example"
            ReferencedContainer = "container:iOS Example.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 16: Create a local (gitignored) `Example/Secrets.xcconfig` for the build test**

```bash
cp "Example/Secrets.xcconfig.example" "Example/Secrets.xcconfig"
sed -i '' 's/your_consumer_key_here/dummy_key_for_build_test/; s/your_consumer_secret_here/dummy_secret_for_build_test/' "Example/Secrets.xcconfig"
```

This file must exist for the build to succeed (it's the target's `baseConfigurationReference`), but dummy values are fine — the build doesn't call Discogs, only runtime `configure()` reads the values. It will be gitignored in Task 2, so it never gets committed.

- [ ] **Step 17: Build the Example scheme and verify success**

```bash
xcodebuild -project "Example/iOS Example.xcodeproj" -scheme "iOS Example" \
  -destination "OS=26.5,name=iPhone 17 Pro" -configuration Debug clean build 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **` with no `error:` lines. (If the destination's OS version isn't available on this machine, run `xcrun simctl list devices available` and substitute a matching iPhone simulator name/OS.)

- [ ] **Step 18: Run swiftlint against the new files**

```bash
swiftlint lint --strict Example/Source 2>&1 | tail -20
```

Expected: zero violations in the 6 new/modified files under `Example/Source` (pre-existing violations elsewhere in `Source/`, if any, are out of scope for this plan — do not fix them here).

- [ ] **Step 19: Commit**

```bash
git add Example/Source Example/Resources Example/Secrets.xcconfig.example "Example/iOS Example.xcodeproj"
git commit -m "feat(example): rewrite Example app in Swift, targeting Discogs OAuth 1.0a"
```

---

## Task 2: Remove the legacy Objective-C Example app and rewire the workspace

**Files:**
- Delete: `Example/CDOAuth1Kit/` (entire directory: `Classes/*.h/*.m`, `Images.xcassets/`, `Supporting Files/`)
- Delete: `Example/CDOAuth1Kit.xcodeproj/` (entire directory)
- Modify: `.gitignore`
- Modify: `CDOAuth1Kit.xcworkspace/contents.xcworkspacedata`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new — this task only removes stale files and repoints the workspace at the `Example/iOS Example.xcodeproj` built in Task 1.

- [ ] **Step 1: Remove the legacy Objective-C app**

```bash
git rm -r "Example/CDOAuth1Kit" "Example/CDOAuth1Kit.xcodeproj"
```

- [ ] **Step 2: Add `Example/Secrets.xcconfig` to `.gitignore`**

Add this block to the end of `/Users/christopherdehaan/Documents/Workspaces/GitHub/CDOAuth1Kit/.gitignore` (after the existing `# Jazzy documentation` block):

```
# Example app secrets
Example/Secrets.xcconfig
```

- [ ] **Step 3: Update the root workspace to reference the new project**

In `CDOAuth1Kit.xcworkspace/contents.xcworkspacedata`, change:

```xml
   <FileRef
      location = "group:Example/CDOAuth1Kit.xcodeproj">
   </FileRef>
```

to:

```xml
   <FileRef
      location = "group:Example/iOS Example.xcodeproj">
   </FileRef>
```

The full file should read:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "group:CDOAuth1Kit.xcodeproj">
   </FileRef>
   <FileRef
      location = "group:Example/iOS Example.xcodeproj">
   </FileRef>
</Workspace>
```

- [ ] **Step 4: Verify the workspace resolves cleanly with no stale schemes**

```bash
xcodebuild -list -workspace CDOAuth1Kit.xcworkspace 2>&1 | tail -20
```

Expected: exactly three schemes listed — `CDOAuth1Kit iOS`, `CDOAuth1Kit macOS`, `iOS Example` — and no error about a missing/unreadable project.

- [ ] **Step 5: Commit**

```bash
git add -A Example .gitignore CDOAuth1Kit.xcworkspace
git status
git commit -m "chore(example): remove legacy Objective-C Example app, rewire workspace"
```

Review `git status` output before committing to confirm only the expected legacy files were removed and no unrelated files were staged.

---

## Task 3: Update documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `Documentation/IMPLEMENTATION.md`

**Interfaces:** None — documentation only.

- [ ] **Step 1: Update `CLAUDE.md`'s Repository Layout tree**

In `CLAUDE.md`, replace:

```
├── CDOAuth1Kit.xcworkspace/           # Ties CDOAuth1Kit.xcodeproj + Example/CDOAuth1Kit.xcodeproj together
```

with:

```
├── CDOAuth1Kit.xcworkspace/           # Ties CDOAuth1Kit.xcodeproj + Example/iOS Example.xcodeproj together
```

And replace:

```
├── Example/                          # Example iOS app
│   ├── Source/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   ├── Networking/TwitterClient.swift
│   │   ├── Model/Tweet.swift
│   │   └── ViewControllers/TweetsViewController.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Base.lproj/
│       └── Info.plist
```

with:

```
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
```

- [ ] **Step 2: Update `CLAUDE.md`'s Known Issues**

Replace:

```
1. **Example app incomplete** — Sections 8.2–8.5 created the structure and basic delegates; full TweetsViewController implementation deferred
2. **Xcode project configuration** — The legacy Xcode project files (Example/CDOAuth1Kit.xcodeproj) have not been updated to use the new Source/ structure; this can be done in a follow-up PR
3. **visionOS excluded** — OAuth browser flows are technically possible on visionOS but deprioritized for v2.0.0; can be added as a follow-up (see CDMarkdownKit 3.1.0 pattern)
4. **Migration path** — Upgrading from v1.0.0 to v2.0.0 requires re-authentication (keychain format changed from NSKeyedArchiver to JSONEncoder)
```

with:

```
1. **visionOS excluded** — OAuth browser flows are technically possible on visionOS but deprioritized for v2.0.0; can be added as a follow-up (see CDMarkdownKit 3.1.0 pattern)
2. **Migration path** — Upgrading from v1.0.0 to v2.0.0 requires re-authentication (keychain format changed from NSKeyedArchiver to JSONEncoder)
```

(Items 1 and 2 from the old list are resolved by this plan — the Example app is now a complete, modern Swift app with a real Xcode project.)

- [ ] **Step 3: Add an "Example App" section to `README.md`**

Insert this new section between `## Usage` and `## Contributing`:

```markdown
## Example App

The `Example/` app demonstrates the full OAuth 1.0a handshake against the [Discogs API](https://www.discogs.com/developers). It reads its Discogs `consumerKey`/`consumerSecret` from `Example/Secrets.xcconfig` (gitignored). Before building it:

```bash
cp "Example/Secrets.xcconfig.example" "Example/Secrets.xcconfig"
```

Then edit `Secrets.xcconfig` with your own credentials from the [Discogs Developer settings](https://www.discogs.com/settings/developers). Open `CDOAuth1Kit.xcworkspace` and run the `iOS Example` scheme.
```

- [ ] **Step 4: Add a superseded note to `Documentation/IMPLEMENTATION.md` §8**

In `Documentation/IMPLEMENTATION.md`, immediately after the `## 8. Example App Update` heading, insert:

```markdown

> **Superseded (2026-08-20):** The Example app was ultimately rewritten with a flat `Source/` layout (no `Networking/`/`Model/`/`ViewControllers/` subfolders) targeting the Discogs API instead of Twitter, to match the pattern established by CDMarkdownKit/CDYelpFusionKit/CDUntappdKit's Example apps. See `docs/superpowers/specs/2026-08-20-example-app-modernization-design.md` and the actual `Example/` directory for what was actually built. The plan below is kept for historical context only.
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md README.md Documentation/IMPLEMENTATION.md
git commit -m "docs: update CLAUDE.md, README.md, IMPLEMENTATION.md for new Example app"
```

---

## Task 4: Final full verification

**Files:** None modified — verification only.

- [ ] **Step 1: Build all three schemes via the workspace**

```bash
xcodebuild -workspace CDOAuth1Kit.xcworkspace -scheme "CDOAuth1Kit iOS" -destination "generic/platform=iOS" -configuration Debug clean build 2>&1 | tail -20
xcodebuild -workspace CDOAuth1Kit.xcworkspace -scheme "CDOAuth1Kit macOS" -destination "platform=macOS" -configuration Debug clean build 2>&1 | tail -20
xcodebuild -workspace CDOAuth1Kit.xcworkspace -scheme "iOS Example" -destination "OS=26.5,name=iPhone 17 Pro" -configuration Debug clean build 2>&1 | tail -40
```

Expected: `** BUILD SUCCEEDED **` for all three.

- [ ] **Step 2: Run the SPM test suite (confirms the Example app changes didn't touch `Source/`)**

```bash
swift test 2>&1 | tail -30
```

Expected: all existing tests still pass (21 tests per `CLAUDE.md`'s testing checklist).

- [ ] **Step 3: Run swiftlint and swiftformat across the whole repo**

```bash
swiftlint lint --strict 2>&1 | tail -20
swiftformat Source Tests --lint 2>&1 | tail -20
```

Expected: zero violations from files touched by this plan. (`swiftformat` only checks `Source Tests` per the existing CI job — `Example/Source` is intentionally out of its scope, matching the pre-existing CI configuration; this plan does not change that.)

- [ ] **Step 4: Confirm a clean git status**

```bash
git status
```

Expected: clean working tree (everything committed across Tasks 1–3), and no leftover `Example/Secrets.xcconfig` tracked by git (it must show as untracked/ignored, not staged).

- [ ] **Step 5: Manual smoke test (requires real Discogs credentials — do this yourself, not via the agent)**

Fill in real Discogs API credentials in `Example/Secrets.xcconfig`, run the `iOS Example` scheme in Simulator, and walk through: tap "Authorize with Discogs" → Safari opens the Discogs authorize page → approve → redirected back into the app → tap "Fetch My Identity" → confirm a pretty-printed JSON response appears → tap "Deauthorize" → confirm the two auth-gated rows gray out again.
