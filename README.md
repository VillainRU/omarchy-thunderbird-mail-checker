# Thunderbird Mail Checker

An Omarchy QuickShell plugin that shows the total number of unread Inbox messages, lists only mailboxes with unread mail, and reveals the five newest unread messages per mailbox. The message controls use Thunderbird's own APIs: reply opens a normal reply composer, delete follows the account's Trash behavior, and spam marks the message as junk then moves it to the account Junk folder when it exists.

## Privacy and security

The plugin has no network backend and never reads Thunderbird passwords, OAuth tokens, or message bodies. Its companion MailExtension sends only the metadata needed by the panel (account label, sender, subject, date, star, attachment flag and internal message id) to a local Unix socket and to a mode-0600 local cache. Mailbox labels, senders, and subjects are rendered only as plain text. Actions are sent only to a live Thunderbird bridge and are never queued across restarts. Thunderbird's extension permission screen is the single authorization point for mailbox access.

## Install

```bash
omarchy plugin add https://github.com/VillainRU/omarchy-thunderbird-mail-checker.git
omarchy plugin enable io.github.villainru.thunderbird-mail-checker
~/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker setup
```

Then open Thunderbird → Add-ons and Themes → Extensions → gear menu → **Install Add-on From File**, and select the `thunderbird/thunderbird-mail-checker.xpi` path printed by `setup`. Accept Thunderbird's listed permissions and restart Thunderbird once. The widget defaults to the right section; move it with `omarchy bar move io.github.villainru.thunderbird-mail-checker --section right` if desired.

The popup always follows Thunderbird's UI language. Its header has a notification-mode switch: Full shows the sender and subject for one message, while Private hides them. New arrivals generate one summary notification; the first connection also summarizes existing unread mail as requested. Omarchy's global Silence Notifications mode always suppresses these alerts.

## Updates

Published changes are listed in [CHANGELOG.md](CHANGELOG.md). The plugin version and companion MailExtension version are maintained separately; the current versions are shown in the root `manifest.json` and the packaged `thunderbird/thunderbird-mail-checker.xpi` respectively.

## Remove

1. In Thunderbird, open **Add-ons and Themes** and remove **Thunderbird Mail Checker**.
2. Remove the Omarchy plugin:

   ```bash
   omarchy plugin disable io.github.villainru.thunderbird-mail-checker
   omarchy plugin remove io.github.villainru.thunderbird-mail-checker
   ```

3. Remove only the native-messaging registration created during setup:

   ```bash
   rm -f ~/.mozilla/native-messaging-hosts/io.github.villainru.thunderbird_mail_checker.json
   ```

This does not delete any Thunderbird messages or account data.

## Development

`make xpi` packs the companion add-on. `make check` validates JSON, Python syntax, and runs protocol tests. The native host is standard-library Python 3 and needs no package installation.
