import QtQuick
import QtQuick.Layouts

Item {
    id: scrubber
    property var player: null
    property color activeColor: Theme.tertiary
    property color inactiveColor: Theme.alpha(Theme.fgTertiaryContainer, 0.28)
    property color textColor: Theme.alpha(Theme.fgTertiaryContainer, 0.85)
    property bool activeAnimation: true
    property bool showTimestamps: true
    property int trackBoxHeight: 24
    property real strokeW: 3.5
    property real maxWaveAmp: 2.8
    property real wavelength: 30.0
    property real thumbBaseW: 4.0
    property real thumbBaseH: 16.0
    property int timeFontSize: 11

    implicitHeight: showTimestamps ? (trackBoxHeight + timeFontSize + 6) : trackBoxHeight

    property var playingOverride: undefined
    property bool holdAtZero: false

    readonly property bool isPlaying: playingOverride !== undefined ? !!playingOverride : (player ? !!player.isPlaying : false)
    readonly property double trackLen: (player && player.length > 0) ? player.length : 0
    readonly property bool hasKnownLength: trackLen > 0.5

    // Smooth monotonic wall-clock position tracker (immune to Chromium/Electron 1s jitter & pause jump-to-end!)
    property double anchorPos: 0
    property double anchorMs: Date.now()
    property double currentPos: 0
    property double resetShieldUntilMs: 0
    property bool dragging: false
    property real dragRatio: 0

    function setAnchor(sec) {
        const safeSec = (typeof sec === "number" && !isNaN(sec) && sec >= 0) ? sec : 0
        const clamped = hasKnownLength ? Math.max(0, Math.min(trackLen, safeSec)) : safeSec
        anchorPos = clamped
        anchorMs = Date.now()
        currentPos = clamped
    }

    function resetToStart() {
        anchorPos = 0
        anchorMs = Date.now()
        currentPos = 0
        resetShieldUntilMs = Date.now() + 1200
        waveCanvas.requestPaint()
    }

    function syncFromPlayer(force) {
        if (!player || dragging || holdAtZero) return
        if (!force && !isPlaying) return
        if (!force && Date.now() < resetShieldUntilMs) return
        const p = player.position
        if (typeof p === "number" && !isNaN(p) && p >= 0) {
            if (hasKnownLength && p > trackLen + 1.0) return
            if (force || Math.abs(p - currentPos) > 1.8) {
                setAnchor(p)
            }
        }
    }

    Component.onCompleted: syncFromPlayer(true)
    onPlayerChanged: syncFromPlayer(true)
    onHoldAtZeroChanged: {
        if (holdAtZero) {
            resetToStart()
        } else {
            anchorPos = currentPos
            anchorMs = Date.now()
        }
    }
    onIsPlayingChanged: {
        // Always lock BOTH anchorPos and anchorMs cleanly on play/pause so handle NEVER jumps!
        anchorPos = currentPos
        anchorMs = Date.now()
    }

    Connections {
        target: scrubber.player
        function onPositionChanged() { scrubber.syncFromPlayer(false) }
        function onTrackTitleChanged() { scrubber.resetToStart() }
        function onPostTrackChanged() { scrubber.resetToStart() }
    }

    readonly property real progress: {
        if (dragging) return dragRatio
        if (holdAtZero) return 0.0
        if (hasKnownLength) return Math.max(0.0, Math.min(1.0, currentPos / trackLen))
        // When length is temporarily 0 during Chromium/YouTube track switch, stay cleanly at 0.0 (never jump to 45%!)
        return 0.0
    }

    // Smooth wave amplitude: wavy when playing -> calm straight line (0px) when paused (zero overshoot!)
    property real waveAmp: isPlaying ? maxWaveAmp : 0.0
    Behavior on waveAmp {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    property real wavePhase: 0.0
    Timer {
        interval: 16
        running: scrubber.visible && scrubber.activeAnimation && (scrubber.isPlaying || scrubber.waveAmp > 0.05)
        repeat: true
        onTriggered: {
            if (scrubber.isPlaying && !scrubber.dragging && !scrubber.holdAtZero) {
                const elapsed = Math.max(0, (Date.now() - scrubber.anchorMs) / 1000.0)
                // Guard against huge elapsed jump if timer was suspended/resumed
                if (elapsed < 3.0) {
                    const nextPos = scrubber.anchorPos + elapsed
                    scrubber.currentPos = scrubber.hasKnownLength ? Math.min(scrubber.trackLen, nextPos) : nextPos
                } else {
                    scrubber.anchorPos = scrubber.currentPos
                    scrubber.anchorMs = Date.now()
                }
            }
            scrubber.wavePhase = (scrubber.wavePhase + 0.11) % (Math.PI * 2)
            waveCanvas.requestPaint()
        }
    }

    onProgressChanged: waveCanvas.requestPaint()
    onWaveAmpChanged: waveCanvas.requestPaint()
    onActiveColorChanged: waveCanvas.requestPaint()
    onInactiveColorChanged: waveCanvas.requestPaint()

    function formatTime(secs) {
        if (!secs || isNaN(secs) || secs < 0) return "0:00"
        const total = Math.floor(secs)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    // ─── Track Area (Wavy Active + Gap + Straight Inactive + Vertical Pill Thumb) ───
    Item {
        id: trackBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: scrubber.trackBoxHeight

        Canvas {
            id: waveCanvas
            anchors.fill: parent
            antialiasing: true
            renderStrategy: Canvas.Threaded

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const w = width
                const h = height
                if (w <= 8 || h <= 4) return

                const midY = h / 2
                const pad = 4
                const usableW = Math.max(1, w - pad * 2)
                const thumbX = pad + usableW * scrubber.progress
                const gap = 7
                const amp = scrubber.waveAmp
                const wavelength = scrubber.wavelength
                const strokeW = scrubber.strokeW

                // 1) Active Wavy Track (Left -> Thumb - gap)
                const activeEnd = Math.max(pad, thumbX - gap)
                if (activeEnd > pad + 1) {
                    ctx.beginPath()
                    ctx.lineWidth = strokeW
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.strokeStyle = scrubber.activeColor

                    const step = 1.0
                    for (let x = pad; x <= activeEnd; x += step) {
                        // Gentle envelope fade near thumb so wave joins cleanly
                        const distToEnd = activeEnd - x
                        const env = distToEnd < 10 ? (distToEnd / 10.0) : 1.0
                        const y = midY + Math.sin((x - pad) * (Math.PI * 2 / wavelength) - scrubber.wavePhase) * amp * env
                        if (x === pad) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }

                // 2) Inactive Straight Track (Thumb + gap -> Right)
                const inactiveStart = Math.min(w - pad, thumbX + gap)
                if (w - pad - inactiveStart > 2) {
                    ctx.beginPath()
                    ctx.lineWidth = strokeW
                    ctx.lineCap = "round"
                    ctx.strokeStyle = scrubber.inactiveColor
                    ctx.moveTo(inactiveStart, midY)
                    ctx.lineTo(w - pad, midY)
                    ctx.stroke()
                }

                // 3) M3 Expressive End-Stop Indicator Dot
                if (scrubber.progress < 0.96) {
                    ctx.beginPath()
                    ctx.fillStyle = scrubber.activeColor
                    ctx.arc(w - pad, midY, 1.9, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }

        // Signature M3 Expressive Vertical Pill Thumb Handle!
        Rectangle {
            id: thumbPill
            readonly property real pad: 4
            readonly property real usableW: Math.max(1, trackBox.width - pad * 2)
            x: pad + usableW * scrubber.progress - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: scrubArea.pressed ? (scrubber.thumbBaseW + 1.2) : (scrubArea.containsMouse ? (scrubber.thumbBaseW + 0.6) : scrubber.thumbBaseW)
            height: scrubArea.pressed ? (scrubber.thumbBaseH + 4) : (scrubArea.containsMouse ? (scrubber.thumbBaseH + 2) : scrubber.thumbBaseH)
            radius: width / 2
            color: scrubber.activeColor

            Behavior on width { SpringAnimation { spring: 6.0; damping: 0.40 } }
            Behavior on height { SpringAnimation { spring: 6.0; damping: 0.40 } }
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        MouseArea {
            id: scrubArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function ratioAt(mx) {
                const pad = 4
                const usable = Math.max(1, width - pad * 2)
                return Math.max(0.0, Math.min(1.0, (mx - pad) / usable))
            }

            onPressed: mouse => {
                if (!scrubber.player) return
                scrubber.dragging = true
                scrubber.dragRatio = ratioAt(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed && scrubber.dragging) {
                    scrubber.dragRatio = ratioAt(mouse.x)
                }
            }
            onReleased: mouse => {
                if (!scrubber.player) {
                    scrubber.dragging = false
                    return
                }
                const r = ratioAt(mouse.x)
                if (scrubber.hasKnownLength) {
                    const targetSec = r * scrubber.trackLen
                    scrubber.setAnchor(targetSec)
                    scrubber.player.position = targetSec
                } else {
                    const delta = (r - scrubber.progress) * 60.0
                    scrubber.player.seek(delta)
                    scrubber.setAnchor(Math.max(0, scrubber.currentPos + delta))
                }
                scrubber.dragging = false
            }
        }
    }

    // ─── Elapsed / Total Timestamps ───
    RowLayout {
        visible: scrubber.showTimestamps
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: trackBox.bottom
        anchors.topMargin: 1

        Text {
            text: scrubber.formatTime(scrubber.dragging && scrubber.hasKnownLength ? (scrubber.dragRatio * scrubber.trackLen) : scrubber.currentPos)
            font.family: Theme.fontSans
            font.pixelSize: scrubber.timeFontSize
            font.weight: Font.DemiBold
            color: scrubber.textColor
            verticalAlignment: Text.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Text {
            text: scrubber.hasKnownLength ? scrubber.formatTime(scrubber.trackLen) : "—:—"
            font.family: Theme.fontSans
            font.pixelSize: scrubber.timeFontSize
            font.weight: Font.DemiBold
            color: scrubber.textColor
            verticalAlignment: Text.AlignVCenter
        }
    }
}
