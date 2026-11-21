pragma Singleton
import QtQuick

/* Official Material Design 3 Expressive Motion Tokens (Qt6 Easing.BezierSpline)
 * Adapted from Google M3 Expressive specs, end-4/dots-hyprland & caelestia-dots/shell.
 * Uses smooth zero-backjump curves (emphasized / emphasizedDecel / expressiveEffects / standard)
 * plus optional expressive spatial tokens.
 */
Singleton {
    id: motion

    // ── BezierSpline curves (Qt6 format: [x1, y1, x2, y2, 1, 1]) ──
    readonly property list<real> emphasized:       [0.05, 0.0, 2/15, 0.06, 1/6, 0.4, 5/24, 0.82, 0.25, 1.0, 1.0, 1.0]
    readonly property list<real> emphasizedDecel:  [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property list<real> emphasizedAccel:  [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property list<real> expressiveEffects:[0.34, 0.80, 0.34, 1.00, 1.0, 1.0]
    readonly property list<real> standard:         [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property list<real> standardDecel:    [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property list<real> standardAccel:    [0.3, 0.0, 1.0, 1.0, 1.0, 1.0]

    // ── Canonical MD3E Durations (ms) ──
    readonly property int fastEffects:    200
    readonly property int defaultEffects: 260
    readonly property int slowEffects:    360
    readonly property int fastSpatial:    300
    readonly property int defaultSpatial: 420
    readonly property int slowSpatial:    540
}
