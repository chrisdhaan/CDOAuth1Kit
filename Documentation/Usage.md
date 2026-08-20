# CDOAuth1Kit Usage Guide

This guide demonstrates how to use CDOAuth1Kit to implement OAuth 1.0a authentication in your iOS or macOS app.

## Installation

See the [README.md](../README.md) for installation instructions via Swift Package Manager.

## Initialization

Create a session manager with your OAuth provider's base URL and your app's consumer credentials:

```swift
import CDOAuth1Kit

let manager = CDOAuth1SessionManager(
    baseURL: URL(string: "https://api.twitter.com/oauth/")!,
    consumerKey: "YOUR_CONSUMER_KEY",
    consumerSecret: "YOUR_CONSUMER_SECRET"
)
```

Replace the following:
- `YOUR_CONSUMER_KEY` — Consumer key from your OAuth provider
- `YOUR_CONSUMER_SECRET` — Consumer secret from your OAuth provider
- `https://api.twitter.com/oauth/` — Your OAuth provider's OAuth endpoint base URL

## Registering a Callback URL Scheme

OAuth requires registering a callback URL scheme that your app will handle when the user authorizes your app.

### Step 1: Define the URL Scheme in Info.plist

Open your app's `Info.plist` and add a URL scheme:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>OAuth Callback</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourappname</string>
        </array>
    </dict>
</array>
```

Or in Xcode: Project → Target → Info → URL Types → Add a new URL type with scheme `yourappname`.

### Step 2: Handle the Callback in SceneDelegate

When the user authorizes your app, the OAuth provider redirects to your callback URL. Your `SceneDelegate` receives this via the `scene(_:openURLContexts:)` method:

```swift
func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
) {
    for urlContext in URLContexts {
        let url = urlContext.url
        
        if CDOAuth1Helper.isAuthorizationCallbackURL(
            url,
            scheme: "yourappname",
            host: "oauthCallback"
        ) {
            // Extract the verifier from the URL query string
            let params = [String: String](queryString: url.query ?? "")
            let verifier = params["oauth_verifier"]
            
            // Post notification to your view controller
            NotificationCenter.default.post(
                name: NSNotification.Name("OAuthCallbackReceived"),
                object: verifier
            )
        }
    }
}
```

## Fetching a Request Token

The first step of OAuth 1.0a is obtaining a request token:

```swift
do {
    let requestToken = try await manager.fetchRequestToken(
        path: "request_token",
        method: "POST",
        callbackURL: URL(string: "yourappname://oauthCallback")!
    )
    
    // Open the authorization URL in Safari
    let authURLString = "https://twitter.com/oauth/authorize?oauth_token=\(requestToken.token)"
    if let authURL = URL(string: authURLString) {
        UIApplication.shared.open(authURL)
    }
    
} catch {
    print("Failed to fetch request token: \(error)")
}
```

The user is now redirected to the OAuth provider's authorization page where they grant your app permission to access their account.

## Handling the OAuth Callback URL

When the user authorizes your app, they are redirected back to your callback URL with an `oauth_verifier` parameter. Your `SceneDelegate` receives this and can extract the verifier:

```swift
// In SceneDelegate.scene(_:openURLContexts:)
if CDOAuth1Helper.isAuthorizationCallbackURL(
    url,
    scheme: "yourappname",
    host: "oauthCallback"
) {
    // Extract oauth_verifier from the query string
    let verifier = URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "oauth_verifier" })?.value

    // Attach the verifier to the request token from step 1
    var verifiedRequestToken = requestToken  // from step 1
    verifiedRequestToken.verifier = verifier

    // Proceed to fetch the access token (see next section)
}
```

## Fetching an Access Token

Once you have the `oauth_verifier` from the callback, exchange it for an access token:

```swift
do {
    let accessToken = try await manager.fetchAccessToken(
        path: "access_token",
        method: "POST",
        requestToken: verifiedRequestToken  // from callback handling
    )
    
    print("Successfully authenticated!")
    print("Access token: \(accessToken.token)")
    print("Token secret: \(accessToken.secret)")
    
} catch {
    print("Failed to fetch access token: \(error)")
}
```

The access token is automatically stored in the device keychain after a successful fetch. You can now use it for authenticated API requests.

## Checking Authorization Status

Check if your app has a valid access token stored:

```swift
if manager.isAuthorized {
    print("User is logged in")
} else {
    print("User is not logged in")
}
```

Call this during app launch to determine whether to show your login flow.

## Refreshing an Expired Access Token

Most OAuth providers set an expiration date on access tokens. Refresh an expired token:

```swift
do {
    let refreshedToken = try await manager.refreshAccessToken(
        path: "access_token",
        method: "POST",
        accessToken: expiredAccessToken
    )
    
    print("Token refreshed successfully")
    
} catch {
    print("Failed to refresh token: \(error)")
}
```

Some OAuth providers require additional parameters for refresh. Consult your OAuth provider's documentation:

```swift
let refreshedToken = try await manager.refreshAccessToken(
    path: "access_token",
    parameters: ["oauth_session_handle": sessionHandle],
    method: "POST",
    accessToken: expiredAccessToken
)
```

## Deauthorizing

To sign the user out and remove their access token from the keychain:

```swift
do {
    try manager.deauthorize()
    print("User signed out")
} catch {
    print("Failed to deauthorize: \(error)")
}
```

After deauthorization, `manager.isAuthorized` returns `false`.

## Using the Access Token for API Requests

Once you have an access token, use it to make authenticated requests to your OAuth provider's API:

```swift
var request = URLRequest(url: URL(string: "https://api.twitter.com/1.1/statuses/update.json")!)
request.httpMethod = "POST"
request.setValue("status=Hello%20World", forHTTPHeaderField: "")

