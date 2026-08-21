# CDOAuth1Kit 2.0 Migration Guide

This guide helps you upgrade from CDOAuth1Kit 1.0.0 (Objective-C, AFNetworking) to 2.0.0 (Swift, zero dependencies).

## Overview of Changes

CDOAuth1Kit 2.0 is a complete rewrite in Swift with the following major changes:

- **Language:** Objective-C → Swift 5.3+
- **Dependencies:** Removed AFNetworking dependency
- **Async/await:** Replaced callback blocks with modern Swift concurrency
- **Minimum OS:** iOS 13.0+, macOS 10.15+ (up from iOS 8.0)
- **Request Signing:** `CDOAuth1RequestSerializer` → `CDOAuth1RequestSigner`
- **Keychain Format:** Changed from `NSKeyedArchiver` to `JSONEncoder` (requires re-authentication)

## Step 1: Installation Changes

### Switch from CocoaPods to Swift Package Manager

CDOAuth1Kit 2.0 drops CocoaPods support entirely — 1.0.0 is the last version available via CocoaPods. Remove `CDOAuth1Kit` (and `AFNetworking`, which 2.0 no longer depends on) from your `Podfile`, then add the package via Swift Package Manager instead:

**Before (`Podfile`):**
```ruby
pod 'CDOAuth1Kit'
pod 'AFNetworking'
```

**After (`Package.swift`):**
```swift
.package(url: "https://github.com/chrisdhaan/CDOAuth1Kit.git", from: "2.0.0")
```

Or in Xcode: File → Add Packages → Enter `https://github.com/chrisdhaan/CDOAuth1Kit.git`. Then run `pod deintegrate` to remove the CocoaPods workspace integration, if you have no other pods remaining.

## Step 2: Import Changes

### Remove AFNetworking Imports

In your source files, remove any AFNetworking imports:

**Before:**
```objective-c
#import <AFNetworking/AFNetworking.h>
#import <CDOAuth1Kit/CDOAuth1Kit.h>
```

**After (Swift):**
```swift
import CDOAuth1Kit
```

## Step 3: Initialization

The initialization is mostly unchanged in terms of parameters, but the method is now in Swift:

**Before (Objective-C):**
```objective-c
self.oAuth1SessionManager = [[CDOAuth1SessionManager alloc]
    initWithBaseURL:[NSURL URLWithString:@"https://api.twitter.com/oauth/"]
       consumerKey:@"YOUR_CONSUMER_KEY"
    consumerSecret:@"YOUR_CONSUMER_SECRET"];
```

**After (Swift):**
```swift
let manager = CDOAuth1SessionManager(
    baseURL: URL(string: "https://api.twitter.com/oauth/")!,
    consumerKey: "YOUR_CONSUMER_KEY",
    consumerSecret: "YOUR_CONSUMER_SECRET"
)
```

The parameters and meaning are identical — only the syntax changes to Swift.

## Step 4: OAuth Handshake

The biggest change is moving from completion handler blocks to `async/await`.

### Fetching a Request Token

**Before (Objective-C with blocks):**
```objective-c
[self.oAuth1SessionManager fetchRequestTokenWithPath:@"request_token"
                                              method:@"POST"
                                         callbackURL:[NSURL URLWithString:@"yourapp://oauthCallback"]
                                               scope:nil
                                             success:^(CDOAuth1Credential *requestToken) {
                                                 NSString *authURL = [NSString stringWithFormat:
                                                     @"https://twitter.com/oauth/authorize?oauth_token=%@",
                                                     requestToken.token];
                                                 [[UIApplication sharedApplication] openURL:[NSURL URLWithString:authURL]];
                                             }
                                             failure:^(NSError *error) {
                                                 NSLog(@"Error: %@", error.localizedDescription);
                                             }];
```

**After (Swift with async/await):**
```swift
Task {
    do {
        let requestToken = try await manager.fetchRequestToken(
            path: "request_token",
            method: "POST",
            callbackURL: URL(string: "yourapp://oauthCallback")!
        )
        
        let authURLString = "https://twitter.com/oauth/authorize?oauth_token=\(requestToken.token)"
        if let authURL = URL(string: authURLString) {
            UIApplication.shared.open(authURL)
        }
    } catch {
        print("Error: \(error)")
    }
}
```

### Fetching an Access Token

**Before (Objective-C with blocks):**
```objective-c
[self.oAuth1SessionManager fetchAccessTokenWithPath:@"access_token"
                                             method:@"POST"
                                      requestToken:requestToken
                                           success:^(CDOAuth1Credential *accessToken) {
                                               [self.oAuth1SessionManager.requestSerializer
                                                   saveAccessToken:accessToken];
                                           }
                                           failure:^(NSError *error) {
                                               NSLog(@"Error: %@", error.localizedDescription);
                                           }];
```

