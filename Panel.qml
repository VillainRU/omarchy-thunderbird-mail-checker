import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.villainru.thunderbird-mail-checker"
  ipcTarget: "io.github.villainru.thunderbird-mail-checker"

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var snapshot: ({ accounts: [], unreadTotal: 0 })
  property string languageSource: String(setting("languageSource", "system"))
  property string privacyMode: String(setting("privacyMode", "full"))
  property bool languageMenuOpen: false
  property bool privacyMenuOpen: false
  property int notifiedEvent: 0
  property var expandedAccounts: ({})
  readonly property string lang: Model.localeCode(languageSource, Qt.locale().name, snapshot.thunderbirdLanguage)
  readonly property int unreadCount: Number(snapshot.unreadTotal || 0)
  readonly property string tooltip: unreadCount > 0 ? unreadCount + " " + Model.text(lang, "unread") : Model.text(lang, "noUnread")
  readonly property var accounts: snapshot.accounts || []
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker"

  function tr(key) { return Model.text(lang, key) }
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }
  function chooseLanguage(source) {
    languageSource = source
    languageMenuOpen = false
    privacyMenuOpen = false
    persistSettings({ languageSource: source })
  }
  function choosePrivacyMode(mode) {
    privacyMode = mode
    languageMenuOpen = false
    privacyMenuOpen = false
    persistSettings({ privacyMode: mode })
  }
  function open() { controller.show(); refresh() }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { root.close() }
  function refresh() { if (!statusProc.running) statusProc.running = true }
  function applySnapshot(raw) {
    var parsed = Model.safeJson(raw, null)
    if (!parsed || typeof parsed !== "object") return
    snapshot = parsed
    var event = Number(parsed.notification && parsed.notification.eventId || 0)
    if (event > notifiedEvent) {
      notifiedEvent = event
      var notification = parsed.notification || {}
      notificationProc.command = ["omarchy-notification-send", notificationText(notification)]
      notificationProc.running = true
    }
  }
  function notificationText(notification) {
    var count = Number(notification.count || 0)
    if (privacyMode === "private") return tr("newMailPrivate") + (count > 1 ? ": " + count : "")
    var first = notification.first || {}
    if (count > 1) return tr("newMail") + ": " + count
    return (first.author || tr("newMail")) + " — " + (first.subject || "")
  }
  function runAction(action, message) {
    if (!message || !message.id || actionProc.running) return
    actionProc.command = [helper, "action", action, String(message.id)]
    actionProc.running = true
  }
  function accountKey(account, index) {
    return String(account.email || account.name || index)
  }
  function accountExpanded(account, index) {
    return Boolean(expandedAccounts[accountKey(account, index)])
  }
  function toggleAccount(index) {
    if (!accounts[index]) return
    var next = {}
    for (var key in expandedAccounts) next[key] = expandedAccounts[key]
    var key = accountKey(accounts[index], index)
    next[key] = !Boolean(next[key])
    expandedAccounts = next
  }

  Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  Process {
    id: statusProc
    command: [root.helper, "status"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function(exitCode) { if (exitCode === 0) root.applySnapshot(statusOut.text) }
  }
  Process { id: actionProc; onExited: root.refresh() }
  Process { id: notificationProc }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(510))
    contentHeight: popup.fittedContentHeight(content.implicitHeight, Style.space(620))

    Flickable {
      id: mailScroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: content
        width: mailScroll.width
        spacing: Style.space(10)

        Item {
          width: parent.width
          height: Math.max(titleText.implicitHeight, controls.height)
          z: root.languageMenuOpen || root.privacyMenuOpen ? 100 : 0
          Text {
            id: titleText
            text: root.tr("title")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            anchors.left: parent.left
            anchors.right: controls.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
          }
          Row {
            id: controls
            width: Style.space(246)
            height: Style.space(30)
            spacing: Style.space(6)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              id: languageSelector
              width: Style.space(148)
              height: Style.space(30)
              radius: Style.cornerRadius; color: "transparent"; border.color: Color.accent; border.width: 1
              Text { anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(20); anchors.verticalCenter: parent.verticalCenter; text: root.languageSource === "thunderbird" ? root.tr("thunderbirdLanguage") : root.tr("systemLanguage"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
              Text { text: ""; color: Color.accent; font.family: root.bar.fontFamily; anchors.right: parent.right; anchors.rightMargin: Style.space(7); anchors.verticalCenter: parent.verticalCenter }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.languageMenuOpen = !root.languageMenuOpen; root.privacyMenuOpen = false } }
              Rectangle {
                visible: root.languageMenuOpen; z: 10; anchors.top: parent.bottom; anchors.topMargin: Style.space(4); width: parent.width; height: languageChoices.implicitHeight + Style.space(6); radius: Style.cornerRadius; color: Color.background; border.color: Color.accent; border.width: 1
                Column {
                  id: languageChoices
                  anchors.left: parent.left; anchors.right: parent.right; anchors.margins: Style.space(3)
                  Repeater {
                    model: [{key:"system", label:root.tr("systemLanguage")}, {key:"thunderbird", label:root.tr("thunderbirdLanguage")}]
                    delegate: Rectangle {
                      required property var modelData
                      width: parent.width; height: Style.space(28); radius: Style.cornerRadius
                      color: choiceTap.containsMouse ? Color.accent : "transparent"
                      Text { anchors.fill: parent; anchors.leftMargin: Style.space(7); verticalAlignment: Text.AlignVCenter; text: modelData.label; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                      MouseArea { id: choiceTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function(mouse) { mouse.accepted = true; root.chooseLanguage(modelData.key) } }
                    }
                  }
                }
              }
            }
            Rectangle {
              id: privacySelector
              width: Style.space(92)
              height: Style.space(30)
              radius: Style.cornerRadius; color: "transparent"; border.color: Color.accent; border.width: 1
              Text { anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(20); anchors.verticalCenter: parent.verticalCenter; text: root.privacyMode === "private" ? root.tr("private") : root.tr("full"); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
              Text { text: ""; color: Color.accent; font.family: root.bar.fontFamily; anchors.right: parent.right; anchors.rightMargin: Style.space(7); anchors.verticalCenter: parent.verticalCenter }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.privacyMenuOpen = !root.privacyMenuOpen; root.languageMenuOpen = false } }
              Rectangle {
                visible: root.privacyMenuOpen; z: 10; anchors.top: parent.bottom; anchors.topMargin: Style.space(4); width: parent.width; height: privacyChoices.implicitHeight + Style.space(6); radius: Style.cornerRadius; color: Color.background; border.color: Color.accent; border.width: 1
                Column {
                  id: privacyChoices
                  anchors.left: parent.left; anchors.right: parent.right; anchors.margins: Style.space(3)
                  Repeater {
                    model: [{key:"full", label:root.tr("full")}, {key:"private", label:root.tr("private")}]
                    delegate: Rectangle {
                      required property var modelData
                      width: parent.width; height: Style.space(28); radius: Style.cornerRadius
                      color: privacyTap.containsMouse ? Color.accent : "transparent"
                      Text { anchors.fill: parent; anchors.leftMargin: Style.space(7); verticalAlignment: Text.AlignVCenter; text: modelData.label; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
                      MouseArea { id: privacyTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: function(mouse) { mouse.accepted = true; root.choosePrivacyMode(modelData.key) } }
                    }
                  }
                }
              }
            }
          }
        }

        Text {
          visible: root.snapshot.connected === false
          text: root.snapshot.setupRequired ? root.tr("setup") : root.tr("offline")
          color: Qt.darker(root.bar.foreground, 1.45)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }
        Text {
          visible: root.accounts.length === 0 && root.snapshot.connected !== false
          text: root.tr("noUnread")
          color: Qt.darker(root.bar.foreground, 1.45)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
        }

        Repeater {
          width: parent.width
          model: root.accounts
          delegate: Column {
            required property var modelData
            required property int index
            width: parent.width
            spacing: Style.space(5)

            Rectangle {
              width: parent.width
              height: Style.space(34)
              color: accountTap.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"
              radius: Style.cornerRadius
              Item {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                Text { id: expandIcon; text: root.accountExpanded(modelData, index) ? "" : ""; color: root.bar.foreground; font.family: root.bar.fontFamily; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Text { id: envelopeIcon; text: "󰇮"; color: Color.accent; font.family: root.bar.fontFamily; anchors.left: expandIcon.right; anchors.leftMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                Text { id: badge; width: Math.max(Style.space(26), implicitWidth + Style.space(8)); height: Style.space(20); text: String(modelData.unreadCount || 0); textFormat: Text.PlainText; color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; Rectangle { anchors.fill: parent; z: -1; radius: height / 2; color: "transparent"; border.color: Color.accent; border.width: 1 } }
                Text { text: modelData.email || modelData.name; textFormat: Text.PlainText; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true; anchors.left: envelopeIcon.right; anchors.leftMargin: Style.space(8); anchors.right: badge.left; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
              }
              MouseArea { id: accountTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleAccount(index) }
            }

            Repeater {
              width: parent.width
              model: root.accountExpanded(modelData, index) ? (modelData.messages || []) : []
              delegate: Rectangle {
                id: mailRow
                required property var modelData
                width: parent.width - Style.space(8)
                x: Style.space(8)
                height: Style.space(51)
                radius: Style.cornerRadius
                color: mailTap.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"
                Item {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  Column {
                    anchors.left: parent.left
                    anchors.right: actionButtons.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text { text: modelData.author || ""; textFormat: Text.PlainText; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight; width: parent.width }
                    Text { text: (modelData.flagged ? " " : "") + (modelData.hasAttachments ? "󰆉 " : "") + (modelData.subject || ""); textFormat: Text.PlainText; color: Qt.darker(root.bar.foreground, 1.35); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                  }
                  Row {
                    id: actionButtons
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    z: 2
                    spacing: Style.space(5)
                    Repeater {
                      model: [
                        { icon: "↩", action: "reply", tip: root.tr("reply") },
                        { icon: "⌫", action: "delete", tip: root.tr("delete") },
                        { icon: "!", action: "spam", tip: root.tr("spam") }
                      ]
                      delegate: Rectangle {
                        required property var modelData
                        width: Style.space(25)
                        height: width
                        radius: Style.cornerRadius
                        color: actionTap.pressed ? Color.accent : (actionTap.containsMouse ? Qt.darker(Color.accent, 1.45) : Qt.darker(Color.accent, 2.5))
                        border.color: Color.accent
                        border.width: 1
                        scale: actionTap.pressed ? 0.86 : (actionTap.containsMouse ? 1.06 : 1.0)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        Text { anchors.centerIn: parent; text: modelData.icon; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                        MouseArea {
                          id: actionTap
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.runAction(modelData.action, mailRow.modelData)
                        }
                      }
                    }
                  }
                  MouseArea {
                    id: mailTap
                    anchors.left: parent.left
                    anchors.right: actionButtons.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    z: 1
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runAction("open", mailRow.modelData)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
