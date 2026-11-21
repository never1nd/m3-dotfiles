import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: pwrWin
    required property bool isOpen
    signal closeRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

    function runAction(cmd) {
        pwrWin.closeRequested()
        NiriState.runDetached(cmd)
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            openTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer { id: openTick; interval: 10; onTriggered: pwrWin.animOpen = true }
    Timer { id: closeDelay; interval: 220 }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-power-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component PowerCard: Rectangle {
        id: pc
        property string iconName: ""
        property string title: ""
        property string hint: ""
        property color baseBg: Theme.surfaceContainerHigh
        property color hoverBg: Theme.secondaryContainer
        property color baseIcon: Theme.primary
        property color hoverFg: Theme.fgSecondaryContainer
        property color baseFg: Theme.fgSurface
        property bool alwaysFilled: false
        signal triggered()

        Layout.fillWidth: true
        height: 108
        radius: pcA.pressed ? 14 : (pcA.containsMouse ? 24 : 20)
        color: pcA.containsMouse ? hoverBg : baseBg
        scale: pcA.pressed ? 0.94 : (pcA.containsMouse ? 1.03 : 1.0)

        Behavior on radius { SpringAnimation { spring: 5.2; damping: 0.35 } }
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.38 } }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            M3Icon {
                Layout.alignment: Qt.AlignHCenter
                name: pc.iconName
                size: 30
                filled: pc.alwaysFilled || pcA.containsMouse
                color: pcA.containsMouse ? pc.hoverFg : pc.baseIcon
            }

            M3Text {
                Layout.alignment: Qt.AlignHCenter
                role: "title"
                customSize: 13
                emphasized: pcA.containsMouse
                text: pc.title
                color: pcA.containsMouse ? pc.hoverFg : pc.baseFg
            }

            M3Text {
                Layout.alignment: Qt.AlignHCenter
                role: "label"
                customSize: 10
                text: pc.hint
                color: pcA.containsMouse ? Theme.alpha(pc.hoverFg, 0.80) : Theme.fgSurfaceVariant
            }
        }

        MouseArea {
            id: pcA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pc.triggered()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: pwrWin.closeRequested()
        Keys.onDigit1Pressed: pwrWin.runAction(["systemctl", "suspend"])
        Keys.onDigit2Pressed: pwrWin.runAction(["systemctl", "reboot"])
        Keys.onDigit3Pressed: pwrWin.runAction(["systemctl", "poweroff"])

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, pwrWin.animOpen ? 0.30 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea { anchors.fill: parent; onClicked: pwrWin.closeRequested() }

        Rectangle {
            id: sheet
            anchors.centerIn: parent
            anchors.verticalCenterOffset: pwrWin.animOpen ? 0 : 18
            width: 452
            implicitHeight: pwrCol.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: pwrWin.animOpen ? 1.0 : 0.0
            scale: pwrWin.animOpen ? 1.0 : 0.93

            Behavior on anchors.verticalCenterOffset { SpringAnimation { spring: 4.8; damping: 0.35; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.35; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: pwrCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 14

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 36; height: 36; radius: 13
                        color: Theme.tertiaryContainer
                        M3Icon {
                            anchors.centerIn: parent
                            name: "power_settings_new"
                            size: 20
                            filled: true
                            color: Theme.fgTertiaryContainer
                        }
                    }

                    ColumnLayout {
                        spacing: 0
                        M3Text { role: "headline"; customSize: 17; text: "Питание"; color: Theme.fgSurface }
                        M3Text { role: "label"; text: "Выбери действие · Esc — отмена"; color: Theme.fgSurfaceVariant }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        width: 32; height: 32; radius: 16
                        color: clsA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }
                        M3Icon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 17
                            color: clsA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                        }
                        MouseArea {
                            id: clsA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: pwrWin.closeRequested()
                        }
                    }
                }

                // ─── 3 Large M3 Expressive Power Tiles (Sleep / Reboot / Power Off) ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    PowerCard {
                        iconName: "bedtime"
                        title: "Сон"
                        hint: "Клавиша 1"
                        baseBg: Theme.surfaceContainerHigh
                        hoverBg: Theme.primaryContainer
                        baseIcon: Theme.primary
                        baseFg: Theme.fgSurface
                        hoverFg: Theme.fgPrimaryContainer
                        onTriggered: pwrWin.runAction(["systemctl", "suspend"])
                    }

                    PowerCard {
                        iconName: "restart_alt"
                        title: "Перезагрузка"
                        hint: "Клавиша 2"
                        baseBg: Theme.surfaceContainerHigh
                        hoverBg: Theme.secondaryContainer
                        baseIcon: Theme.secondary
                        baseFg: Theme.fgSurface
                        hoverFg: Theme.fgSecondaryContainer
                        onTriggered: pwrWin.runAction(["systemctl", "reboot"])
                    }

                    PowerCard {
                        iconName: "power_settings_new"
                        title: "Выключить"
                        hint: "Клавиша 3"
                        baseBg: Theme.tertiaryContainer
                        hoverBg: Theme.tertiary
                        baseIcon: Theme.fgTertiaryContainer
                        baseFg: Theme.fgTertiaryContainer
                        hoverFg: Theme.fgTertiary
                        alwaysFilled: true
                        onTriggered: pwrWin.runAction(["systemctl", "poweroff"])
                    }
                }
            }
        }
    }
}
