//
//  SceneDelegate.swift
//  iOS Example
//
//  Created by Christopher de Haan on 5/30/26.
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

import CDOAuth1Kit
import UIKit

/// Posted when `scene(_:openURLContexts:)` receives the OAuth 1.0a callback URL.
/// `ViewController` observes this to complete the access-token exchange.
extension Notification.Name {
    static let cdoauth1kitAuthorizationCallback = Notification.Name("CDOAuth1KitAuthorizationCallbackURL")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard scene is UIWindowScene else { return }

        // Window is configured by the storyboard's UISceneStoryboardFile entry point.
        // Cold-launch via the OAuth callback URL is not supported by this demo —
        // the app must already be running (in the background) when Discogs redirects back.
    }

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        for urlContext in URLContexts {
            let url = urlContext.url
            if CDOAuth1Helper.isAuthorizationCallbackURL(
                url,
                scheme: "cdoauth1kit",
                host: "oauthCallback"
            ) {
                NotificationCenter.default.post(name: .cdoauth1kitAuthorizationCallback, object: url)
            }
        }
    }
}
