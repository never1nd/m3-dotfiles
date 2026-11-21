import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: clipWindow
    required property bool isOpen
    signal closeRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

    property var allItems: []
    property string filterText: ""
    property int selectedIndex: 0

    readonly property var filteredItems: {
        const q = filterText.trim().toLowerCase()
        if (q === "") return allItems
        return allItems.filter(it => (it.text || "").toLowerCase().indexOf(q) !== -1 || (it.meta || "").toLowerCase().indexOf(q) !== -1)
    }

    function refreshList() {
        listProc.running = false
        listProc.running = true
    }

    function selectItem(item) {
        if (!item) return
        NiriState.runDetached(["sh", "-c", "cliphist decode " + item.id + " | wl-copy"])
        clipWindow.closeRequested()
    }

    function deleteItem(item) {
        if (!item) return
        delProc.command = ["python3", "-c", "import subprocess, sys; subprocess.run(['cliphist', 'delete'], input=sys.argv[1].encode())", item.raw]
        delProc.running = true
    }

    function clearAll() {
        clearProc.running = true
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            filterText = ""
            selectedIndex = 0
            refreshList()
            openNextTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer {
        id: openNextTick
        interval: 10
        onTriggered: {
            clipWindow.animOpen = true
            searchInput.forceActiveFocus()
        }
    }

    Timer {
        id: closeDelay
        interval: 220
    }

    Process {
        id: listProc
        command: ["__HOME__/.local/bin/m3-cliphist-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    clipWindow.allItems = JSON.parse(text.trim() || "[]")
                    clipWindow.selectedIndex = 0
                } catch (e) {
                    clipWindow.allItems = []
                }
            }
        }
    }

    Process {
        id: delProc
        onExited: clipWindow.refreshList()
    }

    Process {
        id: clearProc
        command: ["sh", "-c", "cliphist wipe && rm -rf /tmp/m3-clip-thumbs/*"]
        onExited: clipWindow.refreshList()
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
    WlrLayershell.namespace: "m3-clipboard-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent

        // Soft M3 Scrim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, clipWindow.animOpen ? 0.28 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: clipWindow.closeRequested()
        }

        // ─── Centered Material Design 3 Expressive Clipboard Dialog (ExtraLarge 28px) ───
        Rectangle {
            id: dialog
            anchors.centerIn: parent
            anchors.verticalCenterOffset: clipWindow.animOpen ? 0 : 18
            width: 560
            height: 540
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: clipWindow.animOpen ? 1.0 : 0.0
            scale: clipWindow.animOpen ? 1.0 : 0.94

            Behavior on anchors.verticalCenterOffset { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 36; height: 36; radius: 13
                        color: Theme.primaryContainer
                        M3Icon {
                            anchors.centerIn: parent
                            name: "content_paste"
                            size: 20
                            filled: true
                            color: Theme.fgPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        M3Text {
                            role: "headline"
                            customSize: 18
                            text: "Буфер обмена"
                            color: Theme.fgSurface
                        }
                        Text {
                            text: clipWindow.filteredItems.length + " записей · Enter — вставить"
                            font.family: Theme.fontSans
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.fgSurfaceVariant
                        }
                    }

                    // Clear All Pill
                    Rectangle {
                        height: 32
                        implicitWidth: clrRow.implicitWidth + 22
                        radius: clrA.pressed ? 10 : 16
                        color: clrA.containsMouse ? Theme.errorContainer : Theme.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }

                        Row {
                            id: clrRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "delete_sweep"
                                font.family: Theme.fontIcons
                                font.pixelSize: 16
                                color: clrA.containsMouse ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                text: "Очистить"
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: clrA.containsMouse ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
                            }
                        }

                        MouseArea {
                            id: clrA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: clipWindow.clearAll()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: clsA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: Theme.fontIcons
                            font.pixelSize: 17
                            color: clsA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                        }
                        MouseArea {
                            id: clsA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: clipWindow.closeRequested()
                        }
                    }
                }

                // ─── M3 Expressive Full-Pill Search Bar ───
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 22
                    color: Theme.surfaceContainerHighest
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus ? Theme.primary : Theme.alpha(Theme.outlineVariant, 0.35)
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 14
                        spacing: 10

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            color: Theme.primaryContainer
                            Text {
                                anchors.centerIn: parent
                                text: "search"
                                font.family: Theme.fontIcons
                                font.pixelSize: 17
                                color: Theme.fgPrimaryContainer
                            }
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: Theme.fgSurface
                            selectionColor: Theme.primaryContainer
                            selectedTextColor: Theme.fgPrimaryContainer
                            clip: true
                            text: clipWindow.filterText
                            onTextChanged: {
                                clipWindow.filterText = text
                                clipWindow.selectedIndex = 0
                            }

                            Keys.onEscapePressed: clipWindow.closeRequested()
                            Keys.onDownPressed: {
                                if (clipWindow.filteredItems.length > 0) {
                                    clipWindow.selectedIndex = Math.min(clipWindow.filteredItems.length - 1, clipWindow.selectedIndex + 1)
                                    clipList.positionViewAtIndex(clipWindow.selectedIndex, ListView.Contain)
                                }
                            }
                            Keys.onUpPressed: {
                                if (clipWindow.filteredItems.length > 0) {
                                    clipWindow.selectedIndex = Math.max(0, clipWindow.selectedIndex - 1)
                                    clipList.positionViewAtIndex(clipWindow.selectedIndex, ListView.Contain)
                                }
                            }
                            Keys.onReturnPressed: {
                                if (clipWindow.filteredItems.length > 0) {
                                    clipWindow.selectItem(clipWindow.filteredItems[clipWindow.selectedIndex])
                                }
                            }
                            Keys.onEnterPressed: {
                                if (clipWindow.filteredItems.length > 0) {
                                    clipWindow.selectItem(clipWindow.filteredItems[clipWindow.selectedIndex])
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Поиск по истории буфера..."
                                font.family: Theme.fontSans
                                font.pixelSize: 13
                                color: Theme.fgSurfaceVariant
                                visible: searchInput.text === ""
                            }
                        }
                    }
                }

                // ─── Clipboard Cards List ───
                ListView {
                    id: clipList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: clipWindow.filteredItems

                    delegate: Rectangle {
                        id: rowCard
                        required property var modelData
                        required property int index
                        readonly property bool isSel: index === clipWindow.selectedIndex

                        width: clipList.width
                        height: modelData.is_image ? 74 : 56
                        radius: isSel ? 18 : 16
                        color: isSel
                            ? Theme.primaryContainer
                            : (rowA.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)

                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.38 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 12

                            // Image Thumbnail OR Text Icon Badge
                            Rectangle {
                                width: modelData.is_image ? 56 : 34
                                height: modelData.is_image ? 56 : 34
                                radius: modelData.is_image ? 12 : 11
                                color: rowCard.isSel ? Theme.alpha(Theme.fgPrimaryContainer, 0.14) : Theme.surfaceContainerHighest
                                clip: true
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.fill: parent
                                    visible: modelData.is_image && modelData.thumb !== ""
                                    source: modelData.thumb || ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !(modelData.is_image && modelData.thumb !== "")
                                    text: modelData.is_image ? "image" : "notes"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 18
                                    color: rowCard.isSel ? Theme.fgPrimaryContainer : Theme.primary
                                }
                            }

                            // Text / Image Meta
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: modelData.is_image ? "Изображение" : modelData.text
                                    font.family: Theme.fontSans
                                    font.pixelSize: 13
                                    font.weight: rowCard.isSel ? Font.Bold : Font.Medium
                                    color: rowCard.isSel ? Theme.fgPrimaryContainer : Theme.fgSurface
                                    elide: Text.ElideRight
                                    maximumLineCount: modelData.is_image ? 1 : 2
                                    wrapMode: Text.WrapAnywhere
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: modelData.is_image
                                    text: modelData.meta
                                    font.family: Theme.fontSans
                                    font.pixelSize: 11
                                    color: rowCard.isSel ? Theme.alpha(Theme.fgPrimaryContainer, 0.80) : Theme.fgSurfaceVariant
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Single-Item Delete Button
                            Rectangle {
                                width: 30; height: 30; radius: 15
                                z: 2
                                opacity: (rowA.containsMouse || delA.containsMouse || rowCard.isSel) ? 1.0 : 0.0
                                color: delA.containsMouse ? Theme.errorContainer : Theme.alpha(Theme.fgSurface, 0.08)
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                Behavior on color { ColorAnimation { duration: 140 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "delete"
                                    font.family: Theme.fontIcons
                                    font.pixelSize: 16
                                    color: delA.containsMouse ? Theme.fgErrorContainer : (rowCard.isSel ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant)
                                }

                                MouseArea {
                                    id: delA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: clipWindow.deleteItem(modelData)
                                }
                            }
                        }

                        MouseArea {
                            id: rowA
                            anchors.fill: parent
                            anchors.rightMargin: 42
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: clipWindow.selectedIndex = index
                            onClicked: clipWindow.selectItem(modelData)
                        }
                    }

                    // Empty State
                    Text {
                        anchors.centerIn: parent
                        visible: clipWindow.filteredItems.length === 0
                        text: "История буфера пуста"
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        color: Theme.fgSurfaceVariant
                    }
                }
            }
        }
    }
}
