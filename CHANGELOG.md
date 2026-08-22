# Changelog

All notable changes to Thunderbird Mail Checker are documented here.

## [0.1.7] - 2026-08-22

### Fixed

- Replaced preview-mail action controls with native QuickShell buttons so Reply, Delete, and Spam remain clickable in the panel.

### Changed

- The inbox list keeps Thunderbird's account order when unread counts change, so expanded accounts no longer exchange places after deleting or reading a message.

### Companion MailExtension

- Version 0.1.3 is included. It is packaged as `thunderbird/thunderbird-mail-checker.xpi`.

## [0.1.5] - 2026-08-21

### Security

- Rendered Thunderbird-controlled account labels, senders, and subjects as plain text.
- Removed delayed action delivery: Reply, Delete, and Spam now fail safely while Thunderbird is unavailable instead of being queued for a later restart.

### Changed

- The companion MailExtension source manifest is kept outside the repository's root `manifest.json` path and is staged only while building the XPI, matching Okomart's supported repository layout.

## [0.1.2] - 2026-08-20

### Added

- Unread Inbox count in the QuickShell bar and per-account previews of the five newest unread messages.
- Reply, Delete, and Spam actions through Thunderbird's MailExtension APIs.
- Full and Private notification modes, plus System-language and Thunderbird-language display choices.

### Changed

- Clicking a preview opens its message in Thunderbird and focuses Thunderbird's workspace.
