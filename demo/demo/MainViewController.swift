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
        setupButtons()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadHTMLContent()
    }
    
    deinit {
        bridge?.reset()
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

    private func setupButtons() {
        let button1 = UIButton(type: .system)
        button1.setTitle("Call GetToken", for: .normal)
        button1.addTarget(self, action: #selector(getTokenButtonTapped), for: .touchUpInside)

        let button2 = UIButton(type: .system)
        button2.setTitle("Call AsyncCall", for: .normal)
        button2.addTarget(self, action: #selector(asyncCallButtonTapped), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [button1, button2])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40)
        ])
    }

    @objc private func getTokenButtonTapped() {
        callGetToken()
    }

    @objc private func asyncCallButtonTapped() {
        callAsyncCall()
    }

    private func callGetToken() {
        bridge?.call(handlerName: "GetToken", data: ["action": "GetToken"]) { response in
            if let token = (response as? [String: Any])?["token"] as? String {
                dlog("Received token from JavaScript: \(token)")
            } else {
                dlog("Failed to get token from JavaScript")
            }
        }
    }

    private func callAsyncCall() {
        bridge?.call(handlerName: "AsyncCall", data: ["action": "AsyncCall"]) { response in
            if let result = (response as? [String: Any])?["token"] as? String {
                dlog("Received async result from JavaScript: \(result)")
            } else {
                dlog("Failed to get async result from JavaScript")
            }
        }
    }
}
