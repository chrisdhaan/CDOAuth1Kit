//
//  CDOAuth1CacheConfiguration.swift
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

/// Configures optional in-memory response caching for GET requests made via
/// ``CDOAuth1SessionManager/request(path:method:parameters:)``.
///
/// Caching only ever applies to `GET` requests, keyed on the request's resolved URL
/// (path plus query parameters) — set ``CDOAuth1SessionManager/cacheConfiguration`` to
/// opt in; leave it `nil` (the default) to never cache.
public struct CDOAuth1CacheConfiguration: Sendable {

    /// How long a cached response remains valid, in seconds.
    public var ttl: TimeInterval

    /// The maximum number of cached responses retained at once. When a new entry would
    /// exceed this limit, the oldest entry (by insertion time) is evicted first.
    public var maxEntries: Int

    /// Creates a cache configuration.
    /// - Parameters:
    ///   - ttl: How long a cached response remains valid, in seconds.
    ///   - maxEntries: The maximum number of cached responses retained at once.
    public init(ttl: TimeInterval = 60, maxEntries: Int = 50) {
        self.ttl = ttl
        self.maxEntries = maxEntries
    }
}
