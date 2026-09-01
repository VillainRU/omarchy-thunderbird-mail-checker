#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function message(id, read = true) {
  return { id, read, author: `sender-${id}`, subject: `subject-${id}`, date: id, flagged: false };
}

function loadBackground({ messages, pageSize = 100 }) {
  const posts = [];
  const pages = new Map();
  let pageNumber = 0;
  function makePage(items) {
    const first = items.slice(0, pageSize);
    const rest = items.slice(pageSize);
    const id = rest.length ? `page-${++pageNumber}` : null;
    if (id) pages.set(id, rest);
    return { id, messages: first };
  }

  const listener = { addListener() {} };
  const context = vm.createContext({
    console,
    setTimeout() {},
    setInterval() {},
    messenger: {
      accounts: { async list() { return [{ id: "account", name: "Account", identities: [], folders: [{ id: "inbox", type: "inbox", subFolders: [] }] }]; } },
      i18n: { getUILanguage() { return "en-US"; } },
      runtime: { connectNative() { return { postMessage(value) { posts.push(value); }, onMessage: listener, onDisconnect: listener }; } },
      messages: {
        async list() { return makePage(messages); },
        async continueList(id) { return makePage(pages.get(id)); },
        async listAttachments() { return []; },
        onNewMailReceived: listener,
        async get() {}, async update() {}, async move() {}, async delete() {}
      },
      messageDisplay: { async open() {} },
      compose: { async beginReply() {} }
    }
  });
  const source = fs.readFileSync(path.join(__dirname, "../thunderbird/background.js"), "utf8");
  vm.runInContext(source, context);
  return { context, posts };
}

async function testLargeInboxBaseline() {
  const messages = Array.from({ length: 10000 }, (_, index) => message(index + 1));
  for (const id of [9997, 9998, 9999, 10000]) messages[id - 1].read = false;
  const { context, posts } = loadBackground({ messages });
  await vm.runInContext("snapshot(null)", context);
  const status = posts.find(value => value.type === "snapshot").status;
  assert.equal(status.unreadTotal, 4);
  assert.equal(status.accounts[0].messages.length, 4);
  assert.equal(status.diagnostics.scannedMessages, 10000);
  assert.equal(status.diagnostics.attachmentLookups, 4);
}

testLargeInboxBaseline().then(() => console.log("background baseline: ok"));
