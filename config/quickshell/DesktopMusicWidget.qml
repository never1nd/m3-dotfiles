import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

/* Material Design 3 Expressive Desktop Music Player Widget
 * - Pinned to EVERY workspace on WlrLayer.Bottom (strictly behind Niri's carousel!)
 * - Top-right quarter (x=1000..1880, y=52..540), symmetrically paired above DesktopTerminalCard + kitty-desktop
 * - Auto-hides cleanly whenever no music is playing!
 * - Pulls album cover art, metadata, source identity (Pear Desktop / Telegram / etc.),
 *   M3 Expressive Wavy Scrubber, and live synced karaoke lyrics via LRCLIB!
 */
PanelWindow {
    id: musicWin

    readonly property var playersList: {
        const raw = Mpris.players.values || []
        const filtered = []
        for (let i = 0; i < raw.length; i++) {
            const p = raw[i]
            if (!p) continue
            const bn = String(p.dbusName || "")
            if (bn.indexOf("playerctld") !== -1) continue
            filtered.push(p)
        }
        return filtered.length > 0 ? filtered : raw
    }
    readonly property var activePlayer: {
        if (!playersList || playersList.length === 0) return null
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i] && playersList[i].isPlaying) return playersList[i]
        }
        for (let i = 0; i < playersList.length; i++) {
            if (playersList[i] && (playersList[i].trackTitle || "") !== "") return playersList[i]
        }
        return playersList[0] || null
    }

    onActivePlayerChanged: syncTrackCache()

    // Keep Play/Pause button & wavy scrubber rock-steady while YouTube buffers a skipped track!
    property bool skipBuffering: false
    readonly property bool rawPlaying: activePlayer !== null && !!activePlayer.isPlaying
    property bool isActuallyPlaying: rawPlaying
    onRawPlayingChanged: {
        if (rawPlaying) {
            pauseDebounceTimer.stop()
            isActuallyPlaying = true
        } else if (!skipBuffering) {
            pauseDebounceTimer.restart()
        }
    }
    Timer {
        id: pauseDebounceTimer
        interval: 700
        repeat: false
        onTriggered: if (!musicWin.skipBuffering) musicWin.isActuallyPlaying = musicWin.rawPlaying
    }
    Timer {
        id: skipBufferShield
        interval: 1600
        repeat: false
        onTriggered: {
            musicWin.skipBuffering = false
            musicWin.isActuallyPlaying = musicWin.rawPlaying
        }
    }

    // Stay visible while paused or switching tracks; hide ONLY when all music services are closed!
    readonly property bool hasMusicService: activePlayer !== null

    // ─── Rock-Solid 2-Slot Simultaneous M3E Carousel (IMPOSSIBLE to slide to itself, 144Hz GPU-composited!) ───
    property string activeTitle: ""
    property string slot0Title: ""
    property string slot0Artist: ""
    property string slot0Art: ""
    property string slot1Title: ""
    property string slot1Artist: ""
    property string slot1Art: ""

    property int activeSlot: 0
    property int skipDir: 1
    property bool carouselAnimating: false

    // Pending metadata collector (coalesces Chromium's split title -> artist -> artUrl burst cleanly!)
    property string stagedTitle: ""
    property string stagedArtist: ""
    property string stagedArt: ""
    property string lastCommittedArt: ""

    property real lyricsOpacity: 1.0
    property real lyricsLiftY: 0
    property bool lyricsFetchedOnce: false

    function triggerLyricsReveal() {
        lyricsExitAnim.stop()
        lyricsRevealAnim.restart()
    }

    function commitStagedTrack() {
        commitTrackTimer.stop()
        if (stagedTitle === "" || stagedTitle === activeTitle) return

        const nextSlot = activeSlot === 0 ? 1 : 0
        const useArt = stagedArt !== "" ? stagedArt : ""
        if (nextSlot === 0) {
            slot0Title = stagedTitle
            slot0Artist = stagedArtist
            slot0Art = useArt
        } else {
            slot1Title = stagedTitle
            slot1Artist = stagedArtist
            slot1Art = useArt
        }

        const dir = skipDir || 1
        activeTitle = stagedTitle
        lastCommittedArt = useArt
        skipBufferShield.stop()
        skipBuffering = false

        // Reset scrubber cleanly to 0:00 at exact track transition
        livePos = 0
        if (typeof deskScrubber !== "undefined" && deskScrubber) deskScrubber.resetToStart()

        // Smooth simultaneous 2-card carousel transition (old glides out while new glides in!)
        carouselAnim.stop()
        const outItem = activeSlot === 0 ? cardSlot0 : cardSlot1
        const inItem  = nextSlot === 0 ? cardSlot0 : cardSlot1
        activeSlot = nextSlot
        carouselAnimating = true

        outItem.z = 1
        inItem.z = 2
        inItem.slideX = dir * 110
        inItem.opacity = 0.0
        inItem.scale = 0.92

        outXAnim.target = outItem; outXAnim.from = outItem.slideX; outXAnim.to = -dir * 110
        outOpAnim.target = outItem; outOpAnim.from = outItem.opacity; outOpAnim.to = 0.0
        outScAnim.target = outItem; outScAnim.from = outItem.scale; outScAnim.to = 0.92

        inXAnim.target = inItem; inXAnim.from = dir * 110; inXAnim.to = 0
        inOpAnim.target = inItem; inOpAnim.from = 0.0; inOpAnim.to = 1.0
        inScAnim.target = inItem; inScAnim.from = 0.92; inScAnim.to = 1.0

        carouselAnim.restart()
        skipDir = 1
    }

    readonly property string liveTrackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string liveArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    onLiveTrackTitleChanged: if (liveTrackTitle !== "") syncTrackCache()
    onLiveArtUrlChanged: if (liveArtUrl !== "") syncTrackCache()

    function syncTrackCache() {
        if (!activePlayer) return
        const t = activePlayer.trackTitle || ""
        const a = activePlayer.trackArtist || ""
        const art = activePlayer.trackArtUrl || ""
        if (t === "") return

        // First track on startup: populate active slot immediately without transition
        if (activeTitle === "") {
            activeTitle = t
            slot0Title = t
            slot0Artist = a
            slot0Art = art
            stagedTitle = t
            stagedArtist = a
            stagedArt = art
            lastCommittedArt = art
            activeSlot = 0
            cardSlot0.slideX = 0; cardSlot0.opacity = 1.0; cardSlot0.scale = 1.0; cardSlot0.z = 2
            cardSlot1.slideX = 110; cardSlot1.opacity = 0.0; cardSlot1.scale = 0.92; cardSlot1.z = 1
            fetchLyricsForCurrent()
            return
        }

        // Same currently displayed track: silently update late-arriving artist or cover art!
        if (t === activeTitle) {
            if (activeSlot === 0) {
                if (a !== "") slot0Artist = a
                if (art !== "" && art !== slot0Art) { slot0Art = art; lastCommittedArt = art }
            } else {
                if (a !== "") slot1Artist = a
                if (art !== "" && art !== slot1Art) { slot1Art = art; lastCommittedArt = art }
            }
            fetchLyricsForCurrent()
            return
        }

        // Brand-new track! Stage metadata and wait briefly (~260ms max) for Chromium's fresh artUrl to arrive together
        const isFirstSight = (t !== stagedTitle)
        stagedTitle = t
        if (a !== "") stagedArtist = a
        if (art !== "" && art !== lastCommittedArt) stagedArt = art
        else if (isFirstSight) stagedArt = ""

        if (isFirstSight) {
            // Immediately begin fetching lyrics & gently fade old lyrics out
            fetchLyricsForCurrent()
            if (lyricsLines.length > 0) {
                lyricsRevealAnim.stop()
                lyricsExitAnim.restart()
            }
            livePos = 0
            if (typeof deskScrubber !== "undefined" && deskScrubber) deskScrubber.resetToStart()
        }

        // If fresh cover art AND artist have already arrived, animate immediately; otherwise wait up to 280ms!
        if (stagedArt !== "" && stagedArtist !== "") {
            commitStagedTrack()
        } else {
            commitTrackTimer.restart()
        }
    }

    Timer {
        id: commitTrackTimer
        interval: 280
        repeat: false
        onTriggered: musicWin.commitStagedTrack()
    }

    ParallelAnimation {
        id: carouselAnim
        NumberAnimation { id: outXAnim; property: "slideX"; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { id: outOpAnim; property: "opacity"; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { id: outScAnim; property: "scale"; duration: 280; easing.type: Easing.OutCubic }
        NumberAnimation { id: inXAnim; property: "slideX"; duration: 400; easing.type: Easing.OutQuint }
        NumberAnimation { id: inOpAnim; property: "opacity"; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { id: inScAnim; property: "scale"; duration: 400; easing.type: Easing.OutQuint }
        onFinished: musicWin.carouselAnimating = false
    }

    ParallelAnimation {
        id: lyricsExitAnim
        NumberAnimation { target: musicWin; property: "lyricsLiftY"; from: 0; to: -12; duration: 165; easing.type: Easing.InCubic }
        NumberAnimation { target: musicWin; property: "lyricsOpacity"; from: 1.0; to: 0.0; duration: 150; easing.type: Easing.InCubic }
    }

    ParallelAnimation {
        id: lyricsRevealAnim
        NumberAnimation { target: musicWin; property: "lyricsLiftY"; from: 14; to: 0; duration: 380; easing.type: Easing.OutQuint }
        NumberAnimation { target: musicWin; property: "lyricsOpacity"; from: 0.0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
    }

    property bool animShown: false
    visible: hasMusicService || closeGraceTimer.running || hideTimer.running

    onHasMusicServiceChanged: {
        if (hasMusicService) {
            closeGraceTimer.stop()
            hideTimer.stop()
            showTick.restart()
            syncTrackCache()
        } else {
            // Brief grace period so restarting/re-registering a player never causes flicker
            closeGraceTimer.restart()
        }
    }

    Component.onCompleted: {
        if (hasMusicService) {
            showTick.restart()
            syncTrackCache()
        }
    }

    Timer {
        id: closeGraceTimer
        interval: 650
        onTriggered: {
            if (!musicWin.hasMusicService) {
                musicWin.animShown = false
                hideTimer.restart()
            }
        }
    }
    Timer { id: showTick; interval: 10; onTriggered: musicWin.animShown = true }
    Timer { id: hideTimer; interval: 260 }

    anchors {
        top: true
        right: true
    }
    margins {
        top: 52
        right: 40
    }
    implicitWidth: 880
    implicitHeight: 488
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "m3-desktop-music"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ─── Live Synced Lyrics State ───
    property string lastTrackKey: ""
    property bool lyricsLoading: false
    property bool lyricsSynced: false
    property bool lyricsInstrumental: false
    property var lyricsLines: []
    property double livePos: 0
    property int activeLyricIndex: -1

    function fetchLyricsForCurrent() {
        if (!activePlayer) return
        const t = activePlayer.trackTitle || ""
        const a = activePlayer.trackArtist || ""
        const key = a + "||" + t
        if (t === "" || key === lastTrackKey) return
        lastTrackKey = key
        lyricsLoading = true
        lyricsFetchedOnce = false
        lyricsSynced = false
        lyricsInstrumental = false
        lyricsLines = []
        activeLyricIndex = -1
        lyricsProc.running = false
        lyricsProc.command = ["__HOME__/.local/bin/m3-lyrics-fetch", a, t, key]
        lyricsProc.running = true
    }

    function updateActiveLyric() {
        if (!lyricsSynced || !lyricsLines || lyricsLines.length === 0) {
            activeLyricIndex = -1
            return
        }
        const pos = livePos + 0.25 // slight lookahead for natural sing-along feel
        let idx = -1
        for (let i = 0; i < lyricsLines.length; i++) {
            if (lyricsLines[i].time <= pos) idx = i
            else break
        }
        if (idx !== activeLyricIndex) {
            activeLyricIndex = idx
            if (idx >= 0) scrollLyricsTo(idx)
        }
    }

    function scrollLyricsTo(idx) {
        if (!lyricsList || lyricsList.count === 0) return
        const item = lyricsList.itemAtIndex(idx)
        if (!item) {
            lyricsList.positionViewAtIndex(idx, ListView.Center)
            return
        }
        const maxY = Math.max(0, lyricsList.contentHeight - lyricsList.height)
        const targetY = Math.max(0, Math.min(maxY, item.y + item.height / 2 - lyricsList.height / 2))
        lyricsScrollAnim.stop()
        lyricsScrollAnim.to = targetY
        lyricsScrollAnim.start()
    }

    Connections {
        target: musicWin.activePlayer
        function onTrackTitleChanged() {
            musicWin.livePos = 0
            musicWin.syncTrackCache()
        }
        function onPostTrackChanged() {
            musicWin.livePos = 0
            musicWin.syncTrackCache()
        }
        function onMetadataChanged() {
            musicWin.syncTrackCache()
        }
        function onTrackArtistChanged() {
            musicWin.syncTrackCache()
        }
        function onTrackArtUrlChanged() {
            musicWin.syncTrackCache()
        }
        function onPositionChanged() {
            if (musicWin.activePlayer) {
                const p = musicWin.activePlayer.position
                if (typeof p === "number" && !isNaN(p) && p >= 0) {
                    musicWin.livePos = p
                    musicWin.updateActiveLyric()
                }
            }
        }
    }

    Timer {
        interval: 250
        running: musicWin.visible && musicWin.isActuallyPlaying
        repeat: true
        onTriggered: {
            if (!musicWin.activePlayer) return
            musicWin.livePos += 0.25
            musicWin.updateActiveLyric()
        }
    }

    Process {
        id: lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim()
                if (raw === "") return // Ignore empty stream from cancelled previous fetch!
                try {
                    const d = JSON.parse(raw)
                    // Ignore stale response from an earlier skipped track!
                    if (d.key && d.key !== musicWin.lastTrackKey) return
                    musicWin.lyricsLoading = false
                    musicWin.lyricsFetchedOnce = true
                    musicWin.lyricsSynced = !!d.synced
                    musicWin.lyricsInstrumental = !!d.instrumental
                    musicWin.lyricsLines = d.lines || []
                    if (musicWin.lyricsLines.length > 0) {
                        musicWin.triggerLyricsReveal()
                        musicWin.updateActiveLyric()
                    }
                } catch (e) {
                    // Ignore partial output on process restart
                }
            }
        }
    }

    // Reusable Expressive Transport Button
    component DeskMediaBtn: Rectangle {
        id: dmb
        property string iconName: ""
        property int btnSize: 40
        property int iconSize: 20
        signal triggered()

        Layout.preferredWidth: btnSize
        Layout.preferredHeight: btnSize
        Layout.alignment: Qt.AlignVCenter
        width: btnSize
        height: btnSize
        radius: dmbA.pressed ? 10 : (dmbA.containsMouse ? 13 : btnSize / 2)
        color: Theme.mode === "light"
            ? (dmbA.containsMouse ? Theme.primaryContainer : Theme.secondaryContainer)
            : (dmbA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh)
        border.width: 1
        border.color: Theme.mode === "light"
            ? Theme.alpha(Theme.outline, 0.28)
            : Theme.alpha(Theme.outlineVariant, 0.22)
        scale: dmbA.pressed ? 0.90 : (dmbA.containsMouse ? 1.06 : 1.0)

        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.40 } }

        M3Icon {
            anchors.centerIn: parent
            name: dmb.iconName
            size: dmb.iconSize
            filled: true
            color: Theme.mode === "light"
                ? (dmbA.containsMouse ? Theme.fgPrimaryContainer : Theme.fgSecondaryContainer)
                : (dmbA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface)
        }

        MouseArea {
            id: dmbA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dmb.triggered()
        }
    }

    // ─── Main Material Design 3 Expressive Card (28px ExtraLarge, 2-Column Layout!) ───
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 28
        color: Theme.alpha(Theme.surfaceContainer, 0.90)
        border.width: 1
        border.color: Theme.alpha(Theme.outlineVariant, 0.44)
        clip: true

        opacity: musicWin.animShown ? 1.0 : 0.0
        scale: musicWin.animShown ? 1.0 : 0.95
        transformOrigin: Item.TopRight

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutQuint } }
        Behavior on color { ColorAnimation { duration: 220 } }

        // Subtle ambient tonal wash from tertiary_container (M3 Expressive editorial depth!)
        Rectangle {
            anchors.fill: parent
            radius: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.alpha(Theme.tertiaryContainer, 0.30) }
                GradientStop { position: 0.48; color: Theme.alpha(Theme.primaryContainer, 0.16) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 24

            // ═══════════════════════════════════════════════════
            // LEFT COLUMN: Source Pill + Cover Art + Title + Wavy Scrubber + Controls
            // ═══════════════════════════════════════════════════
            ColumnLayout {
                Layout.preferredWidth: 360
                Layout.fillHeight: true
                spacing: 0

                // Source App Badge + Live Mini Wave
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        height: 28
                        implicitWidth: srcRow.implicitWidth + 20
                        radius: 14
                        color: Theme.tertiaryContainer

                        Row {
                            id: srcRow
                            anchors.centerIn: parent
                            spacing: 7

                            // 3-bar mini wave
                            Row {
                                id: deskWave
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                height: 12
                                property real ph: 0.0
                                Timer {
                                    interval: 50
                                    running: musicWin.visible && musicWin.isActuallyPlaying
                                    repeat: true
                                    onTriggered: deskWave.ph = (deskWave.ph + 0.35) % (Math.PI * 2)
                                }
                                Repeater {
                                    model: [0.0, 2.0, 4.0]
                                    delegate: Rectangle {
                                        required property real modelData
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 2.5; radius: 1.5
                                        height: musicWin.isActuallyPlaying
                                            ? (4 + 7 * (0.5 + 0.5 * Math.sin(deskWave.ph + modelData)))
                                            : 4
                                        color: Theme.fgTertiaryContainer
                                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }

                            M3Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 1
                                role: "labelEmphasized"
                                customSize: 11
                                text: { const id = musicWin.activePlayer ? (musicWin.activePlayer.identity || "Музыка") : "Музыка"; return id.indexOf("youtube-music") !== -1 ? "Pear Desktop" : id }
                                color: Theme.fgTertiaryContainer
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Album chip if available
                    M3Text {
                        visible: musicWin.activePlayer && (musicWin.activePlayer.trackAlbum || "") !== ""
                        role: "label"
                        customSize: 11
                        text: musicWin.activePlayer ? (musicWin.activePlayer.trackAlbum || "") : ""
                        color: Theme.fgSurfaceVariant
                        elide: Text.ElideRight
                        Layout.maximumWidth: 165
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 8; Layout.maximumHeight: 16 }

                // 2-Slot Simultaneous GPU-Layered M3E Track Carousel (old glides out while new glides in at 144Hz!)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 244
                    clip: true

                    component TrackCardSlot: Item {
                        id: slotItem
                        property string trackTitle: ""
                        property string trackArtist: ""
                        property string artUrl: ""
                        property real slideX: 0

                        anchors.fill: parent
                        transform: Translate { x: slotItem.slideX }
                        // GPU texture cache during slide = locked 144 FPS with zero layout churn!
                        layer.enabled: musicWin.carouselAnimating
                        layer.smooth: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 192
                                Layout.preferredHeight: 192
                                width: 192
                                height: 192
                                radius: 24
                                color: Theme.alpha(Theme.primaryContainer, 0.55)
                                border.width: 1
                                border.color: Theme.alpha(Theme.primary, 0.28)
                                clip: true

                                Image {
                                    id: slotArtImg
                                    anchors.fill: parent
                                    source: slotItem.artUrl
                                    asynchronous: true
                                    sourceSize.width: 256
                                    sourceSize.height: 256
                                    cache: true
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }

                                M3Icon {
                                    anchors.centerIn: parent
                                    visible: !slotArtImg.visible
                                    name: "album"
                                    size: 72
                                    filled: true
                                    color: Theme.fgPrimaryContainer
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                M3Text {
                                    role: "headline"
                                    customSize: 17
                                    text: slotItem.trackTitle !== "" ? slotItem.trackTitle : "Ожидание трека"
                                    color: Theme.fgSurface
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                M3Text {
                                    role: "label"
                                    customSize: 12
                                    text: slotItem.trackArtist
                                    color: Theme.primary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    TrackCardSlot {
                        id: cardSlot0
                        trackTitle: musicWin.slot0Title
                        trackArtist: musicWin.slot0Artist
                        artUrl: musicWin.slot0Art
                    }

                    TrackCardSlot {
                        id: cardSlot1
                        trackTitle: musicWin.slot1Title
                        trackArtist: musicWin.slot1Artist
                        artUrl: musicWin.slot1Art
                        opacity: 0.0
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 8; Layout.maximumHeight: 14 }

                // Large Material Design 3 Expressive Wavy Audio Scrubber
                M3WavyScrubber {
                    id: deskScrubber
                    Layout.fillWidth: true
                    player: musicWin.activePlayer
                    playingOverride: musicWin.isActuallyPlaying
                    holdAtZero: commitTrackTimer.running
                    activeColor: Theme.primary
                    inactiveColor: Theme.alpha(Theme.fgSurfaceVariant, 0.28)
                    textColor: Theme.fgSurfaceVariant
                    activeAnimation: musicWin.animShown
                    showTimestamps: true
                    trackBoxHeight: 28
                    strokeW: 4.5
                    maxWaveAmp: 3.6
                    wavelength: 38.0
                    thumbBaseW: 5.0
                    thumbBaseH: 22.0
                    timeFontSize: 12
                }

                Item { Layout.preferredHeight: 12 }

                // Expressive M3 Large Transport Row (-10s · Prev · 76x76 Hero Play/Pause · Next · +10s)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    spacing: 12

                    Item { Layout.fillWidth: true }

                    DeskMediaBtn {
                        iconName: "replay_10"
                        btnSize: 46
                        iconSize: 23
                        onTriggered: if (musicWin.activePlayer) { musicWin.activePlayer.seek(-10); deskScrubber.setAnchor(Math.max(0, deskScrubber.currentPos - 10)) }
                    }

                    DeskMediaBtn {
                        iconName: "skip_previous"
                        btnSize: 52
                        iconSize: 27
                        onTriggered: {
                            if (musicWin.activePlayer) {
                                musicWin.skipDir = -1
                                musicWin.skipBuffering = true
                                skipBufferShield.restart()
                                musicWin.activePlayer.previous()
                            }
                        }
                    }

                    // Hero M3 Expressive Morphing Play/Pause Button (Equal 76x76: Squircle Playing <-> Perfect Circle Paused!)
                    Rectangle {
                        id: deskHeroBtn
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 76
                        radius: dPlayA.pressed ? 16 : (musicWin.isActuallyPlaying ? 20 : 38)
                        color: Theme.primary
                        scale: dPlayA.pressed ? 0.92 : (dPlayA.containsMouse ? 1.05 : 1.0)

                        Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        // Smooth M3 Expressive morphing Pause bars
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            opacity: musicWin.isActuallyPlaying ? 1.0 : 0.0
                            scale: musicWin.isActuallyPlaying ? 1.0 : 0.55
                            rotation: musicWin.isActuallyPlaying ? 0 : -28
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                            Rectangle { width: 9; height: 28; radius: 4.5; color: Theme.fgPrimary }
                            Rectangle { width: 9; height: 28; radius: 4.5; color: Theme.fgPrimary }
                        }

                        // Smooth M3 Expressive morphing Play triangle (optically centered +1.5px)
                        M3Icon {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1.5
                            name: "play_arrow"
                            size: 38
                            filled: true
                            color: Theme.fgPrimary
                            opacity: musicWin.isActuallyPlaying ? 0.0 : 1.0
                            scale: musicWin.isActuallyPlaying ? 0.55 : 1.0
                            rotation: musicWin.isActuallyPlaying ? 28 : 0
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutQuint } }
                        }

                        MouseArea {
                            id: dPlayA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (musicWin.activePlayer) { musicWin.skipBuffering = false; skipBufferShield.stop(); pauseDebounceTimer.stop(); musicWin.isActuallyPlaying = !musicWin.isActuallyPlaying; musicWin.activePlayer.togglePlaying() }
                        }
                    }

                    DeskMediaBtn {
                        iconName: "skip_next"
                        btnSize: 52
                        iconSize: 27
                        onTriggered: {
                            if (musicWin.activePlayer) {
                                musicWin.skipDir = 1
                                musicWin.skipBuffering = true
                                skipBufferShield.restart()
                                musicWin.activePlayer.next()
                            }
                        }
                    }

                    DeskMediaBtn {
                        iconName: "forward_10"
                        btnSize: 46
                        iconSize: 23
                        onTriggered: if (musicWin.activePlayer) { musicWin.activePlayer.seek(10); deskScrubber.setAnchor(deskScrubber.currentPos + 10) }
                    }

                    Item { Layout.fillWidth: true }
                }
            }

            // Subtle tonal divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                color: Theme.alpha(Theme.outlineVariant, 0.38)
            }

            // ═══════════════════════════════════════════════════
            // RIGHT COLUMN: Live YouTube-Music-Style Synced Lyrics Canvas
            // ═══════════════════════════════════════════════════
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    M3Icon {
                        name: "lyrics"
                        size: 18
                        filled: true
                        color: Theme.tertiary
                    }

                    M3Text {
                        role: "title"
                        customSize: 14
                        text: musicWin.lyricsSynced ? "Текст песни · Синхронизация" : "Текст песни"
                        color: Theme.fgSurface
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        visible: musicWin.lyricsSynced
                        height: 22
                        implicitWidth: syncLbl.implicitWidth + 14
                        radius: 11
                        color: Theme.primaryContainer
                        M3Text {
                            id: syncLbl
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            role: "labelEmphasized"
                            customSize: 10
                            text: "LIVE"
                            color: Theme.fgPrimaryContainer
                        }
                    }
                }

                // Synced / Plain Lyrics Scroll Container
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 20
                    color: Theme.alpha(Theme.surfaceContainerLow, 0.65)
                    clip: true

                    ListView {
                        id: lyricsList
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        clip: true
                        model: musicWin.lyricsLines
                        visible: musicWin.lyricsLines.length > 0
                        opacity: musicWin.lyricsOpacity
                        transform: Translate { y: musicWin.lyricsLiftY }

                        NumberAnimation {
                            id: lyricsScrollAnim
                            target: lyricsList
                            property: "contentY"
                            duration: 420
                            easing.type: Easing.OutQuint
                        }

                        delegate: Item {
                            required property var modelData
                            required property int index
                            readonly property bool isCurrent: musicWin.lyricsSynced && index === musicWin.activeLyricIndex
                            readonly property bool isPast: musicWin.lyricsSynced && index < musicWin.activeLyricIndex

                            width: lyricsList.width
                            implicitHeight: lyrTxt.implicitHeight + 10

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -4
                                radius: 14
                                color: isCurrent
                                    ? Theme.alpha(Theme.primaryContainer, 0.42)
                                    : (lyrA.containsMouse && modelData.time >= 0 ? Theme.alpha(Theme.fgSurface, 0.07) : "transparent")
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            M3Text {
                                id: lyrTxt
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                role: isCurrent ? "headline" : "title"
                                customSize: isCurrent ? 18 : 14
                                emphasized: isCurrent
                                text: modelData.text
                                wrapMode: Text.WordWrap
                                color: isCurrent ? Theme.fgSurface : (isPast ? Theme.fgSurfaceVariant : Theme.fgSurface)
                                opacity: musicWin.lyricsSynced ? (isCurrent ? 1.0 : (isPast ? 0.38 : 0.62)) : 0.90

                                Behavior on opacity { NumberAnimation { duration: 220 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            MouseArea {
                                id: lyrA
                                anchors.fill: parent
                                hoverEnabled: modelData.time >= 0
                                cursorShape: modelData.time >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (musicWin.activePlayer && modelData.time >= 0) {
                                        musicWin.activePlayer.position = modelData.time
                                        musicWin.livePos = modelData.time
                                        musicWin.updateActiveLyric()
                                    }
                                }
                            }
                        }
                    }

                    // Soft M3 Expressive Shimmer Skeleton while loading lyrics in background (zero "not found" flash!)
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        spacing: 14
                        visible: musicWin.lyricsLines.length === 0 && (musicWin.lyricsLoading || !musicWin.lyricsFetchedOnce)
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                        Repeater {
                            model: [0.68, 0.92, 0.78, 0.54, 0.84]
                            delegate: Rectangle {
                                required property real modelData
                                required property int index
                                Layout.preferredWidth: Math.round(parent.width * modelData)
                                Layout.preferredHeight: index === 1 ? 18 : 13
                                radius: 7
                                color: index === 1 ? Theme.primaryContainer : Theme.fgSurfaceVariant
                                opacity: 0.16

                                SequentialAnimation on opacity {
                                    running: musicWin.visible && musicWin.lyricsLines.length === 0 && (musicWin.lyricsLoading || !musicWin.lyricsFetchedOnce)
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 110 }
                                    NumberAnimation { to: 0.34; duration: 680; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 0.14; duration: 680; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }

                    // Minimal quiet empty state ONLY after fetch completes with no lyrics (no jarring "not found" banner!)
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: musicWin.lyricsLines.length === 0 && !musicWin.lyricsLoading && musicWin.lyricsFetchedOnce
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        spacing: 8

                        M3Icon {
                            Layout.alignment: Qt.AlignHCenter
                            name: musicWin.lyricsInstrumental ? "piano" : "music_note"
                            size: 38
                            filled: true
                            color: Theme.alpha(Theme.primary, musicWin.lyricsInstrumental ? 0.65 : 0.28)
                        }

                        M3Text {
                            visible: musicWin.lyricsInstrumental
                            Layout.alignment: Qt.AlignHCenter
                            role: "label"
                            customSize: 12
                            text: "Инструментальная композиция"
                            color: Theme.alpha(Theme.fgSurfaceVariant, 0.72)
                        }
                    }
                }
            }
        }
    }
}
