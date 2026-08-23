//
//  CDOAuth1RetryConfiguration.swift
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

/// Configures automatic retry-with-backoff behavior for
/// ``CDOAuth1SessionManager/request(path:method:parameters:)``.
///
/// Retries only ever apply to idempotent HTTP methods (`GET`, `HEAD`, `OPTIONS`) — set
/// ``CDOAuth1SessionManager/retryConfiguration`` to opt in; leave it `nil` (the default)
/// to never retry.
public struct CDOAuth1RetryConfiguration: Sendable {

    /// The maximum number of retry attempts after the initial request fails.
    public var maxRetries: Int

    /// The delay before the first retry, in seconds. Doubles with each subsequent
    /// attempt (exponential backoff) unless overridden by a `Retry-After` header.
    public var baseDelay: TimeInterval

    /// The maximum delay before any single retry, in seconds, regardless of the
    /// computed exponential backoff or a server-provided `Retry-After` value.
    public var maxDelay: TimeInterval

    /// HTTP status codes considered transient and eligible for retry.
    public var retryableStatusCodes: Set<Int>

    /// When `true`, a `Retry-After` header on the failed response (expressed as an
    /// integer number of seconds) is used as the retry delay instead of the computed
    /// exponential backoff, still capped by ``maxDelay``.
    public var respectRetryAfterHeader: Bool

    /// Creates a retry configuration.
    /// - Parameters:
    ///   - maxRetries: The maximum number of retry attempts after the initial request fails.
    ///   - baseDelay: The delay before the first retry, in seconds.
    ///   - maxDelay: The maximum delay before any single retry, in seconds.
    ///   - retryableStatusCodes: HTTP status codes considered transient and eligible for retry.
    ///   - respectRetryAfterHeader: Whether to honor a `Retry-After` response header over the
    ///     computed backoff delay.
    public init(maxRetries: Int = 3,
                baseDelay: TimeInterval = 0.5,
                maxDelay: TimeInterval = 30,
                retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504],
                respectRetryAfterHeader: Bool = true) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.retryableStatusCodes = retryableStatusCodes
        self.respectRetryAfterHeader = respectRetryAfterHeader
    }

    /// The delay before retry attempt `attempt` (0-indexed). Honors a `Retry-After`
    /// response header when present and ``respectRetryAfterHeader`` is `true`; otherwise
    /// computes `baseDelay * 2^attempt`. Either way, capped at ``maxDelay``.
    func retryDelay(forAttempt attempt: Int, responseHeaders: [String: String]) -> TimeInterval {
        if respectRetryAfterHeader,
           let retryAfter = responseHeaders["Retry-After"],
           let seconds = TimeInterval(retryAfter) {
            return min(max(seconds, 0), maxDelay)
        }
        return min(baseDelay * pow(2, Double(attempt)), maxDelay)
    }
}
