import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: ssWindow
    required property bool isOpen
    signal closeRequested()

    property bool animOpen: false
    property bool delay3s: false
    visible: isOpen || closeDelay.running

    function triggerCapture(mode) {
        const d = delay3s ? "3" : "0"
        ssWindow.closeRequested()
        NiriState.runDetached(["__HOME__/.local/bin/m3-screenshot", mode, "--delay", d])
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            openNextTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer {
        id: openNextTick
        interval: 10
        onTriggered: ssWindow.animOpen = true
    }

    Timer {
        id: closeDelay
        interval: 220
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-screenshot-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Reusable M3 Expressive Capture Mode Card
    component CaptureCard: Rectangle {
        id: cap
        property string iconName: ""
        property string title: ""
        property string hint: ""
        property bool emphasized: false
        signal triggered()

        Layout.fillWidth: true
        height: 92
        radius: capA.pressed ? 14 : (capA.containsMouse ? 22 : (emphasized ? 20 : 18))
        color: emphasized
            ? (capA.containsMouse ? Theme.primary : Theme.primaryContainer)
            : (capA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh)
        scale: capA.pressed ? 0.95 : (capA.containsMouse ? 1.03 : 1.0)

        Behavior on radius { SpringAnimation { spring: 5.2; damping: 0.35 } }
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.38 } }

        readonly property color fgMain: emphasized
            ? (capA.containsMouse ? Theme.fgPrimary : Theme.fgPrimaryContainer)
            : (capA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface)
        readonly property color fgSub: emphasized
            ? Theme.alpha(fgMain, 0.80)
            : (capA.containsMouse ? Theme.alpha(Theme.fgSecondaryContainer, 0.82) : Theme.fgSurfaceVariant)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 5

            M3Icon {
                Layout.alignment: Qt.AlignHCenter
                name: cap.iconName
                size: 28
                filled: cap.emphasized || capA.containsMouse
                color: cap.emphasized ? cap.fgMain : (capA.containsMouse ? Theme.fgSecondaryContainer : Theme.primary)
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: cap.title
                font.family: Theme.fontSans
                font.pixelSize: 13
                font.weight: Font.Bold
                color: cap.fgMain
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: cap.hint
                font.family: Theme.fontSans
                font.pixelSize: 10
                font.weight: Font.Medium
                color: cap.fgSub
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        MouseArea {
            id: capA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cap.triggered()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ssWindow.closeRequested()
        Keys.onReturnPressed: ssWindow.triggerCapture("region")
        Keys.onEnterPressed: ssWindow.triggerCapture("region")
        Keys.onDigit1Pressed: ssWindow.triggerCapture("region")
        Keys.onDigit2Pressed: ssWindow.triggerCapture("screen")
        Keys.onDigit3Pressed: ssWindow.triggerCapture("window")

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, ssWindow.animOpen ? 0.08 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ssWindow.closeRequested()
        }

        // ─── Material Design 3 Expressive Floating Screenshot Sheet (Top-Center) ───
        Rectangle {
            id: sheet
            anchors.horizontalCenter: parent.horizontalCenter
            y: ssWindow.animOpen ? 56 : 30
            width: 456
            implicitHeight: ssCol.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: ssWindow.animOpen ? 1.0 : 0.0
            scale: ssWindow.animOpen ? 1.0 : 0.93
            transformOrigin: Item.Top

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.35; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.35; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: ssCol
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
                        width: 34; height: 34; radius: 12
                        color: Theme.primaryContainer
                        Text {
                            anchors.centerIn: parent
                            text: "photo_camera"
                            font.family: Theme.fontIcons
                            font.pixelSize: 19
                            color: Theme.fgPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        M3Text {
                            role: "headline"
                            customSize: 16
                            text: "Снимок экрана"
                            color: Theme.fgSurface
                        }
                        Text {
                            text: "Автокопирование в буфер и сохранение в Screenshots"
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    Rectangle {
                        width: 30; height: 30; radius: 15
                        color: ssClsA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: Theme.fontIcons
                            font.pixelSize: 16
                            color: ssClsA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                        }
                        MouseArea {
                            id: ssClsA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: ssWindow.closeRequested()
                        }
                    }
                }

                // ─── 3 Expressive Mode Cards (Region / Full Screen / Window) ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    CaptureCard {
                        iconName: "screenshot_region"
                        title: "Область"
                        hint: "Enter / 1"
                        emphasized: true
                        onTriggered: ssWindow.triggerCapture("region")
                    }

                    CaptureCard {
                        iconName: "screenshot_monitor"
                        title: "Весь экран"
                        hint: "Клавиша 2"
                        emphasized: false
                        onTriggered: ssWindow.triggerCapture("screen")
                    }

                    CaptureCard {
                        iconName: "web_asset"
                        title: "Окно"
                        hint: "Клавиша 3"
                        emphasized: false
                        onTriggered: ssWindow.triggerCapture("window")
                    }
                }

                // ─── Bottom Options Row (Delay 3s Expressive Toggle Chip) ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        height: 32
                        implicitWidth: dRow.implicitWidth + 22
                        radius: ssWindow.delay3s ? 11 : 16
                        color: ssWindow.delay3s ? Theme.tertiaryContainer : Theme.surfaceContainerHigh
                        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Row {
                            id: dRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "timer"
                                font.family: Theme.fontIcons
                                font.pixelSize: 16
                                color: ssWindow.delay3s ? Theme.fgTertiaryContainer : Theme.fgSurfaceVariant
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                text: ssWindow.delay3s ? "Задержка: 3 сек" : "Задержка 3с"
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: ssWindow.delay3s ? Theme.fgTertiaryContainer : Theme.fgSurfaceVariant
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ssWindow.delay3s = !ssWindow.delay3s
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Esc — отмена"
                        font.family: Theme.fontSans
                        font.pixelSize: 11
                        color: Theme.fgSurfaceVariant
                    }
                }
            }
        }
    }
}
