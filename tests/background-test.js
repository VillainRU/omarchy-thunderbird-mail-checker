#!/usr/bin/env node
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

function message(id, read = true) {
  return { id, read, author: `sender-${id}`, subject: `subject-${id}`, date: id, flagged: false };
}

function loadBackground({ messages, pageSize = 100, browserVersion = "128.0", rejectSortedQuery = false }) {
  const posts = [];
  const calls = { list: 0, query: [], abortList: 0, listAttachments: 0, activeQueries: 0, maxActiveQueries: 0 };
  const intervals = [];
  const pages = new Map();
  let pageNumber = 0;
  function makePage(items, size = pageSize) {
    const first = items.slice(0, size);
    const rest = items.slice(size);
    const id = rest.length ? `page-${++pageNumber}` : null;
    if (id) pages.set(id, rest);
    return { id, messages: first };
  }

  function event() {
    const listeners = [];
    return { listeners, addListener(callback) { listeners.push(callback); } };
  }
  const portMessage = event();
  const portDisconnect = event();
  const events = {
    onNewMailReceived: event(), onUpdated: event(), onMoved: event(), onDeleted: event(), onCopied: event()
  };
  const context = vm.createContext({
    console,
    setTimeout(callback) { return { callback }; },
    clearTimeout() {},
    setInterval(callback, interval) { intervals.push({ callback, interval }); },
    messenger: {
      accounts: { async list() { return [{ id: "account", name: "Account", identities: [], folders: [{ id: "inbox", type: "inbox", subFolders: [] }] }]; } },
      i18n: { getUILanguage() { return "en-US"; } },
      runtime: {
        async getBrowserInfo() { return { version: browserVersion }; },
        connectNative() { return { postMessage(value) { posts.push(value); }, onMessage: portMessage, onDisconnect: portDisconnect }; }
      },
      folders: { async getFolderInfo() { return { unreadMessageCount: messages.filter(value => !value.read).length }; } },
      messages: {
        async list() { calls.list += 1; return makePage(messages); },
        async query(query) {
          calls.activeQueries += 1;
          calls.maxActiveQueries = Math.max(calls.maxActiveQueries, calls.activeQueries);
          calls.query.push(query);
          if (rejectSortedQuery && query.sortType) {
            calls.activeQueries -= 1;
            throw new TypeError("Unexpected properties: sortOrder, sortType");
          }
          let result = messages.filter(value => query.unread ? !value.read : true);
          if (query.sortType === "date") result = result.sort((a, b) => Number(b.date) - Number(a.date));
          await Promise.resolve();
          calls.activeQueries -= 1;
          return makePage(result, query.messagesPerPage || pageSize);
        },
        async continueList(id) { return makePage(pages.get(id)); },
        async abortList() { calls.abortList += 1; },
        async listAttachments() { calls.listAttachments += 1; return []; },
        ...events,
        async get() {}, async update() {}, async move() {}, async delete() {}
      },
      messageDisplay: { async open() {} },
      compose: { async beginReply() {} }
    }
  });
  const source = fs.readFileSync(path.join(__dirname, "../thunderbird/background.js"), "utf8");
  vm.runInContext(source, context);
  return { context, posts, calls, events, intervals };
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

async function testRefreshCoalescing() {
  const messages = [message(1, false)];
  const { context, calls, events, intervals } = loadBackground({ messages });
  await vm.runInContext("Promise.all([requestSnapshot(null), requestSnapshot(null), requestSnapshot(null)])", context);
  assert.equal(calls.query.length, 2);
  assert.equal(calls.maxActiveQueries, 1);
  assert.equal(intervals[0].interval, 600000);
  assert.equal(events.onUpdated.listeners.length, 1);
  assert.equal(events.onMoved.listeners.length, 1);
  assert.equal(events.onDeleted.listeners.length, 1);
}

async function testSortedQueryFallback() {
  const messages = Array.from({ length: 20 }, (_, index) => message(index + 1, index < 15));
  const { context, posts, calls } = loadBackground({ messages, browserVersion: "153.0.2", rejectSortedQuery: true });
  await vm.runInContext("snapshot(null)", context);
  const status = posts.find(value => value.type === "snapshot").status;
  assert.equal(status.unreadTotal, 5);
  assert.equal(status.diagnostics.scannedMessages, 5);
  assert.equal(calls.query.length, 2);
  assert.equal(calls.query[0].sortType, "date");
  assert.equal(calls.query[1].sortType, undefined);
}

async function testAttachmentCache() {
  const messages = [message(1, false), message(2, false)];
  const { context, posts, calls } = loadBackground({ messages });
  await vm.runInContext("snapshot(null)", context);
  await vm.runInContext("snapshot(null)", context);
  const snapshots = posts.filter(value => value.type === "snapshot");
  assert.equal(calls.listAttachments, 2);
  assert.equal(snapshots[1].status.diagnostics.attachmentLookups, 0);
  assert.equal(snapshots[1].status.diagnostics.attachmentCacheHits, 2);
  await vm.runInContext("Promise.all(Array.from({length: 205}, (_, index) => attachmentFlag(index + 1000, {attachmentLookups: 0, attachmentCacheHits: 0})))", context);
  assert.equal(vm.runInContext("attachmentCache.size", context), 200);
}

Promise.all([testLargeInboxBaseline(), testServerSidePreviewLimit(), testRefreshCoalescing(), testSortedQueryFallback(), testAttachmentCache()])
  .then(() => console.log("background scheduling: ok"));
