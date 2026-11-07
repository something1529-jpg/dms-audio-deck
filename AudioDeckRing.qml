import QtQuick
import QtQuick.Shapes
import qs.Common

// Animated circular gauge. The soft outer arc is the glow; the inner arc is
// the value, so the whole thing reads at pill size and at card size.
Item {
    id: root

    property real value: 0
    property real maxValue: 100
    property real strokeWidth: Theme.outlineWidth * 3
    property color ringColor: Theme.primary
    property color trackColor: Theme.withAlpha(Theme.onSurface, 0.12)
    property bool animated: true
    property real startAngle: -90
    property real spanAngle: 360

    readonly property real ratio: maxValue <= 0 ? 0 : Math.max(0, Math.min(1, value / maxValue))
    readonly property real radius: Math.max(0, Math.min(width, height) / 2 - strokeWidth * 1.2)
    property real sweep: ratio * spanAngle

    Behavior on sweep {
        enabled: root.animated && !(typeof SettingsData !== "undefined" && SettingsData.reduceMotion)
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngle
                sweepAngle: root.spanAngle
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.sweep > 0.2 ? Theme.withAlpha(root.ringColor, 0.20) : "transparent"
            strokeWidth: root.strokeWidth * 2.4
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngle
                sweepAngle: Math.max(0, root.sweep)
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.sweep > 0.2 ? root.ringColor : "transparent"
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: root.startAngle
                sweepAngle: Math.max(0, root.sweep)
            }
        }
    }
}
