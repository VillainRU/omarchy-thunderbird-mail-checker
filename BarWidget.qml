import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.villainru.thunderbird-mail-checker"

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool hasUnread: panelLoader.item && panelLoader.item.unreadCount > 0
  implicitWidth: button.implicitWidth + (hasUnread ? unreadLabel.implicitWidth + Style.space(4) : 0)
  implicitHeight: button.implicitHeight

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  BarIconButton {
    id: button
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: "󰇮"
    slotSize: Style.bar.statusSlot
    tooltipText: panelLoader.item ? panelLoader.item.tooltip : "Thunderbird Mail Checker"

    onPressed: function(button) {
      if (button === Qt.LeftButton && panelLoader.item) panelLoader.item.toggle()
      else if (button === Qt.MiddleButton && panelLoader.item) panelLoader.item.refresh()
    }
  }

  Text {
    id: unreadLabel
    visible: root.hasUnread
    text: panelLoader.item ? "(" + String(panelLoader.item.unreadCount) + ")" : ""
    anchors.left: button.right
    anchors.leftMargin: Style.space(2)
    anchors.verticalCenter: button.verticalCenter
    color: Color.accent
    font.family: root.bar ? root.bar.fontFamily : "sans-serif"
    font.pixelSize: Style.font.body
    font.bold: true
  }
}
