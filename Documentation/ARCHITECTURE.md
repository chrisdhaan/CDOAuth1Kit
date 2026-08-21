# CDOAuth1Kit Architecture

## Overview

CDOAuth1Kit is built as a layered system that separates concerns: session management (public API), request signing (internal implementation), and secure token storage (keychain integration).

## OAuth 1.0a Signing Flow

```
Caller (User Code)
  │
  ▼
CDOAuth1SessionManager (public API)
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

KeychainStore (internal)
  │  internal helper — JSONEncoder/Decoder + SecItem APIs
  │  no public API surface
  │
  ├─ write(credential:service:) throws
  ├─ read(service:) throws -> CDOAuth1Credential?
  └─ delete(service:) throws
```

## Component Descriptions

### CDOAuth1SessionManager

The main public API class. Orchestrates the complete OAuth 1.0a three-legged handshake.

**Responsibilities:**
- Holds the base URL for the OAuth provider and consumer credentials
- Creates and configures a `URLSession` instance for network requests
- Delegates request signing to `CDOAuth1RequestSigner`
- Manages credential persistence via `KeychainStore`
- Provides async/await methods for all network operations

**Public methods:**
- `fetchRequestToken(path:method:callbackURL:scope:)` → `CDOAuth1Credential`
- `fetchAccessToken(path:method:requestToken:)` → `CDOAuth1Credential`
- `refreshAccessToken(path:parameters:method:accessToken:)` → `CDOAuth1Credential`
- `deauthorize()` → deletes stored credentials

**Public properties:**
- `isAuthorized` → `Bool` — indicates if an access token is stored and valid

### CDOAuth1RequestSigner

Responsible for generating OAuth signatures according to RFC 5849.

**Responsibilities:**
- Generates OAuth parameters (nonce, timestamp, signature method, version)
- Constructs the signature base string (method, URL, sorted parameters)
- Computes HMAC-SHA1 signature using CryptoKit
- Attaches the signature and OAuth parameters to outgoing requests

**Public methods:**
- `signed(_ request: URLRequest, parameters: [String: String]?) throws → URLRequest`
- `oauthParameters() → [String: String]`

**Key implementation details:**
- Uses `CryptoKit.HMAC<Insecure.SHA1>` for signing
- Percent-encoding per RFC 5849 §3.6 (handled by `String+CDOAuth1Kit`)
- Generates cryptographically secure nonces via `UUID()`
- Timestamps are UNIX epoch seconds (not milliseconds)

### CDOAuth1Credential

A value type (struct) representing an OAuth token, secret, and optional metadata.

**Responsibilities:**
- Stores token, secret, expiration (optional), and user info (optional)
- Conforms to `Codable` for JSON serialization (used by KeychainStore)
- Conforms to `Sendable` for thread-safe use with async/await
- Provides computed properties for authorization state checking

**Properties:**
- `token: String` — OAuth token (request or access token)
- `secret: String` — OAuth secret (token secret)
- `expiration: Date?` — optional expiration date
- `userInfo: [String: Any]?` — optional additional metadata (e.g., `oauth_session_handle`)

**Initializers:**
- `init(token:secret:expiration:userInfo:)` — standard initialization
- `init?(queryString:)` — parses OAuth callback URL query string

**Computed properties:**
- `isExpired: Bool` — checks if expiration date has passed

### CDOAuth1Error

A Swift error enum replacing C-style error codes. Conforms to `LocalizedError`.

**Cases:**
- `invalidRequestToken` — request token endpoint returned invalid response
- `invalidAccessToken` — access token endpoint returned invalid response
- `invalidResponse` — *(deprecated, use `decodingFailed`)* unexpected response format from OAuth provider
- `keychainError(OSStatus)` — SecItem API failure with system error code
- `httpError(statusCode: Int, headers: [String: String])` — OAuth provider returned a non-2xx HTTP status code
- `networkError(URLError)` — the underlying `URLSession` request failed (e.g. offline, timed out)
- `decodingFailed` — the OAuth provider's response body could not be parsed into a credential
- `authorizationCancelled` — the user cancelled the browser-based authorization flow

### CDOAuth1Helper

A namespace for utility functions related to OAuth callback URL handling.

**Static methods:**
- `isAuthorizationCallbackURL(_ url: URL, scheme: String, host: String) → Bool`
  - Checks if a URL matches the expected OAuth callback scheme and host
  - Used in `SceneDelegate.scene(_:openURLContexts:)` to identify OAuth callbacks

### KeychainStore

An internal helper for secure credential storage in the system keychain.

**Responsibilities:**
- Encodes credentials to JSON via `JSONEncoder`
- Stores JSON in keychain under `kSecClassGenericPassword`
- Retrieves and decodes credentials via `JSONDecoder`
- Uses `baseURL.host` as the service identifier (one credential per host)

**Methods (internal, not public):**
- `write(_ credential: CDOAuth1Credential, service: String) throws`
- `read(service: String) throws -> CDOAuth1Credential?`
- `delete(service: String) throws`

**Keychain query attributes:**
- `kSecClass`: `kSecClassGenericPassword` — generic password storage
- `kSecAttrService`: manager's `baseURL.host` — service identifier
- `kSecValueData`: JSON-encoded credential

