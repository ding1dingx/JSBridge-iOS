//
//  JavascriptCode.swift
//  JavascriptBridgeSwift
//
//  Created by HSK on 2022/5/13.
//

import Foundation

enum JavascriptCode {
    public static func bridge() -> String {
        let bridgeScript =
            """
            ; (function (window) {
              if (window.WebViewJavascriptBridge) { return; }

              const messageHandlers = {};
              const responseCallbacks = {};
              let uniqueId = 1;

              window.WebViewJavascriptBridge = {
                registerHandler(handlerName, handler) {
                  messageHandlers[handlerName] = handler;
                },

                callHandler(handlerName, data, responseCallback) {
                  if (arguments.length === 2 && typeof data === 'function') {
                    // 两个参数，第二个参数是函数
                    responseCallback = data;
                    data = null;
                  } else if (arguments.length === 3 && typeof data !== 'function' && typeof responseCallback === 'function') {
                    // 三个参数，第二个参数不是函数，第三个参数是函数，此处无需添加额外的处理代码，因为已经符合预期
                  } else {
                    // 如果参数数量或类型不匹配，则抛出错误
                    console.error('Invalid arguments for callHandler:', arguments);
                    return;
                  }
                  const callbackResult = responseCallback ? responseCallback() : null;
                  doSend({ handlerName, data }, callbackResult);
                },

                handleMessageFromNative(messageJSON) {
                  const message = JSON.parse(messageJSON);

                  if (message.responseId) {
                    if (responseCallbacks[message.responseId]) {
                      // 如果 responseCallbacks 中存在 responseId 对应的回调函数，则调用它
                      const responseCallback = responseCallbacks[message.responseId];
                      try {
                        responseCallback(message.responseData);
                      } catch (error) {
                        console.warn("[WebViewJavascriptBridge] => WARNING: error occurred in responseCallback:", error);
                      } finally {
                        // 无论是否发生错误，都要删除 responseCallbacks 中对应回调函数
                        delete responseCallbacks[message.responseId];
                      }
                    } else {
                      // 如果 responseCallbacks 中不存在 responseId 对应的回调函数，则输出警告信息，并执行默认的处理逻辑
                      console.warn("[WebViewJavascriptBridge] => WARNING: no callback found for responseId:", message.responseId);
                      // 执行默认的处理逻辑，例如将消息丢弃...
                    }
                  } else {
                    if (message.callbackId) {
                      const callbackResponseId = message.callbackId;
                      const handler = messageHandlers[message.handlerName];

                      if (handler) {
                        handler(message.data, responseData => {
                          doSend({ handlerName: message.handlerName, responseId: callbackResponseId, responseData });
                        });
                      } else {
                        console.warn("[WebViewJavascriptBridge] => WARNING: no handler for message from Swift/ObjC:", message);
                      }
                    } else {
                      // 如果 message.callbackId 不存在，则不做任何操作
                      console.warn("[WebViewJavascriptBridge] => WARNING: message from Native does not contain callbackId:", message);
                    }
                  }
                }
              };

              function doSend(message, responseCallback) {
                // 生成一个新的 callbackId
                message.callbackId = 'cb_' + (uniqueId++) + '_' + new Date().getTime();
                // 如果 responseCallback 为 null 或 undefined，则将其设置为 null
                responseCallbacks[message.callbackId] = responseCallback || null;
                // 将消息发送到 Native 端
                window.webkit.messageHandlers.normal.postMessage(JSON.stringify(message));
              }

            })(window);
            """
        return bridgeScript
    }

    public static func hookConsole() -> String {
        let hookConsole =
            """
            ; (function (window) {
              if (window.hookConsole) {
                console.log("hook Console have already finished.");
                return;
              }

              const consoleHandler = window.webkit.messageHandlers?.console;
              if (!consoleHandler) {
                console.warn("consoleHandler not found, unable to send message to native.");
                return;
              }

              function printObject(obj) {
                if (obj instanceof Promise) {
                  return "This is a javascript Promise.";
                } else if (obj instanceof Date) {
                  return obj.toLocaleString();
                } else if (Array.isArray(obj)) {
                  return '[' + obj.map(item => printObject(item)).join(', ') + ']';
                } else if (typeof obj === 'string' || typeof obj === 'number' || typeof obj === 'boolean' || obj === null || typeof obj === 'undefined' || typeof obj === 'symbol') {
                  return obj;
                } else if (typeof obj === 'function') {
                  return obj.toString();
                } else {
                  try {
                    return JSON.stringify(obj) || '';
                  } catch (error) {
                    return '<<Circular Reference>>';
                  }
                }
              }

              console.log("start hook Console.");
              window.hookConsole = true;
              window.console.log = (function (oriLogFunc) {
                return function (...args) {
                  oriLogFunc.apply(window.console, args);
                  args.forEach(obj => {
                    const message = printObject(obj);
                    consoleHandler.postMessage(message);
                  });
                };
              })(window.console.log);
              console.log("end hook Console.");
            })(window);
            """
        return hookConsole
    }
}