**After (Swift with async/await):**
```swift
Task {
    do {
        let accessToken = try await manager.fetchAccessToken(
            path: "access_token",
            method: "POST",
            requestToken: requestToken
        )
        
        // Access token is automatically stored in keychain
        print("Access token: \(accessToken.token)")
    } catch {
        print("Error: \(error)")
    }
}
```

### Refreshing an Access Token

**Before (Objective-C):**
```objective-c
CDOAuth1Credential *accessToken = self.oAuth1SessionManager.requestSerializer.accessToken;
[self.oAuth1SessionManager refreshAccessTokenWithPath:@"access_token"
                                          parameters:@{@"oauth_session_handle": accessToken.userInfo[@"oauth_session_handle"]}
                                              method:@"POST"
                                         accessToken:accessToken
                                             success:^(CDOAuth1Credential *refreshedToken) {
                                                 [self.oAuth1SessionManager.requestSerializer
                                                     saveAccessToken:refreshedToken];
                                             }
                                             failure:^(NSError *error) {
                                                 NSLog(@"Error: %@", error.localizedDescription);
                                             }];
```

**After (Swift):**
```swift
Task {
    do {
        let refreshedToken = try await manager.refreshAccessToken(
            path: "access_token",
            parameters: ["oauth_session_handle": accessToken.userInfo?["oauth_session_handle"] as? String ?? ""],
            method: "POST",
            accessToken: accessToken
        )
        
        print("Token refreshed")
    } catch {
        print("Error: \(error)")
    }
}
```

## Step 5: Callback Handling

The `CDOAuth1Helper` method signature changed to use parameter labels.

**Before (Objective-C):**
```objective-c
if ([CDOAuth1Helper isAuthorizationCallbackURL:url
                             callbackURLScheme:@"yourapp"
                               callbackURLHost:@"oauthCallback"]) {
    // Handle callback
}
```

**After (Swift):**
```swift
if CDOAuth1Helper.isAuthorizationCallbackURL(
    url,
    scheme: "yourapp",
    host: "oauthCallback"
) {
    // Handle callback
}
```

The functionality is identical; only the parameter names changed (`callbackURLScheme` → `scheme`, `callbackURLHost` → `host`).

## Step 6: Token Storage

**Important:** Keychain data is not migrated automatically. Users will need to re-authenticate once after updating to v2.0.0.

### Why the Format Changed

- **v1.0.0** used `NSKeyedArchiver` for storage (deprecated since iOS 12)
- **v2.0.0** uses `JSONEncoder`/`JSONDecoder` for storage (modern Swift standard)

The two formats are incompatible, so existing tokens cannot be decoded.

### Action Required

1. After users install v2.0.0, check `manager.isAuthorized`
2. If `false`, show the OAuth login flow
3. Users re-authenticate once, and new tokens are stored in the v2.0.0 format
4. Future app updates will preserve tokens normally

### Checking Authorization Status

**Before (Objective-C):**
```objective-c
if (self.oAuth1SessionManager.requestSerializer.accessToken != nil) {
    // User is logged in
}
```

**After (Swift):**
```swift
if manager.isAuthorized {
    // User is logged in
}
```

## Step 7: Removed / Changed APIs

### CDOAuth1RequestSerializer → CDOAuth1RequestSigner

The request serializer is now internal and not directly exposed.

**Before (Objective-C):**
```objective-c
CDOAuth1RequestSerializer *serializer = self.oAuth1SessionManager.requestSerializer;
CDOAuth1Credential *token = serializer.accessToken;
[serializer saveAccessToken:updatedToken];
```

**After (Swift):**
Not applicable — use `manager` directly:

```swift
if manager.isAuthorized {
    // Token exists
}

// Token is saved automatically after fetchAccessToken()
// or refreshAccessToken()
```

### saveAccessToken: → automatic

In v1.0.0, you manually called `saveAccessToken:` after fetching a token. In v2.0.0, tokens are saved automatically.

**Before (Objective-C):**
```objective-c
[self.oAuth1SessionManager.requestSerializer saveAccessToken:token];
```

**After (Swift):**
```swift
// Automatic when you call fetchAccessToken() or refreshAccessToken()
// No manual save needed
```

### Deauthorization

**Before (Objective-C):**
```objective-c
[self.oAuth1SessionManager.requestSerializer saveAccessToken:nil];
```

**After (Swift):**
```swift
try manager.deauthorize()
```

## Migration Checklist

