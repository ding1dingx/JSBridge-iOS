; (function (window) {
  if (window.hookConsole) return;
  const consoleHandler = window.webkit.messageHandlers.console;
  if (!consoleHandler || typeof consoleHandler !== 'object') {
    console.warn('consoleHandler is not defined or not an object');
    return;
  }

  function handleCircularReference(key, value) {
    if (typeof value === 'object' && value !== null) {
      return '<<Circular Reference>>';
    }
    return value;
  }

  const formatMessage = (function () {
    const cache = {};
    Object.freeze(cache);
    return function (obj) {
      const key = JSON.stringify(obj, handleCircularReference);
      return cache[key] || (cache[key] = {
        type: typeof obj,
        value: obj instanceof Date ? obj.getTime() : Array.isArray(obj) ? obj.toString() : JSON.stringify(obj, handleCircularReference)
      });
    };
  })();

  const originalConsoleLogFunc = window.console.log;
  window.hookConsole = true;
  window.console.log = function () {
    const args = Array.prototype.slice.call(arguments);
    originalConsoleLogFunc.apply(window.console, args);

    const messageStr = JSON.stringify(args.map(formatMessage).map(function (message) { return message.value; }));
    if (messageStr) {
      const send = function () {
        try {
          consoleHandler.postMessage(encodeURIComponent(messageStr));
        } catch (e) {
          console.error('Error sending console log to native: ' + e.stack);
        }
      };

      // 使用 Promise 或同步方式发送
      'Promise' in window ? new Promise(send).catch(function (e) { console.error(e); }) : send();
    }
  };

  console.log("end hook Console.");
})(window);
