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
