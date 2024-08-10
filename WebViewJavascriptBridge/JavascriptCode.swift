//
//  JavascriptCode.swift
//  JavascriptBridgeSwift
//
//  Created by HSK on 2022/5/13.
//

import Foundation

enum JavascriptCode {
    public static func bridge() -> String {
        let bridgeScript = """
        ; (function (window) {
          if (window.WebViewJavascriptBridge) {
            return;
          }

          const messageHandlers = {};
          const responseCallbacks = {};
          let uniqueId = 1;

          window.WebViewJavascriptBridge = {
            registerHandler(handlerName, handler) {
              messageHandlers[handlerName] = handler;
            },

            callHandler(handlerName, data, responseCallback) {
              if (arguments.length === 2 && typeof data === 'function') {
                responseCallback = data;
                data = null;
              }
              this.doSend({ handlerName, data }, responseCallback);
            },

            handleMessageFromNative(messageJSON) {
              try {
                const message = JSON.parse(messageJSON);
                if (message.responseId) {
                  this.handleResponseMessage(message);
                } else if (message.callbackId) {
                  this.handleCallbackMessage(message);
                } else {
                  console.warn("[WebViewJavascriptBridge] => WARNING: message from Native does not contain callbackId:", message);
                }
              } catch (error) {
                console.error("[WebViewJavascriptBridge] => ERROR: Failed to parse message from native:", error, messageJSON);
              }
            },

            doSend(sendMessage, responseCallback) {
              try {
                sendMessage.callbackId = responseCallback ? 'cb_' + (uniqueId++) + '_' + new Date().getTime() : null;
                responseCallbacks[sendMessage.callbackId] = responseCallback || null;
                if (window.webkit.messageHandlers.normal) {
                  window.webkit.messageHandlers.normal.postMessage(JSON.stringify(sendMessage));
                } else {
                  console.error("[WebViewJavascriptBridge] => ERROR: Unable to find the 'normal' message handler in WKWebView.");
                }
              } catch (error) {
                console.error("[WebViewJavascriptBridge] => ERROR: Failed to send message to native:", error, sendMessage);
              }
            },

            handleResponseMessage(message) {
              const responseCallback = responseCallbacks[message.responseId];
              if (responseCallback) {
                try {
                  responseCallback(message.responseData);
                } catch (error) {
                  console.error("[WebViewJavascriptBridge] => ERROR: Failed to execute response callback:", error, message);
                } finally {
                  delete responseCallbacks[message.responseId];
                }
              }
            },

            handleCallbackMessage(message) {
              const callbackResponseId = message.callbackId;
              const handler = messageHandlers[message.handlerName];
              if (handler) {
                try {
                  handler(message.data, responseData => {
                    this.doSend({ handlerName: message.handlerName, responseId: callbackResponseId, responseData });
                  });
                } catch (error) {
                  console.error("[WebViewJavascriptBridge] => ERROR: Failed to execute callback handler:", error, message);
                }
              } else {
                console.warn("[WebViewJavascriptBridge] => WARNING: no handler for message from Swift/ObjC:", message);
              }
            }
          };

        })(window);
        """
        return bridgeScript
    }

    public static func hookConsole() -> String {
        let hookConsole = """
        ;(function (window) {
          if (window.isConsoleHooked) {
            console.log("Console hook has already been applied.");
            return;
          }
        
          function printObject(obj) {
            if (obj === null) return "null";
            if (typeof obj === "undefined") return "undefined";
            if (obj instanceof Promise) return "This is a javascript Promise.";
            if (obj instanceof Date) return obj.getTime().toString();
            if (Array.isArray(obj)) return `[${obj.toString()}]`;
            if (typeof obj === 'object') {
              const entries = Object.entries(obj).map(([key, value]) => `"${key}":"${value}"`);
              return `{${entries.join(',')}}`;
            }
            return String(obj);
          }
        
          console.log("Starting console hook application.");
        
          const originalConsoleLog = window.console.log;
        
          window.console.log = function (...args) {
            window.isConsoleHooked = true;
        
            args.forEach(obj => {
              originalConsoleLog.call(window.console, obj);
              const message = printObject(obj);
              window.webkit.messageHandlers.console.postMessage(message);
            });
          };
        
          console.log("Console hook has been applied successfully.");
        })(window);
        """
        return hookConsole
    }
}
