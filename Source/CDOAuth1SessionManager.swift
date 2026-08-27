//
//  CDOAuth1SessionManager.swift
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

public final class CDOAuth1SessionManager: Sendable {

    public let baseURL: URL
    public let session: URLSession
    let signerBox: CDOAuth1SignerBox
    private let configurationBox = CDOAuth1SessionConfigurationBox()
    private let responseCacheBox = CDOAuth1ResponseCacheBox()

    /// A snapshot of the current signer state, read from behind an internal lock so
    /// `CDOAuth1SessionManager` can safely conform to `Sendable`.
    public var requestSigner: CDOAuth1RequestSigner {
        signerBox.read { $0 }
    }

    /// The path used to auto-refresh an expired access token before `request(path:method:parameters:)`.
    /// Set with ``refreshAccessTokenMethod`` to opt in; leave both `nil` for manual refresh.
    public var refreshAccessTokenPath: String? {
        get { configurationBox.read { $0.refreshAccessTokenPath } }
        set { configurationBox.mutate { $0.refreshAccessTokenPath = newValue } }
    }

    /// The HTTP method used alongside ``refreshAccessTokenPath``.
    public var refreshAccessTokenMethod: String? {
        get { configurationBox.read { $0.refreshAccessTokenMethod } }
        set { configurationBox.mutate { $0.refreshAccessTokenMethod = newValue } }
    }

    /// Opt-in automatic retry with exponential backoff for `request(path:method:parameters:)`,
    /// applied only to idempotent methods (`GET`, `HEAD`, `OPTIONS`); `nil` (default) never retries.
    /// Only `.httpError` matching ``CDOAuth1RetryConfiguration/retryableStatusCodes`` is retried.
    public var retryConfiguration: CDOAuth1RetryConfiguration? {
        get { configurationBox.read { $0.retryConfiguration } }
        set { configurationBox.mutate { $0.retryConfiguration = newValue } }
    }

    /// Opt-in in-memory response caching for `request(path:method:parameters:)`, applied
    /// only to `GET` requests; `nil` (default) never caches. Call ``clearResponseCache()``
    /// to invalidate cached entries before their TTL expires.
    public var cacheConfiguration: CDOAuth1CacheConfiguration? {
        get { configurationBox.read { $0.cacheConfiguration } }
        set { configurationBox.mutate { $0.cacheConfiguration = newValue } }
    }

    /// Adapters applied, in order, to each signed outgoing request. Empty by default.
    public var requestAdapters: [any CDOAuth1RequestAdapter] {
        get { configurationBox.read { $0.requestAdapters } }
        set { configurationBox.mutate { $0.requestAdapters = newValue } }
    }

    /// Observers notified of each request's lifecycle. Empty by default.
    public var eventMonitors: [any CDOAuth1EventMonitor] {
        get { configurationBox.read { $0.eventMonitors } }
        set { configurationBox.mutate { $0.eventMonitors = newValue } }
    }

    private static let idempotentMethods: Set<String> = ["GET", "HEAD", "OPTIONS"]

    public var isAuthorized: Bool {
        signerBox.read { signer in
            guard let token = signer.accessToken else { return false }
            return !token.isExpired
        }
    }

    public init(baseURL: URL,
                consumerKey: String,
                consumerSecret: String,
                signingMethod: CDOAuth1SigningMethod = .hmacSHA1,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.signerBox = CDOAuth1SignerBox(signer: CDOAuth1RequestSigner(
            service: baseURL.host ?? baseURL.absoluteString,
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            signingMethod: signingMethod
        ))
    }

    // MARK: - Authorization Status

    public func deauthorize() throws {
        try signerBox.mutate { try $0.removeAccessToken() }
    }

    /// Discards every response cached by ``cacheConfiguration``, forcing the next matching
    /// `GET` request to hit the network regardless of TTL.
    public func clearResponseCache() {
        responseCacheBox.removeAll()
    }

    // MARK: - Authenticated Requests

