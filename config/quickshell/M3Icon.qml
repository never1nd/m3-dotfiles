import QtQuick

Text {
    id: icon
    property string name: ""
    property int size: 20
    property bool filled: false
    property real weight: filled ? 520 : 400
    // Official M3 Dark Theme optical grade compensation (-25 resting on dark, +25 filled)
    property real grade: Theme.mode === "dark" ? (filled ? 25 : -25) : (filled ? 45 : 0)

    property real animatedFill: filled ? 1.0 : 0.0
    property real animatedWeight: weight

    Behavior on animatedFill {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on animatedWeight {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }
    Behavior on color { ColorAnimation { duration: 170 } }

    text: name
    font.family: Theme.fontIcons
    font.pixelSize: size
    font.variableAxes: ({
        "FILL": animatedFill,
        "wght": animatedWeight,
        "GRAD": grade,
        "opsz": Math.max(20, Math.min(48, size))
    })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
}
