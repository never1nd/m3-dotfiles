pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string mode: "dark"
    property string scheme: "scheme-content"
    property string wallpaperName: ""
    property string wallpaperPath: ""
    property string profileId: "violet"
    property string profileName: "Фиолетовый"

    property string fontSans: "Roboto Flex"
    property string fontIcons: "Material Symbols Rounded"

    // Material Design 3 Color Roles (defaults = scheme-content dark, auto-updated from colors.json)
    property color primary: "#d0bdfd"
    property color fgPrimary: "#37275c"
    property color primaryContainer: "#594981"
    property color fgPrimaryContainer: "#e9ddff"

    property color secondary: "#ccc2de"
    property color fgSecondary: "#332d41"
    property color secondaryContainer: "#4f485f"
    property color fgSecondaryContainer: "#e8def8"

    property color tertiary: "#fdb0d4"
    property color fgTertiary: "#511d3a"
    property color tertiaryContainer: "#7a3f5e"
    property color fgTertiaryContainer: "#ffd8e8"

    property color surface: "#141317"
    property color surfaceDim: "#141317"
    property color surfaceContainerLowest: "#0f0d12"
    property color surfaceContainerLow: "#1d1b20"
    property color surfaceContainer: "#211f23"
    property color surfaceContainerHigh: "#2b292d"
    property color surfaceContainerHighest: "#363439"

    property color fgSurface: "#e6e1e8"
    property color fgSurfaceVariant: "#cac4cf"
    property color outline: "#938f99"
    property color outlineVariant: "#48454e"

    property color errorColor: "#ffb4ab"
    property color fgError: "#690005"
    property color errorContainer: "#93000a"
    property color fgErrorContainer: "#ffdad6"

    property color inverseSurface: "#e6e1e8"
    property color fgInverseSurface: "#322f35"

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function applyJson(raw) {
        if (!raw || raw.trim() === "") return
        try {
            const d = JSON.parse(raw)
            if (d._mode) mode = d._mode
            if (d._scheme) scheme = d._scheme
            if (d._wallpaper_name) wallpaperName = d._wallpaper_name
            if (d._wallpaper) wallpaperPath = d._wallpaper
            if (d._profile) profileId = d._profile
            if (d._profile_name) profileName = d._profile_name
            if (d.primary) primary = d.primary
            if (d.on_primary) fgPrimary = d.on_primary
            if (d.primary_container) primaryContainer = d.primary_container
            if (d.on_primary_container) fgPrimaryContainer = d.on_primary_container
            if (d.secondary) secondary = d.secondary
            if (d.on_secondary) fgSecondary = d.on_secondary
            if (d.secondary_container) secondaryContainer = d.secondary_container
            if (d.on_secondary_container) fgSecondaryContainer = d.on_secondary_container
            if (d.tertiary) tertiary = d.tertiary
            if (d.on_tertiary) fgTertiary = d.on_tertiary
            if (d.tertiary_container) tertiaryContainer = d.tertiary_container
            if (d.on_tertiary_container) fgTertiaryContainer = d.on_tertiary_container
            if (d.surface) surface = d.surface
            if (d.surface_dim) surfaceDim = d.surface_dim
            if (d.surface_container_lowest) surfaceContainerLowest = d.surface_container_lowest
            if (d.surface_container_low) surfaceContainerLow = d.surface_container_low
            if (d.surface_container) surfaceContainer = d.surface_container
            if (d.surface_container_high) surfaceContainerHigh = d.surface_container_high
            if (d.surface_container_highest) surfaceContainerHighest = d.surface_container_highest
            if (d.on_surface) fgSurface = d.on_surface
            if (d.on_surface_variant) fgSurfaceVariant = d.on_surface_variant
            if (d.outline) outline = d.outline
            if (d.outline_variant) outlineVariant = d.outline_variant
            if (d.error) errorColor = d.error
            if (d.on_error) fgError = d.on_error
            if (d.error_container) errorContainer = d.error_container
            if (d.on_error_container) fgErrorContainer = d.on_error_container
            if (d.inverse_surface) inverseSurface = d.inverse_surface
            if (d.inverse_on_surface) fgInverseSurface = d.inverse_on_surface
        } catch (e) {
            console.warn("Theme JSON parse error:", e)
        }
    }

    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onLoaded: root.applyJson(text())
        onFileChanged: reload()
    }
}
