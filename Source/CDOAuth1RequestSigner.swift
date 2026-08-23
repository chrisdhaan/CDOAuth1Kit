//
//  CDOAuth1RequestSigner.swift
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

import CryptoKit
import Foundation
import Security

public struct CDOAuth1RequestSigner {

    public let service: String
    public let consumerKey: String
    public let consumerSecret: String
    public let signingMethod: CDOAuth1SigningMethod

    public var requestToken: CDOAuth1Credential?
    public private(set) var accessToken: CDOAuth1Credential?

    public init(service: String,
                consumerKey: String,
                consumerSecret: String,
                signingMethod: CDOAuth1SigningMethod = .hmacSHA1) {
        self.service = service
        self.consumerKey = consumerKey
        self.consumerSecret = consumerSecret
        self.signingMethod = signingMethod
        self.accessToken = KeychainStore.read(service: service)
    }

    // MARK: - Keychain

    public mutating func saveAccessToken(_ token: CDOAuth1Credential) throws {
        try KeychainStore.write(token, service: service)
        self.accessToken = token
    }

    public mutating func removeAccessToken() throws {
        try KeychainStore.delete(service: service)
        self.accessToken = nil
    }

    // MARK: - OAuth Parameters

    public func oauthParameters() -> [String: String] {
        var params: [String: String] = [:]
        params["oauth_version"] = "1.0"
        params["oauth_consumer_key"] = consumerKey
        params["oauth_timestamp"] = String(Int(Date().timeIntervalSince1970))
        params["oauth_signature_method"] = signingMethod.rfc5849Name
        params["oauth_nonce"] = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return params
    }

    // MARK: - Request Signing

    /// Produces a signed copy of the given URLRequest, adding an OAuth Authorization header.
    public func signed(_ request: URLRequest,
                       parameters: [String: String] = [:]) throws -> URLRequest {
        guard let method = request.httpMethod,
              let urlString = request.url?.absoluteString else {
            throw CDOAuth1Error.invalidRequestToken
        }

        var authParams = oauthParameters()
        if let token = (accessToken ?? requestToken)?.token {
            authParams["oauth_token"] = token
        }
        for (key, value) in parameters where key.hasPrefix("oauth_") {
            authParams[key] = value
        }

        let allParams = authParams.merging(parameters) { $1 }
        authParams["oauth_signature"] = try signature(
            method: method,
            urlString: urlString,
            parameters: allParams
        )

        var signed = request
        signed.setValue(authorizationHeader(from: authParams), forHTTPHeaderField: "Authorization")
        signed.httpShouldHandleCookies = false
        return signed
    }

    // MARK: - Private

    private func signature(method: String,
                           urlString: String,
                           parameters: [String: String]) throws -> String {
        let tokenSecret = (accessToken ?? requestToken)?.secret ?? ""

        switch signingMethod {
        case .hmacSHA1:
            let baseString = signatureBaseString(method: method, urlString: urlString, parameters: parameters)
            let signingKey = "\(consumerSecret.oauthPercentEncoded())&\(tokenSecret.oauthPercentEncoded())"
            return try hmacSHA1(message: baseString, key: signingKey)
        case let .rsaSHA1(privateKey):
            let baseString = signatureBaseString(method: method, urlString: urlString, parameters: parameters)
            return try rsaSHA1(message: baseString, privateKey: privateKey)
        case .plaintext:
            return "\(consumerSecret.oauthPercentEncoded())&\(tokenSecret.oauthPercentEncoded())"
        }
    }

    private func signatureBaseString(method: String,
                                     urlString: String,
                                     parameters: [String: String]) -> String {
        let baseURL = urlString.components(separatedBy: "?")[0].oauthPercentEncoded()
        let sortedParams = parameters.sorted { $0.key < $1.key }
        let paramString = sortedParams
            .map { "\($0.key.oauthPercentEncoded())=\($0.value.oauthPercentEncoded())" }
            .joined(separator: "&")
            .oauthPercentEncoded()

        return "\(method.uppercased())&\(baseURL)&\(paramString)"
    }

    func hmacSHA1(message: String, key: String) throws -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(message.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: symmetricKey)
        return Data(mac).base64EncodedString()
    }

    private func rsaSHA1(message: String, privateKey: SecKey) throws -> String {
        let messageData = Data(message.utf8)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA1,
            messageData as CFData,
            &error
        ) as Data? else {
            let description = error?.takeRetainedValue().localizedDescription ?? "unknown error"
            throw CDOAuth1Error.signingFailed(description)
        }
        return signature.base64EncodedString()
    }

    private func authorizationHeader(from params: [String: String]) -> String {
        let components = params
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { "\($0.key)=\"\($0.value.oauthPercentEncoded())\"" }
            .joined(separator: ", ")
        return "OAuth \(components)"
    }
}
