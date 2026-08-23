//
//  ViewController.swift
//  iOS Example
//
//  Created by Christopher de Haan on 8/20/26.
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

class ViewController: UIViewController {

    @IBOutlet private var tableView: UITableView!

    private enum Row: Int, CaseIterable {
        case authorize
        case fetchIdentity
        case deauthorize

        var title: String {
            switch self {
            case .authorize: "Authorize with Discogs"
            case .fetchIdentity: "Fetch My Identity"
            case .deauthorize: "Deauthorize"
            }
        }

        /// Only the Authorize row is usable before the user has an access token.
        var requiresAuthorization: Bool {
            self != .authorize
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}

// MARK: - UITableViewDataSource Methods

extension ViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CDOAuth1KitEndpointCell", for: indexPath)
        guard let row = Row(rawValue: indexPath.row) else { return cell }

        cell.textLabel?.text = row.title
        let enabled = !row.requiresAuthorization || CDOAuth1KitManager.shared.isAuthorized
        cell.textLabel?.textColor = enabled ? .label : .tertiaryLabel
        cell.selectionStyle = enabled ? .default : .none

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Discogs OAuth 1.0a Demo"
    }
}

// MARK: - UITableViewDelegate Methods

extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = Row(rawValue: indexPath.row) else { return }

        if row.requiresAuthorization, !CDOAuth1KitManager.shared.isAuthorized {
            presentAlert(title: "Not Authorized", message: "Tap \"Authorize with Discogs\" first.")
            return
        }

        switch row {
        case .authorize:
            authorize()
        case .fetchIdentity:
            fetchIdentity()
        case .deauthorize:
            deauthorize()
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0.1
    }
}

// MARK: - Actions

private extension ViewController {

    func authorize() {
        guard let window = view.window else { return }
        Task {
            do {
                try await CDOAuth1KitManager.shared.authorize(presentationAnchor: window)
                tableView.reloadData()
                presentAlert(title: "Authorized", message: "You're now authorized with Discogs.")
            } catch CDOAuth1Error.authorizationCancelled {
                // User dismissed the browser sheet; no alert needed.
            } catch {
                presentAlert(title: "Request Failed", message: "\(error)")
            }
        }
    }

    func fetchIdentity() {
        Task {
            do {
                let data = try await CDOAuth1KitManager.shared.fetchIdentity()
                let jsonText = JSONPrettyPrinter.string(from: data)
                let jsonResponseViewController = CDOAuth1KitJSONResponseViewController(
                    title: "My Identity",
                    jsonText: jsonText
                )
                navigationController?.pushViewController(jsonResponseViewController, animated: true)
            } catch {
                presentAlert(title: "Request Failed", message: "\(error)")
            }
        }
    }

    func deauthorize() {
        do {
            try CDOAuth1KitManager.shared.deauthorize()
            tableView.reloadData()
        } catch {
            presentAlert(title: "Deauthorize Failed", message: "\(error)")
        }
    }

    func presentAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
}