do {
    let signedRequest = try requestSigner.signed(request)
    let (data, response) = try await URLSession.shared.data(for: signedRequest)
    
    // Process the response
    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
        print("Request successful")
    }
} catch {
    print("Request failed: \(error)")
}
```

Note: CDOAuth1Kit handles generating OAuth signatures. Pair it with your favorite HTTP client for making API requests.

## Error Handling

CDOAuth1Kit provides a typed error enum for proper error handling:

```swift
do {
    let requestToken = try await manager.fetchRequestToken(
        path: "request_token",
        method: "POST",
        callbackURL: URL(string: "yourappname://oauthCallback")!
    )
} catch let error as CDOAuth1Error {
    switch error {
    case .invalidRequestToken:
        print("Request token endpoint returned an invalid response")
    case .invalidAccessToken:
        print("Access token endpoint returned an invalid response")
    case .invalidResponse:
        print("Unexpected response format")
    case .keychainError(let statusCode):
        print("Keychain error: \(statusCode)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Complete Example: Login Flow

Here's a complete example of implementing a login flow in a view controller:

```swift
import UIKit
import CDOAuth1Kit

class LoginViewController: UIViewController {
    
    private let manager = CDOAuth1SessionManager(
        baseURL: URL(string: "https://api.twitter.com/oauth/")!,
        consumerKey: "YOUR_CONSUMER_KEY",
        consumerSecret: "YOUR_CONSUMER_SECRET"
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if user is already logged in
        if manager.isAuthorized {
            showMainViewController()
        }
        
        // Listen for OAuth callback
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOAuthCallback(_:)),
            name: NSNotification.Name("OAuthCallbackReceived"),
            object: nil
        )
    }
    
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        Task {
            await performOAuthFlow()
        }
    }
    
    private func performOAuthFlow() async {
        do {
            // Step 1: Fetch request token
            let requestToken = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: URL(string: "yourappname://oauthCallback")!
            )
            
            // Step 2: Open authorization URL
            let authURLString = "https://twitter.com/oauth/authorize?oauth_token=\(requestToken.token)"
            if let authURL = URL(string: authURLString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(authURL)
                }
            }
            
        } catch {
            DispatchQueue.main.async {
                self.showError("Failed to start login: \(error)")
            }
        }
    }
    
    @objc private func handleOAuthCallback(_ notification: Notification) {
        guard let verifier = notification.object as? String else { return }
        
        Task {
            await completeOAuthFlow(verifier: verifier)
        }
    }
    
    private func completeOAuthFlow(verifier: String) async {
        // Note: In a real app, you'd need to save the request token
        // from step 1 to use it here. Consider storing it in a property.
        
        do {
            // Step 3: Fetch access token
            let accessToken = try await manager.fetchAccessToken(
                path: "access_token",
                method: "POST",
                requestToken: requestTokenWithVerifier  // from step 1
            )
            
            DispatchQueue.main.async {
                self.showMainViewController()
            }
            
        } catch {
            DispatchQueue.main.async {
                self.showError("Failed to complete login: \(error)")
            }
        }
    }
    
    private func showMainViewController() {
        // Navigate to main app
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

## Common Issues

### "Authorization header is malformed"
This usually means the OAuth parameters were not properly formatted. Ensure:
- Consumer key and secret are correct
- URL encoding is applied to all parameters
- Nonce and timestamp are included in the request

### "Invalid signature"
This means the HMAC-SHA1 signature doesn't match. Verify:
- Consumer secret is correct
- Request method (GET, POST, etc.) matches the signature base string
- All parameters are included in the signature

### "Token expired"
Call `refreshAccessToken()` with the expired token and any required parameters (consult your OAuth provider's docs).

### "Callback URL not registered"
Ensure:
- The URL scheme is registered in Info.plist
- The callback URL scheme passed to `fetchRequestToken()` matches the one in Info.plist
- `SceneDelegate.scene(_:openURLContexts:)` is implemented

## Further Reading

- [RFC 5849 — OAuth 1.0 Protocol](https://tools.ietf.org/html/rfc5849)
- [Twitter API Documentation](https://developer.twitter.com/en/docs)
- [ARCHITECTURE.md](ARCHITECTURE.md) — Implementation details
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Contributing to CDOAuth1Kit
