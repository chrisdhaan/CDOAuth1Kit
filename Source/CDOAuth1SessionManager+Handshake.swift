//
//  CDOAuth1SessionManager+Handshake.swift
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

// MARK: - OAuth Handshake

public extension CDOAuth1SessionManager {
    func fetchRequestToken(path: String,
                           method: String,
                           callbackURL: URL,
                           scope: String? = nil) async throws -> CDOAuth1Credential {
        var params: [String: String] = ["oauth_callback": callbackURL.absoluteString]

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try signerBox.mutate { signer -> URLRequest in
            signer.requestToken = nil
            if let scope, signer.accessToken == nil {
                params["scope"] = scope
            }
            return try signer.signed(request, parameters: params)
        }
        let (data, _) = try await performSigned(signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.decodingFailed
        }

        signerBox.mutate { $0.requestToken = credential }
        return credential
    }

    func fetchAccessToken(path: String,
                          method: String,
                          requestToken: CDOAuth1Credential) async throws -> CDOAuth1Credential {
        guard let token = requestToken.token.nilIfEmpty,
              let verifier = requestToken.verifier?.nilIfEmpty else {
            throw CDOAuth1Error.invalidRequestToken
        }

        let params: [String: String] = [
            "oauth_token": token,
            "oauth_verifier": verifier
        ]

        let url = URL(string: path, relativeTo: baseURL)!.absoluteURL
        var request = URLRequest(url: url)
        request.httpMethod = method

        let signedRequest = try signerBox.mutate { signer -> URLRequest in
            signer.requestToken = requestToken
            return try signer.signed(request, parameters: params)
        }
        let (data, _) = try await performSigned(signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.decodingFailed
        }

        try signerBox.mutate {
            try $0.saveAccessToken(credential)
            $0.requestToken = nil
        }
        return credential
    }

    func refreshAccessToken(path: String,
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

        let signedRequest = try signerBox.read { try $0.signed(request, parameters: params) }
        let (data, _) = try await performSigned(signedRequest)
        let queryString = String(data: data, encoding: .utf8) ?? ""

        guard let credential = CDOAuth1Credential(queryString: queryString) else {
            throw CDOAuth1Error.decodingFailed
        }

        try signerBox.mutate {
            try $0.saveAccessToken(credential)
            $0.requestToken = nil
        }
        return credential
    }
}
