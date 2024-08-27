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
//

import Foundation

protocol WebViewJavascriptBridgeBaseDelegate: AnyObject {
    typealias CompletionHandler = ((Any?, Error?) -> Void)?
    func evaluateJavascript(javascript: String, completion: CompletionHandler)
}

extension WebViewJavascriptBridgeBaseDelegate {
    func evaluateJavascript(javascript: String) {
        evaluateJavascript(javascript: javascript, completion: nil)
    }
}

public class WebViewJavascriptBridgeBase: NSObject {
    public var isLogEnable: Bool = false {
        didSet {
            updateLogStatus()
        }
    }

    public typealias Callback = (_ responseData: Any?) -> Void
    public typealias Handler = (_ parameters: [String: Any]?, _ callback: Callback?) -> Void
    public typealias Message = [String: Any]

    weak var delegate: WebViewJavascriptBridgeBaseDelegate?

    var responseCallbacks = [String: Callback]()
    var messageHandlers = [String: Handler]()
    private var uniqueId: Int = 0

    func reset() {
        responseCallbacks.removeAll()
        uniqueId = 0
        log("reset...")
    }

    func send(handlerName: String, data: Any?, callback: Callback?) {
        var message: Message = ["handlerName": handlerName]

        if let data = data {
            message["data"] = data
        }

        if let callback = callback {
            uniqueId += 1
            let callbackID = "native_ios_cb_\(uniqueId)"
            responseCallbacks[callbackID] = callback
            message["callbackId"] = callbackID
        }

        dispatch(message: message)
    }

    func flush(messageQueueString: String) {
        guard let message = deserialize(messageJSON: messageQueueString) else {
            return
        }

        if let responseID = message["responseId"] as? String {
            if let callback = responseCallbacks.removeValue(forKey: responseID) {
                callback(message["responseData"])
            }
        } else {
            var callback: Callback?
            if let callbackID = message["callbackId"] as? String {
                callback = { [weak self] responseData in
                    let msg: Message = ["responseId": callbackID, "responseData": responseData ?? NSNull()]
                    self?.dispatch(message: msg)
                }
            } else {
                callback = { (_: Any?) in
                    // no logic
                }
            }

            if let handlerName = message["handlerName"] as? String,
               let handler = messageHandlers[handlerName]
            {
                handler(message["data"] as? [String: Any], callback)
            } else {
                log("NoHandlerException, No handler for message from JS: \(message)")
            }
        }
    }

    private func dispatch(message: Message) {
        guard let messageJSON = serialize(message: message, pretty: false) else { return }
        let escapedMessageJSON = escapeJSONString(messageJSON)
        let javascriptCommand = "WebViewJavascriptBridge.handleMessageFromNative('\(escapedMessageJSON)');"
        if Thread.isMainThread {
            delegate?.evaluateJavascript(javascript: javascriptCommand)
        } else {
            DispatchQueue.main.async {
                self.delegate?.evaluateJavascript(javascript: javascriptCommand)
            }
        }
    }

    // MARK: - JSON

    private func serialize(message: Message, pretty: Bool) -> String? {
        do {
            let data = try JSONSerialization.data(withJSONObject: message, options: pretty ? .prettyPrinted : [])
            return String(data: data, encoding: .utf8)
        } catch {
            log("serialize fail: \(error)")
            return nil
        }
    }

    private func deserialize(messageJSON: String) -> Message? {
        do {
            if let data = messageJSON.data(using: .utf8) {
                return try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Message
            }
        } catch {
            log("deserialize fail: \(error)")
        }
        return nil
    }

    private func escapeJSONString(_ string: String) -> String {
        var escapedString = string
        escapedString = escapedString.replacingOccurrences(of: "\\", with: "\\\\")
        escapedString = escapedString.replacingOccurrences(of: "\"", with: "\\\"")
        escapedString = escapedString.replacingOccurrences(of: "\'", with: "\\\'")
        escapedString = escapedString.replacingOccurrences(of: "\n", with: "\\n")
        escapedString = escapedString.replacingOccurrences(of: "\r", with: "\\r")
        escapedString = escapedString.replacingOccurrences(of: "\u{000C}", with: "\\f")
        escapedString = escapedString.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        escapedString = escapedString.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return escapedString
    }

    // MARK: - Log

    private func log<T>(_ message: T, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        guard isLogEnable else {
            return
        }

        let fileName = (file as NSString).lastPathComponent
        print("\(fileName):\(line) \(function) | \(message)")
        #endif
    }

    private func updateLogStatus() {
        #if DEBUG
        log("Log status updated: \(isLogEnable)")
        #endif
    }
}
