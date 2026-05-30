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

    public var isAuthorized: Bool {
        guard let token = requestSigner.accessToken else { return false }
        return !token.isExpired
    }

    public init(baseURL: URL,
                consumerKey: String,
                consumerSecret: String,
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        self.requestSigner = CDOAuth1RequestSigner(
            service: baseURL.host ?? baseURL.absoluteString,
            consumerKey: consumerKey,
            consumerSecret: consumerSecret
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
        let (data, _) = try await session.data(for: signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.invalidResponse
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
            "oauth_verifier": verifier,
        ]

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try requestSigner.signed(request, parameters: params)
        let (data, _) = try await session.data(for: signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.invalidResponse
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
        let (data, _) = try await session.data(for: signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.invalidResponse
        }

        try requestSigner.saveAccessToken(credential)
        requestSigner.requestToken = nil
        return credential
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
