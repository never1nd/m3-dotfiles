import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

PanelWindow {
    id: sw
    required property bool isOpen
    required property bool barHidden
    signal closeRequested()
    signal toggleBarRequested()

    property bool animOpen: false
    property int currentTab: 0
    visible: isOpen || closeDelay.running

    // Live system states
    property real brightnessRatio: 1.0
    property int pendingBright: -1
    property bool nightLightOn: false
    property string nightTemp: "4000"
    property bool caffeineOn: false
    property bool desktopKittyOn: true
    property int niriRadius: 20
    property int niriGaps: 10
    property int niriRing: 3
    property int cpuPct: 0
    property int cpuTemp: 0
    property real ramUsed: 0
    property real ramTotal: 16
    property int ramPct: 0
    property string gpuName: "RTX 2060"
    property int gpuPct: 0
    property int gpuTemp: 0
    property real vramUsed: 0
    property real vramTotal: 12
    property int vramPct: 0
    property string netName: "Подключено"

    readonly property var navItems: [
        { icon: "palette",         label: "Оформление",    sub: "M3 цвет, обои, шрифты" },
        { icon: "desktop_windows", label: "Экран и свет",  sub: "Яркость, ночь, сон" },
        { icon: "volume_up",       label: "Звук и аудио",  sub: "Вывод, микрофон" },
        { icon: "space_dashboard", label: "Окна и Niri",   sub: "Радиусы, отступы, панель" },
        { icon: "memory",          label: "Система и сеть", sub: "Датчики, питание, сеть" },
        { icon: "keyboard",        label: "Клавиши и инфо", sub: "Все сочетания и ОС" }
    ]

    readonly property var outputSinks: {
        const list = Pipewire.nodes.values || []
        return list.filter(n => n && n.isSink && !n.isStream && n.audio !== null)
    }

    PwObjectTracker {
        objects: {
            const out = []
            if (Pipewire.defaultAudioSink) out.push(Pipewire.defaultAudioSink)
            if (Pipewire.defaultAudioSource) out.push(Pipewire.defaultAudioSource)
            for (let i = 0; i < sw.outputSinks.length; i++) out.push(sw.outputSinks[i])
            return out
        }
    }

    function nodeLabel(node, fallback) {
        if (!node) return fallback
        const props = node.properties || {}
        return props["application.name"] || node.nickname || node.description || node.name || fallback
    }

    function refreshAll() {
        brightProc.running = false; brightProc.running = true
        nlProc.running = false; nlProc.running = true
        cafProc.running = false; cafProc.running = true
        niriTuneProc.running = false; niriTuneProc.running = true
        statsProc.running = false; statsProc.running = true
        netProc.running = false; netProc.running = true
        dkProc.running = false; dkProc.running = true
    }

    function setBrightness(pct) {
        const c = Math.max(5, Math.min(100, Math.round(pct)))
        brightnessRatio = c / 100.0
        pendingBright = c
        if (!brightTimer.running) brightTimer.start()
    }

    Timer {
        id: brightTimer
        interval: 90
        onTriggered: {
            if (sw.pendingBright >= 5) {
                const v = sw.pendingBright
                sw.pendingBright = -1
                NiriState.runDetached(["__HOME__/.local/bin/m3-brightness", "set", String(v)])
            }
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            refreshAll()
            openTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer { id: openTick; interval: 10; onTriggered: sw.animOpen = true }
    Timer { id: closeDelay; interval: 220 }
    Timer {
        interval: 2000
        running: sw.isOpen && sw.currentTab === 4
        repeat: true
        onTriggered: if (!statsProc.running) statsProc.running = true
    }

    Process {
        id: brightProc
        command: ["__HOME__/.local/bin/m3-brightness", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim(), 10)
                if (!isNaN(v) && v >= 5 && v <= 100) sw.brightnessRatio = v / 100.0
            }
        }
    }
    Process {
        id: nlProc
        command: ["__HOME__/.local/bin/m3-nightlight", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(":")
                sw.nightLightOn = p[0] === "on"
                if (p[1]) sw.nightTemp = p[1]
            }
        }
    }
    Process {
        id: cafProc
        command: ["__HOME__/.local/bin/m3-caffeine", "status"]
        stdout: StdioCollector { onStreamFinished: sw.caffeineOn = text.trim() === "on" }
    }
    Process {
        id: dkProc
        command: ["sh", "-c", "pgrep -f 'kitten panel.*kitty-desktop' >/dev/null && echo on || echo off"]
        stdout: StdioCollector { onStreamFinished: sw.desktopKittyOn = text.trim() === "on" }
    }
    Process {
        id: niriTuneProc
        command: ["__HOME__/.local/bin/m3-niri-tune", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim())
                    sw.niriGaps = d.gaps
                    sw.niriRing = d.ring
                    sw.niriRadius = d.radius
                } catch (e) {}
            }
        }
    }
    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f CONNECTION dev status 2>/dev/null | grep -v '^$' | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: sw.netName = text.trim() || "Отключена"
        }
    }
    Process {
        id: statsProc
        command: ["__HOME__/.local/bin/m3-sysmon-json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim())
                    sw.cpuPct = d.cpu_pct || 0
                    sw.cpuTemp = d.cpu_temp || 0
                    if (d.ram) { sw.ramUsed = d.ram.used_gb; sw.ramTotal = d.ram.total_gb; sw.ramPct = d.ram.pct }
                    if (d.gpu) { sw.gpuName = d.gpu.name; sw.gpuPct = d.gpu.pct; sw.gpuTemp = d.gpu.temp; sw.vramUsed = d.gpu.vram_used_gb; sw.vramTotal = d.gpu.vram_total_gb; sw.vramPct = d.gpu.vram_pct }
                } catch (e) {}
            }
        }
    }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "m3-settings-window"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Reusable M3 Expressive Section Card
    component SettingsCard: Rectangle {
        default property alias content: cardCol.data
        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + 28
        radius: 20
        color: Theme.surfaceContainerHigh
        Behavior on color { ColorAnimation { duration: 180 } }

        ColumnLayout {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10
        }
    }

    // Reusable M3 Expressive Toggle Switch Row
    component SwitchRow: RowLayout {
        id: sr
        property string iconName: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            width: 36; height: 36; radius: 13
            color: sr.checked ? Theme.primaryContainer : Theme.surfaceContainerHighest
            Behavior on color { ColorAnimation { duration: 160 } }
            M3Icon {
                anchors.centerIn: parent
                name: sr.iconName
                size: 19
                filled: sr.checked
                color: sr.checked ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            M3Text { role: "title"; customSize: 13; text: sr.title; color: Theme.fgSurface }
            M3Text { role: "label"; text: sr.subtitle; color: Theme.fgSurfaceVariant; elide: Text.ElideRight; Layout.fillWidth: true }
        }

        // Authentic M3 Expressive Switch (thumb grows on checked!)
        Rectangle {
            width: 52; height: 30; radius: 15
            color: sr.checked ? Theme.primary : Theme.surfaceContainerHighest
            border.width: sr.checked ? 0 : 2
            border.color: Theme.outline
            Behavior on color { ColorAnimation { duration: 180 } }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: sr.checked ? (parent.width - width - 4) : 6
                width: sr.checked ? 22 : 16
                height: width
                radius: width / 2
                color: sr.checked ? Theme.fgPrimary : Theme.fgSurfaceVariant
                Behavior on x { SpringAnimation { spring: 5.5; damping: 0.36; epsilon: 0.2 } }
                Behavior on width { SpringAnimation { spring: 5.5; damping: 0.36; epsilon: 0.2 } }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: sr.toggled()
            }
        }
    }

    // Reusable M3 Segmented Pill Choice Button
    component ChoiceChip: Rectangle {
        id: cc
        property string label: ""
        property bool selected: false
        signal triggered()

        height: 34
        implicitWidth: chipTxt.implicitWidth + 24
        radius: selected ? 12 : 17
        color: selected
            ? Theme.primaryContainer
            : (chipA.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
        border.width: selected ? 1 : 0
        border.color: Theme.alpha(Theme.primary, 0.5)

        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
        Behavior on color { ColorAnimation { duration: 150 } }

        M3Text {
            id: chipTxt
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            role: "labelEmphasized"
            customSize: 12
            emphasized: cc.selected || chipA.containsMouse
            text: cc.label
            color: cc.selected ? Theme.fgPrimaryContainer : Theme.fgSurface
        }

        MouseArea {
            id: chipA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cc.triggered()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: sw.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, sw.animOpen ? 0.36 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea { anchors.fill: parent; onClicked: sw.closeRequested() }

        // ─── Main Centered 2-Pane Material Design 3 Expressive Settings Sheet (860 x 610) ───
        Rectangle {
            id: dialog
            anchors.centerIn: parent
            anchors.verticalCenterOffset: sw.animOpen ? 0 : 20
            width: 860
            height: 610
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.99)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)
            clip: true

            opacity: sw.animOpen ? 1.0 : 0.0
            scale: sw.animOpen ? 1.0 : 0.94

            Behavior on anchors.verticalCenterOffset { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ═══════════════════════════════════════════════
                // LEFT PANE: M3 Expressive Navigation Rail
                // ═══════════════════════════════════════════════
                Rectangle {
                    Layout.preferredWidth: 224
                    Layout.fillHeight: true
                    color: Theme.surfaceContainerLow

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6

                        // App Header
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 38; height: 38; radius: 14
                                color: Theme.primaryContainer
                                M3Icon {
                                    anchors.centerIn: parent
                                    name: "settings"
                                    size: 21
                                    filled: true
                                    color: Theme.fgPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                spacing: 0
                                M3Text { role: "headline"; customSize: 16; text: "Настройки"; color: Theme.fgSurface }
                                M3Text { role: "label"; text: "Material 3 Expressive"; color: Theme.primary }
                            }
                        }

                        // Navigation Items
                        Repeater {
                            model: sw.navItems
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool sel: sw.currentTab === index

                                Layout.fillWidth: true
                                height: 50
                                radius: sel ? 18 : 25
                                color: sel
                                    ? Theme.secondaryContainer
                                    : (navA.containsMouse ? Theme.surfaceContainerHigh : "transparent")

                                Behavior on radius { SpringAnimation { spring: 5.2; damping: 0.36 } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10
                                    spacing: 11

                                    M3Icon {
                                        name: modelData.icon
                                        size: 20
                                        filled: sel || navA.containsMouse
                                        color: sel ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        M3Text {
                                            role: "labelEmphasized"
                                            customSize: 12
                                            emphasized: sel
                                            text: modelData.label
                                            color: sel ? Theme.fgSecondaryContainer : Theme.fgSurface
                                        }
                                        M3Text {
                                            role: "label"
                                            customSize: 10
                                            text: modelData.sub
                                            color: sel ? Theme.alpha(Theme.fgSecondaryContainer, 0.78) : Theme.fgSurfaceVariant
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: navA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        sw.currentTab = index
                                        if (index === 4 && !statsProc.running) statsProc.running = true
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Quick Close Pill at bottom of rail
                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            radius: 18
                            color: footClsA.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                M3Icon { anchors.verticalCenter: parent.verticalCenter; name: "close"; size: 16; color: Theme.fgSurfaceVariant }
                                M3Text { anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 12; text: "Закрыть (Esc)"; color: Theme.fgSurfaceVariant }
                            }
                            MouseArea {
                                id: footClsA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: sw.closeRequested()
                            }
                        }
                    }
                }

                // Subtle vertical divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Theme.alpha(Theme.outlineVariant, 0.35)
                }

                // ═══════════════════════════════════════════════
                // RIGHT PANE: Detailed Scrollable Content Canvas
                // ═══════════════════════════════════════════════
                Flickable {
                    id: contentFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: pageStack.implicitHeight + 44
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    StackLayout {
                        id: pageStack
                        x: 22
                        y: 20
                        width: contentFlick.width - 44
                        currentIndex: sw.currentTab

                        // ─── TAB 0: ОФОРМЛЕНИЕ И MATERIAL 3 EXPRESSIVE ───
                        ColumnLayout {
                            spacing: 12

                            M3Text { role: "headline"; customSize: 20; text: "Оформление и Material 3 Expressive"; color: Theme.fgSurface }

                            // M3 Expressive Profile Switcher
                            SettingsCard {
                                M3Text { role: "title"; text: "Профиль оформления"; color: Theme.fgSurface }
                                M3Text { role: "label"; text: "Переключает обои, палитру системы, виджеты, терминал, иконки и тему AyuGram"; color: Theme.fgSurfaceVariant }
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 8
                                    columnSpacing: 10
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Фиолетовый"
                                        selected: Theme.profileId === "violet"
                                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-profile", "violet"])
                                    }
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Синий"
                                        selected: Theme.profileId === "blue"
                                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-profile", "blue"])
                                    }
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Зеленый"
                                        selected: Theme.profileId === "forest"
                                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-profile", "forest"])
                                    }
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Оранжевый"
                                        selected: Theme.profileId === "peach"
                                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-profile", "peach"])
                                    }
                                }
                            }

                            // Dark / Light Mode
                            SettingsCard {
                                M3Text { role: "title"; text: "Режим темы"; color: Theme.fgSurface }
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Тёмная тема"
                                        selected: Theme.mode === "dark"
                                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-apply-wallpaper", "--mode", "dark", "--no-wallpaper"])
                                    }
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Светлая тема"
                                        selected: Theme.mode === "light"
                                        onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-apply-wallpaper", "--mode", "light", "--no-wallpaper"])
                                    }
                                }
                            }

                            // HCT Dynamic Color Algorithm
                            SettingsCard {
                                M3Text { role: "title"; text: "Алгоритм динамической палитры HCT"; color: Theme.fgSurface }
                                M3Text { role: "label"; text: "Генерирует все 50 цветовых ролей Material 3 из текущих обоев"; color: Theme.fgSurfaceVariant }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { id: "scheme-content",    name: "Content (Реком.)" },
                                            { id: "scheme-tonal-spot", name: "Tonal Spot" },
                                            { id: "scheme-vibrant",    name: "Vibrant" },
                                            { id: "scheme-fidelity",   name: "Fidelity" },
                                            { id: "scheme-expressive", name: "Expressive" }
                                        ]
                                        delegate: ChoiceChip {
                                            required property var modelData
                                            label: modelData.name
                                            selected: Theme.scheme === modelData.id
                                            onTriggered: NiriState.runDetached(["__HOME__/.local/bin/m3-apply-wallpaper", "--scheme", modelData.id, "--no-wallpaper"])
                                        }
                                    }
                                }

                                // Live Color Swatch Strip
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    spacing: 8
                                    Repeater {
                                        model: [
                                            { c: Theme.primary,            lbl: "Primary" },
                                            { c: Theme.primaryContainer,   lbl: "P-Cont" },
                                            { c: Theme.secondaryContainer, lbl: "Sec" },
                                            { c: Theme.tertiary,           lbl: "Tertiary" },
                                            { c: Theme.tertiaryContainer,  lbl: "T-Cont" },
                                            { c: Theme.errorContainer,     lbl: "Error" }
                                        ]
                                        delegate: ColumnLayout {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 3
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 26
                                                radius: 10
                                                color: modelData.c
                                                Behavior on color { ColorAnimation { duration: 220 } }
                                            }
                                            M3Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                role: "label"
                                                customSize: 10
                                                text: modelData.lbl
                                                color: Theme.fgSurfaceVariant
                                            }
                                        }
                                    }
                                }
                            }

                            // Wallpaper + Typography & Icons Info
                            SettingsCard {
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        M3Text { role: "title"; text: "Обои рабочего стола"; color: Theme.fgSurface }
                                        M3Text { role: "label"; text: "Текущие: " + (Theme.wallpaperName || "535592") + " · awww + matugen"; color: Theme.fgSurfaceVariant }
                                    }
                                    ChoiceChip {
                                        label: "Выбрать обои"
                                        selected: true
                                        onTriggered: {
                                            sw.closeRequested()
                                            NiriState.runDetached(["__HOME__/.local/bin/m3-wallpaper-picker"])
                                        }
                                    }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.alpha(Theme.outlineVariant, 0.35) }
                                M3Text { role: "label"; text: "Шрифты: Roboto Flex (вариативный) · Material Symbols Rounded (4 оси) · Иконки: Tela-circle-purple"; color: Theme.fgSurfaceVariant; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                        }

                        // ─── TAB 1: ЭКРАН, ЯРКОСТЬ И СВЕТ ───
                        ColumnLayout {
                            spacing: 12

                            M3Text { role: "headline"; customSize: 20; text: "Экран, яркость и защита глаз"; color: Theme.fgSurface }

                            SettingsCard {
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10
                                    M3Icon { name: "monitor"; size: 22; filled: true; color: Theme.primary }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        M3Text { role: "title"; text: "MSI G242 · HDMI-A-1"; color: Theme.fgSurface }
                                        M3Text { role: "label"; text: "1920 × 1080 @ 144 Гц · Аппаратное управление DDC/CI"; color: Theme.fgSurfaceVariant }
                                    }
                                }

                                M3ExpressiveSlider {
                                    Layout.fillWidth: true
                                    value: sw.brightnessRatio
                                    minValue: 0.05
                                    iconName: "brightness_high"
                                    activeColor: Theme.tertiary
                                    onActiveColor: Theme.fgTertiary
                                    trackHeight: 38
                                    onMoved: v => sw.brightnessRatio = v
                                    onCommitted: v => sw.setBrightness(v * 100)
                                }
                            }

                            SettingsCard {
                                SwitchRow {
                                    iconName: "bedtime"
                                    title: "Ночной свет (wlsunset)"
                                    subtitle: sw.nightLightOn ? ("Активен · " + sw.nightTemp + "K") : "Смягчает синий спектр вечером"
                                    checked: sw.nightLightOn
                                    onToggled: {
                                        sw.nightLightOn = !sw.nightLightOn
                                        NiriState.runDetached(["__HOME__/.local/bin/m3-nightlight", "toggle"])
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    M3Text { role: "label"; text: "Теплота:"; color: Theme.fgSurfaceVariant }
                                    ChoiceChip {
                                        label: "3400K Тёплый"
                                        selected: sw.nightLightOn && sw.nightTemp === "3400"
                                        onTriggered: { sw.nightLightOn = true; sw.nightTemp = "3400"; NiriState.runDetached(["__HOME__/.local/bin/m3-nightlight", "set", "3400"]) }
                                    }
                                    ChoiceChip {
                                        label: "4000K Комфорт"
                                        selected: sw.nightLightOn && sw.nightTemp === "4000"
                                        onTriggered: { sw.nightLightOn = true; sw.nightTemp = "4000"; NiriState.runDetached(["__HOME__/.local/bin/m3-nightlight", "set", "4000"]) }
                                    }
                                    ChoiceChip {
                                        label: "4800K Мягкий"
                                        selected: sw.nightLightOn && sw.nightTemp === "4800"
                                        onTriggered: { sw.nightLightOn = true; sw.nightTemp = "4800"; NiriState.runDetached(["__HOME__/.local/bin/m3-nightlight", "set", "4800"]) }
                                    }
                                }
                            }

                            SettingsCard {
                                SwitchRow {
                                    iconName: "coffee"
                                    title: "Не гасить экран (Кофеин)"
                                    subtitle: sw.caffeineOn ? "Автоблокировка и выключение монитора приостановлены" : "Автосон hypridle активен (10 мин)"
                                    checked: sw.caffeineOn
                                    onToggled: {
                                        sw.caffeineOn = !sw.caffeineOn
                                        NiriState.runDetached(["__HOME__/.local/bin/m3-caffeine", "toggle"])
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Заблокировать экран"
                                        onTriggered: { sw.closeRequested(); NiriState.runDetached(["hyprlock"]) }
                                    }
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Погасить монитор"
                                        onTriggered: { sw.closeRequested(); NiriState.runDetached(["niri", "msg", "action", "power-off-monitors"]) }
                                    }
                                }
                            }
                        }

                        // ─── TAB 2: ЗВУК И АУДИО ───
                        ColumnLayout {
                            spacing: 12

                            M3Text { role: "headline"; customSize: 20; text: "Звук, микрофон и устройства"; color: Theme.fgSurface }

                            SettingsCard {
                                M3Text { role: "title"; text: "Основной вывод · " + sw.nodeLabel(Pipewire.defaultAudioSink, "Выход"); color: Theme.fgSurface }
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

                                M3Text { role: "title"; text: "Микрофон · " + sw.nodeLabel(Pipewire.defaultAudioSource, "Ввод"); color: Theme.fgSurface; visible: Pipewire.defaultAudioSource !== null }
                                M3ExpressiveSlider {
                                    visible: Pipewire.defaultAudioSource !== null
                                    readonly property var aud: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null
                                    Layout.fillWidth: true
                                    value: aud ? Math.max(0, Math.min(1, aud.volume || 0)) : 0
                                    muted: aud ? !!aud.muted : false
                                    iconName: "mic"
                                    mutedIconName: "mic_off"
                                    iconClickable: true
                                    activeColor: Theme.secondary
                                    onActiveColor: Theme.fgSecondary
                                    trackHeight: 36
                                    onIconClicked: if (aud) aud.muted = !aud.muted
                                    onMoved: v => { if (aud) { aud.muted = false; aud.volume = v } }
                                }
                            }

                            SettingsCard {
                                RowLayout {
                                    Layout.fillWidth: true
                                    M3Text { role: "title"; text: "Устройства вывода"; color: Theme.fgSurface }
                                    Item { Layout.fillWidth: true }
                                    ChoiceChip {
                                        label: "Открыть Pavucontrol"
                                        selected: true
                                        onTriggered: { sw.closeRequested(); NiriState.runDetached(["pavucontrol"]) }
                                    }
                                }

                                Repeater {
                                    model: sw.outputSinks
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool act: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.id === modelData.id
                                        Layout.fillWidth: true
                                        height: 40
                                        radius: act ? 14 : 20
                                        color: act ? Theme.primaryContainer : Theme.surfaceContainer
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        RowLayout {
                                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                            M3Icon { name: act ? "check_circle" : "speaker"; size: 18; filled: act; color: act ? Theme.fgPrimaryContainer : Theme.fgSurfaceVariant }
                                            M3Text { role: act ? "labelEmphasized" : "label"; customSize: 12; text: sw.nodeLabel(modelData, "Аудиовыход"); color: act ? Theme.fgPrimaryContainer : Theme.fgSurface; Layout.fillWidth: true; elide: Text.ElideRight }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
                                    }
                                }
                            }
                        }

                        // ─── TAB 3: ОКНА, КОМПОЗИТОР NIRI И ПАНЕЛИ ───
                        ColumnLayout {
                            spacing: 12

                            M3Text { role: "headline"; customSize: 20; text: "Композитор Niri и геометрия окон"; color: Theme.fgSurface }

                            SettingsCard {
                                M3Text { role: "title"; text: "Скругление окон (Shape Scale M3 Expressive)"; color: Theme.fgSurface }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Repeater {
                                        model: [12, 16, 20, 24]
                                        delegate: ChoiceChip {
                                            required property int modelData
                                            Layout.fillWidth: true
                                            label: modelData + " px"
                                            selected: sw.niriRadius === modelData
                                            onTriggered: { sw.niriRadius = modelData; NiriState.runDetached(["__HOME__/.local/bin/m3-niri-tune", "set", "--radius", String(modelData)]) }
                                        }
                                    }
                                }

                                M3Text { role: "title"; text: "Отступы между окнами (Gaps)"; color: Theme.fgSurface }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Repeater {
                                        model: [6, 10, 14]
                                        delegate: ChoiceChip {
                                            required property int modelData
                                            Layout.fillWidth: true
                                            label: modelData + " px"
                                            selected: sw.niriGaps === modelData
                                            onTriggered: { sw.niriGaps = modelData; NiriState.runDetached(["__HOME__/.local/bin/m3-niri-tune", "set", "--gaps", String(modelData)]) }
                                        }
                                    }
                                }

                                M3Text { role: "title"; text: "Толщина рамки фокуса (Focus Ring)"; color: Theme.fgSurface }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    Repeater {
                                        model: [2, 3, 4]
                                        delegate: ChoiceChip {
                                            required property int modelData
                                            Layout.fillWidth: true
                                            label: modelData + " px"
                                            selected: sw.niriRing === modelData
                                            onTriggered: { sw.niriRing = modelData; NiriState.runDetached(["__HOME__/.local/bin/m3-niri-tune", "set", "--ring", String(modelData)]) }
                                        }
                                    }
                                }
                            }

                            SettingsCard {
                                SwitchRow {
                                    iconName: "dock_to_bottom"
                                    title: "Верхний навбар"
                                    subtitle: "Скрытие / показ с пружинным растяжением окон (клавиша F1)"
                                    checked: !sw.barHidden
                                    onToggled: sw.toggleBarRequested()
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.alpha(Theme.outlineVariant, 0.35) }
                                SwitchRow {
                                    iconName: "terminal"
                                    title: "Фоновый терминал Kitty на обоях"
                                    subtitle: "Закреплён на слое bottom каждого рабочего стола с портретом Котоми"
                                    checked: sw.desktopKittyOn
                                    onToggled: {
                                        if (sw.desktopKittyOn) {
                                            sw.desktopKittyOn = false
                                            NiriState.runDetached(["pkill", "-f", "kitten panel.*kitty-desktop"])
                                        } else {
                                            sw.desktopKittyOn = true
                                            NiriState.runDetached(["__HOME__/.local/bin/m3-desktop-kitty"])
                                        }
                                    }
                                }
                            }
                        }

                        // ─── TAB 4: СИСТЕМА, ПИТАНИЕ И СЕТЬ ───
                        ColumnLayout {
                            spacing: 12

                            M3Text { role: "headline"; customSize: 20; text: "Производительность, сеть и датчики"; color: Theme.fgSurface }

                            // Power Profile 3-Way Segmented Control
                            SettingsCard {
                                M3Text { role: "title"; text: "Профиль производительности CPU"; color: Theme.fgSurface }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Экономия"
                                        selected: PowerProfiles.profile === PowerProfile.PowerSaver
                                        onTriggered: PowerProfiles.profile = PowerProfile.PowerSaver
                                    }
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Баланс"
                                        selected: PowerProfiles.profile === PowerProfile.Balanced
                                        onTriggered: PowerProfiles.profile = PowerProfile.Balanced
                                    }
                                    ChoiceChip {
                                        Layout.fillWidth: true
                                        label: "Максимум"
                                        visible: PowerProfiles.hasPerformanceProfile
                                        selected: PowerProfiles.profile === PowerProfile.Performance
                                        onTriggered: PowerProfiles.profile = PowerProfile.Performance
                                    }
                                }
                            }

                            // Live Sensors Summary
                            SettingsCard {
                                RowLayout {
                                    Layout.fillWidth: true
                                    M3Text { role: "title"; text: "Живые датчики"; color: Theme.fgSurface }
                                    Item { Layout.fillWidth: true }
                                    ChoiceChip { label: "btop"; selected: true; onTriggered: { sw.closeRequested(); NiriState.runDetached(["kitty", "-e", "btop"]) } }
                                }
                                M3Text { role: "body"; customSize: 12; text: "CPU (Core i3-10100F):  " + sw.cpuPct + "%  ·  " + sw.cpuTemp + "°C"; color: Theme.fgSurface }
                                M3Text { role: "body"; customSize: 12; text: "ОЗУ:  " + sw.ramUsed.toFixed(1) + " / " + sw.ramTotal.toFixed(1) + " ГБ (" + sw.ramPct + "%)"; color: Theme.fgSurface }
                                M3Text { role: "body"; customSize: 12; text: "GPU (" + sw.gpuName + "):  " + sw.gpuPct + "%  ·  " + sw.gpuTemp + "°C  ·  VRAM " + sw.vramUsed.toFixed(1) + " / " + sw.vramTotal.toFixed(1) + " ГБ"; color: Theme.fgSurface }
                            }

                            // Network & External Tools
                            SettingsCard {
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        M3Text { role: "title"; text: "Сеть"; color: Theme.fgSurface }
                                        M3Text { role: "label"; text: sw.netName; color: Theme.fgSurfaceVariant }
                                    }
                                    ChoiceChip { label: "Управление сетью"; selected: true; onTriggered: { sw.closeRequested(); NiriState.runDetached(["qs", "ipc", "call", "shell", "toggleNetwork"]) } }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.alpha(Theme.outlineVariant, 0.35) }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    ChoiceChip { Layout.fillWidth: true; label: "Настройки Qt6 (qt6ct)"; onTriggered: { sw.closeRequested(); NiriState.runDetached(["qt6ct"]) } }
                                    ChoiceChip { Layout.fillWidth: true; label: "Ядро CachyOS"; onTriggered: { sw.closeRequested(); NiriState.runDetached(["cachyos-kernel-manager"]) } }
                                }
                            }
                        }

                        // ─── TAB 5: ГОРЯЧИЕ КЛАВИШИ И О СИСТЕМЕ ───
                        ColumnLayout {
                            spacing: 12

                            M3Text { role: "headline"; customSize: 20; text: "Горячие клавиши и система"; color: Theme.fgSurface }

                            SettingsCard {
                                M3Text { role: "title"; text: "Управление оболочкой Material 3 Expressive"; color: Theme.fgSurface }
                                Repeater {
                                    model: [
                                        { k: "Alt + Tab  /  Win + S", d: "Центр управления" },
                                        { k: "Alt + A / D (при меню)", d: "Переключение меню навбара влево / вправо" },
                                        { k: "Win + Space (или Win)",  d: "Лаунчер приложений Rofi" },
                                        { k: "Win + V",                d: "Буфер обмена с превью изображений" },
                                        { k: "Shift + Win + S",        d: "Меню скриншота (не закрывает меню)" },
                                        { k: "F1",                     d: "Скрыть / показать навбар с анимацией" },
                                        { k: "F10",                    d: "Запись экрана 1080p 60fps + звук (старт/стоп)" },
                                        { k: "Win + Shift + T",        d: "Переключить Тёмная / Светлая тема M3" },
                                        { k: "Win + Shift + Enter",    d: "Выбрать обои и обновить палитру M3" },
                                        { k: "Win + Alt + L",          d: "Заблокировать экран (Hyprlock)" },
                                        { k: "Win + O / Win + Enter",  d: "Обзор Niri / Новый терминал Kitty" }
                                    ]
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Rectangle {
                                            height: 24
                                            implicitWidth: kTxt.implicitWidth + 16
                                            radius: 8
                                            color: Theme.surfaceContainerHighest
                                            M3Text { id: kTxt; anchors.centerIn: parent; anchors.verticalCenterOffset: 1; role: "labelEmphasized"; customSize: 11; text: modelData.k; color: Theme.primary }
                                        }
                                        M3Text { role: "label"; customSize: 12; text: modelData.d; color: Theme.fgSurface; Layout.fillWidth: true; elide: Text.ElideRight }
                                    }
                                }
                            }

                            SettingsCard {
                                M3Text { role: "title"; text: "О системе"; color: Theme.fgSurface }
                                M3Text { role: "label"; customSize: 12; text: "ОС: CachyOS Linux · Композитор: Niri 26.04 (Wayland) · Оболочка: Quickshell 0.3.2 (Qt 6.12)
Дизайн-система: Material Design 3 Expressive v34.0.0 · Палитра: matugen (" + Theme.scheme + ", " + Theme.mode + ")"; color: Theme.fgSurfaceVariant; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
