//
//  CDOAuth1AuthSessionTests.swift
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
import Testing
@testable import CDOAuth1Kit

struct CDOAuth1AuthSessionTests {

    @Test func returnsCallbackURLOnSuccess() throws {
        let callbackURL = try #require(URL(string: "myapp://oauthCallback?oauth_token=T&oauth_verifier=V"))
        let resolved = try CDOAuth1AuthSession.mapCallback(url: callbackURL, error: nil)
        #expect(resolved == callbackURL)
    }

    @Test func mapsCanceledLoginToAuthorizationCancelled() {
        do {
            _ = try CDOAuth1AuthSession.mapCallback(url: nil, error: ASWebAuthenticationSessionError(.canceledLogin))
            Issue.record("Expected mapCallback to throw")
        } catch CDOAuth1Error.authorizationCancelled {
            // expected
        } catch {
            Issue.record("Expected .authorizationCancelled, got \(error)")
        }
    }

    @Test func rethrowsOtherErrors() {
        do {
            _ = try CDOAuth1AuthSession.mapCallback(
                url: nil,
                error: ASWebAuthenticationSessionError(.presentationContextNotProvided)
            )
            Issue.record("Expected mapCallback to throw")
        } catch let error as ASWebAuthenticationSessionError {
            #expect(error.code == .presentationContextNotProvided)
        } catch {
            Issue.record("Expected ASWebAuthenticationSessionError, got \(error)")
        }
    }

    @Test func throwsDecodingFailedWhenNoURLAndNoError() {
        do {
            _ = try CDOAuth1AuthSession.mapCallback(url: nil, error: nil)
            Issue.record("Expected mapCallback to throw")
        } catch CDOAuth1Error.decodingFailed {
            // expected
        } catch {
            Issue.record("Expected .decodingFailed, got \(error)")
        }
    }
}
