const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const panel = fs.readFileSync(path.join(__dirname, "..", "Panel.qml"), "utf8");

assert.match(panel, /Loader\s*{\s*id:\s*bridgeSocketLoader/,
  "the socket must be owned by a Loader so a failed QLocalSocket can be destroyed");
assert.match(panel, /function recreateSocket\(\)[\s\S]*bridgeSocketLoader\.active = false[\s\S]*socketCreateTimer\.restart\(\)/,
  "a retry must destroy the failed socket before scheduling a fresh client");
assert.match(panel, /id:\s*reconnectTimer[\s\S]*repeat:\s*true[\s\S]*running:\s*!root\.socketOnline[\s\S]*onTriggered:\s*root\.recreateSocket\(\)/,
  "retry attempts must continue independently while the socket is disconnected");
assert.match(panel, /onConnectedChanged:[\s\S]*root\.socketOnline = true[\s\S]*root\.resetConnectionState\(\)/,
  "live socket events must own the explicit connection state");
assert.match(panel, /id:\s*socketCreateTimer[\s\S]*onTriggered:\s*bridgeSocketLoader\.active = true/,
  "socket recreation must happen after the failed Loader item is destroyed");
assert.match(panel, /bridgeActive:\s*bridgeConnected && snapshot\.connected === true/,
  "the bridge indicator must include the live socket state");

console.log("panel reconnect policy: ok");
