//
//  CDOAuth1MockURLProtocol.swift
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

/// A `URLProtocol` stub for mocking `CDOAuth1Kit` network calls in a test suite, without
/// hitting the network.
///
/// Register it on a `URLSession` used to construct a `CDOAuth1SessionManager` under test:
/// ```swift
/// let configuration = URLSessionConfiguration.ephemeral
/// configuration.protocolClasses = [CDOAuth1MockURLProtocol.self]
/// let manager = try CDOAuth1SessionManager(
///     baseURL: URL(string: "https://api.example.com/")!,
///     consumerKey: "key",
///     consumerSecret: "secret",
///     session: URLSession(configuration: configuration)
/// )
///
/// CDOAuth1MockURLProtocol.statusCode = 200
/// CDOAuth1MockURLProtocol.responseBody = "oauth_token=abc&oauth_token_secret=def"
/// ```
///
/// All configuration is static, shared process-wide by every request the stub intercepts —
/// a test suite driving concurrent tests against it must serialize (e.g. Swift Testing's
/// `@Suite(.serialized)`) to avoid cross-test interference.
public final class CDOAuth1MockURLProtocol: URLProtocol, @unchecked Sendable {
    /// The HTTP status code returned when ``statusCodeQueue`` is empty.
    public static var statusCode = 200
    /// When non-empty, each intercepted request pops the next status code from the front
    /// of this queue instead of using ``statusCode`` — lets a single test simulate a
    /// transient failure followed by a success across multiple retry attempts.
    public static var statusCodeQueue: [Int] = []
    /// Response headers returned with the stubbed response, if any.
    public static var headers: [String: String]?
    /// The response body returned for the stubbed response.
    public static var responseBody = ""
    /// When set, the intercepted request fails with this error instead of returning a
    /// response.
    public static var error: URLError?
    /// The most recent request the stub intercepted, for asserting on what was sent.
    public static var lastRequest: URLRequest?
    /// The number of requests the stub has intercepted since it was last reset.
    public static var requestCount = 0

    override public static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override public static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        Self.lastRequest = request
        Self.requestCount += 1
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let statusCode = Self.statusCodeQueue.isEmpty ? Self.statusCode : Self.statusCodeQueue.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: Self.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responseBody.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override public func stopLoading() {}
}
