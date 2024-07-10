; (function (window) {
  if (window.hookConsole) {
    console.log("hook Console have already finished.");
    return;
  }

  const consoleHandler = window.webkit.messageHandlers.console;

  if (!consoleHandler || typeof consoleHandler !== 'object') {
    console.warn('consoleHandler is not defined or not an object');
    return;
  }

  // 处理循环引用
  function handleCircularReference(key, value) {
    if (typeof value === 'object' && value !== null) {
      return '<<Circular Reference>>';
    }
    return value;
  }

  // 缓存 formatMessage 函数
  const formatMessage = (function () {
    const cache = {};
    return function (obj) {
      const key = JSON.stringify(obj);
      if (cache[key]) {
        return cache[key];
      } else {
        let message = {
          type: typeof obj,
          value: obj
        };

        if (typeof obj === 'object' && obj !== null) {
          switch (Object.prototype.toString.call(obj)) {
            case '[object Date]':
              message.value = obj.getTime();
              break;
            case '[object Array]':
              message.value = obj.toString();
              break;
            default:
              message.value = JSON.stringify(obj, handleCircularReference);
          }
        }

        cache[key] = message;
        return message;
      }
    };
  })();

  // 重写 console.log 函数
  window.console.log = (function (oriLogFunc) {
    window.hookConsole = 1; // 设置 hook 标志

    return function () {
      // 将参数存储在一个数组中
      const args = Array.prototype.slice.call(arguments);

      // 执行原生的 console.log 函数
      oriLogFunc.apply(window.console, args);

      // 只在需要发送日志时才进行 JSON.stringify 操作
      const messageStr = JSON.stringify(args.map(formatMessage));
      if (messageStr) {
        // 发送日志到 native 端
        try {
          // 使用 encodeURIComponent 对 messageStr 进行转义处理，防止 XSS 攻击
          consoleHandler.postMessage(encodeURIComponent(messageStr));
        } catch (e) {
          console.error('Error sending console log to native: ' + e.stack);
        }
      }
    };
  })(window.console.log); // 将原生的 console.log 函数作为参数传入

  console.log("end hook Console.");
})(window);
