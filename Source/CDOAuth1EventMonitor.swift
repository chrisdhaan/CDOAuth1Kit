//
//  CDOAuth1EventMonitor.swift
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

/// Observes the lifecycle of requests made via
/// ``CDOAuth1SessionManager/request(path:method:parameters:)`` — e.g. for logging or
/// metrics — without subclassing ``CDOAuth1SessionManager``.
///
/// Every method has a no-op default, so a conformer only implements the events it
/// cares about. Register via ``CDOAuth1SessionManager/eventMonitors``.
public protocol CDOAuth1EventMonitor: Sendable {
    /// Called immediately before a signed, adapted request is sent (once per attempt).
    func requestWillStart(_ request: URLRequest)

    /// Called after a request completes with a 2xx response.
    func requestDidSucceed(_ request: URLRequest, response: HTTPURLResponse)

    /// Called when a request fails with no further retry to follow.
    func requestDidFail(_ request: URLRequest, error: any Error)

    /// Called when a failed attempt will be retried, before the backoff delay is awaited.
    func requestWillRetry(_ request: URLRequest, attempt: Int, delay: TimeInterval)
}

public extension CDOAuth1EventMonitor {
    func requestWillStart(_ request: URLRequest) {}
    func requestDidSucceed(_ request: URLRequest, response: HTTPURLResponse) {}
    func requestDidFail(_ request: URLRequest, error: any Error) {}
    func requestWillRetry(_ request: URLRequest, attempt: Int, delay: TimeInterval) {}
}

extension [any CDOAuth1EventMonitor] {
    func notifyWillStart(_ request: URLRequest) {
        forEach { $0.requestWillStart(request) }
    }
    func notifyDidSucceed(_ request: URLRequest, response: HTTPURLResponse) {
        forEach { $0.requestDidSucceed(request, response: response) }
    }
    func notifyDidFail(_ request: URLRequest, error: any Error) {
        forEach { $0.requestDidFail(request, error: error) }
    }
    func notifyWillRetry(_ request: URLRequest, attempt: Int, delay: TimeInterval) {
        forEach { $0.requestWillRetry(request, attempt: attempt, delay: delay) }
    }
}
