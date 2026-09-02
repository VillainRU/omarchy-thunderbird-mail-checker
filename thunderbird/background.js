const HOST = "io.github.villainru.thunderbird_mail_checker";
let port;
let initialized = false;
let eventId = 0;
let sortedQuerySupport;
let snapshotRunning = false;
let snapshotPending = false;
let pendingNotification = null;
let pendingWaiters = [];
let scheduledNotification = null;
let scheduledRefresh;
const ATTACHMENT_CACHE_LIMIT = 200;
const ATTACHMENT_CACHE_TTL = 60 * 60 * 1000;
const attachmentCache = new Map();

function post(payload) { try { port.postMessage(payload); } catch (error) { console.error(error); } }
function reportError(error) {
  console.error(error);
  post({ type: "error", error: String(error && (error.message || error)) });
}
function inboxes(folders, result) {
  for (const folder of folders || []) {
    if (folder.type === "inbox") result.push(folder);
    inboxes(folder.subFolders, result);
  }
}
async function attachmentFlag(id, diagnostics) {
  const cached = attachmentCache.get(id);
  if (cached && Date.now() - cached.updatedAt < ATTACHMENT_CACHE_TTL) {
    attachmentCache.delete(id);
    attachmentCache.set(id, cached);
    diagnostics.attachmentCacheHits += 1;
    return cached.value;
  }
  attachmentCache.delete(id);
  diagnostics.attachmentLookups += 1;
  let value = false;
  try { value = (await messenger.messages.listAttachments(id)).length > 0; } catch (error) { value = false; }
  attachmentCache.set(id, { value, updatedAt: Date.now() });
  while (attachmentCache.size > ATTACHMENT_CACHE_LIMIT) attachmentCache.delete(attachmentCache.keys().next().value);
  return value;
}
function forgetAttachments(messageList) {
  for (const message of messageList && messageList.messages || []) attachmentCache.delete(message.id);
}
async function supportsSortedQueries() {
  if (sortedQuerySupport !== undefined) return sortedQuerySupport;
  try {
    const info = await messenger.runtime.getBrowserInfo();
    sortedQuerySupport = Number.parseInt(info.version, 10) >= 148;
  } catch (error) {
    sortedQuerySupport = false;
  }
  return sortedQuerySupport;
}
async function collectMessages(page, diagnostics) {
  const messages = [];
  while (page) {
    diagnostics.scannedMessages += page.messages.length;
    messages.push(...page.messages);
    page = page.id ? await messenger.messages.continueList(page.id) : null;
  }
  return messages;
}
async function unreadInFolder(folder, diagnostics) {
  const info = await messenger.folders.getFolderInfo(folder);
  const unreadCount = Number(info.unreadMessageCount || 0);
  if (!unreadCount) return { unreadCount: 0, messages: [] };

  const query = { folderId: folder.id, unread: true };
  if (await supportsSortedQueries()) {
    try {
      const sortedQuery = { ...query, sortType: "date", sortOrder: "descending", messagesPerPage: 5 };
      const page = await messenger.messages.query(sortedQuery);
      diagnostics.scannedMessages += page.messages.length;
      if (page.id) await messenger.messages.abortList(page.id);
      return { unreadCount, messages: page.messages.slice(0, 5) };
    } catch (error) {
      if (!/Unexpected properties.*sort/i.test(String(error))) throw error;
      sortedQuerySupport = false;
    }
  }
  return { unreadCount, messages: await collectMessages(await messenger.messages.query(query), diagnostics) };
}
async function snapshot(notification) {
  const startedAt = Date.now();
  const diagnostics = { scannedMessages: 0, attachmentLookups: 0, attachmentCacheHits: 0 };
  const accounts = await messenger.accounts.list(true);
  const visible = [];
  let total = 0;
  for (const account of accounts) {
    const folders = []; inboxes(account.folders, folders);
    const folderResults = await Promise.all(folders.map(folder => unreadInFolder(folder, diagnostics)));
    const unreadCount = folderResults.reduce((sum, result) => sum + result.unreadCount, 0);
    if (!unreadCount) continue;
    const unread = folderResults.flatMap(result => result.messages);
    unread.sort((a, b) => Number(b.date) - Number(a.date));
    const preview = await Promise.all(unread.slice(0, 5).map(async message => ({
      id: message.id, author: message.author, subject: message.subject, date: message.date,
      flagged: Boolean(message.flagged), hasAttachments: await attachmentFlag(message.id, diagnostics)
    })));
    const identity = account.identities && account.identities[0];
    visible.push({ accountId: account.id, name: account.name, email: identity ? identity.email : account.name, unreadCount, messages: preview, expanded: false });
    total += unreadCount;
  }
  // Keep Thunderbird's account order. Sorting by the changing unread count made
  // expanded mailboxes jump when a message was deleted or marked as read.
  if (notification && notification.initial) {
    notification.count = total;
    notification.first = visible.length && visible[0].messages.length ? visible[0].messages[0] : null;
  }
  post({ type: "snapshot", status: {
    connected: true, updatedAt: Date.now(), thunderbirdLanguage: messenger.i18n.getUILanguage(),
    unreadTotal: total, accounts: visible, notification: notification || null,
    diagnostics: { snapshotDurationMs: Date.now() - startedAt, ...diagnostics }
  } });
}
function mergeNotification(current, next) {
  if (!next) return current;
  if (!current) return { ...next };
  return {
    eventId: Math.max(Number(current.eventId || 0), Number(next.eventId || 0)),
    count: Number(current.count || 0) + Number(next.count || 0),
    first: current.first || next.first || null,
    initial: Boolean(current.initial || next.initial)
  };
}
async function drainSnapshots() {
  if (snapshotRunning) return;
  snapshotRunning = true;
  try {
    while (snapshotPending) {
      snapshotPending = false;
      const notification = pendingNotification;
      const waiters = pendingWaiters;
      pendingNotification = null;
      pendingWaiters = [];
      try {
        await snapshot(notification);
        for (const waiter of waiters) waiter.resolve();
      } catch (error) {
        for (const waiter of waiters) waiter.reject(error);
      }
    }
  } finally {
    snapshotRunning = false;
    if (snapshotPending) drainSnapshots();
  }
}
function requestSnapshot(notification) {
  snapshotPending = true;
  pendingNotification = mergeNotification(pendingNotification, notification);
  const result = new Promise((resolve, reject) => pendingWaiters.push({ resolve, reject }));
  drainSnapshots();
  return result;
}
function scheduleSnapshot(notification) {
  scheduledNotification = mergeNotification(scheduledNotification, notification);
  if (scheduledRefresh) clearTimeout(scheduledRefresh);
  scheduledRefresh = setTimeout(() => {
    const nextNotification = scheduledNotification;
    scheduledNotification = null;
    scheduledRefresh = null;
    requestSnapshot(nextNotification).catch(reportError);
  }, 400);
}
async function folderFor(messageId, type) {
  const message = await messenger.messages.get(messageId);
  const account = (await messenger.accounts.list(true)).find(value => value.id === message.folder.accountId);
  const all = []; inboxes(account ? account.folders : [], all);
  const walk = folders => { for (const folder of folders || []) { if (folder.type === type) return folder; const found = walk(folder.subFolders); if (found) return found; } return null; };
  return walk(account ? account.folders : []);
}
async function perform(request) {
  const id = request.messageId;
  if (request.action === "open") return messenger.messageDisplay.open({ messageId: id, active: true });
  if (request.action === "reply") return messenger.compose.beginReply(id, "replyToSender");
  if (request.action === "delete") return messenger.messages.delete([id], { isUserAction: true });
  if (request.action === "spam") {
    await messenger.messages.update(id, { junk: true });
    const junk = await folderFor(id, "junk");
    if (junk) await messenger.messages.move([id], junk.id, { isUserAction: true });
    return;
  }
  throw new Error("Unsupported action");
}
function connect() {
  port = messenger.runtime.connectNative(HOST);
  port.onMessage.addListener(async request => {
    if (request.type === "ready") {
      try { await requestSnapshot(initialized ? null : { eventId: ++eventId, initial: true }); }
      catch (error) { reportError(error); }
      initialized = true;
      return;
    }
    if (request.type !== "action") return;
    try { await perform(request); await requestSnapshot(null); post({ type: "action-result", requestId: request.requestId, ok: true }); }
    catch (error) { post({ type: "action-result", requestId: request.requestId, ok: false, error: String(error.message || error) }); }
  });
  port.onDisconnect.addListener(() => setTimeout(connect, 5000));
  post({ type: "ready" });
}
messenger.messages.onNewMailReceived.addListener(async (folder, messages) => {
  if (folder.type !== "inbox") return;
  const first = messages.messages && messages.messages[0];
  scheduleSnapshot({ eventId: ++eventId, count: (messages.messages || []).length, first: first ? { author: first.author, subject: first.subject } : null });
}, false);
messenger.messages.onUpdated.addListener((message, changed) => {
  if (message.folder && message.folder.type === "inbox" && ("read" in changed || "flagged" in changed)) scheduleSnapshot(null);
});
messenger.messages.onMoved.addListener((originalMessages, movedMessages) => {
  forgetAttachments(originalMessages);
  forgetAttachments(movedMessages);
  scheduleSnapshot(null);
});
messenger.messages.onDeleted.addListener(messages => {
  forgetAttachments(messages);
  scheduleSnapshot(null);
});
if (messenger.messages.onCopied) messenger.messages.onCopied.addListener(() => scheduleSnapshot(null));
setInterval(() => requestSnapshot(null).catch(reportError), 600000);
connect();
