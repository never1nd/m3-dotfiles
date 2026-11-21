import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calWindow
    required property bool isOpen
    property int navDir: 0
    signal closeRequested()

    property bool animOpen: false
    visible: isOpen || closeDelay.running

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    function resetToToday() {
        const now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }

    onIsOpenChanged: {
        if (isOpen) {
            closeDelay.stop()
            resetToToday()
            openNextTick.restart()
        } else {
            animOpen = false
            closeDelay.restart()
        }
    }

    Timer {
        id: openNextTick
        interval: 10
        onTriggered: calWindow.animOpen = true
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
    WlrLayershell.namespace: "m3-calendar-popup"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    SystemClock {
        id: liveClock
        precision: SystemClock.Seconds
    }

    readonly property var monthNames: ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
    readonly property var monthGenitive: ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
    readonly property var dayNames: ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
    readonly property var shortWeekdays: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    readonly property string liveTimeStr: {
        const d = liveClock.date
        return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0") + ":" + String(d.getSeconds()).padStart(2, "0")
    }
    readonly property string liveFullDate: {
        const d = liveClock.date
        return dayNames[d.getDay()] + ", " + d.getDate() + " " + monthGenitive[d.getMonth()] + " " + d.getFullYear()
    }

    function prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear -= 1 }
        else viewMonth -= 1
    }
    function nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear += 1 }
        else viewMonth += 1
    }

    // Build 42-cell calendar grid starting Monday
    readonly property var calendarCells: {
        const now = liveClock.date
        const todayY = now.getFullYear()
        const todayM = now.getMonth()
        const todayD = now.getDate()

        const first = new Date(viewYear, viewMonth, 1)
        const startOffset = (first.getDay() + 6) % 7 // Monday = 0
        const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
        const daysInPrev = new Date(viewYear, viewMonth, 0).getDate()

        const cells = []
        for (let i = 0; i < 42; i++) {
            let dayNum, inMonth, isToday
            if (i < startOffset) {
                dayNum = daysInPrev - startOffset + 1 + i
                inMonth = false
                isToday = false
            } else if (i < startOffset + daysInMonth) {
                dayNum = i - startOffset + 1
                inMonth = true
                isToday = (viewYear === todayY && viewMonth === todayM && dayNum === todayD)
            } else {
                dayNum = i - (startOffset + daysInMonth) + 1
                inMonth = false
                isToday = false
            }
            const colIdx = i % 7
            cells.push({ day: dayNum, inMonth: inMonth, isToday: isToday, isWeekend: colIdx >= 5 })
        }
        return cells
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: calWindow.closeRequested()

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, calWindow.animOpen ? 0.14 : 0.0)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: calWindow.closeRequested()
        }

        Rectangle {
            id: sheet
            anchors.right: parent.right
            anchors.rightMargin: calWindow.animOpen ? 12 : (12 - calWindow.navDir * 22)
            Behavior on anchors.rightMargin { SpringAnimation { spring: 5.0; damping: 0.36; epsilon: 0.2 } }
            y: calWindow.animOpen ? 40 : 24
            width: 332
            implicitHeight: calCol.implicitHeight + 36
            radius: 28
            color: Theme.alpha(Theme.surfaceContainer, 0.98)
            border.width: 1
            border.color: Theme.alpha(Theme.outlineVariant, 0.45)

            opacity: calWindow.animOpen ? 1.0 : 0.0
            scale: calWindow.animOpen ? 1.0 : 0.94
            transformOrigin: Item.TopRight

            Behavior on y { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.2 } }
            Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.36; epsilon: 0.002 } }
            Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            ColumnLayout {
                id: calCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 12

                // ─── Live Digital Clock & Date Header ───
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    M3Text {
                        role: "display"
                        customSize: 28
                        text: calWindow.liveTimeStr
                        color: Theme.fgSurface
                    }

                    M3Text {
                        role: "label"
                        customSize: 12
                        text: calWindow.liveFullDate
                        color: Theme.primary
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.alpha(Theme.outlineVariant, 0.45)
                }

                // ─── Month Switcher ───
                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        width: 34; height: 34; radius: pMA.pressed ? 10 : 17
                        color: pMA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
                        Text {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            font.family: Theme.fontIcons
                            font.pixelSize: 20
                            color: pMA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface
                        }
                        MouseArea {
                            id: pMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calWindow.prevMonth()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: 17
                        color: titleA.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        M3Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 1
                            role: "title"
                            customSize: 14
                            emphasized: titleA.containsMouse
                            text: calWindow.monthNames[calWindow.viewMonth] + " " + calWindow.viewYear
                            color: Theme.fgSurface
                        }

                        MouseArea {
                            id: titleA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calWindow.resetToToday()
                        }
                    }

                    Rectangle {
                        width: 34; height: 34; radius: nMA.pressed ? 10 : 17
                        color: nMA.containsMouse ? Theme.secondaryContainer : Theme.surfaceContainerHigh
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.36 } }
                        Text {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            font.family: Theme.fontIcons
                            font.pixelSize: 20
                            color: nMA.containsMouse ? Theme.fgSecondaryContainer : Theme.fgSurface
                        }
                        MouseArea {
                            id: nMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: calWindow.nextMonth()
                        }
                    }
                }

                // ─── Weekday Labels (Mon..Sun) ───
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4

                    Repeater {
                        model: calWindow.shortWeekdays
                        delegate: Item {
                            Layout.fillWidth: true
                            height: 22
                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                text: modelData
                                font.family: Theme.fontSans
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: index >= 5 ? Theme.tertiary : Theme.fgSurfaceVariant
                            }
                        }
                    }
                }

                // ─── Calendar Days Grid ───
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: calWindow.calendarCells
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 36
                            radius: modelData.isToday ? 18 : (dayA.containsMouse ? 14 : 18)
                            color: modelData.isToday
                                ? Theme.primary
                                : (dayA.containsMouse && modelData.inMonth ? Theme.secondaryContainer : "transparent")

                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.38 } }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                text: String(modelData.day)
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: modelData.isToday ? Font.Bold : Font.Medium
                                color: modelData.isToday
                                    ? Theme.fgPrimary
                                    : (!modelData.inMonth
                                        ? Theme.alpha(Theme.outline, 0.42)
                                        : (dayA.containsMouse ? Theme.fgSecondaryContainer : (modelData.isWeekend ? Theme.tertiary : Theme.fgSurface)))
                            }

                            MouseArea {
                                id: dayA
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }
        }
    }
}
