//
//  CDOAuth1SessionManagerPublisherTests.swift
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

import Combine
import Foundation
import Testing
@testable import CDOAuth1Kit

@Suite(.serialized)
struct CDOAuth1SessionManagerPublisherTests {

    @Test func fetchRequestTokenPublisherSucceedsOn200() async throws {
        PublisherStubURLProtocol.statusCode = 200
        PublisherStubURLProtocol.responseBody = "oauth_token=abc&oauth_token_secret=def"
        PublisherStubURLProtocol.error = nil

        let manager = try makeManager()

        let credential = try await awaitFirst(
            from: manager.fetchRequestTokenPublisher(
                path: "request_token",
                method: "POST",
                callbackURL: #require(URL(string: "myapp://callback"))
            )
        )

        #expect(credential.token == "abc")
    }

    @Test func fetchRequestTokenPublisherFailsOnNon2xx() async throws {
        PublisherStubURLProtocol.statusCode = 500
        PublisherStubURLProtocol.responseBody = ""
        PublisherStubURLProtocol.error = nil

        let manager = try makeManager()

        do {
            _ = try await awaitFirst(
                from: manager.fetchRequestTokenPublisher(
                    path: "request_token",
                    method: "POST",
                    callbackURL: #require(URL(string: "myapp://callback"))
                )
            )
            Issue.record("Expected fetchRequestTokenPublisher to fail")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == 500)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func fetchAccessTokenPublisherSucceedsOn200() async throws {
        PublisherStubURLProtocol.statusCode = 200
        PublisherStubURLProtocol.responseBody = "oauth_token=access-tok&oauth_token_secret=access-sec"
        PublisherStubURLProtocol.error = nil

        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        var requestToken = CDOAuth1Credential(token: "req-token", secret: "req-secret")
        requestToken.verifier = "verifier"

        let credential = try await awaitFirst(
            from: manager.fetchAccessTokenPublisher(
                path: "access_token",
                method: "POST",
                requestToken: requestToken
            )
        )

        #expect(credential.token == "access-tok")
    }

    @Test func fetchAccessTokenPublisherFailsOnNon2xx() async throws {
        PublisherStubURLProtocol.statusCode = 500
        PublisherStubURLProtocol.responseBody = ""
        PublisherStubURLProtocol.error = nil

        let manager = try makeManager()
        var requestToken = CDOAuth1Credential(token: "req-token", secret: "req-secret")
        requestToken.verifier = "verifier"

        do {
            _ = try await awaitFirst(
                from: manager.fetchAccessTokenPublisher(
                    path: "access_token",
                    method: "POST",
                    requestToken: requestToken
                )
            )
            Issue.record("Expected fetchAccessTokenPublisher to fail")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == 500)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func refreshAccessTokenPublisherSucceedsOn200() async throws {
        PublisherStubURLProtocol.statusCode = 200
        PublisherStubURLProtocol.responseBody = "oauth_token=refreshed-tok&oauth_token_secret=refreshed-sec"
        PublisherStubURLProtocol.error = nil

        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        let accessToken = CDOAuth1Credential(token: "access-token", secret: "access-secret")

        let credential = try await awaitFirst(
            from: manager.refreshAccessTokenPublisher(
                path: "refresh_token",
                method: "POST",
                accessToken: accessToken
            )
        )

        #expect(credential.token == "refreshed-tok")
    }

    @Test func refreshAccessTokenPublisherFailsOnNon2xx() async throws {
        PublisherStubURLProtocol.statusCode = 401
        PublisherStubURLProtocol.responseBody = ""
        PublisherStubURLProtocol.error = nil

        let manager = try makeManager()
        let accessToken = CDOAuth1Credential(token: "access-token", secret: "access-secret")

        do {
            _ = try await awaitFirst(
                from: manager.refreshAccessTokenPublisher(
                    path: "refresh_token",
                    method: "POST",
                    accessToken: accessToken
                )
            )
            Issue.record("Expected refreshAccessTokenPublisher to fail")
        } catch let CDOAuth1Error.httpError(code, _) {
            #expect(code == 401)
        } catch {
            Issue.record("Expected .httpError, got \(error)")
        }
    }

    @Test func requestPublisherSucceedsWhenAuthorizedOn200() async throws {
        let manager = try makeManager()
        defer { try? manager.deauthorize() }
        try await authorize(manager)

        PublisherStubURLProtocol.statusCode = 200
        PublisherStubURLProtocol.responseBody = "ok"
        PublisherStubURLProtocol.error = nil

        let (data, response) = try await awaitFirst(
            from: manager.requestPublisher(path: "resource", method: "GET")
        )

        #expect(response.statusCode == 200)
        #expect(String(data: data, encoding: .utf8) == "ok")
    }

    /// `Future` alone starts its work eagerly at construction and caches its one result for
    /// every subscriber, silently breaking Combine idioms like `.retry()` that rely on cold,
    /// re-invoked-per-subscription publishers. This proves the wrapper avoids that trap.
    @Test func fetchRequestTokenPublisherInvokesOperationAgainOnResubscription() async throws {
        PublisherStubURLProtocol.statusCode = 200
        PublisherStubURLProtocol.responseBody = "oauth_token=abc&oauth_token_secret=def"
        PublisherStubURLProtocol.error = nil
        PublisherStubURLProtocol.loadCount = 0

        let manager = try makeManager()
        let publisher = try manager.fetchRequestTokenPublisher(
            path: "request_token",
            method: "POST",
            callbackURL: #require(URL(string: "myapp://callback"))
        )

        _ = try await awaitFirst(from: publisher)
        #expect(PublisherStubURLProtocol.loadCount == 1)

        _ = try await awaitFirst(from: publisher)
        #expect(PublisherStubURLProtocol.loadCount == 2)
    }

    @Test func requestPublisherFailsWhenNotAuthorized() async throws {
        let manager = try makeManager()

        do {
            _ = try await awaitFirst(from: manager.requestPublisher(path: "resource", method: "GET"))
            Issue.record("Expected requestPublisher to fail")
        } catch CDOAuth1Error.invalidAccessToken {
            // expected
        } catch {
            Issue.record("Expected .invalidAccessToken, got \(error)")
        }
    }

    private func authorize(_ manager: CDOAuth1SessionManager) async throws {
        PublisherStubURLProtocol.statusCode = 200
        PublisherStubURLProtocol.responseBody = "oauth_token=access-tok&oauth_token_secret=access-sec"
        PublisherStubURLProtocol.error = nil

        var requestToken = CDOAuth1Credential(token: "req-token", secret: "req-secret")
        requestToken.verifier = "verifier"
        _ = try await manager.fetchAccessToken(path: "access_token", method: "POST", requestToken: requestToken)
    }

    private func makeManager() throws -> CDOAuth1SessionManager {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublisherStubURLProtocol.self]
        return try CDOAuth1SessionManager(
            baseURL: #require(URL(string: "https://api-publisher.example.com/")),
            consumerKey: "key",
            consumerSecret: "secret",
            session: URLSession(configuration: configuration)
        )
    }

    /// Bridges a Combine publisher's first emitted value (or failure) back into an `async`
    /// call. `Publisher.values` needs iOS 15/macOS 12, newer than this package's iOS 13/macOS
    /// 10.15 floor, so tests use this hand-rolled bridge instead.
    private func awaitFirst<P: Publisher>(from publisher: P) async throws -> P.Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            var didResume = false
            cancellable = publisher.sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion, !didResume {
                        didResume = true
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                },
                receiveValue: { value in
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            )
        }
    }
}

private final class PublisherStubURLProtocol: URLProtocol, @unchecked Sendable {
    static var statusCode = 200
    static var responseBody = ""
    static var error: URLError?
    static var loadCount = 0

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.loadCount += 1
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responseBody.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
