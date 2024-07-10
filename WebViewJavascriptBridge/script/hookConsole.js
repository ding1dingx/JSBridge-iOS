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
    } else {
      return JSON.stringify(obj) || '';
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
