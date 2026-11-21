import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Widgets

PanelWindow {
    id: bar
    required property bool controlCenterOpen
    required property bool mediaPopupOpen
    required property bool calendarOpen
    required property bool sysMonOpen
    required property bool volumeOpen
    required property bool barHidden
    required property bool isRecording
    signal toggleControlCenter()
    signal toggleMediaPopup()
    signal toggleCalendar()
    signal toggleSysMon()
    signal toggleVolume()

    // Filter out Shelly & Telegram status icons from navbar tray
    readonly property var filteredTrayItems: {
        const vals = SystemTray.items.values || []
        return vals.filter(it => {
            const s = ((it.id || "") + " " + (it.title || "") + " " + (it.icon || "")).toLowerCase()
            if (s.indexOf("shelly") !== -1) return false
            if (s.indexOf("telegram") !== -1) return false
            if (s.indexOf("ayugram") !== -1) return false
            return true
        })
    }

    // Smooth M3 Expressive F1 hide/show animation:
    // Animates BOTH exclusiveZone (30 <-> 0) so Niri tiled windows stretch & shrink smoothly in height,
    // AND locks barContent.y 1:1 to animatedExclusiveZone so bar & windows move as one physical spring!
    readonly property bool effectiveHidden: barHidden || NiriState.focusedIsFullscreen
    property real animatedExclusiveZone: 30
    property bool animBarShown: true
    visible: !effectiveHidden || hideDelay.running

    Behavior on animatedExclusiveZone {
        NumberAnimation {
            duration: bar.effectiveHidden ? 280 : 340
            easing.type: Easing.BezierSpline
            easing.bezierCurve: bar.barHidden
                ? [0.30, 0.0, 0.15, 1.0, 1.0, 1.0]
                : [0.22, 1.15, 0.36, 1.0, 1.0, 1.0]
        }
    }

    onEffectiveHiddenChanged: {
        if (effectiveHidden) {
            animBarShown = false
            animatedExclusiveZone = 0
            hideDelay.restart()
        } else {
            hideDelay.stop()
            showNextTick.restart()
        }
    }

    Timer {
        id: showNextTick
        interval: 10
        onTriggered: {
            bar.animBarShown = true
            bar.animatedExclusiveZone = 30
        }
    }

    Timer {
        id: hideDelay
        interval: 320
    }

    // Live elapsed recording seconds counter
    property int recSeconds: 0
    onIsRecordingChanged: {
        if (isRecording) recSeconds = 0
    }
    Timer {
        interval: 1000
        running: bar.isRecording
        repeat: true
        onTriggered: bar.recSeconds += 1
    }
    readonly property string recTimerText: {
        const m = Math.floor(recSeconds / 60)
        const s = recSeconds % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 36
    exclusiveZone: Math.max(0, Math.round(animatedExclusiveZone))
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "m3-topbar"

    // Track default audio sink cleanly via PipeWire
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property int volumePct: sinkAudio ? Math.round((sinkAudio.volume || 0) * 100) : 0
    readonly property bool isMuted: sinkAudio ? !!sinkAudio.muted : false

    // Active MPRIS player (prefer playing)
    readonly property var activePlayer: {
        const list = Mpris.players.values
        if (!list || list.length === 0) return null
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i]
        }
        return list[0]
    }

    // Localized Russian clock
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    readonly property string formattedTime: {
        const d = sysClock.date
        const days = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        const months = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
        const hh = String(d.getHours()).padStart(2, "0")
        const mm = String(d.getMinutes()).padStart(2, "0")
        return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()] + " · " + hh + ":" + mm
    }

    Item {
        id: barContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        height: 32
        // Locked 1:1 with animatedExclusiveZone so windows stretch/compress in exact sync with navbar glide!
        y: Math.min(8, bar.animatedExclusiveZone - 26)
        opacity: Math.max(0.0, Math.min(1.0, bar.animatedExclusiveZone / 24.0))
        scale: 0.95 + 0.05 * Math.max(0.0, Math.min(1.0, bar.animatedExclusiveZone / 30.0))
        transformOrigin: Item.Top

        // ══════════════════════════════════════════════════
        // LEFT: M3 Expressive Sliding Workspaces Capsule
        // ══════════════════════════════════════════════════
        Rectangle {
            id: wsCapsule
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            radius: 16
            color: Theme.alpha(Theme.surfaceContainerHigh, 0.96)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.42)

            readonly property int wsCount: Math.max(1, NiriState.workspaces.length)
            readonly property int dotSpacing: 16
            readonly property int activeExtra: 16
            implicitWidth: 20 + wsCount * dotSpacing + activeExtra

            Behavior on implicitWidth {
                SpringAnimation { spring: 5.0; damping: 0.42; epsilon: 0.2 }
            }
            Behavior on color { ColorAnimation { duration: 220 } }

            // Compute exact x of workspace i accounting for the active pill's extra width
            function slotX(idx) {
                const act = NiriState.activeWorkspaceIndex
                return 10 + idx * dotSpacing + (idx > act ? activeExtra : 0)
            }

            // Inactive background dots
            Repeater {
                model: NiriState.workspaces
                Item {
                    readonly property bool isAct: index === NiriState.activeWorkspaceIndex
                    x: wsCapsule.slotX(index)
                    y: 0
                    width: isAct ? (wsCapsule.dotSpacing + wsCapsule.activeExtra) : wsCapsule.dotSpacing
                    height: wsCapsule.height

                    Behavior on x {
                        SpringAnimation { spring: 5.0; damping: 0.38; epsilon: 0.2 }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: wsHover.containsMouse && !parent.isAct ? 13 : 9
                        height: 9
                        radius: 4.5
                        opacity: parent.isAct ? 0.0 : 1.0
                        color: modelData.is_urgent ? Theme.errorColor : (wsHover.containsMouse ? Theme.secondary : Theme.alpha(Theme.outline, 0.65))

                        Behavior on width { SpringAnimation { spring: 5.5; damping: 0.36 } }
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    MouseArea {
                        id: wsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NiriState.focusWorkspace(modelData.idx)
                    }
                }
            }

            // SINGLE Sliding M3 Expressive Active Workspace Pill
            Rectangle {
                id: wsActivePill
                y: (wsCapsule.height - height) / 2
                x: wsCapsule.slotX(NiriState.activeWorkspaceIndex) + 3
                width: 28
                height: 9
                radius: 4.5
                color: Theme.primary

                Behavior on x {
                    SpringAnimation { spring: 4.8; damping: 0.34; epsilon: 0.2 }
                }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        // ══════════════════════════════════════════════════
        // CENTER: Niri-Synced App Dock + MPRIS Media Pill
        // ══════════════════════════════════════════════════
        Row {
            id: centerGroup
            anchors.centerIn: parent
            spacing: 6

            // Unified M3 Expressive Dock Capsule (Open Niri windows + closed pinned apps, ZERO duplicates!)
            Rectangle {
                id: dockCapsule
                height: 32
                radius: 16
                color: Theme.alpha(Theme.surfaceContainerHigh, 0.96)
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.42)

                readonly property int slotW: 36
                readonly property int slotGap: 4
                readonly property int slotStride: slotW + slotGap
                readonly property int winCount: NiriState.windowModel.count
                readonly property int stripWidth: winCount > 0 ? (winCount * slotStride - slotGap) : 0

                implicitWidth: 6 + launcherBtn.width + (winCount > 0 ? (11 + stripWidth) : 0) + 8

                Behavior on implicitWidth {
                    SpringAnimation { spring: 5.0; damping: 0.42; epsilon: 0.2 }
                }
                Behavior on color { ColorAnimation { duration: 220 } }

                // App Launcher Trigger Button
                Rectangle {
                    id: launcherBtn
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 26
                    radius: launchArea.pressed ? 8 : (launchArea.containsMouse ? 9 : 12)
                    color: launchArea.containsMouse ? Theme.secondaryContainer : "transparent"

                    Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    M3Icon {
                        anchors.centerIn: parent
                        name: "apps"
                        size: 21
                        filled: launchArea.containsMouse
                        color: launchArea.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                    }

                    MouseArea {
                        id: launchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NiriState.runDetached(["__HOME__/.local/bin/launcher-toggle"])
                    }
                }

                // Subtle Divider
                Rectangle {
                    id: dockSep
                    visible: dockCapsule.winCount > 0
                    anchors.left: launcherBtn.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 14
                    radius: 1
                    color: Theme.alpha(Theme.outlineVariant, 0.65)
                }

                // Unified Dock Strip (exact Niri column order + remaining pinned apps, ONE sliding M3 active pill!)
                Item {
                    id: winStrip
                    anchors.left: dockSep.right
                    anchors.leftMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: dockCapsule.stripWidth
                    height: 28
                    visible: dockCapsule.winCount > 0

                    // SINGLE Material Design 3 Expressive Sliding Active Indicator Pill
                    Rectangle {
                        id: activeWinIndicator
                        readonly property bool valid: NiriState.focusedIndex >= 0 && NiriState.focusedIndex < dockCapsule.winCount
                        x: valid ? NiriState.focusedIndex * dockCapsule.slotStride : 0
                        y: 0
                        width: dockCapsule.slotW
                        height: 28
                        radius: 11
                        color: Theme.primaryContainer
                        opacity: valid ? 1.0 : 0.0

                        Behavior on x {
                            SpringAnimation {
                                spring: 4.6
                                damping: 0.34
                                epsilon: 0.2
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }
                        Behavior on color { ColorAnimation { duration: 220 } }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 1
                            width: 14
                            height: 2
                            radius: 1.5
                            color: Theme.primary
                            Behavior on color { ColorAnimation { duration: 220 } }
                        }
                    }

                    // Unified App Icon Delegates
                    Repeater {
                        model: NiriState.windowModel
                        delegate: Item {
                            id: winDelegate
                            readonly property bool isFocused: model.isOpenHere && model.winId === NiriState.focusedWindowId
                            x: index * dockCapsule.slotStride
                            y: 0
                            width: dockCapsule.slotW
                            height: 28

                            Behavior on x {
                                SpringAnimation {
                                    spring: 4.8
                                    damping: 0.38
                                    epsilon: 0.2
                                }
                            }

                            // Hover tonal state layer
                            Rectangle {
                                anchors.fill: parent
                                radius: winArea.pressed ? 8 : 11
                                color: model.isUrgent
                                    ? Theme.errorContainer
                                    : (winArea.containsMouse && !winDelegate.isFocused ? Theme.alpha(Theme.fgSurface, 0.10) : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
                            }

                            Image {
                                id: appIconImg
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: winDelegate.isFocused ? -0.5 : (model.isOpenHere || model.isRunningElsewhere ? -0.5 : 0)
                                width: 22
                                height: 22
                                source: model.iconSource
                                sourceSize.width: 44
                                sourceSize.height: 44
                                smooth: true
                                mipmap: true
                                scale: winArea.pressed ? 0.88 : (winDelegate.isFocused ? 1.05 : (winArea.containsMouse ? 1.06 : (model.isOpenHere ? 0.96 : 0.92)))
                                opacity: winDelegate.isFocused ? 1.0 : (winArea.containsMouse ? 0.98 : (model.isOpenHere ? 0.88 : (model.isRunningElsewhere ? 0.78 : 0.58)))

                                Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.35 } }
                                Behavior on opacity { NumberAnimation { duration: 160 } }
                                Behavior on anchors.verticalCenterOffset { SpringAnimation { spring: 5.0; damping: 0.38 } }
                            }

                            // Subtle M3 dot under open (non-focused) or running-elsewhere apps
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                width: (!winDelegate.isFocused && (model.isOpenHere || model.isRunningElsewhere)) ? 4 : 0
                                height: 2.5
                                radius: 1.5
                                color: model.isOpenHere ? Theme.primary : Theme.outline
                                opacity: (!winDelegate.isFocused && (model.isOpenHere || model.isRunningElsewhere)) ? 0.85 : 0.0
                                Behavior on width { SpringAnimation { spring: 5.0; damping: 0.38 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: winArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    NiriState.clickDockItem(index, model.winId, model.isOpenHere, model.pinIdx, mouse.button === Qt.MiddleButton)
                                }
                            }
                        }
                    }
                }
            }

            // Expressive Tertiary MPRIS Media Pill (visible smoothly only when media exists)
            Rectangle {
                id: mediaPill
                readonly property bool hasMedia: bar.activePlayer !== null && (bar.activePlayer.trackTitle || "") !== ""
                visible: width > 4
                height: 32
                radius: 16
                clip: true
                color: (bar.mediaPopupOpen || (bar.activePlayer && bar.activePlayer.isPlaying && mediaArea.containsMouse))
                    ? Theme.tertiary
                    : (bar.activePlayer && bar.activePlayer.isPlaying ? Theme.tertiaryContainer : Theme.alpha(Theme.surfaceContainerHigh, 0.94))
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.32)

                implicitWidth: hasMedia ? Math.min(200, mediaRow.implicitWidth + (mediaArea.containsMouse ? 28 : 22)) : 0
                opacity: hasMedia ? 1.0 : 0.0

                Behavior on implicitWidth { SpringAnimation { spring: 4.8; damping: 0.40; epsilon: 0.2 } }
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Behavior on color { ColorAnimation { duration: 180 } }

                Row {
                    id: mediaRow
                    anchors.centerIn: parent
                    spacing: 6

                    // Mini Animated M3 Expressive 4-Bar Audio Waveform inside Navbar Music Pill!
                    Row {
                        id: miniWave
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2.5
                        height: 16

                        readonly property bool playing: bar.activePlayer ? !!bar.activePlayer.isPlaying : false
                        readonly property color barClr: (bar.mediaPopupOpen || (playing && mediaArea.containsMouse))
                            ? Theme.fgTertiary
                            : (playing ? Theme.fgTertiaryContainer : Theme.fgSurfaceVariant)
                        property real phase: 0.0

                        Timer {
                            interval: 45
                            running: miniWave.playing && mediaPill.hasMedia
                            repeat: true
                            onTriggered: miniWave.phase = (miniWave.phase + 0.34) % (Math.PI * 2)
                        }

                        Repeater {
                            model: [0.0, 1.55, 3.1, 4.65]
                            delegate: Rectangle {
                                required property real modelData
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                radius: 1.5
                                height: miniWave.playing
                                    ? (5 + 10 * (0.5 + 0.5 * Math.sin(miniWave.phase + modelData)))
                                    : 4
                                color: miniWave.barClr
                                Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.InOutSine } }
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }
                    }

                    M3Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        role: "labelEmphasized"
                        emphasized: bar.mediaPopupOpen || mediaArea.containsMouse
                        text: bar.activePlayer ? (bar.activePlayer.trackTitle || "") : ""
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: Math.min(implicitWidth, 148)
                        color: (bar.mediaPopupOpen || (bar.activePlayer && bar.activePlayer.isPlaying && mediaArea.containsMouse))
                            ? Theme.fgTertiary
                            : (bar.activePlayer && bar.activePlayer.isPlaying ? Theme.fgTertiaryContainer : Theme.fgSurfaceVariant)
                    }
                }

                MouseArea {
                    id: mediaArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (!bar.activePlayer) return
                        if (mouse.button === Qt.RightButton) bar.activePlayer.togglePlaying()
                        else if (mouse.button === Qt.MiddleButton) bar.activePlayer.next()
                        else bar.toggleMediaPopup()
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════
        // RIGHT: Status Capsule + Control Center Trigger Pill
        // ══════════════════════════════════════════════════
        Row {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Live Pulsing M3 Expressive Recording Pill (visible while F10 recording is active; click to stop!)
            Rectangle {
                id: recPill
                visible: width > 4
                height: 32
                implicitWidth: bar.isRecording ? (recRow.implicitWidth + 20) : 0
                radius: 16
                clip: true
                color: recArea.containsMouse ? Theme.errorColor : Theme.errorContainer
                opacity: bar.isRecording ? 1.0 : 0.0

                Behavior on implicitWidth { SpringAnimation { spring: 5.0; damping: 0.38; epsilon: 0.2 } }
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Behavior on color { ColorAnimation { duration: 160 } }

                Row {
                    id: recRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        id: recDot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: recArea.containsMouse ? Theme.fgError : Theme.errorColor

                        SequentialAnimation on opacity {
                            running: bar.isRecording
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.25; to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        text: "REC " + bar.recTimerText
                        font.family: Theme.fontSans
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: recArea.containsMouse ? Theme.fgError : Theme.fgErrorContainer
                    }
                }

                MouseArea {
                    id: recArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: NiriState.runDetached(["__HOME__/.local/bin/m3-screen-record"])
                }
            }

            // Status Capsule (SystemTray + Layout + Volume + Clock)
            Rectangle {
                id: statusCapsule
                height: 32
                radius: 16
                color: Theme.alpha(Theme.surfaceContainerHigh, 0.96)
                border.width: 1
                border.color: Theme.alpha(Theme.outlineVariant, 0.42)
                implicitWidth: statusRow.implicitWidth + 14

                Behavior on implicitWidth { SpringAnimation { spring: 5.0; damping: 0.42; epsilon: 0.2 } }
                Behavior on color { ColorAnimation { duration: 220 } }

                Row {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 5

                    // System Tray Icons (Shelly & Telegram filtered out)
                    Row {
                        id: trayRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        visible: bar.filteredTrayItems.length > 0

                        Repeater {
                            model: bar.filteredTrayItems
                            delegate: Item {
                                required property var modelData
                                width: 25
                                height: 25
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 11
                                    color: trayArea.containsMouse ? Theme.alpha(Theme.fgSurface, 0.10) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    width: 19
                                    height: 19
                                    source: modelData.icon
                                }

                                MouseArea {
                                    id: trayArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                            if (modelData.hasMenu) {
                                                const pt = mapToItem(null, width / 2, height)
                                                modelData.display(bar, pt.x, pt.y)
                                            } else {
                                                modelData.secondaryActivate()
                                            }
                                        } else if (mouse.button === Qt.MiddleButton) {
                                            modelData.secondaryActivate()
                                        } else {
                                            modelData.activate()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // System Monitor Button (CPU / RAM / GPU / Temps Popup)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        radius: smBtnA.pressed ? 8 : 13
                        color: bar.sysMonOpen
                            ? Theme.primaryContainer
                            : (smBtnA.containsMouse ? Theme.secondaryContainer : "transparent")
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }

                        M3Icon {
                            anchors.centerIn: parent
                            name: "monitoring"
                            size: 20
                            filled: bar.sysMonOpen || smBtnA.containsMouse
                            color: bar.sysMonOpen
                                ? Theme.fgPrimaryContainer
                                : (smBtnA.containsMouse ? Theme.fgSecondaryContainer : Theme.primary)
                        }

                        MouseArea {
                            id: smBtnA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.toggleSysMon()
                        }
                    }

                    // Keyboard Layout Chip (EN / RU)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 22
                        implicitWidth: kbText.implicitWidth + 14
                        radius: 11
                        color: kbArea.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHighest
                        Behavior on color { ColorAnimation { duration: 160 } }

                        M3Text {
                            id: kbText
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            role: "labelEmphasized"
                            customSize: 11
                            emphasized: kbArea.containsMouse
                            text: NiriState.keyboardLayout
                            color: kbArea.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface
                        }

                        MouseArea {
                            id: kbArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NiriState.switchLayout()
                        }
                    }

                    // Volume Chip (Live PipeWire + opens VolumePopup!)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        implicitWidth: volRow.implicitWidth + 14
                        radius: 12
                        color: bar.isMuted
                            ? Theme.errorContainer
                            : (bar.volumeOpen ? Theme.primaryContainer : (volArea.containsMouse ? Theme.secondaryContainer : "transparent"))
                        Behavior on color { ColorAnimation { duration: 160 } }

                        Row {
                            id: volRow
                            anchors.centerIn: parent
                            spacing: 4

                            M3Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: bar.isMuted ? "volume_off" : (bar.volumePct === 0 ? "volume_mute" : (bar.volumePct < 50 ? "volume_down" : "volume_up"))
                                size: 19
                                filled: bar.volumeOpen || volArea.containsMouse || bar.isMuted
                                color: bar.isMuted ? Theme.fgErrorContainer : (bar.volumeOpen ? Theme.fgPrimaryContainer : (volArea.containsMouse ? Theme.fgSecondaryContainer : Theme.primary))
                            }

                            M3Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                role: "labelEmphasized"
                                customSize: 11
                                emphasized: bar.volumeOpen || volArea.containsMouse
                                text: bar.isMuted ? "MUTE" : (bar.volumePct + "%")
                                color: bar.isMuted ? Theme.fgErrorContainer : (bar.volumeOpen ? Theme.fgPrimaryContainer : (volArea.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface))
                            }
                        }

                        MouseArea {
                            id: volArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    NiriState.runDetached(["swayosd-client", "--output-volume", "mute-toggle"])
                                } else {
                                    bar.toggleVolume()
                                }
                            }
                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0) {
                                    NiriState.runDetached(["swayosd-client", "--output-volume", "raise"])
                                } else if (wheel.angleDelta.y < 0) {
                                    NiriState.runDetached(["swayosd-client", "--output-volume", "lower"])
                                }
                            }
                        }
                    }

                    // Clock & Date Chip (opens M3 Expressive Calendar Popup!)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        implicitWidth: clockText.implicitWidth + 14
                        radius: 12
                        color: bar.calendarOpen
                            ? Theme.primaryContainer
                            : (clockArea.containsMouse ? Theme.secondaryContainer : "transparent")
                        Behavior on color { ColorAnimation { duration: 160 } }

                        M3Text {
                            id: clockText
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            role: "labelEmphasized"
                            emphasized: bar.calendarOpen || clockArea.containsMouse
                            text: bar.formattedTime
                            color: bar.calendarOpen
                                ? Theme.fgPrimaryContainer
                                : (clockArea.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface)
                        }

                        MouseArea {
                            id: clockArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.toggleCalendar()
                        }
                    }
                }
            }

            // Control Center Accent Button (Morphing M3 Squircle <-> Pill)
            Rectangle {
                id: ccBtn
                height: 32
                width: (bar.controlCenterOpen || ccArea.containsMouse) ? 42 : 36
                radius: ccArea.pressed ? 8 : (bar.controlCenterOpen ? 16 : (ccArea.containsMouse ? 16 : 11))
                color: bar.controlCenterOpen
                    ? Theme.primary
                    : (ccArea.containsMouse ? Theme.primary : Theme.primaryContainer)
                border.width: 1
                border.color: Theme.alpha(Theme.primary, 0.35)

                Behavior on width { SpringAnimation { spring: 5.2; damping: 0.36; epsilon: 0.2 } }
                Behavior on radius { SpringAnimation { spring: 5.2; damping: 0.36; epsilon: 0.2 } }
                Behavior on color { ColorAnimation { duration: 180 } }

                M3Icon {
                    anchors.centerIn: parent
                    name: "tune"
                    size: 21
                    filled: bar.controlCenterOpen || ccArea.containsMouse
                    rotation: bar.controlCenterOpen ? 90 : 0
                    color: (bar.controlCenterOpen || ccArea.containsMouse) ? Theme.fgPrimary : Theme.fgPrimaryContainer

                    Behavior on rotation { SpringAnimation { spring: 4.5; damping: 0.36 } }
                }

                MouseArea {
                    id: ccArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            NiriState.runDetached(["qs", "ipc", "call", "shell", "toggleSettings"])
                        } else if (mouse.button === Qt.MiddleButton) {
                            NiriState.runDetached(["__HOME__/.local/bin/m3-toggle-mode"])
                        } else {
                            bar.toggleControlCenter()
                        }
                    }
                }
            }
        }
    }
}
