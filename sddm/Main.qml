import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: cfg("surface", "#141317")

    function cfg(key, fallback) {
        if (typeof config !== "undefined" && config && config[key] !== undefined && config[key] !== "") {
            return config[key]
        }
        return fallback
    }

    function alpha(colStr, a) {
        const c = Qt.color(colStr)
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    readonly property bool isLight: cfg("mode", "dark") === "light"
    readonly property color cPrimary: cfg("primary", "#d0bdfd")
    readonly property color cOnPrimary: cfg("on_primary", "#36275c")
    readonly property color cPrimaryContainer: cfg("primary_container", "#594981")
    readonly property color cOnPrimaryContainer: cfg("on_primary_container", "#f9f1ff")
    readonly property color cSecondaryContainer: cfg("secondary_container", "#4f485f")
    readonly property color cOnSecondaryContainer: cfg("on_secondary_container", "#eee3ff")
    readonly property color cTertiary: cfg("tertiary", "#fdb0d4")
    readonly property color cSurface: cfg("surface", "#141317")
    readonly property color cSurfaceContainer: cfg("surface_container", "#211f23")
    readonly property color cSurfaceContainerHigh: cfg("surface_container_high", "#2b292d")
    readonly property color cSurfaceContainerHighest: cfg("surface_container_highest", "#363438")
    readonly property color cOnSurface: cfg("on_surface", "#e6e1e6")
    readonly property color cOnSurfaceVariant: cfg("on_surface_variant", "#cac4d0")
    readonly property color cOutline: cfg("outline", "#948f9a")
    readonly property color cOutlineVariant: cfg("outline_variant", "#49454f")
    readonly property color cError: cfg("error", "#ffb4ab")
    readonly property color cErrorContainer: cfg("error_container", "#93000a")
    readonly property color cOnErrorContainer: cfg("on_error_container", "#ffdad6")

    readonly property string fontSans: "Roboto Flex"
    readonly property string fontIcons: "Material Symbols Rounded"

    property int sessionIndex: (sessionModel && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex: (userModel && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property string errorText: ""
    property bool loggingIn: false
    property bool showPassword: false
    property real shakeOffset: 0

    property string timeStr: ""
    property string dateStr: ""

    function updateClock() {
        const now = new Date()
        const hh = String(now.getHours()).padStart(2, "0")
        const mm = String(now.getMinutes()).padStart(2, "0")
        timeStr = hh + ":" + mm
        const days = ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
        const months = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
        dateStr = days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()]
    }

    function currentUserName() {
        if (!userModel || userModel.count === 0) return "plenka"
        const idx = userModel.index(userIndex, 0)
        return userModel.data(idx, Qt.UserRole + 1) || userModel.lastUser || "plenka"
    }

    function currentSessionName() {
        if (!sessionModel || sessionModel.count === 0) return "Niri"
        const idx = sessionModel.index(sessionIndex, 0)
        return sessionModel.data(idx, Qt.UserRole + 4) || sessionModel.data(idx, Qt.DisplayRole) || "Niri"
    }

    function doLogin() {
        if (loggingIn) return
        errorText = ""
        loggingIn = true
        sddm.login(currentUserName(), passwordField.text, sessionIndex)
    }

    Component.onCompleted: {
        updateClock()
        passwordField.forceActiveFocus()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateClock()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loggingIn = false
            root.errorText = "Неверный пароль — попробуйте снова"
            passwordField.text = ""
            passwordField.forceActiveFocus()
            shakeAnim.restart()
        }
        function onLoginSucceeded() {
            root.loggingIn = false
            root.errorText = ""
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shakeOffset"; to: -12; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 11; duration: 75; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 5; duration: 55; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    // ─── Blurred Dynamic Profile Wallpaper Backdrop ───
    Image {
        id: bgImg
        anchors.fill: parent
        source: cfg("background", "background.jpg")
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: bgImg
        blurEnabled: true
        blurMax: 42
        blur: 0.55
        autoPaddingEnabled: false
    }

    // Tonal MD3 scrim for guaranteed readability on both light & dark wallpapers
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.alpha(root.cSurface, root.isLight ? 0.42 : 0.50) }
            GradientStop { position: 0.5; color: root.alpha(root.cSurface, root.isLight ? 0.52 : 0.62) }
            GradientStop { position: 1.0; color: root.alpha(root.cSurface, root.isLight ? 0.62 : 0.74) }
        }
    }

    // ─── Center Column: Giant M3 Expressive Clock + Frosted Login Card ───
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -18
        spacing: 26

        // Android 16 / MD3 Expressive Display Clock
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.timeStr
                font.family: root.fontSans
                font.pixelSize: 92
                font.weight: Font.DemiBold
                font.letterSpacing: -2.5
                color: root.cOnSurface
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                height: 32
                implicitWidth: dateLbl.implicitWidth + 28
                radius: 16
                color: root.alpha(root.cSurfaceContainerHigh, 0.86)
                border.width: 1
                border.color: root.alpha(root.cOutlineVariant, 0.45)

                Text {
                    id: dateLbl
                    anchors.centerIn: parent
                    text: root.dateStr
                    font.family: root.fontSans
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: root.cOnSurface
                }
            }
        }

        // Frosted Material Design 3 Expressive Login Card (28px ExtraLarge)
        Rectangle {
            id: loginCard
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 386
            implicitHeight: cardCol.implicitHeight + 48
            radius: 28
            color: root.alpha(root.cSurfaceContainer, 0.90)
            border.width: 1
            border.color: root.alpha(root.cOutlineVariant, 0.55)
            transform: Translate { x: root.shakeOffset }

            ColumnLayout {
                id: cardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                spacing: 16

                // Avatar & Username Header
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 82
                        height: 82
                        radius: 12
                        color: avatarImg.status === Image.Ready ? "transparent" : root.cPrimaryContainer
                        border.width: avatarImg.status === Image.Ready ? 0 : 2
                        border.color: root.alpha(root.cPrimary, 0.65)

                        Image {
                            id: avatarImg
                            anchors.fill: parent
                            source: cfg("avatar", "avatar.png")
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: avatarImg.status !== Image.Ready
                            text: "person"
                            font.family: root.fontIcons
                            font.pixelSize: 38
                            color: root.cOnPrimaryContainer
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Text {
                            text: root.currentUserName()
                            font.family: root.fontSans
                            font.pixelSize: 21
                            font.weight: Font.DemiBold
                            color: root.cOnSurface
                        }
                    }
                }

                // M3 Expressive Pill Password Field
                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 25
                    color: root.cSurfaceContainerHighest
                    border.width: passwordField.activeFocus ? 2 : 1
                    border.color: root.errorText !== ""
                        ? root.cError
                        : (passwordField.activeFocus ? root.cPrimary : root.alpha(root.cOutlineVariant, 0.70))

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: "lock"
                            font.family: root.fontIcons
                            font.pixelSize: 19
                            color: passwordField.activeFocus ? root.cPrimary : root.cOnSurfaceVariant
                        }

                        TextInput {
                            id: passwordField
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            font.family: root.fontSans
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            color: root.cOnSurface
                            selectionColor: root.cPrimaryContainer
                            selectedTextColor: root.cOnPrimaryContainer
                            clip: true
                            focus: true

                            Keys.onReturnPressed: root.doLogin()
                            Keys.onEnterPressed: root.doLogin()
                            Keys.onEscapePressed: {
                                text = ""
                                root.errorText = ""
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: passwordField.text.length === 0
                                text: "Введите пароль"
                                font.family: root.fontSans
                                font.pixelSize: 14
                                color: root.cOnSurfaceVariant
                                opacity: 0.85
                            }
                        }

                        // Show / hide password button
                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: eyeA.containsMouse ? root.alpha(root.cOnSurface, 0.10) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: root.showPassword ? "visibility_off" : "visibility"
                                font.family: root.fontIcons
                                font.pixelSize: 18
                                color: root.cOnSurfaceVariant
                            }

                            MouseArea {
                                id: eyeA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showPassword = !root.showPassword
                            }
                        }
                    }
                }

                // Inline error pill (visible only on failed login)
                Rectangle {
                    visible: root.errorText !== ""
                    Layout.fillWidth: true
                    height: 34
                    radius: 14
                    color: root.cErrorContainer

                    Text {
                        anchors.centerIn: parent
                        text: root.errorText
                        font.family: root.fontSans
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.cOnErrorContainer
                    }
                }

                // M3 Expressive Filled Primary Action Pill
                Rectangle {
                    Layout.fillWidth: true
                    height: 48
                    radius: loginA.pressed ? 16 : 24
                    color: root.loggingIn
                        ? root.cPrimaryContainer
                        : (loginA.containsMouse ? Qt.lighter(root.cPrimary, root.isLight ? 1.08 : 1.05) : root.cPrimary)
                    scale: loginA.pressed ? 0.98 : 1.0

                    Behavior on radius { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.loggingIn ? "Вход..." : "Войти"
                            font.family: root.fontSans
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: root.loggingIn ? root.cOnPrimaryContainer : root.cOnPrimary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.loggingIn
                            text: "arrow_forward"
                            font.family: root.fontIcons
                            font.pixelSize: 19
                            color: root.cOnPrimary
                        }
                    }

                    MouseArea {
                        id: loginA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.doLogin()
                    }
                }
            }
        }
    }

    // ─── Bottom Floating M3 Expressive Bar: Session · Keyboard · Power ───
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 12

        // Left Pill: Session & Keyboard Layout
        Rectangle {
            height: 44
            implicitWidth: leftPillRow.implicitWidth + 16
            radius: 22
            color: root.alpha(root.cSurfaceContainer, 0.88)
            border.width: 1
            border.color: root.alpha(root.cOutlineVariant, 0.45)

            Row {
                id: leftPillRow
                anchors.centerIn: parent
                spacing: 6

                // Session Switcher Button
                Rectangle {
                    height: 32
                    implicitWidth: sessRow.implicitWidth + 20
                    radius: 16
                    color: sessA.containsMouse ? root.cSecondaryContainer : root.cSurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: sessRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "desktop_windows"
                            font.family: root.fontIcons
                            font.pixelSize: 16
                            color: root.cPrimary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.currentSessionName()
                            font.family: root.fontSans
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: root.cOnSurface
                        }
                    }

                    MouseArea {
                        id: sessA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sessionModel && sessionModel.count > 1) {
                                root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
                            }
                        }
                    }
                }

                // Keyboard Layout Button
                Rectangle {
                    visible: typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 0
                    height: 32
                    implicitWidth: kbRow.implicitWidth + 18
                    radius: 16
                    color: kbA.containsMouse ? root.cSecondaryContainer : root.cSurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        id: kbRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "language"
                            font.family: root.fontIcons
                            font.pixelSize: 15
                            color: root.cPrimary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 0)
                                ? (keyboard.layouts[keyboard.currentLayout].shortName || "EN").toUpperCase()
                                : "EN"
                            font.family: root.fontSans
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.cOnSurface
                        }
                    }

                    MouseArea {
                        id: kbA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 1) {
                                keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Right Pill: Power Actions (Sleep · Reboot · Power Off)
        Rectangle {
            height: 44
            implicitWidth: pwrRow.implicitWidth + 16
            radius: 22
            color: root.alpha(root.cSurfaceContainer, 0.88)
            border.width: 1
            border.color: root.alpha(root.cOutlineVariant, 0.45)

            Row {
                id: pwrRow
                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: [
                        { id: "suspend",  icon: "bedtime",               label: "Сон",          danger: false },
                        { id: "reboot",   icon: "restart_alt",           label: "Перезагрузка", danger: false },
                        { id: "poweroff", icon: "power_settings_new",    label: "Выключить",    danger: true  }
                    ]
                    delegate: Rectangle {
                        id: pBtn
                        required property var modelData
                        height: 32
                        implicitWidth: pbRow.implicitWidth + 18
                        radius: 16
                        color: pBtnA.containsMouse
                            ? (modelData.danger ? root.cErrorContainer : root.cSecondaryContainer)
                            : root.cSurfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Row {
                            id: pbRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pBtn.modelData.icon
                                font.family: root.fontIcons
                                font.pixelSize: 16
                                color: (pBtnA.containsMouse && pBtn.modelData.danger) ? root.cOnErrorContainer : (pBtn.modelData.danger ? root.cError : root.cPrimary)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: pBtn.modelData.label
                                font.family: root.fontSans
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: (pBtnA.containsMouse && pBtn.modelData.danger) ? root.cOnErrorContainer : root.cOnSurface
                            }
                        }

                        MouseArea {
                            id: pBtnA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pBtn.modelData.id === "suspend") sddm.suspend()
                                else if (pBtn.modelData.id === "reboot") sddm.reboot()
                                else if (pBtn.modelData.id === "poweroff") sddm.powerOff()
                            }
                        }
                    }
                }
            }
        }
    }
}
