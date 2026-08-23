.pragma library

function safeJson(raw, fallback) {
  try { return JSON.parse(String(raw || "")) } catch (error) { return fallback }
}

function localeCode(source, systemLocale, thunderbirdLocale) {
  var raw = source === "thunderbird" ? thunderbirdLocale : systemLocale
  return String(raw || "en").toLowerCase().indexOf("ru") === 0 ? "ru" : "en"
}

function text(lang, key) {
  var catalog = {
    en: {
      title: "Thunderbird Mail Checker", systemLanguage: "System language",
      titleBefore: "", titleThunderbird: "Thunderbird", titleAfter: " Mail Checker",
      thunderbirdLanguage: "Thunderbird language", full: "Full", private: "Private",
      unread: "unread", noUnread: "No unread Inbox mail", offline: "Thunderbird is offline",
      reply: "Reply", delete: "Move to Trash", spam: "Mark as spam", attachment: "Attachment",
      important: "Important", setup: "Run setup to connect Thunderbird", newMail: "New mail",
      newMailPrivate: "New mail in Thunderbird", stale: "Last update", restartBridge: "Restart Thunderbird bridge"
    },
    ru: {
      title: "Почта Thunderbird", systemLanguage: "Язык системы",
      titleBefore: "Почта ", titleThunderbird: "Thunderbird", titleAfter: "",
      thunderbirdLanguage: "Язык Thunderbird", full: "Полный", private: "Приватный",
      unread: "непрочитанных", noUnread: "Нет непрочитанных во Входящих", offline: "Thunderbird не подключён",
      reply: "Ответить", delete: "В Корзину", spam: "В Спам", attachment: "Вложение",
      important: "Важное", setup: "Выполните настройку подключения Thunderbird", newMail: "Новые письма",
      newMailPrivate: "Новое письмо в Thunderbird", stale: "Последнее обновление", restartBridge: "Перезапустить мост Thunderbird"
    }
  }
  return (catalog[lang] || catalog.en)[key] || key
}

function initials(value) {
  var clean = String(value || "").replace(/<.*>/, "").trim()
  return clean ? clean.charAt(0).toUpperCase() : "✉"
}

function timeLabel(timestamp, locale) {
  if (!timestamp) return ""
  try { return new Date(timestamp).toLocaleString(locale || undefined, { day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit" }) }
  catch (error) { return "" }
}
