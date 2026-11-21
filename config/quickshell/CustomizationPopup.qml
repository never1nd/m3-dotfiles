import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: custWin
    required property bool isOpen
    signal closeRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

    property int niriRadius: 20
    property int niriGaps: 10
    property string wpPath: Quickshell.env("HOME") + "/Изображения/Wallpapers/535592.jpg"

    function refreshCust() {
        tuneGetProc.running = false; tuneGetProc.running = true
        wpPathProc.running = false; wpPathProc.running = true
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            refreshCust()
            openTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer { id: openTick; interval: 10; onTriggered: custWin.animOpen = true }
    Timer { id: closeDelay; interval: 220 }

    Process {
        id: tuneGetProc
        command: ["__HOME__/.local/bin/m3-niri-tune", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim())
                    custWin.niriGaps = d.gaps
                    custWin.niriRadius = d.radius
                } catch (e) {}
            }
        }
    }

    Process {
        id: wpPathProc
        command: ["sh", "-c", "cat ~/.local/state/m3-current-wallpaper 2>/dev/null || echo ~/Изображения/Wallpapers/535592.jpg"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p !== "") custWin.wpPath = p
            }
        }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-customization-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    component PillChip: Rectangle {
        id: ch
        property string label: ""
        property bool selected: false
        signal triggered()

        height: 32
        implicitWidth: chLbl.implicitWidth + 20
        radius: selected ? 11 : 16
        color: selected
            ? Theme.primaryContainer
            : (chA.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
        border.width: selected ? 1 : 0
        border.color: Theme.alpha(Theme.primary, 0.45)

        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
        Behavior on color { ColorAnimation { duration: 150 } }

        M3Text {
            id: chLbl
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            role: "labelEmphasized"
            customSize: 11
            emphasized: ch.selected || chA.containsMouse
            text: ch.label
            color: ch.selected ? Theme.fgPrimaryContainer : Theme.fgSurface
        }

        MouseArea {
            id: chA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ch.triggered()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: custWin.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, custWin.animOpen ? 0.16 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea { anchors.fill: parent; onClicked: custWin.closeRequested() }

        Rectangle {
            id: sheet
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: custWin.animOpen ? 40 : 24
            width: 416
            implicitHeight: custCol.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: custWin.animOpen ? 1.0 : 0.0
            scale: custWin.animOpen ? 1.0 : 0.94
            transformOrigin: Item.TopRight

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: custCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                // ─── Header ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 34; height: 34; radius: 12
                        color: Theme.primaryContainer
                        M3Icon {
                            anchors.centerIn: parent
                            name: "edit"
                            size: 19
                            filled: true
                            color: Theme.fgPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        M3Text { role: "headline"; customSize: 17; text: "Кастомизация"; color: Theme.fgSurface }
                        M3Text { role: "label"; text: "Material Design 3 Expressive"; color: Theme.primary }
                    }

                    // Color Picker Tool Pill (niri msg pick-color!)
                    Rectangle {
                        height: 30
                        implicitWidth: pickRow.implicitWidth + 18
                        radius: 15
                        color: pickA.containsMouse ? Theme.tertiary : Theme.tertiaryContainer
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: pickRow
                            anchors.centerIn: parent
                            spacing: 5
                            M3Icon { anchors.verticalCenter: parent.verticalCenter; name: "colorize"; size: 15; filled: true; color: pickA.containsMouse ? Theme.fgTertiary : Theme.fgTertiaryContainer }
                            M3Text { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 11; text: "Пипетка"; color: pickA.containsMouse ? Theme.fgTertiary : Theme.fgTertiaryContainer }
                        }

                        MouseArea {
                            id: pickA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                custWin.closeRequested()
                                NiriState.runDetached(["sh", "-c", 'sleep 0.25 && hex=$(niri msg pick-color | grep -oE "#[0-9a-fA-F]{6}" | head -n 1) && [ -n "$hex" ] && printf "%s" "$hex" | wl-copy && notify-send -a "Пипетка M3" "Цвет скопирован" "$hex"'])
                            }
                        }
                    }
                }

                // ─── 0. M3 Expressive Profile Switcher (1-click full desktop + wallpaper + icons + TG) ───
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    M3Text { role: "labelEmphasized"; text: "Профиль оформления"; color: Theme.fgSurfaceVariant }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8
                        Repeater {
                            model: [
                                { id: "violet", name: "Фиолетовый", dot: "#d0bdfd", dot2: "#fdb0d4" },
                                { id: "blue",   name: "Синий",      dot: "#adc6ff", dot2: "#9ecae0" },
                                { id: "forest", name: "Зеленый",    dot: "#477a4f", dot2: "#b6f1bb" },
                                { id: "peach",  name: "Оранжевый",  dot: "#ffb691", dot2: "#f2c98a" }
                            ]
                            delegate: Rectangle {
                                id: profPill
                                required property var modelData
                                property bool active: Theme.profileId === modelData.id
                                Layout.fillWidth: true
                                height: 40
                                radius: active ? 14 : 20
                                color: active
                                    ? Theme.primaryContainer
                                    : (ppA.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                border.width: active ? 1 : 0
                                border.color: Theme.alpha(Theme.primary, 0.55)
                                scale: ppA.pressed ? 0.96 : 1.0

                                Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
                                Behavior on color { ColorAnimation { duration: 160 } }
                                Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.40 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 11
                                    spacing: 7

                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: profPill.modelData.dot
                                        border.width: 2
                                        border.color: profPill.modelData.dot2
                                    }

                                    M3Text {
                                        Layout.fillWidth: true
                                        role: "labelEmphasized"
                                        customSize: 11
                                        emphasized: profPill.active || ppA.containsMouse
                                        text: profPill.modelData.name
                                        color: profPill.active ? Theme.fgPrimaryContainer : Theme.fgSurface
                                        elide: Text.ElideRight
                                    }

                                    M3Icon {
                                        visible: profPill.active
                                        name: "check"
                                        size: 15
                                        filled: true
                                        color: Theme.fgPrimaryContainer
                                    }
                                }

                                MouseArea {
                                    id: ppA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: NiriState.runDetached(["__HOME__/.local/bin/m3-profile", profPill.modelData.id])
                                }
                            }
                        }
                    }
                }

                // ─── 1. Wallpaper Preview Banner Card (click to open Wallpaper Picker!) ───
                Rectangle {
                    Layout.fillWidth: true
                    height: 112
                    radius: 20
                    color: Theme.surfaceContainerHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: custWin.visible ? ("file://" + (Theme.wallpaperPath !== "" ? Theme.wallpaperPath : custWin.wpPath)) : ""
                        sourceSize.width: 420
                        sourceSize.height: 240
                        asynchronous: true
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.12) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            M3Text { role: "title"; customSize: 13; text: "Обои и автопалитра"; color: "#ffffff" }
                            M3Text { role: "label"; text: Theme.wallpaperName || "535592"; color: Qt.rgba(1, 1, 1, 0.82) }
                        }

                        Rectangle {
                            height: 32
                            implicitWidth: wpBtnRow.implicitWidth + 20
                            radius: 16
                            color: wpBtnA.containsMouse ? Theme.primary : Theme.primaryContainer
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Row {
                                id: wpBtnRow
                                anchors.centerIn: parent
                                spacing: 5
                                M3Icon { anchors.verticalCenter: parent.verticalCenter; name: "wallpaper"; size: 15; filled: true; color: wpBtnA.containsMouse ? Theme.fgPrimary : Theme.fgPrimaryContainer }
                                M3Text { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 11; text: "Сменить"; color: wpBtnA.containsMouse ? Theme.fgPrimary : Theme.fgPrimaryContainer }
                            }
                            MouseArea {
                                id: wpBtnA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    custWin.closeRequested()
                                    NiriState.runDetached(["__HOME__/.local/bin/m3-wallpaper-picker"])
                                }
                            }
                        }
                    }
                }

                // ─── 2. Dark / Light Theme Mode Segmented Control ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    PillChip {
                        Layout.fillWidth: true
                        label: "Тёмная тема"
                        selected: Theme.mode === "dark"
                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-apply-wallpaper", "--mode", "dark", "--no-wallpaper"])
                    }
                    PillChip {
                        Layout.fillWidth: true
                        label: "Светлая тема"
                        selected: Theme.mode === "light"
                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-apply-wallpaper", "--mode", "light", "--no-wallpaper"])
                    }
                }

                // ─── 3. HCT Color Scheme Selector + Live Palette Swatches ───
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: hctCol.implicitHeight + 24
                    radius: 18
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        id: hctCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        M3Text { role: "labelEmphasized"; customSize: 12; text: "Алгоритм палитры HCT"; color: Theme.fgSurfaceVariant }

                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [
                                    { id: "scheme-content",    name: "Content" },
                                    { id: "scheme-tonal-spot", name: "Tonal Spot" },
                                    { id: "scheme-vibrant",    name: "Vibrant" },
                                    { id: "scheme-fidelity",   name: "Fidelity" },
                                    { id: "scheme-expressive", name: "Expressive" }
                                ]
                                delegate: PillChip {
                                    required property var modelData
                                    label: modelData.name
                                    selected: Theme.scheme === modelData.id
                                    onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-apply-wallpaper", "--scheme", modelData.id, "--no-wallpaper"])
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: [Theme.primary, Theme.primaryContainer, Theme.secondaryContainer, Theme.tertiary, Theme.tertiaryContainer, Theme.errorContainer]
                                delegate: Rectangle {
                                    required property color modelData
                                    Layout.fillWidth: true
                                    height: 18
                                    radius: 9
                                    color: modelData
                                    Behavior on color { ColorAnimation { duration: 220 } }
                                }
                            }
                        }
                    }
                }

                // ─── 4. Quick Niri Geometry Controls (Corner Radius & Gaps) ───
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: geoCol.implicitHeight + 24
                    radius: 18
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        id: geoCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            M3Text { role: "label"; text: "Скругление:"; color: Theme.fgSurfaceVariant }
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: [12, 16, 20, 24]
                                delegate: PillChip {
                                    required property int modelData
                                    label: modelData + "px"
                                    selected: custWin.niriRadius === modelData
                                    onTriggered: { custWin.niriRadius = modelData; NiriState.runDetached(["__HOME__/.local/bin/m3-niri-tune", "set", "--radius", String(modelData)]) }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            M3Text { role: "label"; text: "Отступы:"; color: Theme.fgSurfaceVariant }
                            Item { Layout.fillWidth: true }
                            Repeater {
                                model: [6, 10, 14]
                                delegate: PillChip {
                                    required property int modelData
                                    label: modelData + "px"
                                    selected: custWin.niriGaps === modelData
                                    onTriggered: { custWin.niriGaps = modelData; NiriState.runDetached(["__HOME__/.local/bin/m3-niri-tune", "set", "--gaps", String(modelData)]) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
