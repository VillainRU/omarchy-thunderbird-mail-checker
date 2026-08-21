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
  implicitWidth: button.implicitWidth
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
    anchors.fill: parent
    bar: root.bar
    text: "󰇮"
    slotSize: Style.bar.statusSlot
    tooltipText: panelLoader.item ? panelLoader.item.tooltip : "Thunderbird Mail Checker"

    Text {
      visible: panelLoader.item && panelLoader.item.unreadCount > 0
      text: panelLoader.item ? String(panelLoader.item.unreadCount) : ""
      anchors.left: parent.horizontalCenter
      anchors.leftMargin: Style.space(5)
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -Style.space(7)
      color: Color.accent
      font.family: root.bar ? root.bar.fontFamily : "sans-serif"
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    onPressed: function(button) {
      if (button === Qt.LeftButton && panelLoader.item) panelLoader.item.toggle()
      else if (button === Qt.MiddleButton && panelLoader.item) panelLoader.item.refresh()
    }
  }
}
