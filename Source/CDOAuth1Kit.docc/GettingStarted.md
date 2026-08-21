# Getting Started

Authenticate with an OAuth 1.0a API in four steps.

## Create a session manager

Initialize a session manager with your OAuth provider's base URL and your app's consumer credentials:

```swift
import CDOAuth1Kit

let manager = CDOAuth1SessionManager(
    baseURL: URL(string: "https://api.example.com/oauth/")!,
    consumerKey: "YOUR_CONSUMER_KEY",
    consumerSecret: "YOUR_CONSUMER_SECRET"
)
```

## Fetch a request token

The first step of OAuth 1.0a is obtaining a request token:

```swift
let requestToken = try await manager.fetchRequestToken(
    path: "request_token",
    method: "POST",
    callbackURL: URL(string: "yourapp://oauthCallback")!
)
```

Then redirect the user to authorize your app on the OAuth provider's website:

```swift
let authURLString = "https://api.example.com/oauth/authorize?oauth_token=\(requestToken.token)"
if let authURL = URL(string: authURLString) {
    UIApplication.shared.open(authURL)
}
```

## Handle the callback URL

When the user authorizes your app, they are redirected back to your app's callback URL with an `oauth_verifier` parameter.

Register your callback URL scheme in your app's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>OAuth Callback</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yourapp</string>
        </array>
    </dict>
</array>
```

Handle the callback in `SceneDelegate.scene(_:openURLContexts:)`:

```swift
func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
) {
    for urlContext in URLContexts {
        let url = urlContext.url
        
        if CDOAuth1Helper.isAuthorizationCallbackURL(
            url,
            scheme: "yourapp",
            host: "oauthCallback"
        ) {
            // Extract oauth_token and oauth_verifier from url.query
            let params = [String: String](queryString: url.query ?? "")
            let verifier = params["oauth_verifier"]
            
            // Proceed to fetch access token (see next step)
        }
    }
}
```

## Fetch the access token

Once you have the `oauth_verifier`, exchange it for an access token:

```swift
let accessToken = try await manager.fetchAccessToken(
    path: "access_token",
    method: "POST",
    requestToken: verifiedRequestToken  // request token with verifier added
)
```

The access token is automatically stored in the device keychain. You can now use it for authenticated API requests.

## Check authorization status

At any time, check if your app has a valid access token:

```swift
if manager.isAuthorized {
    print("User is logged in")
} else {
    print("User needs to log in")
}
```

## Next steps

- See [Documentation/Usage.md](https://github.com/chrisdhaan/CDOAuth1Kit/blob/master/Documentation/Usage.md) for comprehensive usage examples
- See [Documentation/ARCHITECTURE.md](https://github.com/chrisdhaan/CDOAuth1Kit/blob/master/Documentation/ARCHITECTURE.md) for implementation details
- See [Documentation/CDOAuth1Kit 2.0 Migration Guide.md](https://github.com/chrisdhaan/CDOAuth1Kit/blob/master/Documentation/CDOAuth1Kit%202.0%20Migration%20Guide.md) if upgrading from v1.0.0
