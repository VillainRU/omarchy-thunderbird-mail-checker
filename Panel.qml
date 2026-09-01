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
  property string privacyMode: String(setting("privacyMode", "full"))
  property int notifiedEvent: 0
  property var expandedAccounts: ({})
  readonly property string lang: Model.localeCode("thunderbird", "", snapshot.thunderbirdLanguage)
  readonly property int unreadCount: Number(snapshot.unreadTotal || 0)
  readonly property string tooltip: unreadCount > 0 ? unreadCount + " " + Model.text(lang, "unread") : Model.text(lang, "noUnread")
  readonly property var accounts: snapshot.accounts || []
  readonly property bool bridgeActive: snapshot.connected === true
  readonly property color bridgeColor: bridgeActive ? "#6dca76" : Color.urgent
  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.villainru.thunderbird-mail-checker/bin/thunderbird-mail-checker"
  readonly property string socketPath: String(Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/thunderbird-mail-checker.sock"

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
  function choosePrivacyMode(mode) {
    privacyMode = mode
    persistSettings({ privacyMode: mode })
  }
  function open() { controller.show(); refresh() }
  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { root.close() }
  function refresh() { if (!bridgeSocket.connected) bridgeSocket.connected = true }
  function restartBridge() {
    if (restartProc.running) return
    restartProc.command = [helper, "restart"]
    restartProc.running = true
  }
  function applySnapshot(raw) {
    var parsed = typeof raw === "string" ? Model.safeJson(raw, null) : raw
    if (!parsed || typeof parsed !== "object") return
    snapshot = parsed
    var event = Number(parsed.notification && parsed.notification.eventId || 0)
    if (event > notifiedEvent) {
      notifiedEvent = event
      var notification = parsed.notification || {}
      // omarchy-notification-send defaults to the privileged "omarchy-action"
      // identity, whose user-action confirmations intentionally bypass DND.
      // Mail is an ordinary application notification and must follow Omarchy's
      // global Silence Notifications setting.
      notificationProc.command = ["omarchy-notification-send", "--app-name", "Thunderbird Mail Checker", notificationText(notification)]
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

  Socket {
    id: bridgeSocket
    path: root.socketPath
    parser: SplitParser {
      onRead: function(line) {
        var message = Model.safeJson(line, null)
        if (message && message.type === "status") root.applySnapshot(message.status)
      }
    }
    onConnectedChanged: {
      if (connected) {
        write('{"type":"subscribe"}\n')
        flush()
      } else {
        reconnectTimer.restart()
      }
    }
  }
  Component.onCompleted: bridgeSocket.connected = true
  Timer { id: reconnectTimer; interval: 2000; repeat: false; onTriggered: bridgeSocket.connected = true }

  Process { id: actionProc }
  Process { id: restartProc; onExited: bridgeRefreshTimer.restart() }
  Process { id: notificationProc }
  Timer { id: bridgeRefreshTimer; interval: 5500; repeat: false; onTriggered: root.refresh() }

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(570))
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
          height: Math.max(identityRow.implicitHeight, controls.implicitHeight)

          Row {
            id: identityRow
            anchors.left: parent.left
            anchors.right: controls.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(5)

            Button {
              id: bridgeButton
              width: Style.space(30)
              height: width
              iconText: "󰇮"
              tooltipText: root.tr("restartBridge")
              foreground: Color.accent
              accent: Color.accent
              fontFamily: root.bar.fontFamily
              iconSize: Style.font.body
              horizontalPadding: 0
              verticalPadding: 0
              bordered: false
              onClicked: root.restartBridge()

              Text {
                text: "↻"
                color: Color.accent
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.right: parent.right
                anchors.rightMargin: Style.space(1)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(1)

                NumberAnimation on rotation {
                  running: restartProc.running
                  from: 0
                  to: 360
                  duration: 900
                  loops: Animation.Infinite
                }

                onRotationChanged: if (!restartProc.running && rotation !== 0) rotation = 0
              }
            }

            Text {
              text: "Thunderbird"
              textFormat: Text.PlainText
              color: root.bridgeColor
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
              width: Math.min(implicitWidth, identityRow.width - bridgeButton.width - identityRow.spacing)
            }
          }

          Row {
            id: controls
            spacing: Style.space(6)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            ButtonGroup {
              id: privacyToggle
              options: [
                { value: "full", label: "Full" },
                { value: "private", label: "Private" }
              ]
              value: root.privacyMode
              foreground: root.bar.foreground
              background: "transparent"
              accent: Color.accent
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              focusable: false
              spacing: Style.space(2)
              onChanged: function(value) { root.choosePrivacyMode(value) }
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.55)
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
                color: messageHover.hovered ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"
                Item {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  Item {
                    id: messageOpenArea
                    anchors.left: parent.left
                    anchors.right: actionButtons.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Style.space(8)

                    Column {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(1)
                      Text { text: modelData.author || ""; textFormat: Text.PlainText; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight; width: parent.width }
                      Text { text: (modelData.flagged ? " " : "") + (modelData.hasAttachments ? "󰆉 " : "") + (modelData.subject || ""); textFormat: Text.PlainText; color: Qt.darker(root.bar.foreground, 1.35); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight; width: parent.width }
                    }

                    HoverHandler {
                      id: messageHover
                      cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                      acceptedButtons: Qt.LeftButton
                      gesturePolicy: TapHandler.DragThreshold
                      onTapped: root.runAction("open", mailRow.modelData)
                    }
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
                      delegate: Button {
                        required property var modelData
                        width: Style.space(25)
                        height: width
                        iconText: modelData.icon
                        tooltipText: modelData.tip
                        foreground: root.bar.foreground
                        accent: Color.accent
                        fontFamily: root.bar.fontFamily
                        iconSize: Style.font.body
                        horizontalPadding: 0
                        verticalPadding: 0
                        bordered: true
                        onClicked: root.runAction(modelData.action, mailRow.modelData)
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
  }
}
