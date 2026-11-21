import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
    id: mpWindow
    required property bool isOpen
    signal closeRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            for (let i = 0; i < playersList.length; i++) {
                if (playersList[i] && playersList[i].isPlaying) {
                    selectedPlayerIdx = i
                    break
                }
            }
            openNextTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer {
        id: openNextTick
        interval: 10
        onTriggered: mpWindow.animOpen = true
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
    WlrLayershell.namespace: "m3-media-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property int selectedPlayerIdx: 0

    function cleanPlayerName(p) {
        if (!p) return "Плеер"
        const id = (p.identity || p.desktopEntry || "Плеер")
        const low = id.toLowerCase()
        if (low.indexOf("youtube-music") !== -1 || low.indexOf("pear") !== -1) return "Pear Desktop"
        if (low.indexOf("ayugram") !== -1) return "AyuGram"
        if (low.indexOf("telegram") !== -1) return "Telegram"
        if (low.indexOf("zen") !== -1) return "Zen Browser"
        if (low.indexOf("firefox") !== -1) return "Firefox"
        if (low.indexOf("chromium") !== -1 || low.indexOf("chrome") !== -1) return "Browser"
        if (low.indexOf("spotify") !== -1) return "Spotify"
        if (low.indexOf("vlc") !== -1) return "VLC"
        return id
    }

    function playerSourceIcon(p) {
        if (!p) return "music_note"
        const low = ((p.identity || "") + " " + (p.desktopEntry || "")).toLowerCase()
        if (low.indexOf("youtube-music") !== -1 || low.indexOf("pear") !== -1 || low.indexOf("spotify") !== -1) return "music_note"
        if (low.indexOf("telegram") !== -1 || low.indexOf("ayugram") !== -1) return "send"
        if (low.indexOf("zen") !== -1 || low.indexOf("firefox") !== -1 || low.indexOf("chrome") !== -1 || low.indexOf("chromium") !== -1) return "public"
        if (low.indexOf("vlc") !== -1 || low.indexOf("mpv") !== -1 || low.indexOf("nuvio") !== -1) return "movie"
        return "play_circle"
    }
    readonly property var playersList: Mpris.players.values || []
    readonly property var activePlayer: {
        if (playersList.length === 0) return null
        if (selectedPlayerIdx >= 0 && selectedPlayerIdx < playersList.length) {
            return playersList[selectedPlayerIdx]
        }
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i].isPlaying) return playersList[i]
        }
        return playersList[0]
    }

    // Reusable tactile transport button
    component MediaIconBtn: Rectangle {
        id: mbtn
        property string iconName: ""
        property int iconSize: 20
        property int btnSize: 38
        signal triggered()

        width: btnSize
        height: btnSize
        radius: mArea.pressed ? 10 : (mArea.containsMouse ? 13 : btnSize / 2)
        color: mArea.containsMouse ? Theme.alpha(Theme.fgTertiaryContainer, 0.22) : Theme.alpha(Theme.fgTertiaryContainer, 0.10)
        scale: mArea.pressed ? 0.90 : (mArea.containsMouse ? 1.06 : 1.0)

        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.40 } }

        Text {
            anchors.centerIn: parent
            text: mbtn.iconName
            font.family: Theme.fontIcons
            font.pixelSize: mbtn.iconSize
            color: Theme.fgTertiaryContainer
            verticalAlignment: Text.AlignVCenter
        }

        MouseArea {
            id: mArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mbtn.triggered()
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: mpWindow.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, mpWindow.animOpen ? 0.14 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mpWindow.closeRequested()
        }

        // ─── Floating M3 Expressive Media Sheet (anchored top-center right under the music pill!) ───
        Rectangle {
            id: card
            anchors.horizontalCenter: parent.horizontalCenter
            y: mpWindow.animOpen ? 40 : 24
            width: 388
            implicitHeight: col.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.tertiaryContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.tertiary, 0.28)

            opacity: mpWindow.animOpen ? 1.0 : 0.0
            scale: mpWindow.animOpen ? 1.0 : 0.93
            transformOrigin: Item.Top

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 14

                // ─── Top Row: Expandable Active Source Pill + Compact Circular Icons for Inactive Sources ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Row {
                        spacing: 6
                        Layout.fillWidth: true
                        clip: true

                        Repeater {
                            model: mpWindow.playersList
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool selected: mpWindow.activePlayer === modelData
                                height: 28
                                implicitWidth: selected ? Math.min(200, pChipRow.implicitWidth + 20) : 28
                                radius: 14
                                clip: true
                                color: selected
                                    ? Theme.tertiary
                                    : (pChipA.containsMouse ? Theme.alpha(Theme.fgTertiaryContainer, 0.24) : Theme.alpha(Theme.fgTertiaryContainer, 0.12))

                                Behavior on implicitWidth { SpringAnimation { spring: 5.2; damping: 0.38; epsilon: 0.2 } }
                                Behavior on color { ColorAnimation { duration: 160 } }

                                Row {
                                    id: pChipRow
                                    anchors.centerIn: parent
                                    spacing: selected ? 6 : 0

                                    M3Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: modelData.isPlaying && selected ? "graphic_eq" : mpWindow.playerSourceIcon(modelData)
                                        size: 15
                                        filled: selected || pChipA.containsMouse
                                        color: selected ? Theme.fgTertiary : Theme.fgTertiaryContainer
                                    }

                                    M3Text {
                                        id: pChipLbl
                                        visible: selected
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: 1
                                        role: "labelEmphasized"
                                        customSize: 11
                                        text: mpWindow.cleanPlayerName(modelData)
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        color: Theme.fgTertiary
                                    }
                                }

                                MouseArea {
                                    id: pChipA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mpWindow.selectedPlayerIdx = index
                                }
                            }
                        }
                    }

                    // Close Pill Button (always safely anchored right, never pushed out!)
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: clsA.containsMouse ? Theme.alpha(Theme.fgTertiaryContainer, 0.22) : Theme.alpha(Theme.fgTertiaryContainer, 0.10)
                        Behavior on color { ColorAnimation { duration: 140 } }

                        M3Icon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 16
                            color: Theme.fgTertiaryContainer
                        }

                        MouseArea {
                            id: clsA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mpWindow.closeRequested()
                        }
                    }
                }

                // ─── Album Art + Title + Artist ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        width: 68
                        height: 68
                        radius: 18
                        color: Theme.alpha(Theme.fgTertiaryContainer, 0.14)
                        clip: true
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            id: popArt
                            anchors.fill: parent
                            source: mpWindow.activePlayer ? (mpWindow.activePlayer.trackArtUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !popArt.visible
                            text: "music_note"
                            font.family: Theme.fontIcons
                            font.pixelSize: 30
                            color: Theme.fgTertiaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        M3Text {
                            role: "headline"
                            customSize: 16
                            text: mpWindow.activePlayer ? (mpWindow.activePlayer.trackTitle || "Нет воспроизведения") : "Нет активного плеера"
                            color: Theme.fgTertiaryContainer
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: mpWindow.activePlayer ? (mpWindow.activePlayer.trackArtist || mpWindow.activePlayer.trackAlbum || mpWindow.activePlayer.identity || "") : ""
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.alpha(Theme.fgTertiaryContainer, 0.82)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                // ─── Material Design 3 Expressive Wavy Audio Scrubber ───
                M3WavyScrubber {
                    Layout.fillWidth: true
                    player: mpWindow.activePlayer
                    activeColor: Theme.tertiary
                    inactiveColor: Theme.alpha(Theme.fgTertiaryContainer, 0.28)
                    textColor: Theme.alpha(Theme.fgTertiaryContainer, 0.85)
                    activeAnimation: mpWindow.animOpen
                    showTimestamps: true
                }

                // ─── Transport Controls (-10s · Prev · Play/Pause Morph · Next · +10s) ───
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    MediaIconBtn {
                        iconName: "replay_10"
                        iconSize: 19
                        btnSize: 38
                        onTriggered: if (mpWindow.activePlayer) mpWindow.activePlayer.seek(-10)
                    }

                    MediaIconBtn {
                        iconName: "skip_previous"
                        iconSize: 22
                        btnSize: 42
                        onTriggered: if (mpWindow.activePlayer) mpWindow.activePlayer.previous()
                    }

                    // Hero M3 Expressive Play/Pause Button (64x48 Squircle Playing <-> 48x48 Perfect Circle Paused, zero RowLayout drift!)
                    Rectangle {
                        id: mpHeroBtn
                        readonly property bool playing: mpWindow.activePlayer ? !!mpWindow.activePlayer.isPlaying : false
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: playing ? 64 : 48
                        Layout.preferredHeight: 48
                        radius: heroPlayA.pressed ? 12 : (playing ? 15 : 24)
                        color: Theme.tertiary
                        scale: heroPlayA.pressed ? 0.92 : (heroPlayA.containsMouse ? 1.05 : 1.0)

                        Behavior on Layout.preferredWidth { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5.5
                            opacity: mpHeroBtn.playing ? 1.0 : 0.0
                            scale: mpHeroBtn.playing ? 1.0 : 0.55
                            rotation: mpHeroBtn.playing ? 0 : -28
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                            Rectangle { width: 5.5; height: 18; radius: 2.75; color: Theme.fgTertiary }
                            Rectangle { width: 5.5; height: 18; radius: 2.75; color: Theme.fgTertiary }
                        }

                        M3Icon {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1.0
                            name: "play_arrow"
                            size: 26
                            filled: true
                            color: Theme.fgTertiary
                            opacity: mpHeroBtn.playing ? 0.0 : 1.0
                            scale: mpHeroBtn.playing ? 0.55 : 1.0
                            rotation: mpHeroBtn.playing ? 28 : 0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                        }

                        MouseArea {
                            id: heroPlayA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mpWindow.activePlayer) mpWindow.activePlayer.togglePlaying()
                        }
                    }

                    MediaIconBtn {
                        iconName: "skip_next"
                        iconSize: 22
                        btnSize: 42
                        onTriggered: if (mpWindow.activePlayer) mpWindow.activePlayer.next()
                    }

                    MediaIconBtn {
                        iconName: "forward_10"
                        iconSize: 19
                        btnSize: 38
                        onTriggered: if (mpWindow.activePlayer) mpWindow.activePlayer.seek(10)
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
