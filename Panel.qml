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
  readonly property string lang: Model.localeCode(languageSource, Qt.locale().name, snapshot.thunderbirdLanguage)
  readonly property int unreadCount: Number(snapshot.unreadTotal || 0)
  readonly property string tooltip: unreadCount > 0 ? unreadCount + " " + Model.text(lang, "unread") : Model.text(lang, "noUnread")
  readonly property var accounts: snapshot.accounts || []
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker"

  function tr(key) { return Model.text(lang, key) }
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
  function toggleAccount(index) {
    var copy = accounts.slice()
    if (!copy[index]) return
    copy[index].expanded = !copy[index].expanded
    snapshot.accounts = copy
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
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: content
        width: popup.width - popup.padding * 2
        spacing: Style.space(10)

        Item {
          width: parent.width
          height: Math.max(titleText.implicitHeight, controls.implicitHeight)
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
                visible: root.languageMenuOpen; z: 10; anchors.top: parent.bottom; anchors.topMargin: Style.space(4); width: parent.width; height: languageChoices.implicitHeight + Style.space(6); radius: Style.cornerRadius; color: root.bar.background; border.color: Color.accent; border.width: 1
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
                      MouseArea { id: choiceTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.languageSource = modelData.key; root.languageMenuOpen = false } }
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
                visible: root.privacyMenuOpen; z: 10; anchors.top: parent.bottom; anchors.topMargin: Style.space(4); width: parent.width; height: privacyChoices.implicitHeight + Style.space(6); radius: Style.cornerRadius; color: root.bar.background; border.color: Color.accent; border.width: 1
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
                      MouseArea { id: privacyTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.privacyMode = modelData.key; root.privacyMenuOpen = false } }
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
                Text { id: expandIcon; text: modelData.expanded ? "" : ""; color: root.bar.foreground; font.family: root.bar.fontFamily; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter }
                Text { id: envelopeIcon; text: "󰇮"; color: Color.accent; font.family: root.bar.fontFamily; anchors.left: expandIcon.right; anchors.leftMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter }
                Text { id: badge; width: Math.max(Style.space(26), implicitWidth + Style.space(8)); height: Style.space(20); text: String(modelData.unreadCount || 0); color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; Rectangle { anchors.fill: parent; z: -1; radius: height / 2; color: "transparent"; border.color: Color.accent; border.width: 1 } }
                Text { text: (modelData.email || modelData.name) + "  (" + String(modelData.unreadCount || 0) + ")"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; font.bold: true; anchors.left: envelopeIcon.right; anchors.leftMargin: Style.space(8); anchors.right: badge.left; anchors.rightMargin: Style.space(8); anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
              }
              MouseArea { id: accountTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleAccount(index) }
            }

            Repeater {
              model: modelData.expanded ? (modelData.messages || []) : []
              delegate: Rectangle {
                required property var modelData
                width: parent.width - Style.space(8)
                x: Style.space(8)
                height: Style.space(51)
                radius: Style.cornerRadius
                color: mailTap.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"
                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)
                  Text { text: Model.initials(modelData.author); color: Color.accent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; width: Style.space(20); anchors.verticalCenter: parent.verticalCenter }
                  Column {
                    width: parent.width - actionButtons.implicitWidth - Style.space(42)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text { text: modelData.author || ""; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight; width: parent.width }
                    Text { text: (modelData.flagged ? " " : "") + (modelData.hasAttachments ? "󰆉 " : "") + (modelData.subject || ""); color: Qt.darker(root.bar.foreground, 1.35); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                  }
                  Row {
                    id: actionButtons
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(3)
                    Repeater {
                      model: [{icon:"󰏫", action:"reply", tip:root.tr("reply")},{icon:"󰆴",action:"delete",tip:root.tr("delete")},{icon:"󰒃",action:"spam",tip:root.tr("spam")}]
                      delegate: Rectangle {
                        required property var modelData
                        width: Style.space(24); height: width; radius: Style.cornerRadius
                        color: actionTap.containsMouse ? Color.accent : "transparent"
                        Text { anchors.centerIn: parent; text: modelData.icon; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body }
                        MouseArea { id: actionTap; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runAction(modelData.action, parent.parent.parent.parent.modelData) }
                      }
                    }
                  }
                }
                MouseArea { id: mailTap; anchors.fill: parent; z: -1; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.runAction("open", modelData) }
              }
            }
          }
        }
      }
    }
  }
}
