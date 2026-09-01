#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function message(id, read = true) {
  return { id, read, author: `sender-${id}`, subject: `subject-${id}`, date: id, flagged: false };
}

function loadBackground({ messages, pageSize = 100, browserVersion = "128.0" }) {
  const posts = [];
  const calls = { list: 0, query: [], abortList: 0 };
  const pages = new Map();
  let pageNumber = 0;
  function makePage(items, size = pageSize) {
    const first = items.slice(0, size);
    const rest = items.slice(size);
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
      runtime: {
        async getBrowserInfo() { return { version: browserVersion }; },
        connectNative() { return { postMessage(value) { posts.push(value); }, onMessage: listener, onDisconnect: listener }; }
      },
      folders: { async getFolderInfo() { return { unreadMessageCount: messages.filter(value => !value.read).length }; } },
      messages: {
        async list() { calls.list += 1; return makePage(messages); },
        async query(query) {
          calls.query.push(query);
          let result = messages.filter(value => query.unread ? !value.read : true);
          if (query.sortType === "date") result = result.sort((a, b) => Number(b.date) - Number(a.date));
          return makePage(result, query.messagesPerPage || pageSize);
        },
        async continueList(id) { return makePage(pages.get(id)); },
        async abortList() { calls.abortList += 1; },
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
  return { context, posts, calls };
}

async function testLargeInboxBaseline() {
  const messages = Array.from({ length: 10000 }, (_, index) => message(index + 1));
  for (const id of [9997, 9998, 9999, 10000]) messages[id - 1].read = false;
  const { context, posts, calls } = loadBackground({ messages });
  await vm.runInContext("snapshot(null)", context);
  const status = posts.find(value => value.type === "snapshot").status;
  assert.equal(status.unreadTotal, 4);
  assert.equal(status.accounts[0].messages.length, 4);
  assert.equal(status.diagnostics.scannedMessages, 4);
  assert.equal(status.diagnostics.attachmentLookups, 4);
  assert.equal(calls.list, 0);
  assert.equal(calls.query.length, 1);
  assert.equal(calls.query[0].unread, true);
}

async function testServerSidePreviewLimit() {
  const messages = Array.from({ length: 500 }, (_, index) => message(index + 1, false));
  const { context, posts, calls } = loadBackground({ messages, browserVersion: "153.0.2" });
  await vm.runInContext("snapshot(null)", context);
  const status = posts.find(value => value.type === "snapshot").status;
  assert.equal(status.unreadTotal, 500);
  assert.deepEqual(Array.from(status.accounts[0].messages, value => value.id), [500, 499, 498, 497, 496]);
  assert.equal(status.diagnostics.scannedMessages, 5);
  assert.equal(calls.query[0].messagesPerPage, 5);
  assert.equal(calls.query[0].sortType, "date");
  assert.equal(calls.abortList, 1);
}

Promise.all([testLargeInboxBaseline(), testServerSidePreviewLimit()])
  .then(() => console.log("background queries: ok"));
