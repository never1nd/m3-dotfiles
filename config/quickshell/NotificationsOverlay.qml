import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: notifScope

    ListModel {
        id: toastModel
    }

    property var liveMap: ({})

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: false

        onNotification: (n) => {
            if (!n) return
            if (NiriState.dndEnabled && n.urgency !== NotificationUrgency.Critical) {
                return
            }
            n.tracked = true
            const nid = n.id
            const map = Object.assign({}, notifScope.liveMap)
            map[nid] = n
            notifScope.liveMap = map

            const timeoutMs = n.urgency === NotificationUrgency.Critical
                ? 9000
                : (n.expireTimeout > 0 ? Math.max(1800, Math.min(12000, Math.round(n.expireTimeout * 1000))) : 4200)

            let replaced = false
            for (let i = 0; i < toastModel.count; i++) {
                if (toastModel.get(i).nid === nid) {
                    toastModel.set(i, {
                        nid: nid,
                        appName: n.appName || "Система",
                        summary: n.summary || "",
                        body: n.body || "",
                        iconName: n.appIcon || "",
                        imageUrl: n.image || "",
                        isCritical: n.urgency === NotificationUrgency.Critical,
                        timeoutMs: timeoutMs,
                        seq: Date.now()
                    })
                    replaced = true
                    break
                }
            }
            if (!replaced) {
                toastModel.insert(0, {
                    nid: nid,
                    appName: n.appName || "Система",
                    summary: n.summary || "",
                    body: n.body || "",
                    iconName: n.appIcon || "",
                    imageUrl: n.image || "",
                    isCritical: n.urgency === NotificationUrgency.Critical,
                    timeoutMs: timeoutMs,
                    seq: Date.now()
                })
                while (toastModel.count > 4) {
                    const lastId = toastModel.get(toastModel.count - 1).nid
                    notifScope.removeToast(lastId, false)
                }
            }

            n.closed.connect(() => {
                notifScope.removeToast(nid, false)
            })
        }
    }

    function removeToast(nid, callDismiss) {
        for (let i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).nid === nid) {
                toastModel.remove(i)
                break
            }
        }
        const obj = notifScope.liveMap[nid]
        if (obj) {
            const map = Object.assign({}, notifScope.liveMap)
            delete map[nid]
            notifScope.liveMap = map
            if (callDismiss) {
                try { obj.dismiss() } catch (e) {}
            }
        }
    }

    PanelWindow {
        id: toastWin
        visible: toastModel.count > 0
        anchors { top: true; right: true }
        margins { top: 44; right: 12 }
        implicitWidth: 368
        implicitHeight: Math.max(10, toastCol.implicitHeight + 12)
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "m3-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Column {
            id: toastCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            Repeater {
                model: toastModel
                delegate: Rectangle {
                    id: card
                    required property int nid
                    required property string appName
                    required property string summary
                    required property string body
                    required property string iconName
                    required property string imageUrl
                    required property bool isCritical
                    required property int timeoutMs
                    required property double seq

                    width: toastCol.width
                    height: cardRow.implicitHeight + 24
                    radius: 22
                    color: isCritical
                        ? Theme.alpha(Theme.errorContainer, 0.96)
                        : Theme.alpha(Theme.surfaceContainerHigh, 0.96)
                    border.width: 1
                    border.color: isCritical
                        ? Theme.alpha(Theme.errorColor, 0.65)
                        : Theme.alpha(Theme.outlineVariant, 0.48)

                    property bool entered: false
                    opacity: entered ? 1.0 : 0.0
                    x: entered ? 0 : 28
                    Component.onCompleted: entered = true

                    Behavior on x { SpringAnimation { spring: 5.0; damping: 0.38; epsilon: 0.2 } }
                    Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                    Timer {
                        id: expireTimer
                        interval: card.timeoutMs
                        running: !cardHover.containsMouse
                        repeat: false
                        onTriggered: notifScope.removeToast(card.nid, true)
                    }

                    onSeqChanged: expireTimer.restart()

                    RowLayout {
                        id: cardRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 11

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 38
                            Layout.alignment: Qt.AlignTop
                            radius: 13
                            color: card.isCritical ? Theme.errorColor : Theme.primaryContainer
                            clip: true

                            Image {
                                anchors.fill: parent
                                visible: card.imageUrl !== ""
                                source: card.imageUrl
                                sourceSize.width: 76
                                sourceSize.height: 76
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                            }

                            M3Icon {
                                anchors.centerIn: parent
                                visible: card.imageUrl === ""
                                name: card.isCritical ? "warning" : "notifications"
                                size: 20
                                filled: true
                                color: card.isCritical ? Theme.fgError : Theme.fgPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                M3Text {
                                    Layout.fillWidth: true
                                    role: "title"
                                    customSize: 13
                                    text: card.summary !== "" ? card.summary : card.appName
                                    color: card.isCritical ? Theme.fgErrorContainer : Theme.fgSurface
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                }
                                M3Text {
                                    visible: card.summary !== "" && card.appName !== "" && card.appName !== card.summary
                                    role: "label"
                                    customSize: 10
                                    text: card.appName
                                    color: card.isCritical ? Theme.fgErrorContainer : Theme.primary
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 110
                                }
                            }

                            M3Text {
                                visible: card.body !== ""
                                Layout.fillWidth: true
                                role: "body"
                                customSize: 11
                                text: card.body
                                color: card.isCritical ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            Layout.alignment: Qt.AlignTop
                            radius: 13
                            color: closeA.containsMouse
                                ? Theme.alpha(Theme.fgSurface, 0.14)
                                : "transparent"
                            M3Icon {
                                anchors.centerIn: parent
                                name: "close"
                                size: 15
                                color: card.isCritical ? Theme.fgErrorContainer : Theme.fgSurfaceVariant
                            }
                            MouseArea {
                                id: closeA
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: notifScope.removeToast(card.nid, true)
                            }
                        }
                    }

                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifScope.removeToast(card.nid, true)
                    }
                }
            }
        }
    }
}
