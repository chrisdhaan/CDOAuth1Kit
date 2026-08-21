//
//  CDOAuth1Error.swift
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

import Foundation
import Security

public enum CDOAuth1Error: Error, Sendable {
    case invalidRequestToken
    case invalidAccessToken
    @available(*, deprecated, message: "Use .decodingFailed instead.")
    case invalidResponse
    case keychainError(OSStatus)

    /// The OAuth provider returned a non-2xx HTTP status code.
    case httpError(statusCode: Int, headers: [String: String])

    /// The underlying `URLSession` request failed (e.g. offline, timed out).
    case networkError(URLError)

    /// The OAuth provider's response body could not be parsed into a credential.
    case decodingFailed

    /// The user cancelled the browser-based authorization flow.
    case authorizationCancelled
}

extension CDOAuth1Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRequestToken:
            "The OAuth request token is invalid or missing required fields."
        case .invalidAccessToken:
            "The OAuth access token is invalid or missing."
        case .invalidResponse:
            "The OAuth provider returned an unexpected response format."
        case let .keychainError(status):
            "Keychain operation failed with OSStatus \(status)."
        case let .httpError(statusCode, _):
            "The OAuth provider returned HTTP status code \(statusCode)."
        case let .networkError(underlying):
            underlying.localizedDescription
        case .decodingFailed:
            "Failed to decode the OAuth provider's response."
        case .authorizationCancelled:
            "The user cancelled the authorization flow."
        }
    }
}