**Why not NSKeyedArchiver?**
- `NSKeyedArchiver` was deprecated in iOS 12.0 and macOS 10.14
- `JSONEncoder`/`JSONDecoder` are the modern, standard Swift approach
- JSON format is more transparent and portable across versions

### String+CDOAuth1Kit

String extension for OAuth-specific percent encoding/decoding.

**Methods:**
- `oauthPercentEncoded() → String` — RFC 5849 §3.6 percent encoding
  - Encodes all characters except unreserved: `A-Z a-z 0-9 - . _ ~`
  - Uses `%HH` format for encoded octets
- `oauthPercentDecoded() → String` — reverses RFC 5849 encoding

**Why custom encoding?**
- Standard URL percent encoding (`addingPercentEncoding(withAllowedCharacters:)`) encodes a different set of characters
- OAuth 1.0a requires strict RFC 5849 compliance for signature verification

### Dictionary+CDOAuth1Kit

Dictionary extension for OAuth query string handling.

**Methods:**
- `init(queryString: String)` — parses OAuth callback URL query strings into a dictionary
  - Splits on `&`, then `=` for key-value pairs
  - Percent-decodes values using `oauthPercentDecoded()`
- `queryStringRepresentation() → String` — formats dictionary as OAuth query string
  - Sorts keys alphabetically (required for signature base string)
  - Percent-encodes values using `oauthPercentEncoded()`

## Data Flow Example: Request Token Flow

```
1. User calls: manager.fetchRequestToken(path: "request_token", callbackURL: ...)

2. CDOAuth1SessionManager.fetchRequestToken:
   a. Create URLRequest to: baseURL + path
   b. Call requestSigner.oauthParameters() → [oauth_version, oauth_consumer_key, ...]
   c. Call requestSigner.signed(request, parameters: oauthParams)
      → attaches OAuth params + signature to Authorization header
   d. Call URLSession.data(for: signedRequest)
   e. Parse response into CDOAuth1Credential (token + secret from query string)
   f. Return credential to caller

3. Caller extracts oauth_token and oauth_verifier from credential
   (verifier comes from OAuth callback URL, token comes from request token response)

4. User authorizes app via OAuth provider's web interface

5. OAuth provider redirects to app's callback URL with oauth_verifier parameter

6. SceneDelegate detects callback via CDOAuth1Helper.isAuthorizationCallbackURL()

7. Caller invokes: manager.fetchAccessToken(requestToken: verifiedToken)
   (same signing flow as step 2)
   → Response contains access token and secret

8. CDOAuth1SessionManager calls KeychainStore.write(accessToken, service: baseURL.host)
   → Stores in keychain for future use

9. manager.isAuthorized now returns true (credential found in keychain)
```

## Security Considerations

### Keychain Storage

- Credentials are stored in the **device keychain**, not in the app's Documents or Caches
- The keychain is encrypted at the device level
- Only the app that stores the credential can retrieve it
- Loss of keychain access (e.g., device reset) requires re-authentication

### HMAC-SHA1 Signing

- Signature is computed over the normalized request (method, URL, sorted parameters)
- Consumer secret is included in the signing key
- Prevents tampering with the request in transit
- Does **not** encrypt the request body (use HTTPS for transport security)

### Nonce & Timestamp

- Nonce is a cryptographically random UUID-derived value
- Timestamp is the current UNIX epoch
- Together, these prevent replay attacks
- OAuth provider should reject requests with old timestamps

## Testing Strategy

The test suite validates:

1. **Credential Management** (CDOAuth1CredentialTests)
   - Initialization from parameters and query strings
   - Expiration checking
   - Codable round-trip (encoding/decoding)

2. **Request Signing** (CDOAuth1RequestSignerTests)
   - RFC 5849 test vector validation
   - OAuth parameter generation
   - Authorization header formatting

3. **Callback Detection** (CDOAuth1HelperTests)
   - URL scheme and host matching
   - Positive and negative cases

4. **String Utilities** (StringTests)
   - Percent encoding correctness
   - Unreserved character handling

5. **Dictionary Utilities** (DictionaryTests)
   - Query string parsing
   - Alphabetical sorting for signature base string
   - Round-trip encoding/decoding

## Performance Considerations

- **Keychain I/O** — Occurs only on app launch (read) and after OAuth flow (write)
- **HMAC-SHA1** — Computed once per request (negligible cost on modern devices)
- **URLSession** — Reused for all requests (connection pooling, efficient)
- **No external dependencies** — No network overhead from dependency managers

## Future Extensions

1. **Token refresh** — Already supported via `refreshAccessToken()`
2. **Multiple credentials per app** — Would require key-value pairing in keychain service
3. **Custom HTTP headers** — Can be added via `URLRequest.setValue(_:forHTTPHeaderField:)`
4. **Request interceptors** — Can wrap `URLSession` requests at a higher level
5. **visionOS support** — OAuth browser flows are technically possible; deprioritized for v2.0.0

## References

- [RFC 5849 — OAuth 1.0 Protocol](https://tools.ietf.org/html/rfc5849)
- [Apple CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit)
- [Apple Security Framework Documentation](https://developer.apple.com/documentation/security)
- [URLSession Documentation](https://developer.apple.com/documentation/foundation/urlsession)
