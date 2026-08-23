//
//  CDOAuth1SessionManagerPublisher.swift
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

import Combine
import Foundation

/// `Combine` equivalents of ``CDOAuth1SessionManager``'s `async` OAuth handshake and
/// signed-request APIs, for codebases that haven't fully migrated to async/await.
public extension CDOAuth1SessionManager {

    /// `Combine` equivalent of ``fetchRequestToken(path:method:callbackURL:scope:)``.
    func fetchRequestTokenPublisher(path: String,
                                    method: String,
                                    callbackURL: URL,
                                    scope: String? = nil) -> AnyPublisher<CDOAuth1Credential, any Error> {
        publisher {
            try await self.fetchRequestToken(path: path, method: method, callbackURL: callbackURL, scope: scope)
        }
    }

    /// `Combine` equivalent of ``fetchAccessToken(path:method:requestToken:)``.
    func fetchAccessTokenPublisher(path: String,
                                   method: String,
                                   requestToken: CDOAuth1Credential) -> AnyPublisher<CDOAuth1Credential, any Error> {
        publisher {
            try await self.fetchAccessToken(path: path, method: method, requestToken: requestToken)
        }
    }

    /// `Combine` equivalent of ``refreshAccessToken(path:parameters:method:accessToken:)``.
    func refreshAccessTokenPublisher(path: String,
                                     parameters: [String: String]? = nil,
                                     method: String,
                                     accessToken: CDOAuth1Credential) -> AnyPublisher<CDOAuth1Credential, any Error> {
        publisher {
            try await self.refreshAccessToken(
                path: path,
                parameters: parameters,
                method: method,
                accessToken: accessToken
            )
        }
    }

    /// `Combine` equivalent of ``request(path:method:parameters:)``.
    func requestPublisher(path: String,
                          method: String,
                          parameters: [String: String] = [:]) -> AnyPublisher<(Data, HTTPURLResponse), any Error> {
        publisher {
            try await self.request(path: path, method: method, parameters: parameters)
        }
    }

    /// Wraps `operation` as a cold publisher: the work starts on subscription (not on
    /// creation), and each new subscriber re-invokes `operation` rather than replaying a
    /// cached result — matching what `.retry()` and other Combine idioms expect. Cancelling
    /// the subscription stops delivery but does not cancel the underlying `Task`; the
    /// operation still runs to completion (and, for the token-saving methods, still writes
    /// to the keychain) in the background.
    private func publisher<Output>(_ operation: @escaping () async throws -> Output) -> AnyPublisher<Output, any Error> {
        Deferred {
            Future { promise in
                Task {
                    do {
                        try await promise(.success(operation()))
                    } catch {
                        promise(.failure(error))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
