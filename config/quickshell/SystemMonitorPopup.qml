import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: smWindow
    required property bool isOpen
    property int navDir: 0
    signal closeRequested()

    property bool animOpen: false
    property bool ramExpanded: false
    visible: isOpen || closeDelay.running

    property int cpuPct: 0
    property int cpuTemp: 0
    property real ramUsed: 0
    property real ramTotal: 16
    property int ramPct: 0
    property int maxAppMb: 1
    property string gpuName: "RTX 2060"
    property int gpuPct: 0
    property int gpuTemp: 0
    property real vramUsed: 0
    property real vramTotal: 12
    property int vramPct: 0

    ListModel {
        id: ramTopModel
    }

    function reconcileRamTop(arr) {
        if (!arr) return
        maxAppMb = (arr.length > 0 && arr[0].mb > 0) ? arr[0].mb : 1
        const desiredNames = arr.map(it => it.name)

        // 1) Remove entries that left the top list
        for (let i = ramTopModel.count - 1; i >= 0; i--) {
            if (desiredNames.indexOf(ramTopModel.get(i).appName) === -1) {
                ramTopModel.remove(i)
            }
        }

        // 2) Update in place & smoothly move rank without recreating delegates!
        for (let target = 0; target < arr.length; target++) {
            const it = arr[target]
            let found = -1
            for (let j = 0; j < ramTopModel.count; j++) {
                if (ramTopModel.get(j).appName === it.name) {
                    found = j
                    break
                }
            }
            if (found === -1) {
                ramTopModel.insert(target, {
                    appName: it.name,
                    mb: it.mb || 0,
                    sizeStr: it.size || "0 МБ",
                    procs: it.procs || 1
                })
            } else {
                if (found !== target) {
                    ramTopModel.move(found, target, 1)
                }
                ramTopModel.setProperty(target, "mb", it.mb || 0)
                ramTopModel.setProperty(target, "sizeStr", it.size || "0 МБ")
                ramTopModel.setProperty(target, "procs", it.procs || 1)
            }
        }
    }

    function refreshStats() {
        if (!statsProc.running) statsProc.running = true
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            refreshStats()
            openNextTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer { id: openNextTick; interval: 10; onTriggered: smWindow.animOpen = true }
    Timer { id: closeDelay; interval: 220 }

    Timer {
        interval: 2500
        running: smWindow.isOpen
        repeat: true
        onTriggered: smWindow.refreshStats()
    }

    Process {
        id: statsProc
        command: ["__HOME__/.local/bin/m3-sysmon-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim())
                    smWindow.cpuPct = d.cpu_pct || 0
                    smWindow.cpuTemp = d.cpu_temp || 0
                    if (d.ram) {
                        smWindow.ramUsed = d.ram.used_gb || 0
                        smWindow.ramTotal = d.ram.total_gb || 16
                        smWindow.ramPct = d.ram.pct || 0
                    }
                    if (d.ram_top) {
                        smWindow.reconcileRamTop(d.ram_top)
                    }
                    if (d.gpu) {
                        smWindow.gpuName = d.gpu.name || "GPU"
                        smWindow.gpuPct = d.gpu.pct || 0
                        smWindow.gpuTemp = d.gpu.temp || 0
                        smWindow.vramUsed = d.gpu.vram_used_gb || 0
                        smWindow.vramTotal = d.gpu.vram_total_gb || 12
                        smWindow.vramPct = d.gpu.vram_pct || 0
                    }
                } catch (e) {}
            }
        }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-sysmon-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Reusable M3 Expressive Metric Card (supports optional click-to-expand!)
    component MetricCard: Rectangle {
        id: mc
        property string iconName: ""
        property string label: ""
        property string valueText: ""
        property string tempText: ""
        property bool tempHot: false
        property int pct: 0
        property color barColor: Theme.primary
        property string subLabel: ""
        property int subPct: -1
        property bool expandable: false
        property bool expanded: false
        signal clicked()

        default property alias extraContent: extraSlot.data

        Layout.fillWidth: true
        implicitHeight: mcCol.implicitHeight + 24
        radius: 18
        clip: true
        color: (expandable && cardA.containsMouse) ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

        Behavior on color { ColorAnimation { duration: 160 } }

        MouseArea {
            id: cardA
            anchors.fill: parent
            enabled: mc.expandable
            hoverEnabled: mc.expandable
            cursorShape: mc.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mc.clicked()
        }

        ColumnLayout {
            id: mcCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            Item {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    spacing: 8

                    Rectangle {
                        width: 30; height: 30; radius: 11
                        color: Theme.alpha(mc.barColor, 0.18)
                        M3Icon {
                            anchors.centerIn: parent
                            name: mc.iconName
                            size: 19
                            filled: true
                            color: mc.barColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        M3Text {
                            role: "title"
                            customSize: 13
                            text: mc.label
                            color: Theme.fgSurface
                        }

                        M3Text {
                            role: "label"
                            text: mc.valueText
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    // Temperature Chip
                    Rectangle {
                        visible: mc.tempText !== ""
                        height: 24
                        implicitWidth: tRow.implicitWidth + 14
                        radius: 12
                        color: mc.tempHot ? Theme.errorContainer : Theme.surfaceContainerHighest

                        Row {
                            id: tRow
                            anchors.centerIn: parent
                            spacing: 3
                            M3Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "thermostat"
                                size: 14
                                color: mc.tempHot ? Theme.fgErrorContainer : mc.barColor
                            }
                            M3Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                role: "labelEmphasized"
                                customSize: 11
                                text: mc.tempText
                                color: mc.tempHot ? Theme.fgErrorContainer : Theme.fgSurface
                            }
                        }
                    }

                    // Percentage Readout
                    M3Text {
                        role: "title"
                        customSize: 14
                        text: mc.pct + "%"
                        color: mc.barColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Rotating Chevron when expandable
                    M3Icon {
                        visible: mc.expandable
                        name: "expand_more"
                        size: 20
                        rotation: mc.expanded ? 180 : 0
                        color: Theme.fgSurfaceVariant
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on rotation { SpringAnimation { spring: 5.0; damping: 0.38 } }
                    }
                }


            }

            // Thick M3 Expressive Progress Bar
            Rectangle {
                Layout.fillWidth: true
                height: 10
                radius: 5
                color: Theme.surfaceContainerHighest
                clip: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(10, parent.width * Math.max(0, Math.min(1, mc.pct / 100.0)))
                    radius: 5
                    color: mc.barColor
                    Behavior on width { SpringAnimation { spring: 5.0; damping: 0.42; epsilon: 0.5 } }
                }
            }

            // Optional secondary VRAM row
            ColumnLayout {
                visible: mc.subPct >= 0
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    M3Text { role: "label"; text: mc.subLabel; color: Theme.fgSurfaceVariant }
                    Item { Layout.fillWidth: true }
                    M3Text { role: "labelEmphasized"; customSize: 11; text: mc.subPct + "%"; color: Theme.fgSurfaceVariant }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: Theme.surfaceContainerHighest
                    clip: true

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(6, parent.width * Math.max(0, Math.min(1, mc.subPct / 100.0)))
                        radius: 3
                        color: Theme.alpha(mc.barColor, 0.72)
                        Behavior on width { SpringAnimation { spring: 5.0; damping: 0.42; epsilon: 0.5 } }
                    }
                }
            }

            // Single-driver synchronized M3 Expressive clipped reveal (zero deadlock on repeated open/close!)
            Item {
                id: extraClip
                property real revealH: mc.expanded ? extraSlot.implicitHeight : 0
                Behavior on revealH {
                    NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                }
                Layout.fillWidth: true
                Layout.preferredHeight: revealH
                implicitHeight: revealH
                clip: true
                visible: mc.expanded || revealH > 0.5
                opacity: mc.expanded ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    id: extraSlot
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 6
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: smWindow.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, smWindow.animOpen ? 0.14 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea { anchors.fill: parent; onClicked: smWindow.closeRequested() }

        Rectangle {
            id: sheet
            anchors.right: parent.right
            anchors.rightMargin: smWindow.animOpen ? 12 : (12 - smWindow.navDir * 22)
            Behavior on anchors.rightMargin { SpringAnimation { spring: 5.0; damping: 0.36; epsilon: 0.2 } }
            y: smWindow.animOpen ? 40 : 24
            width: 382
            implicitHeight: smCol.implicitHeight + 36
            radius: 28
            clip: true
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: smWindow.animOpen ? 1.0 : 0.0
            scale: smWindow.animOpen ? 1.0 : 0.94
            transformOrigin: Item.TopRight

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: smCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true

                    M3Text {
                        role: "headline"
                        text: "Монитор системы"
                        color: Theme.fgSurface
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 28
                        implicitWidth: btopRow.implicitWidth + 20
                        radius: 14
                        color: btopA.containsMouse ? Theme.primary : Theme.primaryContainer
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: btopRow
                            anchors.centerIn: parent
                            spacing: 5
                            M3Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "terminal"
                                size: 14
                                color: btopA.containsMouse ? Theme.fgPrimary : Theme.fgPrimaryContainer
                            }
                            M3Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                role: "labelEmphasized"
                                customSize: 11
                                text: "btop"
                                color: btopA.containsMouse ? Theme.fgPrimary : Theme.fgPrimaryContainer
                            }
                        }

                        MouseArea {
                            id: btopA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                smWindow.closeRequested()
                                NiriState.runDetached(["kitty", "-e", "btop"])
                            }
                        }
                    }
                }

                // 1) CPU Usage + Temp
                MetricCard {
                    iconName: "memory"
                    label: "Процессор"
                    valueText: "Intel Core i3-10100F"
                    tempText: smWindow.cpuTemp + "°C"
                    tempHot: smWindow.cpuTemp >= 80
                    pct: smWindow.cpuPct
                    barColor: Theme.primary
                }

                // 2) RAM Usage — Clickable to reveal Top Memory-Consuming Apps!
                MetricCard {
                    iconName: "memory_alt"
                    label: "Оперативная память"
                    valueText: smWindow.ramUsed.toFixed(1) + " / " + smWindow.ramTotal.toFixed(1) + " ГБ"
                    pct: smWindow.ramPct
                    barColor: Theme.secondary
                    expandable: true
                    expanded: smWindow.ramExpanded
                    onClicked: smWindow.ramExpanded = !smWindow.ramExpanded

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        height: 1
                        color: Theme.alpha(Theme.outlineVariant, 0.35)
                    }

                    M3Text {
                        role: "labelEmphasized"
                        customSize: 11
                        text: "Топ по потреблению ОЗУ"
                        color: Theme.primary
                    }

                    Item {
                        Layout.fillWidth: true
                        readonly property int rowStride: 31
                        implicitHeight: ramTopModel.count * rowStride

                        Repeater {
                            model: ramTopModel
                            delegate: Item {
                                width: parent.width
                                height: 26
                                y: index * parent.rowStride

                                // Smooth M3 Expressive vertical glide when apps change rank in the top!
                                Behavior on y {
                                    SpringAnimation { spring: 4.8; damping: 0.38; epsilon: 0.2 }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        M3Text {
                                            role: index === 0 ? "labelEmphasized" : "label"
                                            customSize: 12
                                            text: model.appName + (model.procs > 1 ? (" · " + model.procs) : "")
                                            color: Theme.fgSurface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        M3Text {
                                            role: "labelEmphasized"
                                            customSize: 11
                                            text: model.sizeStr
                                            color: index === 0 ? Theme.primary : Theme.fgSurfaceVariant
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 5
                                        radius: 2.5
                                        color: Theme.surfaceContainerHighest
                                        clip: true

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            width: Math.max(6, parent.width * Math.min(1.0, (model.mb || 0) / smWindow.maxAppMb))
                                            radius: 2.5
                                            color: index === 0 ? Theme.primary : (index === 1 ? Theme.tertiary : Theme.secondary)
                                            // Smooth delta glide (no reset to zero!)
                                            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                                            Behavior on color { ColorAnimation { duration: 240 } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3) GPU Usage + Temp + VRAM
                MetricCard {
                    iconName: "developer_board"
                    label: smWindow.gpuName
                    valueText: "Загрузка GPU и видеопамять"
                    tempText: smWindow.gpuTemp + "°C"
                    tempHot: smWindow.gpuTemp >= 82
                    pct: smWindow.gpuPct
                    barColor: Theme.tertiary
                    subLabel: "VRAM: " + smWindow.vramUsed.toFixed(1) + " / " + smWindow.vramTotal.toFixed(1) + " ГБ"
                    subPct: smWindow.vramPct
                }
            }
        }
    }
}
