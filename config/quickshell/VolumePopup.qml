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

    // Track ALL PipeWire audio sinks & streams BEFORE filtering on `.audio`,
    // otherwise untracked PwNodes have audio === null until PwObjectTracker binds them!
    readonly property var allTrackableNodes: {
        const list = Pipewire.nodes.values || []
        const out = []
        if (Pipewire.defaultAudioSink) out.push(Pipewire.defaultAudioSink)
        if (Pipewire.defaultAudioSource) out.push(Pipewire.defaultAudioSource)
        for (let i = 0; i < list.length; i++) {
            const n = list[i]
            if (!n) continue
            if (n.isSink || n.isStream) out.push(n)
        }
        return out
    }

    PwObjectTracker {
        objects: volWindow.allTrackableNodes
    }

    readonly property var outputSinks: {
        const list = Pipewire.nodes.values || []
        return list.filter(n => {
            if (!n || !n.isSink || n.isStream || !n.audio) return false
            const props = n.properties || {}
            const mc = String(props["media.class"] || "")
            return mc === "" || mc.indexOf("Audio/Sink") !== -1
        })
    }

    readonly property var appStreams: {
        const list = Pipewire.nodes.values || []
        return list.filter(n => {
            if (!n || !n.isStream || n.isSink || !n.audio) return false
            const props = n.properties || {}
            const mc = String(props["media.class"] || "")
            if (mc !== "" && mc.indexOf("Output/Audio") === -1) return false
            return true
        })
    }

    function nodeLabel(node, fallback) {
        if (!node) return fallback
        const props = node.properties || {}
        const appName = String(props["application.name"] || "")
        const mediaName = String(props["media.name"] || "")
        const bin = String(props["application.process.binary"] || "").toLowerCase()
        const raw = appName || node.nickname || node.description || node.name || fallback

        if (bin.indexOf("youtube-music") !== -1 || raw.toLowerCase().indexOf("youtube-music") !== -1) return "Pear Desktop"
        if (raw === "Sober" || bin.indexOf("sober") !== -1) return "Roblox (Sober)"
        if (bin === "zen-bin" || raw.toLowerCase().indexOf("zen") !== -1) return "Zen Browser"
        if (raw.toLowerCase().indexOf("ayugram") !== -1 || bin.indexOf("ayugram") !== -1) return "AyuGram"
        if (raw.toLowerCase().indexOf("vesktop") !== -1) return "Vesktop"
        if (raw.toLowerCase().indexOf("chromium") !== -1 && mediaName !== "") return "Pear / " + mediaName
        return raw
    }

    function appIcon(node) {
        if (!node) return "equalizer"
        const props = node.properties || {}
        const s = (String(props["application.name"] || "") + " " + String(props["application.process.binary"] || "") + " " + String(node.name || "")).toLowerCase()
        if (s.indexOf("sober") !== -1 || s.indexOf("steam") !== -1 || s.indexOf("wine") !== -1 || s.indexOf("proton") !== -1 || s.indexOf("game") !== -1) return "sports_esports"
        if (s.indexOf("youtube-music") !== -1 || s.indexOf("pear") !== -1 || s.indexOf("spotify") !== -1 || s.indexOf("chromium") !== -1) return "music_note"
        if (s.indexOf("zen") !== -1 || s.indexOf("firefox") !== -1 || s.indexOf("chrome") !== -1) return "public"
        if (s.indexOf("ayugram") !== -1 || s.indexOf("telegram") !== -1 || s.indexOf("vesktop") !== -1 || s.indexOf("discord") !== -1) return "forum"
        if (s.indexOf("mpv") !== -1 || s.indexOf("celluloid") !== -1 || s.indexOf("vlc") !== -1 || s.indexOf("nuvio") !== -1) return "movie"
        return "graphic_eq"
    }

    function pctText(aud) {
        if (!aud) return "0%"
        if (aud.muted) return "Выкл"
        return Math.round(Math.max(0, Math.min(1.5, aud.volume || 0)) * 100) + "%"
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
            Behavior on anchors.rightMargin { M3Anim { type: M3Anim.FastSpatial } }
            y: volWindow.animOpen ? 40 : 26
            width: 396
            implicitHeight: Math.min(640, volCol.implicitHeight + 36)
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: volWindow.animOpen ? 1.0 : 0.0
            scale: volWindow.animOpen ? 1.0 : 0.95
            transformOrigin: Item.TopRight

            Behavior on y { M3Anim { type: M3Anim.FastSpatial } }
            Behavior on scale { M3Anim { type: M3Anim.FastSpatial } }
            Behavior on opacity { M3Anim { type: M3Anim.FastEffects } }
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
                    spacing: 10

                    Rectangle {
                        width: 34; height: 34; radius: 12
                        color: Theme.primaryContainer
                        M3Icon {
                            anchors.centerIn: parent
                            name: (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted) ? "volume_off" : "volume_up"
                            size: 19
                            filled: true
                            color: Theme.fgPrimaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        M3Text { role: "headline"; customSize: 17; text: "Громкость и звук"; color: Theme.fgSurface }
                        M3Text {
                            role: "label"
                            customSize: 11
                            text: volWindow.appStreams.length > 0
                                ? ("Активных приложений: " + volWindow.appStreams.length)
                                : "Система и устройства"
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        height: 30
                        implicitWidth: pavuRow.implicitWidth + 18
                        radius: 15
                        color: pavuA.containsMouse ? Theme.primary : Theme.primaryContainer
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: pavuRow
                            anchors.centerIn: parent
                            spacing: 5
                            M3Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "tune"
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

                // ─── 1. Master System Output Card ───
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: sysOutCol.implicitHeight + 22
                    radius: 20
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        id: sysOutCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            M3Text {
                                role: "labelEmphasized"
                                customSize: 12
                                text: "Система · " + volWindow.nodeLabel(Pipewire.defaultAudioSink, "Основной вывод")
                                color: Theme.fgSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            M3Text {
                                readonly property var aud: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
                                role: "labelEmphasized"
                                customSize: 12
                                text: volWindow.pctText(aud)
                                color: Theme.primary
                            }
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
                }

                // ─── 2. Microphone Input Row ───
                Rectangle {
                    visible: Pipewire.defaultAudioSource !== null
                    Layout.fillWidth: true
                    implicitHeight: micCol.implicitHeight + 20
                    radius: 20
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        id: micCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            M3Text {
                                role: "labelEmphasized"
                                customSize: 12
                                text: "Микрофон · " + volWindow.nodeLabel(Pipewire.defaultAudioSource, "Ввод")
                                color: Theme.fgSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            M3Text {
                                readonly property var aud: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
                                role: "labelEmphasized"
                                customSize: 12
                                text: volWindow.pctText(aud)
                                color: Theme.secondary
                            }
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
                }

                // ─── 3. Per-App Live Volume Mixer (M3 Expressive Card List!) ───
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        M3Text {
                            role: "labelEmphasized"
                            customSize: 12
                            text: "Громкость приложений"
                            color: Theme.fgSurfaceVariant
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            visible: volWindow.appStreams.length > 0
                            height: 20
                            implicitWidth: cntLbl.implicitWidth + 12
                            radius: 10
                            color: Theme.tertiaryContainer
                            M3Text {
                                id: cntLbl
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                role: "labelEmphasized"
                                customSize: 10
                                text: String(volWindow.appStreams.length)
                                color: Theme.fgTertiaryContainer
                            }
                        }
                    }

                    // Quiet empty card if no apps currently output audio
                    Rectangle {
                        visible: volWindow.appStreams.length === 0
                        Layout.fillWidth: true
                        height: 46
                        radius: 18
                        color: Theme.surfaceContainerLow

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            M3Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "volume_mute"
                                size: 17
                                color: Theme.fgSurfaceVariant
                            }
                            M3Text {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "label"
                                customSize: 12
                                text: "Нет запущенных приложений со звуком"
                                color: Theme.fgSurfaceVariant
                            }
                        }
                    }

                    // Scrollable per-app audio stream cards
                    Flickable {
                        visible: volWindow.appStreams.length > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(248, appsCol.implicitHeight)
                        contentWidth: width
                        contentHeight: appsCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: appsCol
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: volWindow.appStreams
                                delegate: Rectangle {
                                    id: appRowCard
                                    required property var modelData
                                    readonly property var aud: modelData ? modelData.audio : null
                                    Layout.fillWidth: true
                                    implicitHeight: appRowCol.implicitHeight + 18
                                    radius: 18
                                    color: Theme.surfaceContainerHigh

                                    ColumnLayout {
                                        id: appRowCol
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 6

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Rectangle {
                                                width: 24; height: 24; radius: 8
                                                color: Theme.tertiaryContainer
                                                M3Icon {
                                                    anchors.centerIn: parent
                                                    name: volWindow.appIcon(appRowCard.modelData)
                                                    size: 14
                                                    filled: true
                                                    color: Theme.fgTertiaryContainer
                                                }
                                            }

                                            M3Text {
                                                role: "labelEmphasized"
                                                customSize: 12
                                                text: volWindow.nodeLabel(appRowCard.modelData, "Приложение")
                                                color: Theme.fgSurface
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            M3Text {
                                                role: "labelEmphasized"
                                                customSize: 11
                                                text: volWindow.pctText(appRowCard.aud)
                                                color: (appRowCard.aud && appRowCard.aud.muted) ? Theme.fgSurfaceVariant : Theme.tertiary
                                            }
                                        }

                                        M3ExpressiveSlider {
                                            Layout.fillWidth: true
                                            value: appRowCard.aud ? Math.max(0, Math.min(1, appRowCard.aud.volume || 0)) : 0
                                            muted: appRowCard.aud ? !!appRowCard.aud.muted : false
                                            iconName: volWindow.appIcon(appRowCard.modelData)
                                            mutedIconName: "volume_off"
                                            iconClickable: true
                                            activeColor: Theme.tertiary
                                            onActiveColor: Theme.fgTertiary
                                            trackHeight: 30
                                            onIconClicked: if (appRowCard.aud) appRowCard.aud.muted = !appRowCard.aud.muted
                                            onMoved: v => { if (appRowCard.aud) { appRowCard.aud.muted = false; appRowCard.aud.volume = v } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─── 4. Output Device Switcher ───
                ColumnLayout {
                    visible: volWindow.outputSinks.length > 1
                    Layout.fillWidth: true
                    spacing: 6

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

                            Behavior on radius { M3Anim { type: M3Anim.FastSpatial } }
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
