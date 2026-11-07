import QtQuick
import qs.Common

// Gradient level bar with a glowing thumb. Built locally instead of using the
// stock slider so app rows can share the exact look of the master card.
Item {
    id: root

    property real value: 0
    property real maxValue: 100
    property bool muted: false
    property bool enabled: true
    property bool animate: true
    property int wheelStep: 5
    property real resetValue: 100
    property color accent: Theme.primary
    property color trackColor: Theme.withAlpha(Theme.onSurface, 0.10)
    readonly property bool motion: animate && !(typeof SettingsData !== "undefined" && SettingsData.reduceMotion)

    signal moved(real newValue)
    signal committed(real newValue)

    implicitHeight: Theme.iconSize
    readonly property real ratio: maxValue <= 0 ? 0 : Math.max(0, Math.min(1, shownValue / maxValue))
    readonly property real shownValue: dragArea.pressed ? dragValue : value

    property real dragValue: 0

    Rectangle {
        id: track
        width: parent.width
        height: Theme.spacingXS + Theme.spacingXXS
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.trackColor
    }

    Item {
        width: parent.width
        height: track.height
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        Rectangle {
            width: Math.max(0, root.ratio * parent.width)
            height: parent.height
            radius: parent.height / 2
            opacity: root.muted ? 0.35 : 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.withAlpha(root.accent, 0.55) }
                GradientStop { position: 1; color: root.accent }
            }

            Behavior on width {
                enabled: root.motion && !dragArea.pressed
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                enabled: root.motion
                NumberAnimation { duration: 160 }
            }
        }
    }

    // A translucent halo is visually equivalent to the old blurred layer at a
    // fraction of the cost: no offscreen texture per row while idle.
    Rectangle {
        id: thumbGlow
        anchors.centerIn: thumb
        width: thumb.width + Theme.spacingS
        height: width
        radius: width / 2
        color: Theme.withAlpha(root.muted ? Theme.surfaceVariantText : root.accent, 0.20)
        visible: root.enabled
        opacity: 0.8
    }

    Rectangle {
        id: thumb
        width: dragArea.pressed ? Theme.iconSizeSmall : Theme.iconSizeSmall - Theme.spacingXXS
        height: width
        radius: width / 2
        x: Math.max(0, Math.min(parent.width - width, root.ratio * parent.width - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: root.muted ? Theme.surfaceVariantText : root.accent
        border.width: Theme.outlineWidth
        border.color: Theme.withAlpha(Theme.onPrimary, 0.7)
        scale: dragArea.pressed ? 1.18 : (dragArea.containsMouse ? 1.08 : 1)
        opacity: root.enabled ? 1 : 0.4

        Behavior on x {
            enabled: root.motion && !dragArea.pressed
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            enabled: root.motion
            NumberAnimation { duration: 140; easing.type: Easing.OutBack }
        }

        Behavior on width {
            enabled: root.motion
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: root.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function valueAt(px) {
            const ratio = Math.max(0, Math.min(1, px / Math.max(1, width)));
            return Math.round(ratio * root.maxValue);
        }

        onPressed: mouse => {
            root.dragValue = valueAt(mouse.x);
            root.moved(root.dragValue);
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            root.dragValue = valueAt(mouse.x);
            root.moved(root.dragValue);
        }

        onReleased: root.committed(root.dragValue)

        onDoubleClicked: {
            root.dragValue = Math.min(root.resetValue, root.maxValue);
            root.moved(root.dragValue);
            root.committed(root.dragValue);
        }

        onWheel: wheel => {
            if (!root.enabled)
                return;
            const direction = wheel.angleDelta.y !== 0 ? (wheel.angleDelta.y > 0 ? 1 : -1) : (wheel.angleDelta.x > 0 ? -1 : 1);
            const next = Math.max(0, Math.min(root.maxValue, Math.round(root.value) + direction * root.wheelStep));
            root.moved(next);
            root.committed(next);
            wheel.accepted = true;
        }
    }
}
