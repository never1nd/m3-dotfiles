import QtQuick

NumberAnimation {
    enum Type {
        FastEffects = 0,
        DefaultEffects,
        SlowEffects,
        FastSpatial,
        DefaultSpatial,
        SlowSpatial,
        Emphasized,
        EmphasizedDecel,
        EmphasizedAccel,
        Standard
    }

    property int type: M3Anim.DefaultSpatial

    duration: {
        switch (type) {
        case M3Anim.FastEffects:     return M3Motion.fastEffects
        case M3Anim.DefaultEffects:  return M3Motion.defaultEffects
        case M3Anim.SlowEffects:     return M3Motion.slowEffects
        case M3Anim.FastSpatial:     return M3Motion.fastSpatial
        case M3Anim.SlowSpatial:     return M3Motion.slowSpatial
        case M3Anim.Emphasized:      return M3Motion.defaultSpatial
        case M3Anim.EmphasizedDecel: return M3Motion.defaultSpatial
        case M3Anim.EmphasizedAccel: return M3Motion.fastEffects
        case M3Anim.Standard:        return M3Motion.fastSpatial
        default:                     return M3Motion.defaultSpatial
        }
    }

    easing.type: Easing.BezierSpline
    easing.bezierCurve: {
        switch (type) {
        case M3Anim.FastEffects:
        case M3Anim.DefaultEffects:
        case M3Anim.SlowEffects:     return M3Motion.expressiveEffects
        case M3Anim.Emphasized:      return M3Motion.emphasized
        case M3Anim.EmphasizedAccel: return M3Motion.emphasizedAccel
        case M3Anim.Standard:        return M3Motion.standard
        default:                     return M3Motion.emphasizedDecel
        }
    }
}
