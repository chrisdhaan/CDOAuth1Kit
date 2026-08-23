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
import Security
import Testing
@testable import CDOAuth1Kit

struct CDOAuth1RequestSignerTests {

    private func makeRSAKeyPair() throws -> (privateKey: SecKey, publicKey: SecKey) {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw try #require(error?.takeRetainedValue())
        }
        let publicKey = try #require(SecKeyCopyPublicKey(privateKey))
        return (privateKey, publicKey)
    }

    private func makeECPrivateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw try #require(error?.takeRetainedValue())
        }
        return privateKey
    }

    /// RFC 5849 Appendix A.1 — initiate request (request token phase)
    /// Consumer credentials from Appendix A: key=dpf43f3p2l4k3l03, secret=kd94hf93k423kf44
    /// Signing key: kd94hf93k423kf44& (empty token secret for request token phase)
    /// https://tools.ietf.org/html/rfc5849#appendix-A
    @Test func rfc5849SignatureTestVector() throws {
        let signer = CDOAuth1RequestSigner(
            service: "photos.example.net",
            consumerKey: "dpf43f3p2l4k3l03",
            consumerSecret: "kd94hf93k423kf44"
        )
        let baseString = "POST&https%3A%2F%2Fphotos.example.net%2Finitiate&oauth_callback%3Doob%26oauth_consumer_key%3Ddpf43f3p2l4k3l03%26oauth_nonce%3DwnnvGrqVeYPSIXXI%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D137131200%26oauth_version%3D1.0"
        let signingKey = "kd94hf93k423kf44&" // consumerSecret& (empty token secret)
        let signature = try signer.hmacSHA1(message: baseString, key: signingKey)
        #expect(signature == "hBCGVQEI0x4L1D8ZjGU0hIhig2k=")
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
        var request = try URLRequest(url: #require(URL(string: "https://api.example.com/endpoint")))
        request.httpMethod = "GET"
        let signed = try signer.signed(request)
        let authHeader = signed.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader?.hasPrefix("OAuth ") == true)
    }

    // MARK: - PLAINTEXT

    @Test func plaintextOauthParametersUsePlaintextMethod() {
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "key",
                                           consumerSecret: "secret",
                                           signingMethod: .plaintext)
        #expect(signer.oauthParameters()["oauth_signature_method"] == "PLAINTEXT")
    }

    @Test func plaintextSignatureIsConsumerSecretAmpersandTokenSecret() throws {
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "ck",
                                           consumerSecret: "cs&ecret",
                                           signingMethod: .plaintext)
        var request = try URLRequest(url: #require(URL(string: "https://api.example.com/endpoint")))
        request.httpMethod = "GET"
        let signed = try signer.signed(request)
        let authHeader = try #require(signed.value(forHTTPHeaderField: "Authorization"))

        let signatureField = try #require(
            authHeader.components(separatedBy: ", ").first { $0.hasPrefix("oauth_signature=") }
        )
        let encodedSignature = signatureField
            .replacingOccurrences(of: "oauth_signature=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
        let rawSignature = try #require(encodedSignature.removingPercentEncoding)

        #expect(rawSignature == "cs%26ecret&")
    }

    // MARK: - RSA-SHA1

    @Test func rsaSHA1OauthParametersUseRSAMethod() throws {
        let (privateKey, _) = try makeRSAKeyPair()
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "key",
                                           consumerSecret: "secret",
                                           signingMethod: .rsaSHA1(privateKey: privateKey))
        #expect(signer.oauthParameters()["oauth_signature_method"] == "RSA-SHA1")
    }

    @Test func rsaSHA1SignatureVerifiesAgainstPublicKey() throws {
        let (privateKey, publicKey) = try makeRSAKeyPair()
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "ck",
                                           consumerSecret: "cs",
                                           signingMethod: .rsaSHA1(privateKey: privateKey))
        var request = try URLRequest(url: #require(URL(string: "https://api.example.com/endpoint")))
        request.httpMethod = "GET"
        let signed = try signer.signed(request)
        let authHeader = try #require(signed.value(forHTTPHeaderField: "Authorization"))

        let signatureField = try #require(
            authHeader
                .components(separatedBy: ", ")
                .first { $0.hasPrefix("oauth_signature=") }
        )
        let encodedSignature = signatureField
            .replacingOccurrences(of: "oauth_signature=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
        let percentDecoded = try #require(encodedSignature.removingPercentEncoding)
        let signatureData = try #require(Data(base64Encoded: percentDecoded))

        // Re-derive the base string from the produced Authorization header's own
        // oauth_ params (mirrors the construction `signed(_:)` used internally).
        let headerParams = Dictionary(uniqueKeysWithValues: authHeader
            .replacingOccurrences(of: "OAuth ", with: "")
            .components(separatedBy: ", ")
            .compactMap { component -> (String, String)? in
                let parts = component.components(separatedBy: "=\"")
                guard parts.count == 2 else { return nil }
                let value = String(parts[1].dropLast())
                return (parts[0], value.removingPercentEncoding ?? value)
            })
        var signingParams = headerParams
        signingParams.removeValue(forKey: "oauth_signature")
        let baseStringParams = signingParams
            .sorted { $0.key < $1.key }
            .map { "\($0.key.oauthPercentEncoded())=\($0.value.oauthPercentEncoded())" }
            .joined(separator: "&")
            .oauthPercentEncoded()
        let baseString = "GET&\(request.url!.absoluteString.oauthPercentEncoded())&\(baseStringParams)"
        let messageData = Data(baseString.utf8)

        var error: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA1,
            messageData as CFData,
            signatureData as CFData,
            &error
        )
        #expect(error == nil)
        #expect(isValid)
    }

    @Test func rsaSHA1WithWrongKeyTypeThrowsSigningFailed() throws {
        let wrongTypeKey = try makeECPrivateKey()
        let signer = CDOAuth1RequestSigner(service: "test",
                                           consumerKey: "ck",
                                           consumerSecret: "cs",
                                           signingMethod: .rsaSHA1(privateKey: wrongTypeKey))
        var request = try URLRequest(url: #require(URL(string: "https://api.example.com/endpoint")))
        request.httpMethod = "GET"

        do {
            _ = try signer.signed(request)
            Issue.record("Expected signing with a mismatched key type to throw")
        } catch let CDOAuth1Error.signingFailed(message) {
            #expect(!message.isEmpty)
        } catch {
            Issue.record("Expected .signingFailed, got \(error)")
        }
    }
}
