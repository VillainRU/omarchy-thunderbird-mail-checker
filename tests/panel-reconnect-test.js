const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const panel = fs.readFileSync(path.join(__dirname, "..", "Panel.qml"), "utf8");

assert.match(panel, /Loader\s*{\s*id:\s*bridgeSocketLoader/,
  "the socket must be owned by a Loader so a failed QLocalSocket can be destroyed");
assert.match(panel, /function scheduleReconnect\(\)[\s\S]*bridgeSocketLoader\.active = false[\s\S]*reconnectTimer\.restart\(\)/,
  "reconnecting must destroy the failed socket before scheduling another attempt");
assert.match(panel, /onError:\s*function\(error\)\s*{\s*root\.scheduleReconnect\(\)\s*}/,
  "socket errors must schedule a new client");
assert.match(panel, /onConnectedChanged:[\s\S]*else\s*{\s*root\.scheduleReconnect\(\)\s*}/,
  "socket disconnects must schedule a new client");
assert.match(panel, /Timer\s*{[^}]*onTriggered:\s*bridgeSocketLoader\.active = true/,
  "the retry timer must create a fresh socket client");

console.log("panel reconnect policy: ok");
