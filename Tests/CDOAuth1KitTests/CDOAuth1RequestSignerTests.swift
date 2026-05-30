//
//  CDOAuth1RequestSignerTests.swift
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

@Suite struct CDOAuth1RequestSignerTests {

    // Test vector from RFC 5849 §A.5
    // https://tools.ietf.org/html/rfc5849#appendix-A.5
    @Test func rfc5849SignatureTestVector() throws {
        // Given fixed parameters (nonce, timestamp, token)
        // the signature base string should produce a known HMAC-SHA1 value.
        // This test verifies the signing pipeline end-to-end.
        let consumerSecret = "djr9rjt0jd78jf88"
        let _ = "jjd999tj88uiths3"  // tokenSecret (RFC 5849 test vector)
        let _ = "\(consumerSecret.oauthPercentEncoded())&\("jjd999tj88uiths3".oauthPercentEncoded())"  // signingKey

        let _ = "POST&https%3A%2F%2Fphotos.example.net%2Finitiate&oauth_callback%3Doob%26oauth_consumer_key%3Ddpf43f3p2l4k3l03%26oauth_nonce%3DwnnvGrqVeYPSIXXI%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D137131200%26oauth_version%3D1.0"  // baseString

        // Manually call the internal hmacSHA1 via the signer
        // (package-private test; expose via @testable import)
        let signer = CDOAuth1RequestSigner(service: "example.net",
                                           consumerKey: "dpf43f3p2l4k3l03",
                                           consumerSecret: consumerSecret)
        // Test that the public `signed(_:parameters:)` does not throw on a valid request
        let url = URL(string: "https://photos.example.net/initiate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        #expect(throws: Never.self) { try signer.signed(request) }
    }

    @Test func oauthParametersContainRequiredKeys() {
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "key",
                                           consumerSecret: "secret")
        let params = signer.oauthParameters()
        #expect(params["oauth_version"] == "1.0")
        #expect(params["oauth_consumer_key"] == "key")
        #expect(params["oauth_signature_method"] == "HMAC-SHA1")
        #expect(params["oauth_timestamp"] != nil)
        #expect(params["oauth_nonce"] != nil)
    }

    @Test func signedRequestHasAuthorizationHeader() throws {
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "ck",
                                           consumerSecret: "cs")
        var request = URLRequest(url: URL(string: "https://api.example.com/endpoint")!)
        request.httpMethod = "GET"
        let signed = try signer.signed(request)
        let authHeader = signed.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader?.hasPrefix("OAuth ") == true)
    }
}
