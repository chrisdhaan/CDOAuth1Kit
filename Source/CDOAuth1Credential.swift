//
//  CDOAuth1Credential.swift
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

public struct CDOAuth1Credential: Codable, Sendable, Equatable {

    public let token: String
    public let secret: String
    public var verifier: String?
    public var expiration: Date?
    public var userInfo: [String: String]?

    public var isExpired: Bool {
        guard let expiration else { return false }
        return expiration < Date()
    }

    public init(token: String,
                secret: String,
                expiration: Date? = nil) {
        self.token = token
        self.secret = secret
        self.expiration = expiration
    }

    public init?(queryString: String) {
        let params = [String: String](queryString: queryString)
        guard let token = params["oauth_token"],
              let secret = params["oauth_token_secret"] else {
            return nil
        }
        self.token = token
        self.secret = secret
        self.verifier = params["oauth_verifier"]
        if let duration = params["oauth_token_duration"].flatMap(Double.init) {
            self.expiration = Date(timeIntervalSinceNow: duration)
        }
        var info = params
        ["oauth_token", "oauth_token_secret", "oauth_verifier", "oauth_token_duration"]
            .forEach { info.removeValue(forKey: $0) }
        self.userInfo = info.isEmpty ? nil : info
    }
}
