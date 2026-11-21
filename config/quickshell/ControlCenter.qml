import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

PanelWindow {
    id: ccWindow
    required property bool isOpen
    property int navDir: 0
    signal closeRequested()
    signal openSettingsRequested()
    signal openVolumeRequested()
    signal openNetworkRequested()
    signal openCustomizationRequested()
    signal openPowerRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            refreshSystemState()
            openNextTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer {
        id: openNextTick
        interval: 10
        onTriggered: ccWindow.animOpen = true
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
    WlrLayershell.namespace: "m3-control-center"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Live PipeWire audio
    PwObjectTracker {
        objects: {
            const arr = []
            if (Pipewire.defaultAudioSink) arr.push(Pipewire.defaultAudioSink)
            if (Pipewire.defaultAudioSource) arr.push(Pipewire.defaultAudioSource)
            return arr
        }
    }
    readonly property var sinkAudio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var micAudio: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
    readonly property bool micMuted: micAudio ? !!micAudio.muted : false
    readonly property real volumeRatio: sinkAudio ? Math.max(0, Math.min(1, sinkAudio.volume || 0)) : 0
    readonly property bool isMuted: sinkAudio ? !!sinkAudio.muted : false

    // Live Hardware DDC/CI Monitor Brightness (0.05 .. 1.0)
    property real brightnessRatio: 1.0
    property int pendingBrightness: -1

    function applyBrightness(pct) {
        const clamped = Math.max(5, Math.min(100, Math.round(pct)))
        brightnessRatio = clamped / 100.0
        pendingBrightness = clamped
        if (!brightSetTimer.running) brightSetTimer.start()
    }

    Timer {
        id: brightSetTimer
        interval: 90
        onTriggered: {
            if (ccWindow.pendingBrightness >= 5) {
                const v = ccWindow.pendingBrightness
                ccWindow.pendingBrightness = -1
                NiriState.runDetached(["__HOME__/.local/bin/m3-brightness", "set", String(v)])
            }
        }
    }

    // Live MPRIS player
    readonly property var activePlayer: {
        const list = Mpris.players.values
        if (!list || list.length === 0) return null
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i]
        }
        return list[0]
    }

    // Live Clock for Header
    SystemClock {
        id: ccClock
        precision: SystemClock.Seconds
    }

    readonly property string headerTime: {
        const d = ccClock.date
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
    }
    readonly property string headerDate: {
        const d = ccClock.date
        const days = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
        const months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
    }

    // Live PC States
    property bool netConnected: true
    property string netName: "Сеть активна"
    property string netIcon: "lan"
    property bool dndActive: NiriState.dndEnabled
    property bool nightLightActive: false
    property string nightLightTemp: "4000"
    property bool caffeineActive: false

    readonly property string schemeLabel: {
        const map = {
            "scheme-content": "Content",
            "scheme-tonal-spot": "Tonal Spot",
            "scheme-vibrant": "Vibrant",
            "scheme-fidelity": "Fidelity",
            "scheme-expressive": "Expressive"
        }
        return map[Theme.scheme] || Theme.scheme
    }

    function refreshSystemState() {
        netProc.running = false; netProc.running = true
        nlProc.running = false; nlProc.running = true
        cafProc.running = false; cafProc.running = true
        brightGetProc.running = false; brightGetProc.running = true
    }

    Process {
        id: brightGetProc
        command: ["__HOME__/.local/bin/m3-brightness", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim(), 10)
                if (!isNaN(v) && v >= 5 && v <= 100) ccWindow.brightnessRatio = v / 100.0
            }
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION dev status 2>/dev/null | grep ':connected:' | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (line === "") {
                    ccWindow.netConnected = false
                    ccWindow.netName = "Отключена"
                    ccWindow.netIcon = "wifi_off"
                } else {
                    const parts = line.split(":")
                    const typ = parts[0] || ""
                    const conn = parts.slice(2).join(":") || "Подключено"
                    ccWindow.netConnected = true
                    ccWindow.netName = conn
                    ccWindow.netIcon = (typ === "wifi") ? "wifi" : "lan"
                }
            }
        }
    }

    Process {
        id: nlProc
        command: ["__HOME__/.local/bin/m3-nightlight", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(":")
                ccWindow.nightLightActive = parts[0] === "on"
                if (parts[1]) ccWindow.nightLightTemp = parts[1]
            }
        }
    }

    Process {
        id: cafProc
        command: ["__HOME__/.local/bin/m3-caffeine", "status"]
        stdout: StdioCollector {
            onStreamFinished: ccWindow.caffeineActive = text.trim() === "on"
        }
    }

    // Reusable Canonical Android 16 Material Design 3 Expressive Wide Pill Tile
    component QsTile: Rectangle {
        id: tile
        property string iconName: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool accentOnActive: true
        signal triggered()

        height: 58
        radius: tileArea.pressed ? 14 : (active ? 18 : 29)
        color: active
            ? (accentOnActive ? Theme.primaryContainer : Theme.secondaryContainer)
            : (tileArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
        scale: tileArea.pressed ? 0.96 : 1.0

        Behavior on radius { SpringAnimation { spring: 5.2; damping: 0.35; epsilon: 0.2 } }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.40 } }

        readonly property color textPrimary: active
            ? (accentOnActive ? Theme.fgPrimaryContainer : Theme.fgSecondaryContainer)
            : Theme.fgSurface
        readonly property color textSecondary: active
            ? Theme.alpha(textPrimary, 0.82)
            : Theme.fgSurfaceVariant

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 13
            spacing: 11

            M3Icon {
                name: tile.iconName
                size: 22
                filled: tile.active || tileArea.containsMouse
                color: tile.active ? tile.textPrimary : Theme.primary
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                M3Text {
                    role: "labelEmphasized"
                    customSize: 13
                    emphasized: tile.active || tileArea.containsMouse
                    text: tile.title
                    color: tile.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                M3Text {
                    role: "label"
                    text: tile.subtitle
                    color: tile.textSecondary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.triggered()
        }
    }

    // Reusable Circular Header Action Button (with optional smooth rotation for gear icon!)
    component CircleActionBtn: Rectangle {
        id: cbtn
        property string iconName: ""
        property bool destructive: false
        property bool spinOnHover: false
        signal triggered()

        width: 36
        height: 36
        radius: cArea.pressed ? 10 : (cArea.containsMouse ? 13 : 18)
        color: cArea.containsMouse
            ? (destructive ? Theme.errorContainer : Theme.primaryContainer)
            : Theme.surfaceContainerHigh
        scale: cArea.pressed ? 0.92 : 1.0

        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.40 } }

        M3Icon {
            anchors.centerIn: parent
            name: cbtn.iconName
            size: 19
            filled: cArea.containsMouse
            rotation: (cbtn.spinOnHover && cArea.containsMouse) ? 60 : 0
            color: cArea.containsMouse
                ? (cbtn.destructive ? Theme.fgErrorContainer : Theme.fgPrimaryContainer)
                : Theme.fgSurfaceVariant

            Behavior on rotation { SpringAnimation { spring: 4.5; damping: 0.36 } }
        }

        MouseArea {
            id: cArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cbtn.triggered()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: ccWindow.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, ccWindow.animOpen ? 0.16 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: ccWindow.closeRequested()
        }

        Rectangle {
            id: sheet
            anchors.right: parent.right
            anchors.rightMargin: ccWindow.animOpen ? 12 : (12 - ccWindow.navDir * 22)
            Behavior on anchors.rightMargin { SpringAnimation { spring: 5.0; damping: 0.36; epsilon: 0.2 } }
            y: ccWindow.animOpen ? 40 : 24
            width: 396
            implicitHeight: sheetCol.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: ccWindow.animOpen ? 1.0 : 0.0
            scale: ccWindow.animOpen ? 1.0 : 0.94
            transformOrigin: Item.TopRight

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: sheetCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                // ─── 1. ANDROID 16 HEADER (Wide Display Clock + Gear Settings + Lock + Power) ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        spacing: 1

                        M3Text {
                            role: "display"
                            customSize: 26
                            text: ccWindow.headerTime
                            color: Theme.fgSurface
                        }

                        M3Text {
                            role: "label"
                            customSize: 12
                            text: ccWindow.headerDate
                            color: Theme.primary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                        // Gear Icon -> Full Detailed M3 Expressive Settings Hub!
                        CircleActionBtn {
                            iconName: "settings"
                            spinOnHover: true
                            onTriggered: ccWindow.openSettingsRequested()
                        }

                        CircleActionBtn {
                            iconName: "lock"
                            onTriggered: {
                                ccWindow.closeRequested()
                                NiriState.runDetached(["hyprlock"])
                            }
                        }

                        CircleActionBtn {
                            iconName: "power_settings_new"
                            destructive: true
                            onTriggered: ccWindow.openPowerRequested()
                        }
                    }
                }

                // ─── 2. STRICT M3 EXPRESSIVE SPLIT-TRACK SLIDERS (с вертикальной палочкой!) ───
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Master Volume Slider
                    M3ExpressiveSlider {
                        Layout.fillWidth: true
                        value: ccWindow.volumeRatio
                        muted: ccWindow.isMuted
                        iconName: ccWindow.volumeRatio < 0.01 ? "volume_mute" : (ccWindow.volumeRatio < 0.5 ? "volume_down" : "volume_up")
                        mutedIconName: "volume_off"
                        iconClickable: true
                        activeColor: Theme.primary
                        onActiveColor: Theme.fgPrimary
                        trackHeight: 36
                        onIconClicked: {
                            if (ccWindow.sinkAudio) ccWindow.sinkAudio.muted = !ccWindow.sinkAudio.muted
                        }
                        onMoved: v => {
                            if (!ccWindow.sinkAudio) return
                            ccWindow.sinkAudio.muted = false
                            ccWindow.sinkAudio.volume = v
                        }
                    }

                    // Hardware Monitor Brightness Slider (MSI G242 DDC/CI)
                    M3ExpressiveSlider {
                        Layout.fillWidth: true
                        value: ccWindow.brightnessRatio
                        minValue: 0.05
                        iconName: ccWindow.brightnessRatio < 0.35 ? "brightness_low" : (ccWindow.brightnessRatio < 0.72 ? "brightness_medium" : "brightness_high")
                        iconClickable: false
                        activeColor: Theme.tertiary
                        onActiveColor: Theme.fgTertiary
                        trackHeight: 36
                        onMoved: v => ccWindow.brightnessRatio = v
                        onCommitted: v => ccWindow.applyBrightness(v * 100)
                    }
                }

                // ─── 3. 8 USEFUL PC-ONLY QUICK SETTINGS TILES (ZERO REDUNDANT KEYBOUND CLUTTER!) ───
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 9
                    columnSpacing: 9

                    // 1) Сеть
                    QsTile {
                        Layout.fillWidth: true
                        iconName: ccWindow.netIcon
                        title: "Сеть"
                        subtitle: ccWindow.netName
                        active: ccWindow.netConnected
                        onTriggered: ccWindow.openNetworkRequested()
                    }

                    // 2) Микшер звука
                    QsTile {
                        Layout.fillWidth: true
                        iconName: "graphic_eq"
                        title: "Микшер звука"
                        subtitle: "Выходы и каналы"
                        active: false
                        onTriggered: ccWindow.openVolumeRequested()
                    }

                    // 3) Не беспокоить (DND)
                    QsTile {
                        Layout.fillWidth: true
                        iconName: ccWindow.dndActive ? "do_not_disturb_on" : "notifications"
                        title: "Не беспокоить"
                        subtitle: ccWindow.dndActive ? "Включён" : "Выключен"
                        active: ccWindow.dndActive
                        onTriggered: {
                            NiriState.dndEnabled = !NiriState.dndEnabled
                        }
                    }

                    // 4) Тема M3 (Dark / Light)
                    QsTile {
                        Layout.fillWidth: true
                        iconName: Theme.mode === "dark" ? "dark_mode" : "light_mode"
                        title: "Тема M3"
                        subtitle: Theme.mode === "dark" ? "Тёмная" : "Светлая"
                        active: Theme.mode === "dark"
                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-toggle-mode"])
                    }

                    // 5) Ночной свет (Тёплый экран wlsunset)
                    QsTile {
                        Layout.fillWidth: true
                        iconName: "bedtime"
                        title: "Ночной свет"
                        subtitle: ccWindow.nightLightActive ? (ccWindow.nightLightTemp + "K · Активен") : "Выключен"
                        active: ccWindow.nightLightActive
                        onTriggered: {
                            ccWindow.nightLightActive = !ccWindow.nightLightActive
                            NiriState.runDetached(["__HOME__/.local/bin/m3-nightlight", "toggle"])
                        }
                    }

                    // 6) Не гасить экран (Keep-Awake / hypridle pause)
                    QsTile {
                        Layout.fillWidth: true
                        iconName: "coffee"
                        title: "Не гасить экран"
                        subtitle: ccWindow.caffeineActive ? "Сон отключён" : "Автосон активен"
                        active: ccWindow.caffeineActive
                        onTriggered: {
                            ccWindow.caffeineActive = !ccWindow.caffeineActive
                            NiriState.runDetached(["__HOME__/.local/bin/m3-caffeine", "toggle"])
                        }
                    }

                    // 7) Кастомизация (иконка карандаша -> отдельное меню кастомизации!)
                    QsTile {
                        Layout.fillWidth: true
                        iconName: "edit"
                        title: "Кастомизация"
                        subtitle: "Обои, цвет, окна"
                        active: false
                        onTriggered: ccWindow.openCustomizationRequested()
                    }

                    // 8) Микрофон (глобальное отключение микрофона — важно на 60% клавиатуре без бинда!)
                    QsTile {
                        Layout.fillWidth: true
                        iconName: ccWindow.micMuted ? "mic_off" : "mic"
                        title: "Микрофон"
                        subtitle: ccWindow.micMuted ? "Заглушён" : "Активен"
                        active: !ccWindow.micMuted
                        accentOnActive: true
                        onTriggered: {
                            if (ccWindow.micAudio) {
                                ccWindow.micAudio.muted = !ccWindow.micAudio.muted
                            } else {
                                NiriState.runDetached(["swayosd-client", "--input-volume", "mute-toggle"])
                            }
                        }
                    }
                }

                // ─── 4. CANONICAL ANDROID 16 MEDIA CARD WITH WAVY AUDIO SCRUBBER ───
                Rectangle {
                    id: mediaCard
                    visible: ccWindow.activePlayer !== null && (ccWindow.activePlayer.trackTitle || "") !== ""
                    Layout.fillWidth: true
                    implicitHeight: mediaCardCol.implicitHeight + 26
                    radius: 24
                    color: Theme.tertiaryContainer
                    Behavior on color { ColorAnimation { duration: 220 } }

                    ColumnLayout {
                        id: mediaCardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 13
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 11

                            Rectangle {
                                width: 50
                                height: 50
                                radius: 14
                                color: Theme.alpha(Theme.fgTertiaryContainer, 0.14)
                                clip: true
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: ccWindow.activePlayer ? (ccWindow.activePlayer.trackArtUrl || "") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    visible: status === Image.Ready
                                }

                                M3Icon {
                                    anchors.centerIn: parent
                                    visible: !artImg.visible
                                    name: "music_note"
                                    size: 24
                                    filled: true
                                    color: Theme.fgTertiaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                M3Text {
                                    role: "title"
                                    customSize: 13
                                    text: ccWindow.activePlayer ? (ccWindow.activePlayer.trackTitle || "Без названия") : ""
                                    color: Theme.fgTertiaryContainer
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                M3Text {
                                    role: "label"
                                    text: ccWindow.activePlayer ? (ccWindow.activePlayer.trackArtist || ccWindow.activePlayer.identity || "") : ""
                                    color: Theme.alpha(Theme.fgTertiaryContainer, 0.80)
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Row {
                                spacing: 5
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: prevA.containsMouse ? Theme.alpha(Theme.fgTertiaryContainer, 0.22) : Theme.alpha(Theme.fgTertiaryContainer, 0.10)
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    M3Icon {
                                        anchors.centerIn: parent
                                        name: "skip_previous"
                                        size: 18
                                        filled: true
                                        color: Theme.fgTertiaryContainer
                                    }
                                    MouseArea {
                                        id: prevA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (ccWindow.activePlayer) ccWindow.activePlayer.previous()
                                    }
                                }

                                Rectangle {
                                    id: ccPlayBtn
                                    readonly property bool playing: ccWindow.activePlayer ? !!ccWindow.activePlayer.isPlaying : false
                                    width: 44
                                    height: 44
                                    radius: playA.pressed ? 10 : (playing ? 13 : 22)
                                    color: Theme.tertiary
                                    scale: playA.pressed ? 0.92 : (playA.containsMouse ? 1.05 : 1.0)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on radius { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4.5
                                        opacity: ccPlayBtn.playing ? 1.0 : 0.0
                                        scale: ccPlayBtn.playing ? 1.0 : 0.55
                                        rotation: ccPlayBtn.playing ? 0 : -28
                                        Behavior on opacity { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                        Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                        Rectangle { width: 4.5; height: 15; radius: 2.25; color: Theme.fgTertiary }
                                        Rectangle { width: 4.5; height: 15; radius: 2.25; color: Theme.fgTertiary }
                                    }

                                    M3Icon {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: 1.0
                                        name: "play_arrow"
                                        size: 22
                                        filled: true
                                        color: Theme.fgTertiary
                                        opacity: ccPlayBtn.playing ? 0.0 : 1.0
                                        scale: ccPlayBtn.playing ? 0.55 : 1.0
                                        rotation: ccPlayBtn.playing ? 28 : 0
                                        Behavior on opacity { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                        Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                                    }

                                    MouseArea {
                                        id: playA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (ccWindow.activePlayer) ccWindow.activePlayer.togglePlaying()
                                    }
                                }

                                Rectangle {
                                    width: 30; height: 30; radius: 15
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: nextA.containsMouse ? Theme.alpha(Theme.fgTertiaryContainer, 0.22) : Theme.alpha(Theme.fgTertiaryContainer, 0.10)
                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    M3Icon {
                                        anchors.centerIn: parent
                                        name: "skip_next"
                                        size: 18
                                        filled: true
                                        color: Theme.fgTertiaryContainer
                                    }
                                    MouseArea {
                                        id: nextA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: if (ccWindow.activePlayer) ccWindow.activePlayer.next()
                                    }
                                }
                            }
                        }

                        M3WavyScrubber {
                            Layout.fillWidth: true
                            player: ccWindow.activePlayer
                            activeColor: Theme.tertiary
                            inactiveColor: Theme.alpha(Theme.fgTertiaryContainer, 0.28)
                            textColor: Theme.alpha(Theme.fgTertiaryContainer, 0.85)
                            activeAnimation: ccWindow.animOpen
                            showTimestamps: true
                        }
                    }
                }
            }
        }
    }
}
