const HOST = "io.github.villainru.thunderbird_mail_checker";
let port;
let initialized = false;
let eventId = 0;
let sortedQuerySupport;

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
  diagnostics.attachmentLookups += 1;
  try { return (await messenger.messages.listAttachments(id)).length > 0; } catch (error) { return false; }
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
    query.sortType = "date";
    query.sortOrder = "descending";
    query.messagesPerPage = 5;
    const page = await messenger.messages.query(query);
    diagnostics.scannedMessages += page.messages.length;
    if (page.id) await messenger.messages.abortList(page.id);
    return { unreadCount, messages: page.messages.slice(0, 5) };
  }
  return { unreadCount, messages: await collectMessages(await messenger.messages.query(query), diagnostics) };
}
async function snapshot(notification) {
  const startedAt = Date.now();
  const diagnostics = { scannedMessages: 0, attachmentLookups: 0 };
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
      try { await snapshot(initialized ? null : { eventId: ++eventId, initial: true }); }
      catch (error) { reportError(error); }
      initialized = true;
      return;
    }
    if (request.type !== "action") return;
    try { await perform(request); await snapshot(null); post({ type: "action-result", requestId: request.requestId, ok: true }); }
    catch (error) { post({ type: "action-result", requestId: request.requestId, ok: false, error: String(error.message || error) }); }
  });
  port.onDisconnect.addListener(() => setTimeout(connect, 5000));
  post({ type: "ready" });
}
messenger.messages.onNewMailReceived.addListener(async (folder, messages) => {
  if (folder.type !== "inbox") return;
  const first = messages.messages && messages.messages[0];
  try { await snapshot({ eventId: ++eventId, count: (messages.messages || []).length, first: first ? { author: first.author, subject: first.subject } : null }); }
  catch (error) { reportError(error); }
}, false);
setInterval(() => snapshot(null).catch(reportError), 60000);
connect();