- [ ] Remove `CDOAuth1Kit` and `AFNetworking` from your `Podfile`; add CDOAuth1Kit via Swift Package Manager instead
- [ ] Update imports (remove AFNetworking)
- [ ] Convert Objective-C code to Swift
- [ ] Migrate from blocks to `async/await` for OAuth methods
- [ ] Update `CDOAuth1Helper` method call with new parameter labels
- [ ] Remove calls to `requestSerializer` (use manager directly)
- [ ] Remove `saveAccessToken:` calls (automatic now)
- [ ] Update authorization checking to use `manager.isAuthorized`
- [ ] Test login flow (users will need to re-authenticate once)
- [ ] Update your app's minimum OS requirements if needed (iOS 13+, macOS 10.15+)

## Common Migration Patterns

### Before & After: Complete Login Flow

**Before (Objective-C):**
```objective-c
@interface LoginViewController : UIViewController {
    CDOAuth1SessionManager *manager;
}
@end

@implementation LoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    manager = [[CDOAuth1SessionManager alloc]
        initWithBaseURL:[NSURL URLWithString:@"https://api.twitter.com/oauth/"]
           consumerKey:@"KEY"
        consumerSecret:@"SECRET"];
}

- (IBAction)loginTapped:(id)sender {
    [manager fetchRequestTokenWithPath:@"request_token"
                                method:@"POST"
                           callbackURL:[NSURL URLWithString:@"yourapp://oauth"]
                                 scope:nil
                               success:^(CDOAuth1Credential *token) {
                                   NSString *url = [NSString stringWithFormat:
                                       @"https://twitter.com/oauth/authorize?oauth_token=%@",
                                       token.token];
                                   [[UIApplication sharedApplication]
                                       openURL:[NSURL URLWithString:url]];
                               }
                               failure:^(NSError *error) {
                                   NSLog(@"Error: %@", error);
                               }];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url
  sourceApplication:(NSString *)source annotation:(id)annotation {
    if ([CDOAuth1Helper isAuthorizationCallbackURL:url
                                callbackURLScheme:@"yourapp"
                                  callbackURLHost:@"oauth"]) {
        
        CDOAuth1Credential *verifiedToken = /* extract from url.query */;
        [manager fetchAccessTokenWithPath:@"access_token"
                                  method:@"POST"
                           requestToken:verifiedToken
                                success:^(CDOAuth1Credential *token) {
                                    [manager.requestSerializer saveAccessToken:token];
                                    [self showMain];
                                }
                                failure:^(NSError *error) {
                                    NSLog(@"Error: %@", error);
                                }];
    }
    return NO;
}

@end
```

**After (Swift):**
```swift
import CDOAuth1Kit

class LoginViewController: UIViewController {
    
    let manager = CDOAuth1SessionManager(
        baseURL: URL(string: "https://api.twitter.com/oauth/")!,
        consumerKey: "KEY",
        consumerSecret: "SECRET"
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if manager.isAuthorized {
            showMain()
        }
    }
    
    @IBAction func loginTapped(_ sender: UIButton) {
        Task {
            await performLogin()
        }
    }
    
    private func performLogin() async {
        do {
            let requestToken = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: URL(string: "yourapp://oauth")!
            )
            
            let urlString = "https://twitter.com/oauth/authorize?oauth_token=\(requestToken.token)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    // In SceneDelegate.scene(_:openURLContexts:)
    func handleOAuthCallback(url: URL) {
        if CDOAuth1Helper.isAuthorizationCallbackURL(
            url,
            scheme: "yourapp",
            host: "oauth"
        ) {
            Task {
                await completeLogin(callbackURL: url)
            }
        }
    }
    
    private func completeLogin(callbackURL: URL) async {
        do {
            let verifiedToken = /* extract from callbackURL.query */
            let accessToken = try await manager.fetchAccessToken(
                path: "access_token",
                method: "POST",
                requestToken: verifiedToken
            )
            
            showMain()
        } catch {
            print("Error: \(error)")
        }
    }
}
```

## Need Help?

- Check [Usage.md](Usage.md) for detailed usage examples
- See [ARCHITECTURE.md](ARCHITECTURE.md) for implementation details
- Ask on [Stack Overflow](https://stackoverflow.com/questions/tagged/cdoauth1kit) with the `cdoauth1kit` tag
- Open an issue on [GitHub](https://github.com/chrisdhaan/CDOAuth1Kit/issues)

## What's New in 2.0

- ✨ Full Swift rewrite with modern syntax
- ✨ async/await concurrency model
- ✨ Zero external dependencies
- ✨ CryptoKit HMAC-SHA1 (no CommonCrypto)
- ✨ Improved keychain handling
- ✨ Comprehensive test suite
- ✨ DocC documentation
- ✨ GitHub Actions CI/CD

Welcome to CDOAuth1Kit 2.0! 🎉
