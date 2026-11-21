import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property string activePopup: "" // "", "cc", "media", "calendar", "sysmon", "clipboard", "volume", "settings"
    property int navDir: 0
    property bool screenshotOpen: false
    property bool barHidden: false
    property bool isRecording: false

    readonly property var rightMenus: ["sysmon", "volume", "calendar", "cc"]

    onActivePopupChanged: syncPopupState()
    Component.onCompleted: syncPopupState()

    function syncPopupState() {
        const rt = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" > "$2/m3-popup"', "_", root.activePopup, rt])
    }

    function togglePopup(name) {
        navDir = 0
        activePopup = (activePopup === name) ? "" : name
    }

    function stepMenu(dir) {
        const list = rightMenus
        const curIdx = list.indexOf(activePopup)
        if (curIdx === -1) {
            if (activePopup === "media") {
                navDir = (dir === "left") ? -1 : 1
                activePopup = (dir === "left") ? list[list.length - 1] : list[0]
            }
            return
        }
        const delta = (dir === "left") ? -1 : 1
        navDir = delta
        const nextIdx = (curIdx + delta + list.length) % list.length
        activePopup = list[nextIdx]
    }

    IpcHandler {
        target: "shell"
        function toggleControlCenter(): void { root.togglePopup("cc") }
        function closeControlCenter(): void { if (root.activePopup === "cc") root.activePopup = "" }
        function toggleMediaPopup(): void { root.togglePopup("media") }
        function closeMediaPopup(): void { if (root.activePopup === "media") root.activePopup = "" }
        function toggleCalendar(): void { root.togglePopup("calendar") }
        function toggleSysMon(): void { root.togglePopup("sysmon") }
        function toggleClipboard(): void { root.togglePopup("clipboard") }
        function toggleVolume(): void { root.togglePopup("volume") }
        function toggleSettings(): void { root.togglePopup("settings") }
        function toggleNetwork(): void { root.togglePopup("network") }
        function toggleCustomization(): void { root.togglePopup("customization") }
        function togglePower(): void { root.togglePopup("power") }
        function toggleScreenshot(): void { root.screenshotOpen = !root.screenshotOpen }
        function stepMenu(dir: string): void { root.stepMenu(dir) }
        function closeAll(): void {
            root.activePopup = ""
            root.screenshotOpen = false
        }

        function toggleBar(): void {
            root.barHidden = !root.barHidden
            if (root.barHidden) root.activePopup = ""
        }
        function setRecording(active: string): void {
            root.isRecording = (active === "true" || active === "1")
        }
    }

    // Pinned Desktop Background Widgets (WlrLayer.Bottom, strictly behind Niri carousel on every workspace!)
    DesktopTerminalCard {}
    DesktopMusicWidget {}

    TopBar {
        controlCenterOpen: root.activePopup === "cc"
        mediaPopupOpen: root.activePopup === "media"
        calendarOpen: root.activePopup === "calendar"
        sysMonOpen: root.activePopup === "sysmon"
        volumeOpen: root.activePopup === "volume"
        barHidden: root.barHidden
        isRecording: root.isRecording
        onToggleControlCenter: root.togglePopup("cc")
        onToggleMediaPopup: root.togglePopup("media")
        onToggleCalendar: root.togglePopup("calendar")
        onToggleSysMon: root.togglePopup("sysmon")
        onToggleVolume: root.togglePopup("volume")
    }

    ControlCenter {
        isOpen: root.activePopup === "cc"
        navDir: root.navDir
        onCloseRequested: if (root.activePopup === "cc") root.activePopup = ""
        onOpenSettingsRequested: { root.navDir = 0; root.activePopup = "settings" }
        onOpenVolumeRequested: { root.navDir = -1; root.activePopup = "volume" }
        onOpenNetworkRequested: { root.navDir = 0; root.activePopup = "network" }
        onOpenCustomizationRequested: { root.navDir = 0; root.activePopup = "customization" }
        onOpenPowerRequested: { root.navDir = 0; root.activePopup = "power" }
    }

    MediaPopup {
        isOpen: root.activePopup === "media"
        onCloseRequested: if (root.activePopup === "media") root.activePopup = ""
    }

    CalendarPopup {
        isOpen: root.activePopup === "calendar"
        navDir: root.navDir
        onCloseRequested: if (root.activePopup === "calendar") root.activePopup = ""
    }

    SystemMonitorPopup {
        isOpen: root.activePopup === "sysmon"
        navDir: root.navDir
        onCloseRequested: if (root.activePopup === "sysmon") root.activePopup = ""
    }

    VolumePopup {
        isOpen: root.activePopup === "volume"
        navDir: root.navDir
        onCloseRequested: if (root.activePopup === "volume") root.activePopup = ""
    }

    ClipboardPopup {
        isOpen: root.activePopup === "clipboard"
        onCloseRequested: if (root.activePopup === "clipboard") root.activePopup = ""
    }

    SettingsWindow {
        isOpen: root.activePopup === "settings"
        barHidden: root.barHidden
        onCloseRequested: if (root.activePopup === "settings") root.activePopup = ""
        onToggleBarRequested: {
            root.barHidden = !root.barHidden
        }
    }

    NetworkPopup {
        isOpen: root.activePopup === "network"
        onCloseRequested: if (root.activePopup === "network") root.activePopup = ""
    }

    CustomizationPopup {
        isOpen: root.activePopup === "customization"
        onCloseRequested: if (root.activePopup === "customization") root.activePopup = ""
    }

    PowerPopup {
        isOpen: root.activePopup === "power"
        onCloseRequested: if (root.activePopup === "power") root.activePopup = ""
    }

    ScreenshotPopup {
        isOpen: root.screenshotOpen
        onCloseRequested: root.screenshotOpen = false
    }

    NotificationsOverlay {}
}
