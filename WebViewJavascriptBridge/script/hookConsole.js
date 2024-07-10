; (function (window) {
  if (window.hookConsole) {
    console.log("hook Console have already finished.");
    return;
  }

  const consoleHandler = window.webkit.messageHandlers.console;

  // 检查 consoleHandler 是否存在
  if (!consoleHandler || typeof consoleHandler !== 'object') {
    console.warn('consoleHandler is not defined or not an object');
    return;
  }

  function formatMessage(obj) {
    let message = {
      type: typeof obj,
      value: obj
    };

    if (obj instanceof Date) {
      message.value = obj.getTime();
    } else if (obj instanceof Array) {
      message.value = obj.toString();
    } else if (typeof obj === 'object') {
      message.value = JSON.stringify(obj, function (key, value) {
        if (typeof value === 'object' && value !== null) {
          return '<<Circular Reference>>';
        }
        return value;
      });
    }

    return message;
  }

  window.console.log = (function (oriLogFunc) {
    window.hookConsole = 1;
    return function () {
      const len = arguments.length;
      for (let i = 0; i < len; i++) {
        const obj = arguments[i];
        oriLogFunc.call(window.console, obj);

        try {
          const message = formatMessage(obj);
          const messageStr = JSON.stringify(message);
          if (messageStr !== undefined && messageStr !== null) {
            // 使用 encodeURIComponent 对 messageStr 进行转义处理，防止 XSS 攻击
            consoleHandler.postMessage(encodeURIComponent(messageStr));
          }
        } catch (e) {
          console.warn(`Error sending console log to native: ${e}`); // 使用模板字符串
        }
      }
    };
  })(window.console.log);
  console.log("end hook Console.");
})(window);
