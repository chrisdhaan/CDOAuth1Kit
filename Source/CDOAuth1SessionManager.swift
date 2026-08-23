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

public final class CDOAuth1SessionManager {

    public let baseURL: URL
    public let session: URLSession
    public private(set) var requestSigner: CDOAuth1RequestSigner

    /// The path used to auto-refresh an expired access token before an authenticated
    /// `request(path:method:parameters:)` call goes out. Set this together with
    /// ``refreshAccessTokenMethod`` to opt in; leave both `nil` to require callers to
    /// refresh manually.
    public var refreshAccessTokenPath: String?

    /// The HTTP method used alongside ``refreshAccessTokenPath`` to auto-refresh an
    /// expired access token before an authenticated `request(path:method:parameters:)` call.
    public var refreshAccessTokenMethod: String?

    public var isAuthorized: Bool {
        guard let token = requestSigner.accessToken else { return false }
        return !token.isExpired
    }

    public init(baseURL: URL,
                consumerKey: String,
                consumerSecret: String,
                signingMethod: CDOAuth1SigningMethod = .hmacSHA1,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.requestSigner = CDOAuth1RequestSigner(
            service: baseURL.host ?? baseURL.absoluteString,
            consumerKey: consumerKey,
            consumerSecret: consumerSecret,
            signingMethod: signingMethod
        )
    }

    // MARK: - Authorization Status

    public func deauthorize() throws {
        try requestSigner.removeAccessToken()
    }

    // MARK: - OAuth Handshake

    public func fetchRequestToken(path: String,
                                  method: String,
                                  callbackURL: URL,
                                  scope: String? = nil) async throws -> CDOAuth1Credential {
        requestSigner.requestToken = nil

        var params: [String: String] = ["oauth_callback": callbackURL.absoluteString]
        if let scope, requestSigner.accessToken == nil {
            params["scope"] = scope
        }

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try requestSigner.signed(request, parameters: params)
        let (data, _) = try await performSigned(signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.decodingFailed
        }

        requestSigner.requestToken = credential
        return credential
    }

    public func fetchAccessToken(path: String,
                                 method: String,
                                 requestToken: CDOAuth1Credential) async throws -> CDOAuth1Credential {
        guard let token = requestToken.token.nilIfEmpty,
              let verifier = requestToken.verifier?.nilIfEmpty else {
            throw CDOAuth1Error.invalidRequestToken
        }

        requestSigner.requestToken = requestToken

        let params: [String: String] = [
            "oauth_token": token,
            "oauth_verifier": verifier
        ]

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try requestSigner.signed(request, parameters: params)
        let (data, _) = try await performSigned(signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.decodingFailed
        }

        try requestSigner.saveAccessToken(credential)
        requestSigner.requestToken = nil
        return credential
    }

    public func refreshAccessToken(path: String,
                                   parameters: [String: String]? = nil,
                                   method: String,
                                   accessToken: CDOAuth1Credential) async throws -> CDOAuth1Credential {
        guard let token = accessToken.token.nilIfEmpty else {
            throw CDOAuth1Error.invalidAccessToken
        }

        var params: [String: String] = ["oauth_token": token]
        if let extra = parameters {
            params.merge(extra) { $1 }
        }

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try requestSigner.signed(request, parameters: params)
        let (data, _) = try await performSigned(signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.decodingFailed
        }

        try requestSigner.saveAccessToken(credential)
        requestSigner.requestToken = nil
        return credential
    }

    // MARK: - Authenticated Requests

    /// Makes a signed request to the given path using the current access token.
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
    ///   whatever error the auto-refresh attempt throws, `.httpError` for a non-2xx response,
    ///   or `.networkError` if the underlying request fails.
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

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request: URLRequest
        switch method.uppercased() {
        case "GET", "HEAD", "DELETE":
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            if !parameters.isEmpty {
                components.queryItems = (components.queryItems ?? []) + sortedQueryItems(from: parameters)
            }
            request = URLRequest(url: components.url!)
            request.httpMethod = method
        default:
            request = URLRequest(url: url)
            request.httpMethod = method
            if !parameters.isEmpty {
                request.httpBody = Data(formEncodedBody(from: parameters).utf8)
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            }
        }

        let signedRequest = try requestSigner.signed(request, parameters: parameters)
        return try await performSigned(signedRequest)
    }

    private func sortedQueryItems(from parameters: [String: String]) -> [URLQueryItem] {
        parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    private func formEncodedBody(from parameters: [String: String]) -> String {
        parameters.sorted { $0.key < $1.key }
            .map { "\($0.key.oauthPercentEncoded())=\($0.value.oauthPercentEncoded())" }
            .joined(separator: "&")
    }

    // MARK: - Response Validation

    private func performSigned(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw CDOAuth1Error.networkError(urlError)
        }
        let validatedData = try validated(data, response)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CDOAuth1Error.networkError(URLError(.badServerResponse))
        }
        return (validatedData, httpResponse)
    }

    private func validated(_ data: Data, _ response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else { return data }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            var headers: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let key = key as? String, let value = value as? String {
                    headers[canonicalizedHeaderName(key)] = value
                }
            }
            throw CDOAuth1Error.httpError(statusCode: httpResponse.statusCode, headers: headers)
        }
        return data
    }

    /// HTTP header names are case-insensitive over the wire (and HTTP/2 lowercases
    /// them by spec), but `HTTPURLResponse.allHeaderFields` preserves whatever case
    /// the server sent. Normalizing to `Title-Case` here gives callers a predictable
    /// key to look up (e.g. `headers["Retry-After"]`) regardless of server casing.
    private func canonicalizedHeaderName(_ name: String) -> String {
        name.split(separator: "-", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: "-")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
