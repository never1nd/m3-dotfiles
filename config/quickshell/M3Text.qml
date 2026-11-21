import QtQuick

Text {
    id: txt
    // M3 Expressive Type Roles:
    //   "display"         -> Editorial wide expressive clock (wdth=114, wght=760, opsz=36)
    //   "headline"        -> Emphasized sheet titles (wdth=107, wght=720, opsz=22)
    //   "title"           -> Card & track titles (wdth=104, wght=680, opsz=16)
    //   "labelEmphasized" -> Interactive pills, chips, buttons (wdth=103, wght=660, animated GRAD!)
    //   "label"           -> Supporting metadata & subtitles (wdth=100, wght=540, opsz=12)
    //   "body"            -> Regular copy (wdth=100, wght=440, opsz=14)
    property string role: "labelEmphasized"
    property bool emphasized: false
    property int customSize: 0

    readonly property int resolvedSize: {
        if (customSize > 0) return customSize
        if (role === "display") return 26
        if (role === "headline") return 17
        if (role === "title") return 13
        if (role === "labelEmphasized") return 12
        if (role === "label") return 11
        return 13
    }

    readonly property real baseWeight: {
        if (role === "display") return 760
        if (role === "headline") return 720
        if (role === "title") return emphasized ? 720 : 660
        if (role === "labelEmphasized") return emphasized ? 720 : 650
        if (role === "label") return emphasized ? 650 : 520
        return emphasized ? 600 : 440
    }

    readonly property real baseWidth: {
        if (role === "display") return 114
        if (role === "headline") return 107
        if (role === "title") return 104
        if (role === "labelEmphasized") return 103
        return 100
    }

    // M3 Expressive GRAD axis: smoothly boosts visual weight on hover/active with ZERO layout shift!
    property real animatedGrade: emphasized ? 45 : (Theme.mode === "dark" ? -10 : 0)
    Behavior on animatedGrade {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on color { ColorAnimation { duration: 160 } }

    font.family: Theme.fontSans
    font.pixelSize: resolvedSize
    font.letterSpacing: {
        if (role === "display") return -0.6
        if (role === "headline") return -0.25
        if (role === "title") return -0.1
        if (role === "label") return 0.15
        return 0.0
    }
    font.variableAxes: ({
        "wght": baseWeight,
        "wdth": baseWidth,
        "opsz": Math.max(8, Math.min(144, resolvedSize * 1.2)),
        "GRAD": animatedGrade
    })
    verticalAlignment: Text.AlignVCenter
    renderType: Text.QtRendering
}
