# Thunderbird Mail Checker

Unread Thunderbird mail in the Omarchy bar — fast, private, and event-driven.

[English](#english) · [Русский](#русский)

![Thunderbird Mail Checker panel](preview.png)

**Versions:** Omarchy plugin `0.1.24` · MailExtension `0.1.5` · Thunderbird `128+`

## English

### Highlights

- Unread totals and five recent messages per account.
- Open, reply, delete, and mark-as-spam actions through Thunderbird APIs.
- Full or privacy-friendly notifications that respect Omarchy's silence mode.
- Automatic recovery when Thunderbird starts or its native bridge restarts.
- No polling process, remote service, credentials, or message bodies.

### Install

> [!IMPORTANT]
> The Omarchy widget and Thunderbird MailExtension are installed separately.

```bash
omarchy plugin add https://github.com/VillainRU/omarchy-thunderbird-mail-checker.git --enable
~/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker setup
```

The setup command registers the native bridge and prints the bundled XPI path. In Thunderbird, open **Add-ons and Themes → Extensions → gear menu → Install Add-on From File**, select `thunderbird/thunderbird-mail-checker.xpi`, approve its permissions, and restart Thunderbird once.

### Update and diagnose

```bash
omarchy plugin update io.github.villainru.thunderbird-mail-checker --yes
~/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker setup
~/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker status
```

The widget reconnects every two seconds while Thunderbird is unavailable. Reinstall the XPI only when [CHANGELOG.md](CHANGELOG.md) lists a newer MailExtension version.

## Русский

Показывает непрочитанные письма Thunderbird прямо в панели Omarchy: общий счётчик, аккаунты и пять последних писем для каждого ящика.

### Возможности

- Открытие письма с переходом на рабочее пространство Thunderbird.
- Ответ, удаление и пометка как спам через штатный API Thunderbird.
- Обычные и приватные уведомления с учётом режима тишины Omarchy.
- Автоматическое восстановление связи после запуска или перезапуска Thunderbird.
- Без внешних серверов, доступа к паролям и чтения содержимого писем.

### Установка

```bash
omarchy plugin add https://github.com/VillainRU/omarchy-thunderbird-mail-checker.git --enable
~/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker setup
```

Команда `setup` зарегистрирует локальный мост и покажет путь к XPI. В Thunderbird откройте **Дополнения и темы → Расширения → меню с шестерёнкой → Установить дополнение из файла**, выберите `thunderbird/thunderbird-mail-checker.xpi`, подтвердите разрешения и один раз перезапустите Thunderbird.

### Обновление и диагностика

```bash
omarchy plugin update io.github.villainru.thunderbird-mail-checker --yes
~/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker setup
~/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker status
```

Красный индикатор означает, что мост недоступен. Проверьте, что Thunderbird запущен и MailExtension включено; виджет продолжит попытки подключения автоматически.

## Architecture and privacy

The MailExtension reacts to mail events and sends metadata through a native-messaging host and a user-only Unix socket. Cached panel state is mode `0600`. Actions are never queued while Thunderbird is offline.

## Development

```bash
make check   # manifests, syntax, unit and protocol regressions
make xpi     # rebuild the companion MailExtension package
```

See [AGENTS.md](AGENTS.md) for contribution guidelines and [CHANGELOG.md](CHANGELOG.md) for release notes.
