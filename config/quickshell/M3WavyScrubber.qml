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

    readonly property bool isPlaying: player ? !!player.isPlaying : false
    readonly property double trackLen: (player && player.length > 0) ? player.length : 0
    readonly property bool hasKnownLength: trackLen > 0.5

    // Local smooth position tracker (synced with MPRIS position)
    property double currentPos: 0
    property bool dragging: false
    property real dragRatio: 0

    function syncFromPlayer() {
        if (!player || dragging) return
        const p = player.position
        if (typeof p === "number" && !isNaN(p) && p >= 0) {
            currentPos = p
        }
    }

    onPlayerChanged: syncFromPlayer()

    Connections {
        target: scrubber.player
        function onPositionChanged() { scrubber.syncFromPlayer() }
        function onTrackTitleChanged() {
            scrubber.currentPos = 0
            scrubber.syncFromPlayer()
        }
    }

    // Poll MPRIS position cleanly while visible & playing
    Timer {
        interval: 500
        running: scrubber.visible && scrubber.player !== null && scrubber.isPlaying && !scrubber.dragging
        repeat: true
        onTriggered: {
            if (!scrubber.player) return
            scrubber.player.positionChanged()
            if (scrubber.hasKnownLength) {
                scrubber.currentPos = Math.min(scrubber.trackLen, scrubber.currentPos + 0.5)
            } else {
                scrubber.currentPos = scrubber.currentPos + 0.5
            }
        }
    }

    readonly property real progress: {
        if (dragging) return dragRatio
        if (hasKnownLength) return Math.max(0.0, Math.min(1.0, currentPos / trackLen))
        // Graceful visual progress when player omits mpris:length (e.g. Telegram audio)
        if (currentPos > 0) {
            // Smooth visual sweep across 4-minute reference or steady 0.58 fill
            return Math.max(0.18, Math.min(0.88, (currentPos % 240) / 240))
        }
        return isPlaying ? 0.45 : 0.25
    }

    // Smooth wave amplitude: wavy (3.2px) when playing -> flat straight line (0px) when paused!
    property real waveAmp: isPlaying ? maxWaveAmp : 0.0
    Behavior on waveAmp {
        SpringAnimation { spring: 4.5; damping: 0.42; epsilon: 0.02 }
    }

    property real wavePhase: 0.0
    Timer {
        interval: 16
        running: scrubber.visible && scrubber.activeAnimation && (scrubber.isPlaying || scrubber.waveAmp > 0.05)
        repeat: true
        onTriggered: {
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
                    scrubber.currentPos = targetSec
                    scrubber.player.position = targetSec
                } else {
                    // Relative seek fallback for players without mpris:length
                    const delta = (r - scrubber.progress) * 60.0
                    scrubber.player.seek(delta)
                    scrubber.currentPos = Math.max(0, scrubber.currentPos + delta)
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
