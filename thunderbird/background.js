const HOST = "io.github.villainru.thunderbird_mail_checker";
let port;
let initialized = false;
let eventId = 0;

function post(payload) { try { port.postMessage(payload); } catch (error) { console.error(error); } }
function inboxes(folders, result) {
  for (const folder of folders || []) {
    if (folder.type === "inbox") result.push(folder);
    inboxes(folder.subFolders, result);
  }
}
async function attachmentFlag(id) {
  try { return (await messenger.messages.listAttachments(id)).length > 0; } catch (error) { return false; }
}
async function unreadInFolder(folder) {
  const messages = [];
  let page = await messenger.messages.list(folder.id);
  while (page) {
    messages.push(...page.messages.filter(message => !message.read));
    page = page.id ? await messenger.messages.continueList(page.id) : null;
  }
  return messages;
}
async function snapshot(notification) {
  const accounts = await messenger.accounts.list(true);
  const visible = [];
  let total = 0;
  for (const account of accounts) {
    const folders = []; inboxes(account.folders, folders);
    const unread = (await Promise.all(folders.map(unreadInFolder))).flat();
    if (!unread.length) continue;
    unread.sort((a, b) => Number(b.date) - Number(a.date));
    const preview = await Promise.all(unread.slice(0, 5).map(async message => ({
      id: message.id, author: message.author, subject: message.subject, date: message.date,
      flagged: Boolean(message.flagged), hasAttachments: await attachmentFlag(message.id)
    })));
    const identity = account.identities && account.identities[0];
    visible.push({ accountId: account.id, name: account.name, email: identity ? identity.email : account.name, unreadCount: unread.length, messages: preview, expanded: false });
    total += unread.length;
  }
  visible.sort((a, b) => b.unreadCount - a.unreadCount || a.email.localeCompare(b.email));
  if (notification && notification.initial) {
    notification.count = total;
    notification.first = visible.length && visible[0].messages.length ? visible[0].messages[0] : null;
  }
  post({ type: "snapshot", status: { connected: true, updatedAt: Date.now(), thunderbirdLanguage: messenger.i18n.getUILanguage(), unreadTotal: total, accounts: visible, notification: notification || null } });
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
    if (request.type === "ready") { await snapshot(initialized ? null : { eventId: ++eventId, initial: true }); initialized = true; return; }
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
  await snapshot({ eventId: ++eventId, count: (messages.messages || []).length, first: first ? { author: first.author, subject: first.subject } : null });
}, false);
setInterval(() => snapshot(null).catch(console.error), 60000);
connect();
