pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var workspaces: []
    property int activeWorkspaceId: -1
    property int activeWorkspaceIndex: 0

    property var windowsById: ({})
    property var activeWindows: []
    property int focusedWindowId: -1
    property int focusedIndex: -1
    property bool focusedIsFullscreen: false
    property bool dndEnabled: false

    property var kbNames: ["English (US)", "Russian"]
    property int kbIndex: 0
    property string keyboardLayout: {
        const name = (kbNames && kbIndex >= 0 && kbIndex < kbNames.length) ? kbNames[kbIndex] : "EN"
        const low = name.toLowerCase()
        if (low.indexOf("rus") !== -1) return "RU"
        if (low.indexOf("eng") !== -1) return "EN"
        return name.substring(0, 2).toUpperCase()
    }

    // Pinned apps always visible in the unified dock (even when closed), in exact requested order:
    readonly property var pinnedApps: [
        { key: "pin:files",    name: "Файлы",    iconId: "org.gnome.Nautilus",    appIds: ["org.gnome.nautilus", "nautilus"],    cmd: ["nautilus"] },
        { key: "pin:zen",      name: "Zen",      iconId: "zen",                   appIds: ["zen", "zen-alpha", "zen-browser"],   cmd: ["/opt/zen-browser-bin/zen-bin"] },
        { key: "pin:keqdroid", name: "KeqDroid", iconId: "com.keqdroid.keqdroid", appIds: ["com.keqdroid.keqdroid", "keqdroid"], cmd: ["keqdroid"] },
        { key: "pin:ayugram",  name: "AyuGram",  iconId: "com.ayugram.desktop",   appIds: ["com.ayugram.desktop", "ayugram"],    cmd: ["/usr/local/bin/AyuGram"] }
    ]

    // Unified ListModel: open windows on active workspace in exact Niri column order + any pinned apps not on this workspace (ZERO duplicates!)
    property ListModel windowModel: ListModel {}

    function resolveIcon(appId) {
        if (!appId) return Quickshell.iconPath("application-x-executable")
        const low = appId.toLowerCase()
        const h = Quickshell.env("HOME")

        // Direct verified icon paths for apps whose Wayland/X11 app_id differs from icon theme name
        const directFiles = {
            "com.github.th-ch.youtube-music": "file:///usr/lib/pear-desktop/app.asar.unpacked/assets/generated/icons/png/256x256.png",
            "pear-desktop": "file:///usr/lib/pear-desktop/app.asar.unpacked/assets/generated/icons/png/256x256.png",
            "com-nuvio-app-mainkt": "file://" + h + "/.local/share/icons/hicolor/256x256/apps/nuvio.png",
            "nuvio": "file://" + h + "/.local/share/icons/hicolor/256x256/apps/nuvio.png",
            "hydra": "file://" + h + "/.local/share/icons/hicolor/256x256/apps/hydralauncher.png",
            "hydralauncher": "file://" + h + "/.local/share/icons/hicolor/256x256/apps/hydralauncher.png"
        }
        if (directFiles[low]) return directFiles[low]

        const overrides = {
            "zen": "zen-browser",
            "zen-alpha": "zen-browser",
            "kitty": "kitty",
            "alacritty": "Alacritty",
            "org.telegram.desktop": "telegram",
            "com.ayugram.desktop": "com.ayugram.desktop",
            "org.gnome.nautilus": "org.gnome.Nautilus",
            "steam": "steam",
            "firefox": "firefox",
            "vesktop": "vesktop",
            "vscodium": "vscodium",
            "codium": "vscodium",
            "termius": "termius-app",
            "termius-app": "termius-app",
            "com.keqdroid.keqdroid": "com.keqdroid.keqdroid"
        }
        if (overrides[low]) {
            const p2 = Quickshell.iconPath(overrides[low], true)
            if (p2 && p2 !== "") return p2
        }
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon && entry.icon !== "") {
            const p = Quickshell.iconPath(entry.icon, true)
            if (p && p !== "") return p
        }
        const p3 = Quickshell.iconPath(appId, true)
        if (p3 && p3 !== "") return p3
        return Quickshell.iconPath("application-x-executable")
    }

    function recomputeWindows() {
        const list = []
        for (const k in windowsById) {
            const w = windowsById[k]
            if (w && w.workspace_id === activeWorkspaceId) {
                list.push(w)
            }
        }
        // Strict left-to-right spatial sort matching Niri scrolling column & tile order!
        list.sort((a, b) => {
            const pa = a.layout && a.layout.pos_in_scrolling_layout
            const pb = b.layout && b.layout.pos_in_scrolling_layout
            if (pa && pb) {
                if (pa[0] !== pb[0]) return pa[0] - pb[0]
                if (pa[1] !== pb[1]) return pa[1] - pb[1]
            } else if (pa && !pb) {
                return -1
            } else if (!pa && pb) {
                return 1
            }
            return a.id - b.id
        })

        activeWindows = list

        // Build unified dock items:
        //   1) All open windows on the active workspace in exact left-to-right Niri column order
        //   2) Any pinned app (Файлы, Zen, KeqDroid, AyuGram) NOT already present on this workspace (in exact order, ZERO duplicates!)
        const desired = []
        const presentOnWs = {}
        for (let i = 0; i < list.length; i++) {
            const w = list[i]
            const low = (w.app_id || "").toLowerCase()
            presentOnWs[low] = true
            desired.push({
                itemKey: "win:" + w.id,
                winId: w.id,
                appId: w.app_id || "",
                title: w.title || w.app_id || "",
                iconSource: resolveIcon(w.app_id),
                isUrgent: !!w.is_urgent,
                isFloating: !!w.is_floating,
                isOpenHere: true,
                isRunningElsewhere: false,
                pinIdx: -1
            })
        }

        for (let p = 0; p < pinnedApps.length; p++) {
            const pin = pinnedApps[p]
            let onThisWs = false
            for (let a = 0; a < pin.appIds.length; a++) {
                if (presentOnWs[pin.appIds[a]]) {
                    onThisWs = true
                    break
                }
            }
            if (!onThisWs) {
                const otherWinId = findOpenWindowId(pin.appIds)
                desired.push({
                    itemKey: pin.key,
                    winId: otherWinId,
                    appId: pin.iconId,
                    title: pin.name,
                    iconSource: resolveIcon(pin.iconId),
                    isUrgent: false,
                    isFloating: false,
                    isOpenHere: false,
                    isRunningElsewhere: otherWinId !== -1,
                    pinIdx: p
                })
            }
        }

        const desiredKeys = desired.map(d => d.itemKey)

        // 1) Remove items no longer in unified dock
        for (let i = windowModel.count - 1; i >= 0; i--) {
            if (desiredKeys.indexOf(windowModel.get(i).itemKey) === -1) {
                windowModel.remove(i)
            }
        }

        // 2) Insert or smoothly move items to their exact unified slot
        for (let target = 0; target < desired.length; target++) {
            const d = desired[target]
            let found = -1
            for (let j = 0; j < windowModel.count; j++) {
                if (windowModel.get(j).itemKey === d.itemKey) {
                    found = j
                    break
                }
            }
            if (found === -1) {
                windowModel.insert(target, d)
            } else {
                if (found !== target) {
                    windowModel.move(found, target, 1)
                }
                windowModel.setProperty(target, "winId", d.winId)
                windowModel.setProperty(target, "title", d.title)
                windowModel.setProperty(target, "isUrgent", d.isUrgent)
                windowModel.setProperty(target, "isFloating", d.isFloating)
                windowModel.setProperty(target, "isOpenHere", d.isOpenHere)
                windowModel.setProperty(target, "isRunningElsewhere", d.isRunningElsewhere)
                windowModel.setProperty(target, "pinIdx", d.pinIdx)
            }
        }

        updateFocusedIndex()
    }

    function updateFocusedIndex() {
        let idx = -1
        let fs = false
        for (let i = 0; i < activeWindows.length; i++) {
            if (activeWindows[i].id === focusedWindowId) {
                idx = i
                const lay = activeWindows[i].layout
                if (lay) {
                    const ws = lay.window_size || lay.tile_size
                    if (ws && ws.length >= 2 && ws[0] >= 1915 && ws[1] >= 1075) {
                        fs = true
                    }
                }
                break
            }
        }
        focusedIndex = idx
        focusedIsFullscreen = fs
        if (!fs && focusedWindowId > 0) trappedSyncTimer.restart()
    }

    function handleEvent(line) {
        if (!line || line.trim() === "") return
        try {
            const ev = JSON.parse(line)
            if (ev.WorkspacesChanged) {
                const ws = ev.WorkspacesChanged.workspaces.slice().sort((a, b) => a.idx - b.idx)
                workspaces = ws
                for (let i = 0; i < ws.length; i++) {
                    if (ws[i].is_active || ws[i].is_focused) {
                        activeWorkspaceId = ws[i].id
                        activeWorkspaceIndex = i
                        break
                    }
                }
                recomputeWindows()
            } else if (ev.WorkspaceActivated) {
                const id = ev.WorkspaceActivated.id
                activeWorkspaceId = id
                for (let i = 0; i < workspaces.length; i++) {
                    if (workspaces[i].id === id) {
                        activeWorkspaceIndex = i
                        break
                    }
                }
                recomputeWindows()
            } else if (ev.WindowsChanged) {
                const map = {}
                let foc = focusedWindowId
                for (const w of ev.WindowsChanged.windows) {
                    map[w.id] = w
                    if (w.is_focused) foc = w.id
                }
                windowsById = map
                focusedWindowId = foc
                recomputeWindows()
            } else if (ev.WindowOpenedOrChanged) {
                const w = ev.WindowOpenedOrChanged.window
                const map = Object.assign({}, windowsById)
                map[w.id] = w
                windowsById = map
                if (w.is_focused) focusedWindowId = w.id
                recomputeWindows()
            } else if (ev.WindowClosed) {
                const id = ev.WindowClosed.id
                const map = Object.assign({}, windowsById)
                delete map[id]
                windowsById = map
                if (focusedWindowId === id) focusedWindowId = -1
                recomputeWindows()
            } else if (ev.WindowFocusChanged) {
                focusedWindowId = (ev.WindowFocusChanged.id === null || ev.WindowFocusChanged.id === undefined) ? -1 : ev.WindowFocusChanged.id
                updateFocusedIndex()
            } else if (ev.WindowLayoutsChanged) {
                const map = Object.assign({}, windowsById)
                for (const pair of ev.WindowLayoutsChanged.changes) {
                    const id = pair[0]
                    const lay = pair[1]
                    if (map[id]) {
                        map[id] = Object.assign({}, map[id], { layout: lay })
                    }
                }
                windowsById = map
                recomputeWindows()
            } else if (ev.KeyboardLayoutsChanged) {
                kbNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names || ["English (US)"]
                kbIndex = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx || 0
            } else if (ev.KeyboardLayoutSwitched) {
                kbIndex = ev.KeyboardLayoutSwitched.idx || 0
            }
        } catch (e) {
            console.warn("Niri event parse error:", e)
        }
    }

    function runDetached(cmd) {
        Quickshell.execDetached(cmd)
    }

    function findOpenWindowId(appIds) {
        if (!appIds || !windowsById) return -1
        let fallback = -1
        for (const k in windowsById) {
            const w = windowsById[k]
            if (!w || !w.app_id) continue
            const low = w.app_id.toLowerCase()
            for (let i = 0; i < appIds.length; i++) {
                if (low === appIds[i]) {
                    if (w.workspace_id === activeWorkspaceId) return w.id
                    if (fallback === -1) fallback = w.id
                }
            }
        }
        return fallback
    }

    function activateOrLaunch(appIds, launchCmd) {
        const wid = findOpenWindowId(appIds)
        if (wid !== -1) {
            focusWindow(wid)
        } else {
            runDetached(launchCmd)
        }
    }

    function clickDockItem(slotIdx, winId, isOpenHere, pinIdx, isMiddle) {
        if (pinIdx >= 0 && pinIdx < pinnedApps.length) {
            const pin = pinnedApps[pinIdx]
            if (isMiddle) {
                runDetached(pin.cmd)
            } else {
                runDetached(["__HOME__/.local/bin/m3-nav-lr", "index", String(slotIdx + 1)])
            }
            return
        }
        if (isMiddle && winId > 0) {
            closeWindow(winId)
        } else if (winId > 0) {
            focusWindow(winId)
        }
    }

    function focusWorkspace(idx) {
        runDetached(["niri", "msg", "action", "focus-workspace", String(idx)])
    }

    function focusWindow(winId) {
        runDetached(["__HOME__/.local/bin/m3-nav-lr", "focus", String(winId)])
    }

    function closeWindow(winId) {
        runDetached(["niri", "msg", "action", "close-window", "--id", String(winId)])
    }

    function switchLayout() {
        runDetached(["niri", "msg", "action", "switch-layout", "next"])
    }

    Process {
        id: niriStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => root.handleEvent(line)
        }
        onExited: (code, status) => {
            restartTimer.start()
        }
    }

    Timer {
        id: trappedSyncTimer
        interval: 120
        onTriggered: {
            if (!root.focusedIsFullscreen && root.focusedWindowId > 0) {
                root.runDetached(["__HOME__/.local/bin/m3-nav-lr", "sync"])
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: niriStream.running = true
    }
}
