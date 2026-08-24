# Changelog

All notable changes to Thunderbird Mail Checker are documented here.

## [0.1.16] - Unreleased

### Fixed

- Keep every opened selector option inside the Flickable hit area so the Thunderbird-language option is clickable.

## [0.1.15] - Unreleased

### Fixed

- Keep the header aligned to the top while selector menus use the panel's reserved space below it.

## [0.1.14] - Unreleased

### Changed

- Keep a fixed minimum panel height for short or empty mail lists, so opening a selector no longer resizes the window.

## [0.1.13] - Unreleased

### Fixed

- Keep an opened language or notification-mode menu inside the panel when no unread messages are listed.

## [0.1.12] - Unreleased

### Changed

- Widened the panel so the title and header controls do not overlap.

## [0.1.11] - Unreleased

### Fixed

- Kept the notification-mode selector within the panel by matching the header control container width to its contents.

## [0.1.10] - Unreleased

### Fixed

- Replaced split title translation fragments with one title so translation keys can never appear in the panel.

### Changed

- Moved the bridge restart control before the language selector and simplified its icon.

## [0.1.9] - Unreleased

### Fixed

- The restart control can replace an already running bridge from a version that predates the restart command.

## [0.1.8] - Unreleased

### Added

- A green/red bridge-status indicator on the `Thunderbird` title and a restart button for the local Thunderbird bridge.

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
