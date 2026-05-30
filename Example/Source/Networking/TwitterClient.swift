//
//  TwitterClient.swift
//  CDOAuth1Kit
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

import CDOAuth1Kit

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
