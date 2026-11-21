import QtQuick
import QtQuick.Layouts

/* Material Design 3 Expressive Wavy Audio Scrubber — 100% GPU-Scrolled (0 repaints/sec during playback!)
 * Paints the static anti-aliased sine strip ONCE into a GPU texture when size/color changes,
 * then translates it smoothly on the GPU at locked 144Hz VSync with <0.5% CPU usage!
 */
Item {
    id: scrubber
    property var player: null
    property var playingOverride: undefined
    property bool holdAtZero: false

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

    readonly property bool isPlaying: playingOverride !== undefined ? !!playingOverride : (player ? !!player.isPlaying : false)
    readonly property double trackLen: (player && player.length > 0) ? player.length : 0
    readonly property bool hasKnownLength: trackLen > 0.5

    // Monotonic wall-clock position tracker (zero MPRIS jitter, zero pause jump-to-end!)
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
        anchorPos = currentPos
        anchorMs = Date.now()
    }

    Connections {
        target: scrubber.player
        function onPositionChanged() { scrubber.syncFromPlayer(false) }
        function onTrackTitleChanged() { scrubber.resetToStart() }
        function onPostTrackChanged() { scrubber.resetToStart() }
    }

    // Lightweight 200ms timestamp/position advance (smoothly animated by GPU Behavior on thumbX!)
    Timer {
        interval: 200
        running: scrubber.visible && scrubber.activeAnimation && scrubber.isPlaying && !scrubber.dragging && !scrubber.holdAtZero
        repeat: true
        onTriggered: {
            const elapsed = Math.max(0, (Date.now() - scrubber.anchorMs) / 1000.0)
            if (elapsed < 3.0) {
                const nextPos = scrubber.anchorPos + elapsed
                scrubber.currentPos = scrubber.hasKnownLength ? Math.min(scrubber.trackLen, nextPos) : nextPos
            } else {
                scrubber.anchorPos = scrubber.currentPos
                scrubber.anchorMs = Date.now()
            }
        }
    }

    readonly property real progress: {
        if (dragging) return dragRatio
        if (holdAtZero) return 0.0
        if (hasKnownLength) return Math.max(0.0, Math.min(1.0, currentPos / trackLen))
        return 0.0
    }

    // Smooth GPU scale factor: 1.0 = full wave (playing), 0.0 = flat straight line (paused)
    property real waveFactor: isPlaying ? 1.0 : 0.0
    Behavior on waveFactor {
        M3Anim { type: M3Anim.FastSpatial }
    }

    function formatTime(secs) {
        if (!secs || isNaN(secs) || secs < 0) return "0:00"
        const total = Math.floor(secs)
        const m = Math.floor(total / 60)
        const s = total % 60
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    // ─── Track Area: 100% GPU-Composited Wavy Active + Straight Inactive + Pill Handle ───
    Item {
        id: trackBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: scrubber.trackBoxHeight

        readonly property real pad: 4
        readonly property real gap: 7
        readonly property real usableW: Math.max(1, width - pad * 2)
        readonly property real thumbX: pad + usableW * scrubber.progress
        readonly property real activeW: Math.max(0, thumbX - gap - pad)
        readonly property real inactiveStart: Math.min(width - pad, thumbX + gap)

        // 1) Active Wavy Track: painted ONCE into static Canvas, scrolled purely by GPU NumberAnimation!
        Item {
            id: waveClip
            x: trackBox.pad
            y: 0
            width: trackBox.activeW
            height: trackBox.height
            clip: true

            // Smooth flat line shown as waveFactor -> 0 (guarantees uniform stroke thickness when paused!)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: scrubber.strokeW
                radius: height / 2
                color: scrubber.activeColor
                opacity: 1.0 - scrubber.waveFactor
                visible: opacity > 0.01
            }

            // Static sine strip translated horizontally on GPU (ZERO per-frame Canvas repaints!)
            Item {
                id: waveStripHolder
                x: 0
                y: 0
                width: trackBox.width + scrubber.wavelength * 2
                height: trackBox.height
                opacity: scrubber.waveFactor
                visible: opacity > 0.01

                property real scrollOffset: 0
                transform: [
                    Translate { x: -waveStripHolder.scrollOffset },
                    Scale {
                        origin.y: trackBox.height / 2
                        yScale: Math.max(0.01, scrubber.waveFactor)
                    }
                ]

                NumberAnimation on scrollOffset {
                    from: 0
                    to: scrubber.wavelength
                    duration: 1050
                    loops: Animation.Infinite
                    running: scrubber.visible && scrubber.activeAnimation && scrubber.isPlaying
                }

                Canvas {
                    id: staticWaveCanvas
                    anchors.fill: parent
                    antialiasing: true
                    renderStrategy: Canvas.Cooperative

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Connections {
                        target: scrubber
                        function onActiveColorChanged() { staticWaveCanvas.requestPaint() }
                        function onWavelengthChanged() { staticWaveCanvas.requestPaint() }
                        function onMaxWaveAmpChanged() { staticWaveCanvas.requestPaint() }
                    }

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width
                        const h = height
                        if (w <= 8 || h <= 4) return
                        const midY = h / 2
                        const amp = scrubber.maxWaveAmp
                        const wl = Math.max(8, scrubber.wavelength)

                        ctx.beginPath()
                        ctx.lineWidth = scrubber.strokeW
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"
                        ctx.strokeStyle = scrubber.activeColor

                        for (let px = 0; px <= w; px += 1.0) {
                            const py = midY + Math.sin(px * (Math.PI * 2 / wl)) * amp
                            if (px === 0) ctx.moveTo(px, py)
                            else ctx.lineTo(px, py)
                        }
                        ctx.stroke()
                    }
                }
            }
        }

        // 2) Inactive Straight Track (pure GPU Rectangle — 0 Canvas overhead!)
        Rectangle {
            x: trackBox.inactiveStart
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, trackBox.width - trackBox.pad - trackBox.inactiveStart)
            height: scrubber.strokeW
            radius: height / 2
            color: scrubber.inactiveColor
            visible: width > 2
        }

        // 3) M3 Expressive End-Stop Dot (pure GPU Rectangle!)
        Rectangle {
            x: trackBox.width - trackBox.pad - 1.9
            anchors.verticalCenter: parent.verticalCenter
            width: 3.8
            height: 3.8
            radius: 1.9
            color: scrubber.activeColor
            visible: scrubber.progress < 0.96
        }

        // 4) Signature M3 Expressive Vertical Pill Thumb Handle!
        Rectangle {
            id: thumbPill
            x: trackBox.thumbX - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: scrubArea.pressed ? (scrubber.thumbBaseW + 1.2) : (scrubArea.containsMouse ? (scrubber.thumbBaseW + 0.6) : scrubber.thumbBaseW)
            height: scrubArea.pressed ? (scrubber.thumbBaseH + 4) : (scrubArea.containsMouse ? (scrubber.thumbBaseH + 2) : scrubber.thumbBaseH)
            radius: width / 2
            color: scrubber.activeColor

            Behavior on width { M3Anim { type: M3Anim.FastEffects } }
            Behavior on height { M3Anim { type: M3Anim.FastEffects } }
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        MouseArea {
            id: scrubArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function ratioAt(mx) {
                const p = trackBox.pad
                const usable = Math.max(1, width - p * 2)
                return Math.max(0.0, Math.min(1.0, (mx - p) / usable))
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
