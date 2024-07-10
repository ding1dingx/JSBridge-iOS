; (function (window) {
  if (window.WebViewJavascriptBridge) { return; }

  window.WebViewJavascriptBridge = {
    registerHandler: registerHandler,
    callHandler: callHandler,
    handleMessageFromNative: handleMessageFromNative
  };

  let messageHandlers = {};
  let responseCallbacks = {};
  let uniqueId = 1;

  function registerHandler(handlerName, handler) {
    messageHandlers[handlerName] = handler;
  }

  function callHandler(handlerName, data, responseCallback) {
    if (arguments.length === 2 && typeof data === 'function') {
      responseCallback = data;
      data = null;
    }
    doSend({ handlerName, data }, responseCallback);
  }

  function doSend(message, responseCallback) {
    if (responseCallback) {
      const callbackId = 'cb_' + (uniqueId++) + '_' + new Date().getTime();
      responseCallbacks[callbackId] = responseCallback;
      message.callbackId = callbackId;
    }
    window.webkit.messageHandlers.normal.postMessage(JSON.stringify(message));
  }

  function handleMessageFromNative(messageJSON) {
    const message = JSON.parse(messageJSON);
    let responseCallback;

    if (message.responseId) {
      responseCallback = responseCallbacks[message.responseId];
      if (responseCallback) {
        responseCallback(message.responseData);
        delete responseCallbacks[message.responseId];
      }
    } else {
      if (message.callbackId) {
        const callbackResponseId = message.callbackId;
        responseCallback = function (responseData) {
          doSend({ handlerName: message.handlerName, responseId: callbackResponseId, responseData: responseData });
        };
      }
      let handler = messageHandlers[message.handlerName];
      if (handler) {
        handler(message.data, responseCallback);
      } else {
        console.warn("[WebViewJavascriptBridge] => WARNING: no handler for message from Swift/ObjC:", message);
      }
    }
  }
})(window);
