//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import WebKit

enum PipeType: String {
    case normal
    case console
}

public typealias ConsolePipeClosure = (Any?) -> Void

public class WebViewJavascriptBridge: NSObject {
    private weak var webView: WKWebView?
    private lazy var base: WebViewJavascriptBridgeBase = {
        let base = WebViewJavascriptBridgeBase()
        base.delegate = self
        return base
    }()

    public var consolePipeClosure: ConsolePipeClosure?

    public var isLogEnable: Bool {
        get {
            return base.isLogEnable
        }
        set(newValue) {
            base.isLogEnable = newValue
        }
    }

    public init(webView: WKWebView, _ otherJSCode: String = "", injectionTime: WKUserScriptInjectionTime = .atDocumentStart) {
        super.init()
        self.webView = webView
        addScriptMessageHandlers()
        injectJavascriptFile(otherJSCode, injectionTime: injectionTime)
    }

    deinit {
        #if DEBUG
        print("\(type(of: self)) release")
        #endif
        removeScriptMessageHandlers()
    }

    // MARK: - Public Funcs

    public func reset() {
        base.reset()
    }

    public func register(handlerName: String, handler: @escaping WebViewJavascriptBridgeBase.Handler) {
        base.messageHandlers[handlerName] = handler
    }

    public func remove(handlerName: String) -> WebViewJavascriptBridgeBase.Handler? {
        return base.messageHandlers.removeValue(forKey: handlerName)
    }

    public func call(handlerName: String, data: Any? = nil, callback: WebViewJavascriptBridgeBase.Callback? = nil) {
        base.send(handlerName: handlerName, data: data, callback: callback)
    }

    private func injectJavascriptFile(_ otherJSCode: String = "", injectionTime: WKUserScriptInjectionTime = .atDocumentStart) {
        var userScripts: [WKUserScript] = [
            WKUserScript(source: JavascriptCode.bridge(), injectionTime: injectionTime, forMainFrameOnly: true),
            WKUserScript(source: JavascriptCode.hookConsole(), injectionTime: injectionTime, forMainFrameOnly: true)
        ]

        if !otherJSCode.isEmpty {
            userScripts.append(WKUserScript(source: otherJSCode, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        for userScript in userScripts {
            webView?.configuration.userContentController.addUserScript(userScript)
        }
    }

    private func addScriptMessageHandlers() {
        for pipeType in [PipeType.normal, PipeType.console] {
            webView?.configuration.userContentController.add(LeakAvoider(delegate: self), name: pipeType.rawValue)
        }
    }

    private func removeScriptMessageHandlers() {
        for pipeType in [PipeType.normal, PipeType.console] {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: pipeType.rawValue)
        }
    }
}

extension WebViewJavascriptBridge: WebViewJavascriptBridgeBaseDelegate {
    func evaluateJavascript(javascript: String, completion: CompletionHandler) {
        webView?.evaluateJavaScript(javascript, completionHandler: completion)
    }
}

extension WebViewJavascriptBridge: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == PipeType.console.rawValue {
            consolePipeClosure?(message.body)
        } else if message.name == PipeType.normal.rawValue {
            let body = message.body as? String
            guard let resultString = body else { return }
            base.flush(messageQueueString: resultString)
        }
    }
}

class LeakAvoider: NSObject {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) {
        super.init()
        self.delegate = delegate
    }
}

extension LeakAvoider: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
