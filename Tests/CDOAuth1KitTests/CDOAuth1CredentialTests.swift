//
//  CDOAuth1CredentialTests.swift
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

struct CDOAuth1CredentialTests {

    @Test func initWithTokenAndSecret() {
        let cred = CDOAuth1Credential(token: "tok", secret: "sec")
        #expect(cred.token == "tok")
        #expect(cred.secret == "sec")
        #expect(cred.isExpired == false)
    }

    @Test func initWithQueryString() {
        let qs = "oauth_token=T&oauth_token_secret=S&oauth_verifier=V"
        let cred = CDOAuth1Credential(queryString: qs)
        #expect(cred != nil)
        #expect(cred?.token == "T")
        #expect(cred?.secret == "S")
        #expect(cred?.verifier == "V")
    }

    @Test func initWithInvalidQueryString() {
        #expect(CDOAuth1Credential(queryString: "") == nil)
        #expect(CDOAuth1Credential(queryString: "oauth_token=T") == nil) // missing secret
    }

    @Test func isExpiredWhenPastDate() {
        let past = Date(timeIntervalSinceNow: -1)
        let cred = CDOAuth1Credential(token: "t", secret: "s", expiration: past)
        #expect(cred.isExpired == true)
    }

    @Test func isNotExpiredWhenFutureDate() {
        let future = Date(timeIntervalSinceNow: 3600)
        let cred = CDOAuth1Credential(token: "t", secret: "s", expiration: future)
        #expect(cred.isExpired == false)
    }

    @Test func isNotExpiredWhenNoExpiration() {
        let cred = CDOAuth1Credential(token: "t", secret: "s")
        #expect(cred.isExpired == false)
    }

    @Test func codableRoundTrip() throws {
        let cred = CDOAuth1Credential(token: "t", secret: "s", expiration: Date())
        let data = try JSONEncoder().encode(cred)
        let decoded = try JSONDecoder().decode(CDOAuth1Credential.self, from: data)
        #expect(decoded == cred)
    }

    @Test func userInfoPopulatedFromExtraQueryParams() {
        let qs = "oauth_token=T&oauth_token_secret=S&oauth_session_handle=H"
        let cred = CDOAuth1Credential(queryString: qs)
        #expect(cred?.userInfo?["oauth_session_handle"] == "H")
    }
}
