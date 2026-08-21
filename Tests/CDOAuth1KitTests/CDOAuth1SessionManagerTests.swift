//
//  CDOAuth1SessionManagerTests.swift
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

struct CDOAuth1SessionManagerTests {

    @Test func initWithBaseURL() throws {
        let baseURL = try #require(URL(string: "https://api.example.com/"))
        let manager = CDOAuth1SessionManager(
            baseURL: baseURL,
            consumerKey: "key",
            consumerSecret: "secret"
        )
        #expect(manager.baseURL == baseURL)
        #expect(manager.isAuthorized == false)
    }

    @Test func fetchRequestTokenThrowsDecodingFailedOnMalformedResponse() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com/"))
        let callbackURL = try #require(URL(string: "myapp://callback"))
        MalformedResponseURLProtocol.responseBody = "not=a&valid=credential"

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MalformedResponseURLProtocol.self]
        let manager = CDOAuth1SessionManager(
            baseURL: baseURL,
            consumerKey: "key",
            consumerSecret: "secret",
            session: URLSession(configuration: configuration)
        )

        do {
            _ = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: callbackURL
            )
            Issue.record("Expected fetchRequestToken to throw")
        } catch CDOAuth1Error.decodingFailed {
            // expected
        } catch {
            Issue.record("Expected .decodingFailed, got \(error)")
        }
    }
}

private final class MalformedResponseURLProtocol: URLProtocol, @unchecked Sendable {
    static var responseBody = ""

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responseBody.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
