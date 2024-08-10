//
//  MainViewController.swift
//  demo
//
//  Created by syxc on 2024/8/10.
//

import UIKit
import WebKit

class MainViewController: UIViewController {
    private var bridge: WebViewJavascriptBridge?

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()

        let preferences = WKPreferences()
        // 开启 js
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true

        config.preferences = preferences

        let wkWebView = WKWebView(frame: .zero, configuration: config)
        wkWebView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Allow cross domain
        wkWebView.configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // 禁用 webView 回弹效果
        wkWebView.scrollView.bounces = false
        // 只允许 webView 上下滚动
        wkWebView.scrollView.alwaysBounceVertical = true

        if #available(iOS 11.0, *) {
            wkWebView.scrollView.contentInsetAdjustmentBehavior = .never
        }

        wkWebView.allowsBackForwardNavigationGestures = true

        return wkWebView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WebView Demo"
        setupWebView()
        setupBridge()
        setupButton()
        loadHTMLContent()
    }

    private func setupWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func setupBridge() {
        bridge = WebViewJavascriptBridge(webView: webView)

        #if DEBUG
        // This can get javascript console.log
        bridge?.consolePipeClosure = { message in
            guard let jsConsoleLog = message else {
                dlog("JavaScript console.log give native is nil!")
                return
            }
            dlog("[console.log]\n\(jsConsoleLog)")
        }
        #endif

        // This register for javascript call
        bridge?.register(handlerName: "DeviceLoadJavascriptSuccess") { _, callback in
            let data = ["result": "iOS"]
            callback?(data)
        }
    }

    private func loadHTMLContent() {
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL)
        }
    }

    private func setupButton() {
        let button = UIButton(type: .system)
        button.setTitle("Call JavaScript Functions", for: .normal)
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func buttonTapped() {
        callGetToken()
        callAsyncCall()
    }

    private func callGetToken() {
        bridge?.call(handlerName: "GetToken", data: ["key": "value"]) { response in
            if let token = (response as? [String: Any])?["token"] as? String {
                dlog("Received token from JavaScript: \(token)")
            } else {
                dlog("Failed to get token from JavaScript")
            }
        }
    }

    private func callAsyncCall() {
        bridge?.call(handlerName: "AsyncCall", data: ["action": "doSomething"]) { response in
            if let result = (response as? [String: Any])?["token"] as? String {
                dlog("Received async result from JavaScript: \(result)")
            } else {
                dlog("Failed to get async result from JavaScript")
            }
        }
    }
}
