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

    // Debounce brief 50-150ms Stopped/Paused dips during Chromium track skips so Play/Pause & wave never flicker!
    readonly property bool rawPlaying: activePlayer !== null && !!activePlayer.isPlaying
    property bool isActuallyPlaying: rawPlaying
    onRawPlayingChanged: {
        if (rawPlaying) {
            pauseDebounceTimer.stop()
            isActuallyPlaying = true
        } else {
            pauseDebounceTimer.restart()
        }
    }
    Timer {
        id: pauseDebounceTimer
        interval: 220
        repeat: false
        onTriggered: musicWin.isActuallyPlaying = musicWin.rawPlaying
    }

    // Stay visible while paused or switching tracks; hide ONLY when all music services are closed!
    readonly property bool hasMusicService: activePlayer !== null

    // ─── Synchronized 2-Phase Material 3 Expressive Track Slide-Out -> Wait-for-Art -> Slide-In ───
    property string displayedTitle: ""
    property string displayedArtist: ""
    property string displayedAlbum: ""
    property string displayedArtUrl: ""

    property string pendingTitle: ""
    property string pendingArtist: ""
    property string pendingAlbum: ""
    property string pendingArtUrl: ""
    property string oldArtUrlBeforeSkip: ""

    // State machine: "idle" | "exiting" | "waiting" | "entering"
    property string swapPhase: "idle"
    property int skipDir: 1   // +1 = Next (exits left, enters from right), -1 = Prev (exits right, enters from left)

    property real stageX: 0
    property real stageScale: 1.0
    property real stageOpacity: 1.0
    property real lyricsOpacity: 1.0
    property real lyricsLiftY: 0
    property bool lyricsFetchedOnce: false

    function triggerLyricsReveal() {
        lyricsRevealAnim.stop()
        lyricsLiftY = 14
        lyricsOpacity = 0.0
        lyricsRevealAnim.start()
    }

    function beginTrackExit(dir) {
        skipDir = dir || 1
        oldArtUrlBeforeSkip = displayedArtUrl
        // Clear stale pendingArtUrl if it still belongs to the old track so we never reuse old art on Prev/Next!
        if (pendingArtUrl === displayedArtUrl) pendingArtUrl = ""
        // Immediately reset scrubber & livePos to 0:00 (zero 0.5s lag at old song position!)
        livePos = 0
        if (typeof deskScrubber !== "undefined" && deskScrubber) deskScrubber.resetToStart()
        // Smoothly glide old lyrics out in sync with the track slide-out
        if (lyricsLines.length > 0) {
            lyricsRevealAnim.stop()
            lyricsExitAnim.restart()
        }
        swapWaitTimer.stop()
        slideInAnim.stop()
        if (swapPhase === "idle" || swapPhase === "entering") {
            swapPhase = "exiting"
            slideOutAnim.restart()
        }
    }

    function finishSwapAndEnter() {
        swapWaitTimer.stop()
        if (pendingTitle !== "") displayedTitle = pendingTitle
        if (pendingArtist !== "") displayedArtist = pendingArtist
        displayedAlbum = pendingAlbum
        if (pendingArtUrl !== "") {
            displayedArtUrl = pendingArtUrl
        } else if (liveArtUrl !== "" && liveArtUrl !== oldArtUrlBeforeSkip) {
            displayedArtUrl = liveArtUrl
        }
        swapPhase = "entering"
        slideInAnim.restart()
    }

    function checkReadyToEnter() {
        if (swapPhase !== "waiting") return
        const hasTitle = pendingTitle !== "" && pendingTitle !== displayedTitle
        const hasFreshArt = pendingArtUrl !== "" && pendingArtUrl !== oldArtUrlBeforeSkip && artPreloader.status === Image.Ready
        if (hasTitle && hasFreshArt) {
            finishSwapAndEnter()
        }
    }

    readonly property string liveTrackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string liveArtUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    onLiveTrackTitleChanged: {
        if (liveTrackTitle !== "") syncTrackCache()
    }
    onLiveArtUrlChanged: {
        if (liveArtUrl !== "") {
            pendingArtUrl = liveArtUrl
            if (displayedArtUrl === "") {
                displayedArtUrl = liveArtUrl
            } else if (swapPhase === "idle" || swapPhase === "entering") {
                // Always catch late-arriving cover art (e.g. after Prev/Next when Chromium writes /tmp art slightly later!)
                displayedArtUrl = liveArtUrl
            } else {
                checkReadyToEnter()
            }
        }
    }

    function syncTrackCache() {
        if (!activePlayer) return
        const t = activePlayer.trackTitle || ""
        const a = activePlayer.trackArtist || activePlayer.identity || ""
        const alb = activePlayer.trackAlbum || ""
        const art = activePlayer.trackArtUrl || ""
        if (t === "") return

        // First track on startup: show immediately without exit slide
        if (displayedTitle === "") {
            displayedTitle = t
            displayedArtist = a
            displayedAlbum = alb
            displayedArtUrl = art
            pendingTitle = t
            pendingArtist = a
            pendingAlbum = alb
            pendingArtUrl = art
            oldArtUrlBeforeSkip = art
            fetchLyricsForCurrent()
            return
        }

        // Update pending fields cleanly (Chromium delivers title -> artist -> artUrl over ~200ms!)
        const isNewTrack = (t !== displayedTitle && t !== pendingTitle)
        pendingTitle = t
        if (a !== "") pendingArtist = a
        pendingAlbum = alb
        if (art !== "") pendingArtUrl = art

        if (isNewTrack) {
            fetchLyricsForCurrent()
            if (swapPhase === "idle" || swapPhase === "entering") {
                beginTrackExit(skipDir)
            } else if (swapPhase === "waiting") {
                checkReadyToEnter()
            }
        } else if (swapPhase === "waiting") {
            checkReadyToEnter()
        } else if (swapPhase === "idle" && t === displayedTitle) {
            if (a !== "") displayedArtist = a
            displayedAlbum = alb
            if (art !== "") displayedArtUrl = art
            fetchLyricsForCurrent()
        }
    }

    // Hidden async 256x256 preloader so the new cover is 100% decoded BEFORE sliding in!
    Image {
        id: artPreloader
        visible: false
        source: musicWin.pendingArtUrl
        asynchronous: true
        sourceSize.width: 256
        sourceSize.height: 256
        cache: true
        onStatusChanged: {
            if (status === Image.Ready) musicWin.checkReadyToEnter()
        }
    }

    // Safety timeout: if a song has no cover art or art takes >450ms, slide in cleanly anyway!
    Timer {
        id: swapWaitTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (musicWin.swapPhase === "waiting") {
                musicWin.finishSwapAndEnter()
            }
        }
    }

    // Smooth lyrics exit glide synchronized with track slide-out
    ParallelAnimation {
        id: lyricsExitAnim
        NumberAnimation { target: musicWin; property: "lyricsLiftY"; from: 0; to: -12; duration: 165; easing.type: Easing.InCubic }
        NumberAnimation { target: musicWin; property: "lyricsOpacity"; from: 1.0; to: 0.0; duration: 150; easing.type: Easing.InCubic }
    }

    // Phase 1: Old song visibly glides OUT (0 -> +-96px) while holding old cover & title
    ParallelAnimation {
        id: slideOutAnim
        NumberAnimation {
            target: musicWin; property: "stageX"
            from: 0; to: -musicWin.skipDir * 96
            duration: 185; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: musicWin; property: "stageScale"
            from: 1.0; to: 0.88
            duration: 185; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: musicWin; property: "stageOpacity"
            from: 1.0; to: 0.0
            duration: 165; easing.type: Easing.InCubic
        }
        onFinished: {
            musicWin.swapPhase = "waiting"
            musicWin.checkReadyToEnter()
            if (musicWin.swapPhase === "waiting") {
                swapWaitTimer.restart()
            }
        }
    }

    // Phase 2: New song (fully decoded cover + title + artist!) glides smoothly IN (+-104px -> 0, OutQuint)
    ParallelAnimation {
        id: slideInAnim
        NumberAnimation {
            target: musicWin; property: "stageX"
            from: musicWin.skipDir * 104; to: 0
            duration: 420; easing.type: Easing.OutQuint
        }
        NumberAnimation {
            target: musicWin; property: "stageScale"
            from: 0.88; to: 1.0
            duration: 420; easing.type: Easing.OutQuint
        }
        NumberAnimation {
            target: musicWin; property: "stageOpacity"
            from: 0.0; to: 1.0
            duration: 340; easing.type: Easing.OutCubic
        }
        onFinished: {
            musicWin.swapPhase = "idle"
            musicWin.skipDir = 1
            if (musicWin.pendingTitle !== "" && musicWin.displayedTitle !== musicWin.pendingTitle) {
                musicWin.displayedTitle = musicWin.pendingTitle
            }
            if (musicWin.pendingArtist !== "" && musicWin.displayedArtist !== musicWin.pendingArtist) {
                musicWin.displayedArtist = musicWin.pendingArtist
            }
            if (musicWin.pendingArtUrl !== "" && musicWin.displayedArtUrl !== musicWin.pendingArtUrl) {
                musicWin.displayedArtUrl = musicWin.pendingArtUrl
            } else if (musicWin.liveArtUrl !== "" && musicWin.displayedArtUrl !== musicWin.liveArtUrl) {
                musicWin.displayedArtUrl = musicWin.liveArtUrl
            }
            musicWin.oldArtUrlBeforeSkip = musicWin.displayedArtUrl
        }
    }

    ParallelAnimation {
        id: lyricsRevealAnim
        NumberAnimation { target: musicWin; property: "lyricsLiftY"; from: 14; to: 0; duration: 360; easing.type: Easing.OutQuint }
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

                // Clipped Synchronized M3E Shared Axis X Stage (Cover + Title + Artist glide out & in as ONE unit!)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 244
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10
                        opacity: musicWin.stageOpacity
                        scale: musicWin.stageScale
                        transform: Translate { x: musicWin.stageX }

                        // Hero Album Cover Art (192x192, ExtraLarge 24px)
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
                                id: coverArt
                                anchors.fill: parent
                                source: musicWin.displayedArtUrl
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
                                visible: !coverArt.visible
                                name: "album"
                                size: 72
                                filled: true
                                color: Theme.fgPrimaryContainer
                            }
                        }

                        // Track Title + Artist (subtle horizontal parallax inside stage)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            transform: Translate { x: musicWin.stageX * 0.22 }

                            M3Text {
                                role: "headline"
                                customSize: 17
                                text: musicWin.displayedTitle !== "" ? musicWin.displayedTitle : (musicWin.activePlayer ? (musicWin.activePlayer.trackTitle || "Ожидание трека") : "")
                                color: Theme.fgSurface
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            M3Text {
                                role: "label"
                                customSize: 12
                                text: musicWin.displayedArtist !== "" ? musicWin.displayedArtist : (musicWin.activePlayer ? (musicWin.activePlayer.trackArtist || musicWin.activePlayer.identity || "") : "")
                                color: Theme.primary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.minimumHeight: 8; Layout.maximumHeight: 14 }

                // Large Material Design 3 Expressive Wavy Audio Scrubber
                M3WavyScrubber {
                    id: deskScrubber
                    Layout.fillWidth: true
                    player: musicWin.activePlayer
                    playingOverride: musicWin.isActuallyPlaying
                    holdAtZero: musicWin.swapPhase === "exiting" || musicWin.swapPhase === "waiting"
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
                                musicWin.beginTrackExit(-1)
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
                            onClicked: if (musicWin.activePlayer) musicWin.activePlayer.togglePlaying()
                        }
                    }

                    DeskMediaBtn {
                        iconName: "skip_next"
                        btnSize: 52
                        iconSize: 27
                        onTriggered: {
                            if (musicWin.activePlayer) {
                                musicWin.beginTrackExit(1)
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
