//
//  CDOAuth1SigningMethod.swift
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

@preconcurrency import Security

/// The RFC 5849 §3.4 signature method used to sign OAuth 1.0a requests.
///
/// `SecKey` isn't `Sendable`-audited by the Security framework, but its underlying
/// Keychain/CF object is safe to read from and pass across threads, so this enum's
/// conformance is safe despite requiring `@preconcurrency import Security` above.
public enum CDOAuth1SigningMethod: Sendable {
    /// HMAC-SHA1 (RFC 5849 §3.4.2) — the default, and the only method supported by most providers.
    case hmacSHA1

    /// RSA-SHA1 (RFC 5849 §3.4.3), signed with the consumer's RSA private key.
    case rsaSHA1(privateKey: SecKey)

    /// PLAINTEXT (RFC 5849 §3.4.4) — sends the signing key unhashed. Only safe over HTTPS.
    case plaintext

    var rfc5849Name: String {
        switch self {
        case .hmacSHA1: "HMAC-SHA1"
        case .rsaSHA1: "RSA-SHA1"
        case .plaintext: "PLAINTEXT"
        }
    }
}
