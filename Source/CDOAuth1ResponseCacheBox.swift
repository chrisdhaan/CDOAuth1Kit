//
//  CDOAuth1ResponseCacheBox.swift
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

/// Serializes access to `CDOAuth1SessionManager`'s optional GET response cache, the same
/// lock-based approach as `CDOAuth1SignerBox` and `CDOAuth1SessionConfigurationBox`, kept
/// as a separate type since it guards unrelated state with its own eviction rules.
final class CDOAuth1ResponseCacheBox: @unchecked Sendable {
    private struct Entry {
        let data: Data
        let response: HTTPURLResponse
        let insertedAt: Date
        let expiresAt: Date
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    func value(forKey key: String) -> (Data, HTTPURLResponse)? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key] else { return nil }
        guard entry.expiresAt > Date() else {
            entries.removeValue(forKey: key)
            return nil
        }
        return (entry.data, entry.response)
    }

    func store(_ result: (Data, HTTPURLResponse), forKey key: String, ttl: TimeInterval, maxEntries: Int) {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        entries[key] = Entry(data: result.0, response: result.1, insertedAt: now, expiresAt: now.addingTimeInterval(ttl))
        while entries.count > maxEntries, let oldestKey = entries.min(by: { $0.value.insertedAt < $1.value.insertedAt })?.key {
            entries.removeValue(forKey: oldestKey)
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}
