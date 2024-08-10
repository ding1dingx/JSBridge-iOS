;(function(window) {
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
    return function(responseData) {
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
