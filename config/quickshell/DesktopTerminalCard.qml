import QtQuick
import Quickshell
import Quickshell.Wayland

/* Rounded 28px Material Design 3 Expressive Desktop Card backing kitty-desktop
 * Uses the exact same vibrant tonal surfaceContainer + subtle ambient wash as DesktopMusicWidget
 * so it ALWAYS looks active, bright, and cohesive with the music widget above it!
 */
PanelWindow {
    id: termCard
    anchors {
        top: true
        right: true
    }
    margins {
        top: 556
        right: 40
    }
    implicitWidth: 880
    implicitHeight: 496
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "m3-desktop-terminal-card"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        radius: 28
        color: Theme.alpha(Theme.surfaceContainer, 0.90)
        border.width: 1
        border.color: Theme.alpha(Theme.primary, 0.34)
        clip: true

        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }

        // Subtle matching M3 Expressive tonal wash (always looks alive & active!)
        Rectangle {
            anchors.fill: parent
            radius: 28
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.alpha(Theme.primaryContainer, 0.22) }
                GradientStop { position: 0.55; color: Theme.alpha(Theme.tertiaryContainer, 0.12) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
}
