import QtQuick

/* Strict Material Design 3 Expressive v34.0.0 Slider (Size M/L)
 * Official anatomy:
 *   - Active Track (left): outer rounded corners (12px), inner handle-facing corners (4px ExtraSmall)
 *   - Symmetric 6px gap on EACH side of the handle
 *   - Vertical Pill Handle ("палочка"): 4px x 42px resting -> stretches/narrows to 2.5px x 46px on press!
 *   - Inactive Track (right): inner 4px corners, outer 12px corners + 4px M3 stop-indicator dot
 *   - Authentic M3 Expressive spatial spring physics on value, handle & track morphing
 */
Item {
    id: slider
    property real value: 0.5          // 0.0 .. 1.0
    property real minValue: 0.0
    property string iconName: "volume_up"
    property string mutedIconName: "volume_off"
    property bool muted: false
    property bool iconClickable: false
    property string valueLabel: Math.round(displayValue * 100) + "%"
    property color activeColor: Theme.primary
    property color onActiveColor: Theme.fgPrimary
    property color trackColor: Theme.surfaceContainerHighest
    property int trackHeight: 36

    signal moved(real newValue)
    signal committed(real newValue)
    signal iconClicked()

    implicitHeight: trackHeight + 10

    property bool dragging: false
    property real dragValue: value
    readonly property real targetVal: dragging ? dragValue : (muted ? 0.0 : Math.max(minValue, Math.min(1.0, value)))

    // Smooth M3 Expressive spring value for non-drag updates
    property real displayValue: targetVal
    Behavior on displayValue {
        enabled: !slider.dragging
        SpringAnimation { spring: 5.8; damping: 0.40; epsilon: 0.002 }
    }

    readonly property real handleW: dragArea.pressed ? 2.8 : (dragArea.containsMouse ? 4.5 : 4.0)
    readonly property real handleH: dragArea.pressed ? (trackHeight + 10) : (dragArea.containsMouse ? (trackHeight + 8) : (trackHeight + 6))
    readonly property real gap: 6.0
    readonly property real padX: 2.0
    readonly property real usableW: Math.max(1, width - padX * 2)
    // Keep handle neatly within track bounds
    readonly property real handleCenterX: padX + Math.max(handleW / 2, Math.min(usableW - handleW / 2, usableW * displayValue))

    readonly property real activeRightEdge: Math.max(0, handleCenterX - handleW / 2 - gap)
    readonly property real inactiveLeftEdge: Math.min(width, handleCenterX + handleW / 2 + gap)
    readonly property real inactiveW: Math.max(0, width - inactiveLeftEdge)

    readonly property color effectiveActiveColor: muted ? Theme.errorContainer : activeColor
    readonly property color effectiveOnActiveColor: muted ? Theme.fgErrorContainer : onActiveColor

    // ─── 1. Active Track (Left: 12px outer corners, 4px handle-facing corners — seamless single-pass!) ───
    Rectangle {
        id: activeClip
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: slider.activeRightEdge
        height: slider.trackHeight
        visible: width > 1
        topLeftRadius: Math.min(12, width / 2)
        bottomLeftRadius: Math.min(12, width / 2)
        topRightRadius: Math.min(4, width / 2)
        bottomRightRadius: Math.min(4, width / 2)
        color: slider.effectiveActiveColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    // ─── 2. Inactive Track (Right: 4px handle-facing corners, 12px outer corners — seamless single-pass!) ───
    Rectangle {
        id: inactiveClip
        x: slider.inactiveLeftEdge
        anchors.verticalCenter: parent.verticalCenter
        width: slider.inactiveW
        height: slider.trackHeight
        visible: width > 1
        topLeftRadius: Math.min(4, width / 2)
        bottomLeftRadius: Math.min(4, width / 2)
        topRightRadius: Math.min(12, width / 2)
        bottomRightRadius: Math.min(12, width / 2)
        color: slider.trackColor
        Behavior on color { ColorAnimation { duration: 160 } }

        // Official M3 Expressive End-Stop Indicator Dot (4px circle in activeColor)
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 4
            radius: 2
            color: slider.effectiveActiveColor
            opacity: slider.inactiveW > 22 ? 0.85 : 0.0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    // ─── 3. THE VERTICAL PILL HANDLE ("Палочка" M3 Expressive!) ───
    Rectangle {
        id: handleStick
        x: slider.handleCenterX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: slider.handleW
        height: slider.handleH
        radius: width / 2
        color: slider.muted ? Theme.errorColor : slider.activeColor
        z: 4

        Behavior on width { SpringAnimation { spring: 6.5; damping: 0.36; epsilon: 0.05 } }
        Behavior on height { SpringAnimation { spring: 6.5; damping: 0.36; epsilon: 0.1 } }
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    // ─── 4. Leading M3 Icon (adapts color smoothly whether sitting on active or inactive track!) ───
    Item {
        id: iconHit
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: slider.trackHeight
        z: 5

        readonly property bool onActive: slider.activeRightEdge > 28

        M3Icon {
            anchors.centerIn: parent
            name: slider.muted ? slider.mutedIconName : slider.iconName
            size: 19
            filled: true
            color: slider.muted
                ? Theme.errorColor
                : (iconHit.onActive ? slider.effectiveOnActiveColor : slider.activeColor)
        }

        MouseArea {
            anchors.fill: parent
            enabled: slider.iconClickable
            cursorShape: slider.iconClickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: slider.iconClicked()
        }
    }

    // ─── 5. Trailing Percentage Label (smart contrast whether over inactive or active track!) ───
    M3Text {
        id: pctLabel
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 1
        z: 5
        role: "labelEmphasized"
        customSize: 12
        emphasized: dragArea.pressed || dragArea.containsMouse
        text: slider.muted ? "Выкл" : slider.valueLabel
        color: (slider.activeRightEdge > slider.width - 52 && !slider.muted)
            ? slider.effectiveOnActiveColor
            : Theme.fgSurface
    }

    // ─── 6. Interactive Drag / Click / Wheel Overlay ───
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.leftMargin: slider.iconClickable ? 36 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: 3

        function calcRatio(mx) {
            const globalX = mx + (slider.iconClickable ? 36 : 0)
            const r = (globalX - slider.padX) / slider.usableW
            return Math.max(slider.minValue, Math.min(1.0, r))
        }

        onPressed: mouse => {
            slider.dragging = true
            slider.dragValue = calcRatio(mouse.x)
            slider.moved(slider.dragValue)
        }
        onPositionChanged: mouse => {
            if (pressed && slider.dragging) {
                slider.dragValue = calcRatio(mouse.x)
                slider.moved(slider.dragValue)
            }
        }
        onReleased: mouse => {
            const r = calcRatio(mouse.x)
            slider.dragValue = r
            slider.dragging = false
            slider.committed(r)
        }
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            const next = Math.max(slider.minValue, Math.min(1.0, slider.value + step))
            slider.moved(next)
            slider.committed(next)
        }
    }
}
