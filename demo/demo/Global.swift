//
//  Global.swift
//  demo
//
//  Created by syxc on 2024/8/10.
//

import Foundation
import WebKit

// MARK: - print

func dlog<T>(_ message: T, file: String = #file, lineNumber: Int = #line, function: String = #function) {
    #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print("[\(fileName) line: \(lineNumber) funciton: \(function)] - \(message)")
    #endif
}

// MARK: - String extension

extension String {
    func urlEncoded() -> String {
        let encodeUrlString = self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        return encodeUrlString ?? ""
    }

    func urlDecoded() -> String {
        return self.removingPercentEncoding ?? ""
    }

    /// 检测 http(s) url 是否合规
    func isValidHttpURL() -> Bool {
        if let url = URL(string: self) {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
                if let scheme = components.scheme {
                    return scheme.lowercased() == "http" || scheme.lowercased() == "https"
                }
            }
        }
        return false
    }
}

// MARK: - WKWebView extension

public extension WKWebView {
    /// SwifterSwift: Navigate to `url`.
    /// - Parameter url: URL to navigate.
    /// - Returns: A new navigation for given `url`.
    @discardableResult
    func loadURL(_ url: URL) -> WKNavigation? {
        return load(URLRequest(url: url))
    }

    /// SwifterSwift: Navigate to url using `String`.
    /// - Parameter urlString: The string specifying the URL to navigate to.
    /// - Returns: A new navigation for given `urlString`.
    @discardableResult
    func loadURLString(_ urlString: String, timeout: TimeInterval? = nil) -> WKNavigation? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        if let timeout = timeout {
            request.timeoutInterval = timeout
        }
        return load(request)
    }
}
