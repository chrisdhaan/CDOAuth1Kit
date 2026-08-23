//
//  CDOAuth1ErrorTests.swift
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
import Testing
@testable import CDOAuth1Kit

struct CDOAuth1ErrorTests {

    @Test func httpErrorCarriesStatusCodeAndHeaders() {
        let error = CDOAuth1Error.httpError(statusCode: 429, headers: ["Retry-After": "30"])

        guard case let .httpError(statusCode, headers) = error else {
            Issue.record("Expected .httpError")
            return
        }
        #expect(statusCode == 429)
        #expect(headers["Retry-After"] == "30")
    }

    @Test func httpErrorDescriptionMentionsStatusCode() {
        let error = CDOAuth1Error.httpError(statusCode: 500, headers: [:])
        #expect(error.errorDescription?.contains("500") == true)
    }

    @Test func networkErrorWrapsURLError() {
        let underlying = URLError(.notConnectedToInternet)
        let error = CDOAuth1Error.networkError(underlying)

        guard case let .networkError(wrapped) = error else {
            Issue.record("Expected .networkError")
            return
        }
        #expect(wrapped.code == .notConnectedToInternet)
    }

    @Test func networkErrorDescriptionSurfacesUnderlyingDescription() {
        let underlying = URLError(.notConnectedToInternet)
        let error = CDOAuth1Error.networkError(underlying)
        #expect(error.errorDescription == underlying.localizedDescription)
    }

    @Test func decodingFailedHasNonEmptyDescription() {
        let error = CDOAuth1Error.decodingFailed
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func authorizationCancelledHasNonEmptyDescription() {
        let error = CDOAuth1Error.authorizationCancelled
        #expect(error.errorDescription?.isEmpty == false)
    }

    @Test func allExistingCasesHaveNonEmptyDescriptions() {
        let errors: [CDOAuth1Error] = [
            .invalidRequestToken,
            .invalidAccessToken,
            .keychainError(errSecItemNotFound)
        ]
        for error in errors {
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test func signingFailedCarriesUnderlyingDescription() {
        let error = CDOAuth1Error.signingFailed("key size mismatch")

        guard case let .signingFailed(message) = error else {
            Issue.record("Expected .signingFailed")
            return
        }
        #expect(message == "key size mismatch")
        #expect(error.errorDescription?.contains("key size mismatch") == true)
    }
}
