//
//  CDOAuth1AuthSession.swift
//  CDOAuth1Kit
//
//  Created by Christopher de Haan on 8/28/16.
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

import AuthenticationServices
import Foundation

/// An `async`/`await` wrapper around `ASWebAuthenticationSession` for completing the
/// browser-redirect step of an OAuth 1.0a handshake.
///
/// `CDOAuth1SessionManager` is unaware of this type — wire it in around
/// ``CDOAuth1SessionManager/fetchRequestToken(path:method:callbackURL:scope:)`` yourself:
/// ```swift
/// let requestToken = try await manager.fetchRequestToken(path: "request_token", method: "POST", callbackURL: callbackURL)
/// let authorizeURL = URL(string: "authorize?oauth_token=\(requestToken.token)", relativeTo: manager.baseURL)!
/// let callback = try await CDOAuth1AuthSession(presentationAnchor: view.window!)
///     .authorize(authorizationURL: authorizeURL, callbackScheme: "myapp")
/// // extract oauth_verifier from `callback` and pass it into fetchAccessToken
/// ```
@available(iOS 12.0, macOS 10.15, visionOS 1.0, *)
public final class CDOAuth1AuthSession: NSObject {

    private let presentationAnchorProvider: () -> ASPresentationAnchor

    /// Retains the in-flight `ASWebAuthenticationSession` for the duration of the browser
    /// presentation. `ASWebAuthenticationSession` does not retain itself, and the completion
    /// handler closure is retained *by* the session rather than the reverse — without this
    /// property, ARC is free to deallocate the session as soon as `authorize(_:callbackScheme:)`'s
    /// synchronous setup returns, before the user ever interacts with the browser sheet.
    private var activeSession: ASWebAuthenticationSession?

    /// - Parameter presentationAnchor: The window `ASWebAuthenticationSession` presents its browser
    ///   sheet from. This type never calls `UIApplication.shared`/`NSApplication.shared` to discover
    ///   one itself, since doing so is unavailable in app extensions; pass your app's key window.
    public init(presentationAnchor: @autoclosure @escaping () -> ASPresentationAnchor) {
        self.presentationAnchorProvider = presentationAnchor
        super.init()
    }

    /// Presents the browser-based OAuth authorization page and suspends until the provider
    /// redirects back to `callbackScheme`.
    ///
    /// - Parameters:
    ///   - authorizationURL: The provider's authorize URL, including the `oauth_token` query item.
    ///   - callbackScheme: The custom URL scheme the provider redirects back to.
    /// - Returns: The callback URL, containing `oauth_token` and `oauth_verifier` query items.
    /// - Throws: `CDOAuth1Error.authorizationCancelled` if the user cancels, `.decodingFailed` if
    ///   the session completes without a callback URL or an error, or the underlying
    ///   `ASWebAuthenticationSession` error otherwise.
    public func authorize(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                self?.activeSession = nil
                do {
                    try continuation.resume(returning: Self.mapCallback(url: callbackURL, error: error))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            session.presentationContextProvider = self
            activeSession = session
            session.start()
        }
    }

    static func mapCallback(url callbackURL: URL?, error: (any Error)?) throws -> URL {
        if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
            throw CDOAuth1Error.authorizationCancelled
        }
        if let error {
            throw error
        }
        guard let callbackURL else {
            throw CDOAuth1Error.decodingFailed
        }
        return callbackURL
    }
}

extension CDOAuth1AuthSession: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        presentationAnchorProvider()
    }
}
