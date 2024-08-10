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
        ;(function (window) {
          if (window.WebViewJavascriptBridge) return;
        
          const messageHandlers = {};
          const responseCallbacks = {};
          let uniqueId = 1;
        
          function doSend(message, responseCallback) {
            if (responseCallback) {
              const callbackId = `cb_${uniqueId++}_${Date.now()}`;
              responseCallbacks[callbackId] = responseCallback;
              message.callbackId = callbackId;
            }
            window.webkit.messageHandlers.normal.postMessage(JSON.stringify(message));
          }
        
          function handleResponse(responseId, responseData) {
            const callback = responseCallbacks[responseId];
            if (callback) {
              callback(responseData);
              delete responseCallbacks[responseId];
            }
          }
        
          function createResponseCallback(handlerName, callbackId) {
            return function (responseData) {
              doSend({ handlerName, responseId: callbackId, responseData });
            };
          }
        
          window.WebViewJavascriptBridge = {
            registerHandler(handlerName, handler) {
              messageHandlers[handlerName] = handler;
            },
        
            callHandler(handlerName, data, responseCallback) {
              if (arguments.length === 2 && typeof data === 'function') {
                responseCallback = data;
                data = null;
              }
              doSend({ handlerName, data }, responseCallback);
            },
        
            handleMessageFromNative(messageJSON) {
              const message = JSON.parse(messageJSON);
        
              if (message.responseId) {
                handleResponse(message.responseId, message.responseData);
                return;
              }
        
              let responseCallback;
              if (message.callbackId) {
                responseCallback = createResponseCallback(message.handlerName, message.callbackId);
              }
        
              const handler = messageHandlers[message.handlerName];
              if (handler) {
                handler(message.data, responseCallback);
              } else {
                console.warn("WebViewJavascriptBridge: No handler for message from ObjC/Swift:", message);
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
