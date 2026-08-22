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

@Suite(.serialized)
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
        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "not=a&valid=credential"
        StubURLProtocol.error = nil

        let manager = try makeManager()

        do {
            _ = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: #require(URL(string: "myapp://callback"))
            )
            Issue.record("Expected fetchRequestToken to throw")
        } catch CDOAuth1Error.decodingFailed {
            // expected
        } catch {
            Issue.record("Expected .decodingFailed, got \(error)")
        }
    }

    @Test func fetchRequestTokenSucceedsOn200() async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "oauth_token=abc&oauth_token_secret=def"
        StubURLProtocol.error = nil

        let manager = try makeManager()

        let credential = try await manager.fetchRequestToken(
            path: "request_token",
            method: "POST",
            callbackURL: #require(URL(string: "myapp://callback"))
        )

        #expect(credential.token == "abc")
    }

    @Test(arguments: [401, 403, 500, 503])
    func fetchRequestTokenThrowsHTTPErrorOnNon2xx(statusCode: Int) async throws {
        StubURLProtocol.statusCode = statusCode
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = nil

        let manager = try makeManager()

        do {
            _ = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: #require(URL(string: "myapp://callback"))
            )
            Issue.record("Expected fetchRequestToken to throw")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == statusCode)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func fetchRequestTokenHTTPErrorCarriesRetryAfterHeader() async throws {
        StubURLProtocol.statusCode = 429
        StubURLProtocol.headers = ["Retry-After": "120"]
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = nil

        let manager = try makeManager()

        do {
            _ = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: #require(URL(string: "myapp://callback"))
            )
            Issue.record("Expected fetchRequestToken to throw")
        } catch let CDOAuth1Error.httpError(code, headers) {
            #expect(code == 429)
            #expect(headers["Retry-After"] == "120")
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func fetchRequestTokenHTTPErrorCanonicalizesLowercaseHeaderName() async throws {
        StubURLProtocol.statusCode = 429
        StubURLProtocol.headers = ["retry-after": "120"]
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = nil

        let manager = try makeManager()

        do {
            _ = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: #require(URL(string: "myapp://callback"))
            )
            Issue.record("Expected fetchRequestToken to throw")
        } catch let CDOAuth1Error.httpError(_, headers) {
            #expect(headers["Retry-After"] == "120")
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func fetchAccessTokenThrowsHTTPErrorOnNon2xx() async throws {
        StubURLProtocol.statusCode = 500
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = nil

        let manager = try makeManager()
        let requestToken = CDOAuth1Credential(token: "req-token", secret: "req-secret")
        var tokenWithVerifier = requestToken
        tokenWithVerifier.verifier = "verifier"

        do {
            _ = try await manager.fetchAccessToken(
                path: "access_token",
                method: "POST",
                requestToken: tokenWithVerifier
            )
            Issue.record("Expected fetchAccessToken to throw")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == 500)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func refreshAccessTokenThrowsHTTPErrorOnNon2xx() async throws {
        StubURLProtocol.statusCode = 401
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = nil

        let manager = try makeManager()
        let accessToken = CDOAuth1Credential(token: "access-token", secret: "access-secret")

        do {
            _ = try await manager.refreshAccessToken(
                path: "refresh_token",
                method: "POST",
                accessToken: accessToken
            )
            Issue.record("Expected refreshAccessToken to throw")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == 401)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func fetchRequestTokenThrowsNetworkErrorWhenUnreachable() async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = URLError(.notConnectedToInternet)

        let manager = try makeManager()

        do {
            _ = try await manager.fetchRequestToken(
                path: "request_token",
                method: "POST",
                callbackURL: #require(URL(string: "myapp://callback"))
            )
            Issue.record("Expected fetchRequestToken to throw")
        } catch let CDOAuth1Error.networkError(underlying) {
            #expect(underlying.code == .notConnectedToInternet)
        } catch {
            Issue.record("Expected .networkError, got \(error)")
        }
    }

    @Test func requestThrowsInvalidAccessTokenWhenNotAuthorized() async throws {
        let manager = try makeManager()

        do {
            _ = try await manager.request(path: "resource", method: "GET")
            Issue.record("Expected request to throw")
        } catch CDOAuth1Error.invalidAccessToken {
            // expected
        } catch {
            Issue.record("Expected .invalidAccessToken, got \(error)")
        }
    }

    @Test func requestSucceedsWhenAuthorizedOn200() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorize(manager)

        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "ok"
        StubURLProtocol.error = nil

        let (data, response) = try await manager.request(path: "resource", method: "GET")

        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    @Test(arguments: [401, 500])
    func requestThrowsHTTPErrorOnNon2xx(statusCode: Int) async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorize(manager)

        StubURLProtocol.statusCode = statusCode
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = nil

        do {
            _ = try await manager.request(path: "resource", method: "GET")
            Issue.record("Expected request to throw")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == statusCode)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func requestThrowsNetworkErrorWhenUnreachable() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorize(manager)

        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = URLError(.notConnectedToInternet)

        do {
            _ = try await manager.request(path: "resource", method: "GET")
            Issue.record("Expected request to throw")
        } catch let CDOAuth1Error.networkError(underlying) {
            #expect(underlying.code == .notConnectedToInternet)
        } catch {
            Issue.record("Expected .networkError, got \(error)")
        }
    }

    @Test func requestAutoRefreshesExpiredTokenWhenRefreshConfigured() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorizeExpired(manager)

        manager.refreshAccessTokenPath = "refresh_token"
        manager.refreshAccessTokenMethod = "POST"

        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "oauth_token=refreshed-tok&oauth_token_secret=refreshed-sec"
        StubURLProtocol.error = nil
        StubURLProtocol.lastRequest = nil

        let (data, response) = try await manager.request(path: "resource", method: "GET")

        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "oauth_token=refreshed-tok&oauth_token_secret=refreshed-sec")

        let sentRequest = try #require(StubURLProtocol.lastRequest)
        let authHeader = try #require(sentRequest.value(forHTTPHeaderField: "Authorization"))
        #expect(authHeader.contains("oauth_token=\"refreshed-tok\""))
    }

    @Test func requestThrowsInvalidAccessTokenWhenExpiredAndRefreshNotConfigured() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorizeExpired(manager)

        do {
            _ = try await manager.request(path: "resource", method: "GET")
            Issue.record("Expected request to throw")
        } catch CDOAuth1Error.invalidAccessToken {
            // expected
        } catch {
            Issue.record("Expected .invalidAccessToken, got \(error)")
        }
    }

    @Test func requestPropagatesErrorWhenRefreshFails() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorizeExpired(manager)

        manager.refreshAccessTokenPath = "refresh_token"
        manager.refreshAccessTokenMethod = "POST"

        StubURLProtocol.statusCode = 401
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = ""
        StubURLProtocol.error = nil

        do {
            _ = try await manager.request(path: "resource", method: "GET")
            Issue.record("Expected request to throw")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == 401)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func requestSignsGivenParametersIntoAuthorizationHeader() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorize(manager)

        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "ok"
        StubURLProtocol.error = nil
        StubURLProtocol.lastRequest = nil

        _ = try await manager.request(path: "resource", method: "GET", parameters: ["foo": "bar"])

        let sentRequest = try #require(StubURLProtocol.lastRequest)
        let authHeader = try #require(sentRequest.value(forHTTPHeaderField: "Authorization"))
        var authParams = parseOAuthAuthorizationHeader(authHeader)
        let removedSignature = authParams.removeValue(forKey: "oauth_signature")
        let actualSignature = try #require(removedSignature)

        #expect(authParams["oauth_token"] == "access-tok")

        authParams["foo"] = "bar"
        let paramString = authParams
            .sorted { $0.key < $1.key }
            .map { "\($0.key.oauthPercentEncoded())=\($0.value.oauthPercentEncoded())" }
            .joined(separator: "&")
            .oauthPercentEncoded()
        let encodedURL = "https://api.example.com/resource".oauthPercentEncoded()
        let baseString = "GET&\(encodedURL)&\(paramString)"
        let signingKey = "secret".oauthPercentEncoded() + "&" + "access-sec".oauthPercentEncoded()

        let signer = CDOAuth1RequestSigner(service: "unused", consumerKey: "key", consumerSecret: "secret")
        let expectedSignature = try signer.hmacSHA1(message: baseString, key: signingKey)

        #expect(actualSignature == expectedSignature)
    }

    @Test func requestEncodesParametersAsFormBodyForPOST() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorize(manager)

        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "ok"
        StubURLProtocol.error = nil
        StubURLProtocol.lastRequest = nil

        _ = try await manager.request(path: "resource", method: "POST", parameters: ["foo": "bar", "baz": "qux"])

        let sentRequest = try #require(StubURLProtocol.lastRequest)

        #expect(sentRequest.url?.absoluteString == "https://api.example.com/resource")
        #expect(sentRequest.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")

        let body = try #require(readBody(from: sentRequest))
        #expect(String(data: body, encoding: .utf8) == "baz=qux&foo=bar")
    }

    /// `URLSession` moves `httpBody` into `httpBodyStream` for requests dispatched to a
    /// custom `URLProtocol`, so the body must be read back from the stream in tests.
    private func readBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 {
                break
            }
            data.append(buffer, count: read)
        }
        return data
    }

    private func parseOAuthAuthorizationHeader(_ header: String) -> [String: String] {
        var result: [String: String] = [:]
        let content = header.hasPrefix("OAuth ") ? String(header.dropFirst("OAuth ".count)) : header
        for pair in content.components(separatedBy: ", ") {
            guard let separatorIndex = pair.firstIndex(of: "=") else { continue }
            let key = String(pair[pair.startIndex ..< separatorIndex])
            var value = String(pair[pair.index(after: separatorIndex)...])
            if value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value.oauthPercentDecoded()
        }
        return result
    }

    private func authorize(_ manager: CDOAuth1SessionManager) async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "oauth_token=access-tok&oauth_token_secret=access-sec"
        StubURLProtocol.error = nil

        var requestToken = CDOAuth1Credential(token: "req-token", secret: "req-secret")
        requestToken.verifier = "verifier"
        _ = try await manager.fetchAccessToken(path: "access_token", method: "POST", requestToken: requestToken)
    }

    private func authorizeExpired(_ manager: CDOAuth1SessionManager) async throws {
        StubURLProtocol.statusCode = 200
        StubURLProtocol.headers = nil
        StubURLProtocol.responseBody = "oauth_token=access-tok&oauth_token_secret=access-sec&oauth_token_duration=-100"
        StubURLProtocol.error = nil

        var requestToken = CDOAuth1Credential(token: "req-token", secret: "req-secret")
        requestToken.verifier = "verifier"
        _ = try await manager.fetchAccessToken(path: "access_token", method: "POST", requestToken: requestToken)
    }

    private func makeManager() throws -> CDOAuth1SessionManager {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return try CDOAuth1SessionManager(
            baseURL: #require(URL(string: "https://api.example.com/")),
            consumerKey: "key",
            consumerSecret: "secret",
            session: URLSession(configuration: configuration)
        )
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static var statusCode = 200
    static var headers: [String: String]?
    static var responseBody = ""
    static var error: URLError?
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: Self.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responseBody.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
