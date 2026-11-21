import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: netWin
    required property bool isOpen
    signal closeRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

    property bool netEnabled: true
    property bool connected: true
    property string connName: "Проводное подключение"
    property string connType: "ethernet"
    property string devName: ""
    property string ipAddr: ""
    property string gateway: ""
    property string dnsAddr: ""
    property string linkSpeed: ""
    property string rxRate: "0 Б/с"
    property string txRate: "0 Б/с"
    property bool vpnActive: false
    property string vpnName: ""
    property string vpnIp: ""
    property var connections: []
    property bool copiedIp: false

    function refreshNet() {
        if (!netDataProc.running) netDataProc.running = true
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            copiedIp = false
            refreshNet()
            openTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer { id: openTick; interval: 10; onTriggered: netWin.animOpen = true }
    Timer { id: closeDelay; interval: 220 }
    Timer { id: copyReset; interval: 1600; onTriggered: netWin.copiedIp = false }
    Timer {
        interval: 2200
        running: netWin.isOpen
        repeat: true
        onTriggered: netWin.refreshNet()
    }

    Process {
        id: netDataProc
        command: ["__HOME__/.local/bin/m3-net-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim() || "{}")
                    netWin.netEnabled = !!d.networking
                    netWin.rxRate = d.rx || "0 Б/с"
                    netWin.txRate = d.tx || "0 Б/с"
                    netWin.connections = d.connections || []
                    if (d.primary) {
                        netWin.connected = !!d.primary.connected
                        netWin.connName = d.primary.name || "Сеть"
                        netWin.connType = d.primary.type || "ethernet"
                        netWin.devName = d.primary.device || ""
                        netWin.ipAddr = d.primary.ip || ""
                        netWin.gateway = d.primary.gateway || ""
                        netWin.dnsAddr = d.primary.dns || ""
                        netWin.linkSpeed = d.primary.link_speed || ""
                    } else {
                        netWin.connected = false
                        netWin.connName = "Нет подключения"
                    }
                    if (d.vpn) {
                        netWin.vpnActive = true
                        netWin.vpnName = d.vpn.name || "VPN"
                        netWin.vpnIp = d.vpn.ip || ""
                    } else {
                        netWin.vpnActive = false
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: nmActProc
        onExited: netWin.refreshNet()
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-network-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: netWin.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, netWin.animOpen ? 0.16 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea { anchors.fill: parent; onClicked: netWin.closeRequested() }

        Rectangle {
            id: sheet
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: netWin.animOpen ? 40 : 24
            width: 396
            implicitHeight: netCol.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: netWin.animOpen ? 1.0 : 0.0
            scale: netWin.animOpen ? 1.0 : 0.94
            transformOrigin: Item.TopRight

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: netCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    M3Text {
                        role: "headline"
                        text: "Сеть и интернет"
                        color: Theme.fgSurface
                    }

                    Rectangle {
                        height: 24
                        implicitWidth: stLbl.implicitWidth + 16
                        radius: 12
                        color: netWin.connected ? Theme.primaryContainer : Theme.errorContainer
                        M3Text {
                            id: stLbl
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            role: "labelEmphasized"
                            customSize: 10
                            text: netWin.connected ? "Онлайн" : "Офлайн"
                            color: netWin.connected ? Theme.fgPrimaryContainer : Theme.fgErrorContainer
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Master Networking M3 Switch
                    Rectangle {
                        width: 48; height: 28; radius: 14
                        color: netWin.netEnabled ? Theme.primary : Theme.surfaceContainerHighest
                        border.width: netWin.netEnabled ? 0 : 2
                        border.color: Theme.outline
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            x: netWin.netEnabled ? (parent.width - width - 4) : 5
                            width: netWin.netEnabled ? 20 : 14
                            height: width
                            radius: width / 2
                            color: netWin.netEnabled ? Theme.fgPrimary : Theme.fgSurfaceVariant
                            Behavior on x { SpringAnimation { spring: 5.5; damping: 0.36 } }
                            Behavior on width { SpringAnimation { spring: 5.5; damping: 0.36 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const next = netWin.netEnabled ? "off" : "on"
                                netWin.netEnabled = !netWin.netEnabled
                                nmActProc.command = ["nmcli", "networking", next]
                                nmActProc.running = true
                            }
                        }
                    }
                }

                // ─── Hero Active Connection Card (20px LargeIncreased) ───
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: heroCol.implicitHeight + 28
                    radius: 20
                    color: netWin.connected ? Theme.primaryContainer : Theme.surfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 200 } }

                    ColumnLayout {
                        id: heroCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                width: 42; height: 42; radius: 15
                                color: netWin.connected ? Theme.primary : Theme.surfaceContainerHighest
                                M3Icon {
                                    anchors.centerIn: parent
                                    name: !netWin.connected ? "wifi_off" : (netWin.connType === "wifi" ? "wifi" : "lan")
                                    size: 22
                                    filled: true
                                    color: netWin.connected ? Theme.fgPrimary : Theme.fgSurfaceVariant
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                M3Text {
                                    role: "title"
                                    customSize: 14
                                    text: netWin.connName
                                    color: netWin.connected ? Theme.fgPrimaryContainer : Theme.fgSurface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                M3Text {
                                    role: "label"
                                    text: netWin.devName + (netWin.linkSpeed !== "" ? (" · " + netWin.linkSpeed) : "")
                                    color: netWin.connected ? Theme.alpha(Theme.fgPrimaryContainer, 0.82) : Theme.fgSurfaceVariant
                                }
                            }
                        }

                        // Live RX / TX Throughput Pills
                        RowLayout {
                            visible: netWin.connected
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 14
                                color: Theme.alpha(Theme.fgPrimaryContainer, 0.12)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    M3Icon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 15; color: Theme.fgPrimaryContainer }
                                    M3Text { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 11; text: netWin.rxRate; color: Theme.fgPrimaryContainer }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
                                radius: 14
                                color: Theme.alpha(Theme.fgPrimaryContainer, 0.12)
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    M3Icon { anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 15; color: Theme.fgPrimaryContainer }
                                    M3Text { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 11; text: netWin.txRate; color: Theme.fgPrimaryContainer }
                                }
                            }
                        }
                    }
                }

                // ─── Active VPN Card (shown automatically when VPN tunnel like KeqDroid is active!) ───
                Rectangle {
                    visible: netWin.vpnActive
                    Layout.fillWidth: true
                    height: 52
                    radius: 18
                    color: Theme.tertiaryContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        M3Icon {
                            name: "vpn_lock"
                            size: 21
                            filled: true
                            color: Theme.fgTertiaryContainer
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            M3Text { role: "labelEmphasized"; customSize: 12; text: "VPN активен · " + netWin.vpnName; color: Theme.fgTertiaryContainer }
                            M3Text { role: "label"; text: "Туннель " + netWin.vpnIp; color: Theme.alpha(Theme.fgTertiaryContainer, 0.80) }
                        }

                        Rectangle {
                            height: 24
                            implicitWidth: vpnChip.implicitWidth + 14
                            radius: 12
                            color: Theme.tertiary
                            M3Text { id: vpnChip; anchors.centerIn: parent; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 10; text: "ON"; color: Theme.fgTertiary }
                        }
                    }
                }

                // ─── IP / Gateway / DNS Details Card (with 1-click Copy IP!) ───
                Rectangle {
                    visible: netWin.connected && netWin.ipAddr !== ""
                    Layout.fillWidth: true
                    implicitHeight: detCol.implicitHeight + 24
                    radius: 18
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        id: detCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            M3Text { role: "label"; text: "IPv4-адрес"; color: Theme.fgSurfaceVariant }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 24
                                implicitWidth: ipRow.implicitWidth + 14
                                radius: 12
                                color: ipA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHighest
                                Behavior on color { ColorAnimation { duration: 140 } }

                                Row {
                                    id: ipRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    M3Text { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 11; text: netWin.copiedIp ? "Скопировано!" : netWin.ipAddr; color: ipA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface }
                                    M3Icon { anchors.verticalCenter: parent.verticalCenter; name: netWin.copiedIp ? "check" : "content_copy"; size: 13; color: ipA.containsMouse ? Theme.fgSecondaryContainer : Theme.primary }
                                }

                                MouseArea {
                                    id: ipA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        NiriState.runDetached(["wl-copy", netWin.ipAddr])
                                        netWin.copiedIp = true
                                        copyReset.restart()
                                    }
                                }
                            }
                        }

                        RowLayout {
                            visible: netWin.gateway !== ""
                            Layout.fillWidth: true
                            M3Text { role: "label"; text: "Шлюз"; color: Theme.fgSurfaceVariant }
                            Item { Layout.fillWidth: true }
                            M3Text { role: "labelEmphasized"; customSize: 11; text: netWin.gateway; color: Theme.fgSurface }
                        }

                        RowLayout {
                            visible: netWin.dnsAddr !== ""
                            Layout.fillWidth: true
                            M3Text { role: "label"; text: "DNS"; color: Theme.fgSurfaceVariant }
                            Item { Layout.fillWidth: true }
                            M3Text { role: "labelEmphasized"; customSize: 11; text: netWin.dnsAddr; color: Theme.fgSurface }
                        }
                    }
                }

                // ─── Saved Profiles List (1-click Connect / Disconnect) ───
                ColumnLayout {
                    visible: netWin.connections.length > 0
                    Layout.fillWidth: true
                    spacing: 6

                    M3Text {
                        role: "labelEmphasized"
                        customSize: 12
                        text: "Профили подключений"
                        color: Theme.fgSurfaceVariant
                    }

                    Repeater {
                        model: netWin.connections
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 44
                            radius: modelData.active ? 14 : 22
                            color: modelData.active
                                ? Theme.secondaryContainer
                                : (conA.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)

                            Behavior on radius { SpringAnimation { spring: 5.2; damping: 0.36 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                M3Icon {
                                    name: modelData.type.indexOf("wireless") !== -1 ? "wifi" : "lan"
                                    size: 18
                                    filled: modelData.active || conA.containsMouse
                                    color: modelData.active ? Theme.fgSecondaryContainer : Theme.primary
                                }

                                M3Text {
                                    role: modelData.active ? "labelEmphasized" : "label"
                                    customSize: 12
                                    text: modelData.name
                                    color: modelData.active ? Theme.fgSecondaryContainer : Theme.fgSurface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                M3Text {
                                    role: "label"
                                    customSize: 10
                                    text: modelData.active ? "Отключить" : "Подключить"
                                    color: modelData.active ? Theme.alpha(Theme.fgSecondaryContainer, 0.80) : Theme.primary
                                }
                            }

                            MouseArea {
                                id: conA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const verb = modelData.active ? "down" : "up"
                                    nmActProc.command = ["nmcli", "con", verb, modelData.name]
                                    nmActProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
