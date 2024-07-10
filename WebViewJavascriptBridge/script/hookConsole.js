; (function (window) {
  if (window.hookConsole) {
    console.log("hook Console have already finished.");
    return;
  }

  if (!window.webkit.messageHandlers || !window.webkit.messageHandlers.console) {
    console.warn("consoleHandler not found, unable to send message to native.");
    return;
  }

  function printObject(obj) {
    if (typeof obj === 'object') {
      return JSON.stringify(obj);
    } else {
      return "" + obj;
    }
  }

  function getObjectString(obj) {
    let message;
    if (obj === null) {
      message = "null";
    } else if (typeof obj === "undefined") {
      message = "undefined";
    } else if (obj instanceof Promise) {
      message = "This is a javascript Promise.";
    } else if (obj instanceof Date) {
      message = obj.getTime().toString();
    } else if (obj instanceof Array) {
      message = '[' + obj.toString() + ']';
    } else {
      message = printObject(obj);
    }
    return message;
  }

  console.log("start hook Console.");
  window.console.log = (function (oriLogFunc) {
    window.hookConsole = true;
    return function () {
      for (let obj of Array.from(arguments)) {
        oriLogFunc.apply(window.console, [obj]);
        const message = getObjectString(obj);
        window.webkit.messageHandlers.console.postMessage(message);
      }
    };
  })(window.console.log, printObject);
  console.log("end hook Console.");
})(window);