    /// Makes a signed request to the given path using the current access token.
    ///
    /// When ``cacheConfiguration`` is set and `method` is `GET`, a request matching a live
    /// (unexpired) cached entry for the same path and parameters returns that entry without
    /// touching the network; a successful response is cached afterward. Call
    /// ``clearResponseCache()`` to invalidate cached entries early.
    ///
    /// - Parameters:
    ///   - path: A path relative to `baseURL`.
    ///   - method: The HTTP method (e.g. `"GET"`, `"POST"`).
    ///   - parameters: Additional parameters to sign and send. For `GET`/`HEAD`/`DELETE`
    ///     these are appended to the URL as query items; for other methods they're sent as
    ///     an `application/x-www-form-urlencoded` body. Either way they're included in the
    ///     OAuth signature.
    /// - Returns: The response body and the `HTTPURLResponse`.
    /// - Throws: `CDOAuth1Error.invalidAccessToken` if not authorized (or the access token
    ///   is expired and ``refreshAccessTokenPath``/``refreshAccessTokenMethod`` aren't set),
    ///   whatever error the auto-refresh attempt throws, `.httpError` for a non-2xx response
    ///   (after exhausting any retries configured via ``retryConfiguration``), or
    ///   `.networkError` if the underlying request fails.
    public func request(path: String,
                        method: String,
                        parameters: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        guard let token = requestSigner.accessToken else {
            throw CDOAuth1Error.invalidAccessToken
        }
        if token.isExpired {
            guard let refreshPath = refreshAccessTokenPath,
                  let refreshMethod = refreshAccessTokenMethod else {
                throw CDOAuth1Error.invalidAccessToken
            }
            _ = try await refreshAccessToken(path: refreshPath, method: refreshMethod, accessToken: token)
        }

        let isCacheable = method.uppercased() == "GET" && cacheConfiguration != nil
        let cacheKey = isCacheable ? unsignedRequest(path: path, method: method, parameters: parameters).url?.absoluteString : nil

        if let cacheKey, let cached = responseCacheBox.value(forKey: cacheKey) {
            return cached
        }

        let retryConfig = Self.idempotentMethods.contains(method.uppercased()) ? retryConfiguration : nil
        var attempt = 0

        while true {
            let signedRequest = try requestAdapters.adapting(
                requestSigner.signed(unsignedRequest(path: path, method: method, parameters: parameters), parameters: parameters)
            )
            eventMonitors.notifyWillStart(signedRequest)
            do {
                let result = try await performSigned(signedRequest)
                eventMonitors.notifyDidSucceed(signedRequest, response: result.1)
                if let cacheKey, let cacheConfiguration {
                    responseCacheBox.store(
                        result,
                        forKey: cacheKey,
                        ttl: cacheConfiguration.ttl,
                        maxEntries: cacheConfiguration.maxEntries
                    )
                }
                return result
            } catch let error as CDOAuth1Error {
                guard let retryConfig,
                      case let .httpError(statusCode, headers) = error,
                      retryConfig.retryableStatusCodes.contains(statusCode),
                      attempt < retryConfig.maxRetries else {
                    eventMonitors.notifyDidFail(signedRequest, error: error)
                    throw error
                }
                let delay = retryConfig.retryDelay(forAttempt: attempt, responseHeaders: headers)
                eventMonitors.notifyWillRetry(signedRequest, attempt: attempt, delay: delay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
            }
        }
    }

    /// Builds the request for `path`/`method`/`parameters`, before OAuth signing. Used both
    /// to derive the response-cache key (which must stay stable across calls) and as the
    /// input to signing itself.
    private func unsignedRequest(path: String, method: String, parameters: [String: String]) -> URLRequest {
        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request: URLRequest
        switch method.uppercased() {
        case "GET", "HEAD", "DELETE":
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            if !parameters.isEmpty {
                components.queryItems = (components.queryItems ?? []) + parameters.sortedQueryItems()
            }
            request = URLRequest(url: components.url!)
            request.httpMethod = method
        default:
            request = URLRequest(url: url)
            request.httpMethod = method
            if !parameters.isEmpty {
                request.httpBody = Data(parameters.queryStringRepresentation().utf8)
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }
        return request
    }

    // MARK: - Response Validation

    func performSigned(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw CDOAuth1Error.networkError(urlError)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CDOAuth1Error.networkError(URLError(.badServerResponse))
        }
        return try (httpResponse.cdoauth1ValidatedData(data), httpResponse)
    }
}
