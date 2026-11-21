import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
    id: volWindow
    required property bool isOpen
    property int navDir: 0
    signal closeRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

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
        onTriggered: volWindow.animOpen = true
    }

    Timer {
        id: closeDelay
        interval: 220
    }

    readonly property var outputSinks: {
        const list = Pipewire.nodes.values || []
        return list.filter(n => n && n.isSink && !n.isStream && n.audio !== null)
    }

    readonly property var appStreams: {
        const list = Pipewire.nodes.values || []
        return list.filter(n => n && n.isStream && n.audio !== null && !n.isSink)
    }

    readonly property var trackedNodes: {
        const out = []
        if (Pipewire.defaultAudioSink) out.push(Pipewire.defaultAudioSink)
        if (Pipewire.defaultAudioSource) out.push(Pipewire.defaultAudioSource)
        for (let i = 0; i < outputSinks.length; i++) out.push(outputSinks[i])
        for (let i = 0; i < appStreams.length; i++) out.push(appStreams[i])
        return out
    }

    PwObjectTracker {
        objects: volWindow.trackedNodes
    }

    function nodeLabel(node, fallback) {
        if (!node) return fallback
        const props = node.properties || {}
        return props["application.name"] || node.nickname || node.description || node.name || fallback
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
    WlrLayershell.namespace: "m3-volume-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: volWindow.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, volWindow.animOpen ? 0.14 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: volWindow.closeRequested()
        }

        Rectangle {
            id: sheet
            anchors.right: parent.right
            anchors.rightMargin: volWindow.animOpen ? 12 : (12 - volWindow.navDir * 22)
            Behavior on anchors.rightMargin { SpringAnimation { spring: 5.0; damping: 0.36; epsilon: 0.2 } }
            y: volWindow.animOpen ? 40 : 24
            width: 378
            implicitHeight: volCol.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: volWindow.animOpen ? 1.0 : 0.0
            scale: volWindow.animOpen ? 1.0 : 0.94
            transformOrigin: Item.TopRight

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: volCol
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
                        text: "Громкость и звук"
                        color: Theme.fgSurface
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 28
                        implicitWidth: pavuRow.implicitWidth + 20
                        radius: 14
                        color: pavuA.containsMouse ? Theme.primary : Theme.primaryContainer
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: pavuRow
                            anchors.centerIn: parent
                            spacing: 5
                            M3Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "graphic_eq"
                                size: 15
                                filled: true
                                color: pavuA.containsMouse ? Theme.fgPrimary : Theme.fgPrimaryContainer
                            }
                            M3Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                role: "labelEmphasized"
                                customSize: 11
                                text: "Микшер"
                                color: pavuA.containsMouse ? Theme.fgPrimary : Theme.fgPrimaryContainer
                            }
                        }

                        MouseArea {
                            id: pavuA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                volWindow.closeRequested()
                                NiriState.runDetached(["pavucontrol"])
                            }
                        }
                    }
                }

                // ─── 1. Master Output M3 Expressive Slider ───
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    M3Text {
                        role: "label"
                        text: volWindow.nodeLabel(Pipewire.defaultAudioSink, "Основной вывод")
                        color: Theme.fgSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    M3ExpressiveSlider {
                        readonly property var aud: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                        Layout.fillWidth: true
                        value: aud ? Math.max(0, Math.min(1, aud.volume || 0)) : 0
                        muted: aud ? !!aud.muted : false
                        iconName: "volume_up"
                        mutedIconName: "volume_off"
                        iconClickable: true
                        activeColor: Theme.primary
                        onActiveColor: Theme.fgPrimary
                        trackHeight: 38
                        onIconClicked: if (aud) aud.muted = !aud.muted
                        onMoved: v => { if (aud) { aud.muted = false; aud.volume = v } }
                    }
                }

                // ─── 2. Microphone M3 Expressive Slider ───
                ColumnLayout {
                    visible: Pipewire.defaultAudioSource !== null
                    Layout.fillWidth: true
                    spacing: 4

                    M3Text {
                        role: "label"
                        text: "Микрофон · " + volWindow.nodeLabel(Pipewire.defaultAudioSource, "Ввод")
                        color: Theme.fgSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    M3ExpressiveSlider {
                        readonly property var aud: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
                        Layout.fillWidth: true
                        value: aud ? Math.max(0, Math.min(1, aud.volume || 0)) : 0
                        muted: aud ? !!aud.muted : false
                        iconName: "mic"
                        mutedIconName: "mic_off"
                        iconClickable: true
                        activeColor: Theme.secondary
                        onActiveColor: Theme.fgSecondary
                        trackHeight: 34
                        onIconClicked: if (aud) aud.muted = !aud.muted
                        onMoved: v => { if (aud) { aud.muted = false; aud.volume = v } }
                    }
                }

                // ─── 3. Per-App Audio Streams ───
                ColumnLayout {
                    visible: volWindow.appStreams.length > 0
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.alpha(Theme.outlineVariant, 0.40)
                    }

                    M3Text {
                        role: "labelEmphasized"
                        customSize: 12
                        text: "Приложения"
                        color: Theme.fgSurfaceVariant
                    }

                    Repeater {
                        model: volWindow.appStreams
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 3

                            M3Text {
                                role: "label"
                                text: volWindow.nodeLabel(modelData, "Приложение")
                                color: Theme.fgSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            M3ExpressiveSlider {
                                readonly property var aud: modelData ? modelData.audio : null
                                Layout.fillWidth: true
                                value: aud ? Math.max(0, Math.min(1, aud.volume || 0)) : 0
                                muted: aud ? !!aud.muted : false
                                iconName: "music_note"
                                mutedIconName: "volume_off"
                                iconClickable: true
                                activeColor: Theme.tertiary
                                onActiveColor: Theme.fgTertiary
                                trackHeight: 30
                                onIconClicked: if (aud) aud.muted = !aud.muted
                                onMoved: v => { if (aud) { aud.muted = false; aud.volume = v } }
                            }
                        }
                    }
                }

                // ─── 4. Output Device Switcher ───
                ColumnLayout {
                    visible: volWindow.outputSinks.length > 1
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.alpha(Theme.outlineVariant, 0.40)
                    }

                    M3Text {
                        role: "labelEmphasized"
                        customSize: 12
                        text: "Устройство вывода"
                        color: Theme.fgSurfaceVariant
                    }

                    Repeater {
                        model: volWindow.outputSinks
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isActiveSink: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.id === modelData.id
                            Layout.fillWidth: true
                            height: 38
                            radius: isActiveSink ? 14 : 19
                            color: isActiveSink
                                ? Theme.primaryContainer
                                : (sinkA.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)

                            Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                M3Icon {
                                    name: isActiveSink ? "check_circle" : "speaker"
                                    size: 18
                                    filled: isActiveSink || sinkA.containsMouse
                                    color: isActiveSink ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
                                }

                                M3Text {
                                    role: isActiveSink ? "labelEmphasized" : "label"
                                    customSize: 12
                                    text: volWindow.nodeLabel(modelData, "Аудиовыход")
                                    color: isActiveSink ? Theme.fgPrimaryContainer : Theme.fgSurface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: sinkA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
